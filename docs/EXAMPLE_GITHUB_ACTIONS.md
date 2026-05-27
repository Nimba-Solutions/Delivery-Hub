# Example GitHub Actions — Dev-Loop Mirror (Layer 6)

Copy-paste starters for wiring a subscriber's GitHub repo into the Delivery
Hub's dev-loop cockpit. Two workflows ship under `.github/workflows/`:

| File | Trigger | Endpoint |
|---|---|---|
| `example-scratch-org-create.yml` | `pull_request: [opened, synchronize]` | `POST /scratch-orgs` |
| `example-scratch-org-decommission.yml` | `pull_request: [closed]` | `PATCH /scratch-orgs/{id}` |

> Both files ship with `if: false` AND a `branches: ['__never-matches__']`
> filter so they never run inside the Delivery Hub's own CI. They are meant to
> be copied into a subscriber's repo, not executed in this one.

## What it does

When a subscriber dev opens a PR, the create workflow provisions a scratch org
(via your existing CumulusCI step) and POSTs a `ScratchOrgInstance__c` row
into the Delivery Hub org. The DH cockpit's `deliveryDevLoopGuide` LWC then
shows the org alongside the matching `WorkItem__c` (matched by branch name,
when you pass `workItemName` in the body). When the PR closes, the
decommission workflow PATCHes the row to `state=Decommissioned` so the cockpit
can hide or sweep it.

> **Auto-create option:** the `deliveryDevLoopGuide` LWC only shows scratch
> orgs that are linked to a `WorkItem__c`. If you open PRs for branches that
> don't yet have a matching WI, pass `"autoCreateWorkItem": true` in the POST
> body and the endpoint will insert a stub WI (Status `New`, Stage `Backlog`,
> current API caller assigned as Developer, branch stored in `BranchTxt__c`)
> and link the scratch to it. The default (`false` / omitted) preserves the
> original PR #804 behavior: scratch row created, but unlinked when the name
> doesn't match. Closes the Flow 6 #2 audit gap.

## What you need

1. **A Delivery Hub instance URL.** The base URL of your DH org, e.g.
   `https://my-dh-instance.my.salesforce.com`. The workflow appends
   `/services/apexrest/delivery/deliveryhub/v1/api/scratch-orgs` to it.
2. **An API key.** Generate a `NetworkEntity__c` row in your DH org and
   capture its `ApiKeyTxt__c` value (`DeliveryPublicApiService.generateApiKey()`
   helper exists for this). The DH public REST API authenticates via an
   `X-Api-Key` header — it does NOT use a Salesforce session, OAuth Bearer
   token, or Named Credential.
3. **Two GitHub secrets in the subscriber repo:**
   - `DH_BASE_URL` — the URL from step 1
   - `DH_API_KEY` — the key from step 2

## Adoption checklist

- [ ] Copy `example-scratch-org-create.yml` and
      `example-scratch-org-decommission.yml` into your repo's `.github/workflows/`.
- [ ] Add the `DH_BASE_URL` + `DH_API_KEY` secrets.
- [ ] In each workflow, remove the `if: false` line on the job AND change the
      `branches: ['__never-matches__']` filter to your real branch patterns (or
      delete it to fire on every PR).
- [ ] Replace the `Provision scratch org (stub — replace with your tooling)`
      step in the create workflow with your actual CumulusCI (or other) scratch
      provisioning step. Capture its `orgId`, `loginUrl`, and `cciFlow` as step
      outputs the POST step can read.
- [ ] Decide how to persist the returned `data.id` between the create and
      decommission runs (job artifact, repo variable keyed by PR number, a
      comment on the PR, etc.) and update the decommission workflow's `lookup`
      step accordingly.
- [ ] Open a throw-away PR to verify a `ScratchOrgInstance__c` row appears in
      the DH cockpit, then close it to verify the row flips to
      `Decommissioned`.

## Endpoint contract (POST)

```
POST {DH_BASE_URL}/services/apexrest/delivery/deliveryhub/v1/api/scratch-orgs
X-Api-Key: <ApiKeyTxt__c>
Content-Type: application/json

{
  "orgId":              "<required — Salesforce 15/18-char scratch org id>",
  "branch":             "<optional — git branch name>",
  "loginUrl":           "<optional — scratch login URL from cci org info>",
  "cciFlow":            "<optional — cumulusci flow that built the org>",
  "workItemName":       "<optional — WorkItem__c.Name to link the row to>",
  "expiresAt":          "<optional — ISO-8601 timestamp>",
  "autoCreateWorkItem": "<optional boolean — default false. When true AND workItemName doesn't match an existing WI, inserts a stub WI so the scratch is visible in deliveryDevLoopGuide.>"
}
```

Success (201):

```json
{
  "success": true,
  "data": {
    "id": "a01XX...",
    "state": "Active",
    "workItemId": "a04XX...",
    "workItemAutoCreated": true
  }
}
```

`workItemId` is `null` when no link was made; `workItemAutoCreated` is `true`
only when this call inserted a brand-new stub WI (false for both
known-name-matched and not-linked outcomes).

Error (400/500):

```json
{ "success": false, "error": "<message>" }
```

### Alternative POST — auto-stub the WI for unknown branches

For teams that want every PR branch to surface in the cockpit without
pre-creating a `WorkItem__c`, set `autoCreateWorkItem: true`:

```bash
curl -s -X POST \
  -H "X-Api-Key: $DH_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "orgId": "00DSB000005xY1z",
    "branch": "feature/new-experimental-thing",
    "loginUrl": "https://scratch-org-12345.my.salesforce.com",
    "cciFlow": "ci_feature",
    "workItemName": "feature/new-experimental-thing",
    "autoCreateWorkItem": true
  }' \
  "$DH_BASE_URL/services/apexrest/delivery/deliveryhub/v1/api/scratch-orgs"
```

The stub WI ships at `Status='New'` / `Stage='Backlog'` and is assigned to the
API caller (`DeveloperLookup__c = UserInfo.getUserId()` of whatever user owns
the X-Api-Key's `NetworkEntity__c`). A DH admin can groom it from the board
later.

## Pairing PATCH — decommission on PR close

`example-scratch-org-decommission.yml` fires on `pull_request: [closed]` and
PATCHes the row to mark it for cleanup. You need the `ScratchOrgInstance__c.Id`
the create workflow received (see the persistence note in the adoption
checklist above) — pass it on the URL path, and POST `{ "state":
"Decommissioned" }` in the body. The DH cockpit's sweeper picks up
non-Active rows past their `ExpiresDateTime__c`.

```
PATCH {DH_BASE_URL}/services/apexrest/delivery/deliveryhub/v1/api/scratch-orgs/{id}
X-Api-Key: <ApiKeyTxt__c>
Content-Type: application/json

{
  "state":      "<required — one of the ScratchOrgState GVS values>",
  "lastSyncAt": "<optional — ISO-8601 timestamp>"
}
```

## Reference

The single source of truth for the endpoint contract is
[`force-app/main/default/classes/DeliveryPublicApiService.cls`](../force-app/main/default/classes/DeliveryPublicApiService.cls).
See in particular `postScratchOrg` (≈ line 662) and `patchScratchOrg`
(≈ line 713), plus the `handlePost` / `handlePatch` routers near the top of
the file for the auth + rate-limit gates that wrap both endpoints.

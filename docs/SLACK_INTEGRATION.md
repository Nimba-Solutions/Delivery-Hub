# Slack Comment Sync

Two-way bridge between WorkItemComment__c records and a Slack channel. Operator opts in per org via `DeliveryHubSettings__c.EnableSlackCommentSyncDateTime__c`. Default off.

## What it does

- **Outbound** — every new `WorkItemComment__c` insert is fanned out to the configured Slack channel via incoming webhook. Each callout posts a single batched Block Kit message containing all comments from the same transaction (WI Name → record link → author → body).
- **Inbound** — Slack messages that mention a WorkItem Name (e.g. `T-0123`) are mirrored back as comments on that WI. AuthorTxt is tagged `Slack: <user-id>`, SourcePk is `API`, and the body carries a footer `(via Slack channel C…)` so operators can trace the source.

## Production Activation Runbook

Use this section to flip the feature on for the first time on a production org (dh-prod, nimba, or MF-Prod). Default is OFF in every org. Order matters: do the Slack-side config first, then the Salesforce-side flip. ~20 minutes if you have admin access to both sides.

### Step 1 — Create the Slack app

1. Go to https://api.slack.com/apps → **Create New App** → **From Scratch**.
2. Name it `Delivery Hub Sync` (or whatever you want shown in the channel), pick the target workspace, **Create App**.
3. Stay on the new app's settings page; you'll come back to it in Step 3 and Step 5.

### Step 2 — Enable Incoming Webhooks (outbound from DH → Slack)

1. In the left nav, **Incoming Webhooks** → toggle **Activate Incoming Webhooks** ON.
2. Click **Add New Webhook to Workspace**, pick the channel that should receive comments, **Allow**.
3. Copy the resulting webhook URL — it looks like `https://hooks.slack.com/services/T.../B.../...`. You'll paste this into Salesforce in Step 6.

### Step 3 — Enable Event Subscriptions (inbound Slack → DH)

1. In the left nav, **Event Subscriptions** → toggle **Enable Events** ON.
2. **Request URL** — paste the org's Slack-facing endpoint:
   - dh-prod / nimba / MF-Prod (installed-package orgs): `<your-site-url>/services/apexrest/delivery/deliveryhub/v1/webhook/Slack_Webhook`
   - scratch / unmanaged dev orgs: `<your-site-url>/services/apexrest/deliveryhub/v1/webhook/Slack_Webhook` (no `delivery/` namespace segment)
   - `<your-site-url>` is the Salesforce Site URL — see Step 4 if you haven't set one up yet.
   - **You won't be able to save this until Step 4 + Step 5 are done.** Slack POSTs a `challenge` payload to verify the URL — the receiver echoes it back automatically, but only if the Site Guest User has Apex access to `DeliveryWebhookReceiverApi` (granted by the `Delivery Hub Guest User` permission set) AND the `Slack_Webhook` IntegrationProvider record has `EnabledDateTime__c` populated.
3. Under **Subscribe to bot events**, add `message.channels` for public channels (or `message.groups` for private channels, or both). Save changes.
4. **Install App** → **Install to Workspace** → **Allow**. Slack will issue a Bot User OAuth Token; you don't need it for the comment sync (signing-secret based verification only), but you do need the install step to make the bot a workspace member.
5. **Invite the bot to the channel** in Slack: `/invite @Delivery Hub Sync` in the target channel, otherwise inbound `message.channels` events won't fire for that channel.

### Step 4 — Confirm the Salesforce Site exposes the receiver

The `@RestResource(urlMapping='/deliveryhub/v1/webhook/*')` endpoint is on `DeliveryWebhookReceiverApi`. For Slack to reach it, the org needs a Salesforce Site whose Guest User has Apex class access to the receiver chain (added to `Delivery Hub Guest User` permission set in this release — verify it's been applied to your Site's Guest User profile).

1. **Setup → Sites** — confirm a site exists (the same one serving the public Delivery Hub status page or portal works). Note its URL (`https://<your-org>.my.site.com/<site-path>`).
2. **Public Access Settings** → assign the `Delivery Hub Guest User` permission set if not already assigned.
3. Verify the URL resolves: `curl -sS -X POST '<your-site-url>/services/apexrest/delivery/deliveryhub/v1/webhook/Slack_Webhook' -H 'Content-Type: application/json' -d '{}'` should return a JSON body with `"status":401` or `"status":404` (NOT a Salesforce login page). If you see a login HTML page, the Site isn't exposing the route — re-check Public Access Settings.

### Step 5 — Paste the Slack signing secret into the IntegrationProvider record

The signing secret is a SECRET — paste it directly into Setup, never into source control.

1. In Slack app config → **Basic Information** → **App Credentials** → **Signing Secret** → **Show** → copy.
2. In Salesforce: **Setup → Custom Metadata Types → Integration Provider → Manage Records → Slack Webhook → Edit**.
3. Fill in:
   - **Signature Secret** (`SignatureSecretTxt__c`) — paste the Slack signing secret from the previous step.
   - **Enabled DateTime** (`EnabledDateTime__c`) — set to **NOW** (any non-null DateTime activates the inbound route). Without this, `DeliveryWebhookEventRouter.findInbound` returns null and the receiver responds 404.
4. **Save**.
5. Back in Slack: **Event Subscriptions** → click **Retry** next to the Request URL. It should turn green ("Verified"). If it doesn't, run the `curl` test in Step 7 below to see the actual error response.

### Step 6 — Flip outbound on with anonymous Apex

Subscriber orgs: prefix custom-setting fields with `delivery__` because the managed package owns them. Paste into **Setup → Developer Console → Debug → Open Execute Anonymous Window**, replace the webhook URL, and run:

```apex
// Run on the target org (dh-prod / nimba / MF-Prod).
// Replace the URL with the one you copied in Step 2.
delivery__DeliveryHubSettings__c s = delivery__DeliveryHubSettings__c.getOrgDefaults();
s.delivery__SlackWebhookUrlTxt__c = '[REPLACE WITH SLACK WEBHOOK URL]';
s.delivery__EnableSlackCommentSyncDateTime__c = DateTime.now();
upsert s;
System.debug('Slack comment sync enabled at ' + s.delivery__EnableSlackCommentSyncDateTime__c
    + ' with webhook ' + s.delivery__SlackWebhookUrlTxt__c.substring(0, 40) + '…');
```

> **For non-namespaced dev orgs (scratch / unmanaged)**, drop the `delivery__` prefix on every field reference and on the SObject type.

### Step 7 — End-to-end smoke test

See `## Smoke Test (run after activation)` below for the 4-step happy path AND a `curl` command that hits the inbound endpoint with a valid Slack signature (so you can prove the inbound side independently of Slack's UI).

## Loop prevention

The inbound handler tags every mirrored comment with `AuthorTxt__c = "Slack: …"`. The outbound trigger handler (`DeliveryWorkItemCommentTriggerHandler.postCommentsToSlack`) skips any comment whose author starts with `"Slack"`. That single discriminator breaks the inbound → outbound → inbound loop without a recursion guard or de-dup table.

## Smoke Test (run after activation)

End-to-end happy path. Run these in order — if Step 1 doesn't show up in Slack, do NOT proceed to Step 3 until you fix outbound (see "Troubleshooting" below).

### 1. Outbound: Salesforce → Slack

Pick a real WorkItem Id from the target org and run in Execute Anonymous (subscriber-org form):

```apex
WorkItem__c wi = [SELECT Id, Name FROM delivery__WorkItem__c LIMIT 1];
insert new delivery__WorkItemComment__c(
    delivery__WorkItemId__c = wi.Id,
    delivery__BodyTxt__c    = 'Outbound smoke test from ' + UserInfo.getName(),
    delivery__AuthorTxt__c  = UserInfo.getName()
);
System.debug('Posted comment under ' + wi.Name + ' — expect it in Slack within ~10s.');
```

**Expect**: a Block Kit message lands in the bound Slack channel within ~10s, containing the WI Name as a link, the author, and the body. If nothing appears, see Troubleshooting.

### 2. Inbound: Slack → Salesforce (via Slack UI)

In the Slack channel where the bot is invited, post:

```
T-0123 quick test from Slack
```

(Replace `T-0123` with a real WorkItem Name in the target org.)

**Expect**: a new `WorkItemComment__c` on `T-0123` within ~5s. `AuthorTxt__c` = `"Slack: U…"` (your Slack user id). `BodyTxt__c` ends with `(via Slack channel C…)`. `SourcePk__c` = `'API'`.

### 3. Inbound: Slack → Salesforce (via curl, no UI)

Use this when Slack's UI says "Verified" but you want to confirm the message-handler chain end-to-end without waiting for a real Slack event. You need to compute the `X-Slack-Signature` manually because the signing secret is paired to the body.

Save the signing secret to an env var so it never lands in shell history:

```bash
read -s SLACK_SIGNING_SECRET
# paste the secret, press enter
export SLACK_SIGNING_SECRET
```

Then run (substitute `<your-site-url>` and `<T-NNNN>`):

```bash
SITE_URL='<your-site-url>'                                                            # e.g. https://example.my.site.com
ENDPOINT="$SITE_URL/services/apexrest/delivery/deliveryhub/v1/webhook/Slack_Webhook"  # drop "delivery/" on scratch orgs
WI_NAME='T-0123'                                                                      # real WorkItem Name on the org
TS="$(date +%s)"
BODY=$(cat <<EOF
{"type":"event_callback","event":{"type":"message","user":"U_CURL_TEST","channel":"C_TEST","text":"${WI_NAME} curl smoke test","ts":"${TS}.000001"}}
EOF
)
BASE="v0:${TS}:${BODY}"
SIG="v0=$(printf '%s' "$BASE" | openssl dgst -sha256 -hmac "$SLACK_SIGNING_SECRET" | awk '{print $2}')"

curl -sS -X POST "$ENDPOINT" \
  -H 'Content-Type: application/json' \
  -H "X-Slack-Request-Timestamp: ${TS}" \
  -H "X-Slack-Signature: ${SIG}" \
  --data "$BODY"
```

**Expect**:
- HTTP 200 with `{"status":200,"message":"...","recordId":"a0..."}` — the `recordId` is the new `WorkItemComment__c`.
- A new `WorkItemComment__c` on the referenced WI within seconds. `AuthorTxt__c = "Slack: U_CURL_TEST"`, `SourcePk__c = "API"`, body footer `(via Slack channel C_TEST)`.

**Failure modes worth recognizing:**
- `{"status":401,"message":"Signature verification failed: ..."}` — signing secret pasted wrong, OR `EnabledDateTime__c` is null on the IntegrationProvider record, OR the body in your curl differs by even one byte from what you signed (use the same `$BODY` variable both places).
- `{"status":404,"message":"No inbound IntegrationProvider__mdt for Slack_Webhook"}` — `EnabledDateTime__c` is null. Set it in Setup → Custom Metadata Types → Integration Provider → Slack Webhook.
- HTML login page in the response — the Site Guest User doesn't have Apex access to `DeliveryWebhookReceiverApi`. Re-assign `Delivery Hub Guest User` permission set to the Site's Guest User profile.

### Troubleshooting outbound silence

If Step 1 doesn't deliver to Slack:

1. **Check `AsyncApexJob`** in Setup → Apex Jobs for a recent `DeliverySlackService.postCommentBatch` entry — if it shows "Failed" with a callout exception, the webhook URL is bad. If it doesn't appear at all, the trigger gate is wrong (see #2).
2. **Confirm the gate** — run in Execute Anonymous:
   ```apex
   DeliveryHubSettings__c s = DeliveryHubSettings__c.getOrgDefaults();
   System.debug('EnableSlackCommentSyncDateTime__c=' + s.EnableSlackCommentSyncDateTime__c);
   System.debug('SlackWebhookUrlTxt__c=' + s.SlackWebhookUrlTxt__c);
   ```
   Both must be non-null. If they aren't, re-run the Step 6 anon Apex from the activation runbook.
3. **Test the webhook URL directly** from the Settings LWC (the existing `DeliverySlackService.testWebhook` AuraEnabled method posts a "connected" message). If that fails with `Failed (404)` or similar, the webhook URL is wrong — re-copy it from Slack app config → Incoming Webhooks.

## Security

- **HMAC-SHA256 signature verification** on every inbound request, using Slack's `v0:<timestamp>:<body>` signing base. Implemented in `WebhookSignatureVerifier.verifySlack`. Replay protection: timestamps older than 5 minutes are rejected.
- **No bot-user auth needed** for inbound — Slack signs each event with the signing secret, no per-user token.
- **Outbound** uses Slack incoming webhooks (long-lived URL credential, scope-locked to one channel). Rotate the URL in Slack if compromised; paste the new URL into `SlackWebhookUrlTxt__c`.

## Known limits (v1)

- **Single channel per org.** All outbound comments go to the channel bound to `SlackWebhookUrlTxt__c`. Per-WorkItem or per-NetworkEntity channel routing is on the v1.5 roadmap.
- **WorkItem lookup is by Name only** (`T-NNNN` pattern). Slack thread routing and `<https://...|T-0123>` linkbacks are v1.5.
- **No Slack-User → Salesforce-User mapping.** Inbound author tags as `Slack: <user-id>`. v1.5 will support a `SlackUserMapping__mdt` lookup.
- **No reaction → status sync.** Adding a reaction in Slack does not flip a WI stage. Future feature.
- **Outbound payload includes the record-page URL.** Subscriber-org users without WI read permission will hit Login on click — handle via your existing permission set assignments.

## Disabling

```apex
// Subscriber-org form — drop the delivery__ prefix on scratch/unmanaged orgs.
delivery__DeliveryHubSettings__c s = delivery__DeliveryHubSettings__c.getOrgDefaults();
s.delivery__EnableSlackCommentSyncDateTime__c = null;   // outbound off
update s;
```

For inbound, set the IntegrationProvider record's `EnabledDateTime__c` to null in **Setup → Custom Metadata Types → Integration Provider → Slack Webhook**.

## Files

- `classes/DeliverySlackService.cls` — outbound poster (`postCommentBatch`)
- `classes/DeliverySlackInboundHandler.cls` — inbound `IWebhookEventHandler`
- `classes/DeliveryWorkItemCommentTriggerHandler.cls` — trigger hook
- `classes/WebhookSignatureVerifier.cls` — Slack signing extension (`verifySlack`)
- `classes/DeliveryWebhookReceiverApi.cls` — generic challenge echo (URL verification)
- `classes/DeliveryWebhookEventRouter.cls` — slug → IntegrationProvider lookup + handler dispatch
- `customMetadata/IntegrationProvider.Slack_Webhook.md-meta.xml` — inbound config
- `objects/DeliveryHubSettings__c/fields/EnableSlackCommentSyncDateTime__c.field-meta.xml` — opt-in flag
- `objects/WorkItemComment__c/fields/SourcePk__c.field-meta.xml` — currently uses `'API'` for Slack-origin comments; extend with `'Slack'` value in v1.5 when migrating to GlobalValueSet
- `permissionsets/DeliveryHubGuestUser.permissionset-meta.xml` — grants Apex access on the four Slack-inbound classes to the Site Guest User (required for Slack to reach the `@RestResource` endpoint)

## Reference

- Slack Events API: https://api.slack.com/apis/connections/events-api
- Slack signing secrets: https://api.slack.com/authentication/verifying-requests-from-slack
- Slack Block Kit: https://api.slack.com/block-kit

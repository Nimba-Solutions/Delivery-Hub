# Cross-Org Sync — PROVEN & Documented (2026-07-13)

> The months-long blocker is resolved. **Bidirectional cross-org sync works**, demonstrated end-to-end
> on a fresh scratch org ↔ dh-prod, both directions, with real WorkItem records. It needed **zero new
> code** — only three field settings and the poller that already runs on install. This doc is the
> single source of truth for how sync works, the criteria to make it work, and the proof.

---

## 1. THE PROOF (2026-07-13, ~14:20–14:22 UTC)

Two orgs: **child** = `DHglen2` scratch org (non-namespaced, `test-kjfqdxzloott`), **mothership** =
`dh-prod` (namespaced `delivery__`, live Force.com Site `Deliver_Hub_Mothership`).

| Direction | Created where | Record | Landed where | Mechanism |
|-----------|---------------|--------|--------------|-----------|
| **Forward** (child→mothership) | DHglen2 | "FORWARD-PATH-PROOF child to mothership" | dh-prod as **T-1089** | outbound SyncItem → **PUSH** (HTTP POST to mothership Site) → `Synced` |
| **Return** (mothership→child) | dh-prod | "RETURN-PATH-PROOF cross-org pull test" (T-1087) | DHglen2 as **T-0000** | mothership stages SyncItem → child **PULLS** via poller |

Yesterday (2026-07-11) the child's handshake also created NetworkEntity `a02fj00000jTStdAAG`
("DHglen2 Probe Child") in dh-prod — proving the connection/identity leg.

**Nothing was hand-patched.** Each record was created by the real engine and moved by the real
transport. Both directions verified by SOQL on both orgs.

---

## 2. THE TWO MODES (Glen's design, confirmed correct by code + two independent audits)

Sync has **two transport modes, backwards-compatible, selectable per connection**:

### Mode A — **Push/Pull** (DEFAULT, the reliable one, needs NO Site on the spoke)
- **Spoke → Hub = PUSH:** the spoke's `DeliverySyncItemProcessor` POSTs the SyncItem to the hub's
  public Site REST endpoint. (Spoke makes an *outbound* callout — no inbound endpoint needed on the spoke.)
- **Hub → Spoke = PULL:** the hub **stages** the SyncItem (`StatusPk__c='Staged'`). The spoke's
  `DeliveryHubPoller.pollUpdates()` (scheduled every 15 min by `DeliveryHubScheduler`, armed on install
  by `DeliveryHubInstallHandler.scheduleAll()`) does an *outbound* `GET {hub}/sync/changes?since=…&clientId=…`,
  ingests the results via `DeliverySyncItemIngestor.processInboundItem`, and advances its watermark
  (`LastInboundSyncDateTime__c`).
- **Why this is the default:** a spoke org needs **no public Site, no guest user, no inbound
  reachability** — it only ever calls *out*. This is what makes "install free anywhere and it just
  syncs" achievable as a pure package install.

### Mode B — **Push/Push** (OPTIONAL, "instant", flag-gated)
- Enabled by stamping `EnableVendorPushDateTime__c` (a DateTime toggle) **and** a reachable
  `IntegrationEndpointUrlTxt__c` on the destination NetworkEntity.
- When set, the hub PUSHES to the spoke instead of staging — near-instant propagation.
- **Requirement / caveat:** push-to-spoke only works if the spoke exposes a **public Site** guest
  REST endpoint, because unauthenticated Apex REST is reachable *only* through a Site domain (a POST to
  a bare My-Domain host is rejected `INVALID_SESSION_ID` before Apex runs). `CustomSite` is **not a
  packageable component** in 2GP unlocked/managed packages, so this tier requires the subscriber to
  stand up a Site post-install (the `unpackaged/post/sites/Delivery_Hub.site-meta.xml` piece) — or a
  Nimba-style relay server (see §6). This is why Mode B is the *upgrade*, not the default.

**The critical routing rule (this is what had sync broken):** the hub decides push-vs-stage by
whether the destination entity has an `IntegrationEndpointUrlTxt__c`. If a handshake stamps an
endpoint on a spoke that can't actually receive a push (no Site), every hub→spoke item takes the push
path, 401s, and dies — and the pull channel stays starved because the item never becomes `Staged`.
**For Mode A, the destination (spoke) entity at the hub must have `IntegrationEndpointUrlTxt__c` BLANK**
so items stage for pull. (`requeueStagedItemsWithEndpoint` in the scheduler will re-queue staged items
if an endpoint is present — so the blank endpoint is load-bearing for pull.)

---

## 3. THE CRITERIA (exact config that makes a connection sync — Mode A)

For a **spoke ↔ hub** pair, per direction:

**On the SPOKE, its NetworkEntity representing the HUB (type `Vendor`/`Both`):**
- `StatusPk__c = 'Active'`
- `IntegrationEndpointUrlTxt__c` = hub Site REST **base** (e.g. `https://…my.salesforce-sites.com/services/apexrest/delivery/deliveryhub/v1`). The poller appends `/sync/changes`.
- `RemoteExternalIdTxt__c` = **the hub-side NetworkEntity Id that represents this spoke** (the poller sends it as `clientId`; the hub filters staged items to `WorkItemLookup__r.ClientNetworkEntityLookup__c = clientId`). **The poller hard-skips if this is blank.**

**On the HUB, its NetworkEntity representing the SPOKE (type `Client`/`Both`):**
- `StatusPk__c = 'Active'`, `ConnectionStatusPk__c = 'Connected'` (spoke pushes 401 until Connected).
- `IntegrationEndpointUrlTxt__c` = **BLANK** for Mode A (so hub→spoke items stage for pull).

**On each WorkItem that should cross:** `ClientNetworkEntityLookup__c` must point at the destination
NetworkEntity. Hub-originated items must have this set explicitly (inbound-created ones are
auto-stamped; vendor-created ones are not — this is the #1 "why isn't it syncing" gotcha).

**Scheduler running:** `DeliveryHubScheduler.scheduleAll()` (auto on install; every 15 min). Force a
tick anytime with anonymous `DeliveryHubPoller.pollUpdates();` (spoke) — no need to wait.

---

## 4. REPRODUCE IT YOURSELF (the exact steps that produced the proof above)

```bash
# --- arm the connection (data only) ---
# SPOKE: tell the poller who it is to the hub (clientId)
sf data update record --sobject NetworkEntity__c --record-id <spokeVendorEntity> \
  --values "RemoteExternalIdTxt__c=<hubEntityIdForThisSpoke>" --target-org <spoke>
# HUB: approve the connection
sf data update record --sobject delivery__NetworkEntity__c --record-id <hubEntityIdForThisSpoke> \
  --values "delivery__ConnectionStatusPk__c=Connected" --target-org <hub>
#   (leave the hub entity's IntegrationEndpointUrlTxt__c BLANK for pull mode)

# --- RETURN test: create in hub, pull to spoke ---
# HUB anon apex: insert delivery__WorkItem__c with ClientNetworkEntityLookup__c=<hubEntityIdForThisSpoke>
# SPOKE anon apex: DeliveryHubPoller.pollUpdates();   → "Success: Synced N items."
sf data query --target-org <spoke> -q "SELECT Name, BriefDescriptionTxt__c FROM WorkItem__c"

# --- FORWARD test: create in spoke, push to hub ---
# SPOKE anon apex: insert WorkItem__c with ClientNetworkEntityLookup__c=<spokeVendorEntity>
sf data query --target-org <hub> -q "SELECT Name, delivery__BriefDescriptionTxt__c FROM delivery__WorkItem__c"
```

Known-benign noise: the poller logs caught `Invalid field WorkItemId__c for SyncItem__c`
exceptions (dynamic FK put/get probing bare+namespaced field names); they're handled, sync still
reports success. Non-fatal, but worth silencing later.

---

## 5. DAISY-CHAINING (client → me → subcontractor → …)

The engine is built for multi-hop relay, not just two orgs:
- **`GlobalSourceId`** travels with every record so any org in the chain can recognize a record it
  originated and **suppress echoes** (`DeliverySyncEngine`: `blockedOrigins`/`globalSourceId` checks,
  and the inbound-relay gate "don't echo back to the org that sent us this record").
- A middle org (you) can be **both** a `Client` (to your client) **and** a `Vendor` (to your
  subcontractor) — `EntityTypePk__c = 'Both'` — so a record flows A → B, and B relays it → C, with
  each hop deduped by `GlobalSourceId` and content-hash (WorkLog idempotency protects billing).
- **Proven so far:** 2-org duplex (A ↔ B). **Next verification:** a 3-org chain (A → B → C) to
  demonstrate the relay + echo-suppression end-to-end. The machinery is present; it needs the same
  data-wiring as §3 applied twice, then a create at A observed arriving at C.

This is the product thesis: install free anywhere, wire connections however you subcontract, and work
flows along the chain. Zero barrier to entry; a spoke needs nothing but outbound HTTPS.

---

## 6. MVP THIS WEEK + WORKING WITH DAVID

**MVP (demonstrable to a buyer this week):** the two-org Mode-A round trip above, driven through the
UI instead of anon apex — install DH in a client org, run Quick Setup (handshake → `scheduleAll`),
create a ticket in the client, watch it appear in the vendor hub, comment in the hub, watch it pull
back. **No Site build, no new code required for the demo.** One small product PR to make it turnkey:
have the handshake NOT advertise a spoke endpoint by default (so hub→spoke defaults to stage/pull),
i.e. Mode A is the out-of-box default and Mode B is opt-in. (Today it's armed by data edits; the PR
makes it automatic.)

**Where David's Nimba fits — cleanly, on the two gaps pull does NOT close:**
1. **Org spin-up / toolchain** — the install path (cci auth bug, sf false-green, silent field drops)
   is the real pain. David's Nimba (Node port of the cci/sf toolchain, API-callable) is exactly the
   "generate a scratch org / run tests / cut a release from a button" layer DH would call out to.
2. **Mode B instant-push relay** — since a spoke can't host a packageable Site, the "instant" tier can
   route hub→spoke pushes through a Nimba relay server instead of requiring each spoke to stand up a
   Site. This is the natural home for David's "DH makes API calls to a Nimba server" vision.

**Question to bring David (his metadata-deploy point):** confirmed — `CustomSite` is **not**
packageable in 2GP, and even a scripted mdapi Site deploy needs the subscriber to have registered a
Force.com Sites domain first (a manual Setup step, no metadata API). So Mode B can't ship as pure
package metadata. **This is the concrete thing to design with David:** either (a) a guided post-install
"create your Site" step for self-hosted instant-push, or (b) a Nimba relay so spokes never need a Site.
Mode A (default) sidesteps it entirely and works today.

---

## Audit trail
Diagnosis independently corroborated by two models (Codex + Fable) reviewing the full repo + a digest
of all 400 merged 2026 PRs. Both converged on "use the existing hub-spoke pull, don't build a Site."
Fable additionally identified the endpoint-poisons-pull routing bug (§2). Root cause of the historical
"sync is broken" fog: the Apr-26 rewrite (#700→#702) interleaved push+pull transports without owning
the routing decision between them, and fresh spokes were advertised endpoints they couldn't receive on.

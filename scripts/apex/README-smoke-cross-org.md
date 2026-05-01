# Cross-org sync smoke test

Three coordinated anonymous-Apex scripts that prove an end-to-end round-trip is alive on the cross-org sync mesh. Built after the 2026-04-30 four-PR sync arc and the 2026-05-01 reconciler namespace bug — both classes of bug would have shown up here within minutes if this had existed.

## When to run

- **After every promote+install** to verify the freshly-installed build still routes records cleanly between orgs.
- **When the health dashboard shows Failed counts climbing** — confirms the bug is in the live wire, not just stale data.
- **Before pushing a PR that touches `DeliverySyncEngine`, `DeliverySyncItemIngestor`, `DeliverySyncReconciler`, or any `*TriggerHandler` whose `syncFields` change.**

## Topology assumed

```
sender ──Outbound──► receiver
                ◄── Inbound
```

The current production mesh: **MF-Prod ↔ Nimba ↔ dh-prod**. Pick a sender + receiver pair and run.

## Steps

```bash
# 1. SENDER — insert tagged records under a routed WorkRequest.
sf apex run --target-org MF-Prod --file scripts/apex/smoke-cross-org-sender.apex

# 2. Wait ~30 seconds for the cross-org dispatcher to land them on the receiver.

# 3. RECEIVER — assert each leg arrived with full payload.
sf apex run --target-org nimba --file scripts/apex/smoke-cross-org-receiver.apex

# 4. CLEANUP — once satisfied, remove the SMOKE_ records on the sender.
#    Receiver-side rows tombstone via the cross-org DELETE flow.
sf apex run --target-org MF-Prod --file scripts/apex/smoke-cross-org-cleanup.apex
```

## What each leg proves

| Leg | What a PASS proves |
|---|---|
| WorkItem | `DeliveryWorkItemTriggerHandler.syncFields` includes `BriefDescriptionTxt__c`; `captureChanges` serializes it; receiver ingestor accepts the payload |
| Comment | `DeliveryWorkItemCommentTriggerHandler.syncFields` includes the parent FK (`WorkItemId__c`) — the bug behind PR #740 |
| WorkLog | `DeliveryWorkLogTriggerHandler` outbound path; receiver Pending-queue resolves cross-org parent ID |

The **payload-carries-X** flags catch the namespace-stripping bug class (PR #742) — empty payloads can pass schema validation but fail real-data assertions.

## Failure signals

- **`No SMOKE_ WorkItem on this org`** — outbound never dispatched, or receiver ingestor rejected it pre-insert. Check sender's `delivery__SyncItem__c` for that tag's `LocalRecordIdTxt__c`.
- **`Inbound status=Failed`** — receiver SOQL the row's `delivery__ErrorLogTxt__c` for the actual error.
- **`Inbound status=Pending`** — child arrived before parent; the Pending-queue should auto-resolve once parent lands. If stuck for > 5 min, the parent is missing from cross-org bridge.
- **`payload-carries-X=false`** — the field isn't in the receiver's payload. Outbound bug. Pull the sender-side `delivery__SyncItem__c.PayloadTxt__c` for that tag and confirm it's emitting only routing metadata.

## Promote/install gate

Run sender → wait → receiver after every install on each org pair. If any leg fails, hold the promote rollout to the rest of the orgs until the underlying outbound or ingestor bug is fixed.

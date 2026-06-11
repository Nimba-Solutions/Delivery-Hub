# Handoff — Invoice pipeline status (DH code side)

**Date:** 2026-06-02
**Author:** Delivery Hub Claude session (`C:\Projects\Delivery-Hub`)
**Audience:** future DH sessions + Glen. Companion to the MF-side operational thread.

## TL;DR

**No DH code change is required to cut the overdue May "At Large" invoice.** The only DH *code* blocker — the snapshot field overflow — is already fixed and promoted (`0.258.0.1`). The remaining problem is **operational/data on dh-prod**, not logic. Do not gate invoicing on a DH release.

## What the DH code already does (shipped + promoted in 0.258.0.1)

- **#859 — invoice snapshot overflow fix.** `DeliveryDocGenerationService.buildSnapshot` was serializing *every* WorkRequest ever linked to the billing entity into `SnapshotTxt__c` (131,072 cap) → `STRING_TOO_LONG` → whole `generateDocument` rolled back. Fix: period-scope WRs to billed items + `boundSnapshotToFieldCap()` guard. **`generateDocument` now succeeds.**
- **#860 — sync parent-resolution fix.** `DeliverySyncItemIngestor` parent lookup took an unordered `LIMIT 1` with no existence check; when a WorkItem was re-created in dh-prod it could resolve a child WorkLog to a *deleted* parent and strand it. Fix: route through `findLocalId()` (Inbound + `ORDER BY CreatedDate DESC` + existence validation). **Stops NEW stranding going forward.**

## What is NOT a DH code problem (the actual invoice blocker)

The invoice is generated **on dh-prod**, but the **canonical hours live on MF-Prod** (May = **236.5h / 108 rows**), three sync-hops upstream (MF-Prod → Nimba → dh-prod). The wrong invoice numbers came from:
- Reconciling dh-prod to the **wrong source** (nimba 250.6h carries test/extra noise) instead of MF-Prod's 236.5h.
- The **auto-sync re-duplicating** manually-fixed rows (produced the 365.6h / 135h artifacts).

The generator is GIGO — it correctly sums whatever worklogs sit on dh-prod for the period. **Right data in → right invoice out.**

### The operational fix (MF-side, no code, no release)
1. Keep the sync **paused** (so it can't re-duplicate).
2. Mirror dh-prod May worklogs to **MF-Prod's exact 236.5h / 108 rows** (MF-Prod is canonical).
3. Run `delivery.DeliveryDocumentController.generateDocument(<At Large entity Id>, 'Invoice', 2026-05-01, 2026-05-31, null)`.
4. Verify the draft total against the **April invoice DOC-000014** as the reference shape, then send.

## ⚠️ Correction (2026-06-02, post-audit): the sync IS a DH code problem

A full read-only idempotency audit of the sync engine (`DeliverySyncItemIngestor`, `DeliverySyncEngine`, `DeliveryWorkLogTriggerHandler`, `DeliverySyncReconciler`, `DeliveryHubPoller`, `SyncItem__c`) found that the recurring WorkLog duplication is a **code** problem, not just data surgery side-effects.

### Confirmed root cause (two layers)
1. **No content-based dedup for WorkLogs.** `processInboundItem` decides insert-vs-update ONLY via the SyncItem__c ledger (SourceId) + GlobalSourceId (`DeliverySyncItemIngestor.cls:82, 96-101`). If both miss → unconditional INSERT (`:138, :501`). No "does a WorkLog with this parent+date+hours+description already exist?" check. So manually-inserted rows (no ledger) get synced twins. **This is the 250.6→365.6 mechanism.**
2. **GlobalSourceId is re-minted to the local Id at every hop for WorkLogs.** WorkLog outbound bypasses `DeliverySyncEngine.captureChanges` (which inherits origin GSID for WorkItems). Instead `DeliveryWorkLogTriggerHandler.buildSyncItems/buildPushSyncItems:312,324,356,370` and `DeliverySyncReconciler.buildWorkLogSyncItem:358,374` hardcode `GlobalSourceId = wl.Id`. So across MF→Nimba→dh-prod the origin id is lost at each relay (inbound ingest never sets `runAfterLogic=false`, so the relay org re-emits with its OWN local id). **GlobalSourceId is NOT a stable cross-org key for WorkLogs** → the `:96-101` dedup is effectively dead for relayed logs. This is the "wrong for months" structural driver, independent of manual surgery.

### Ranked gaps (full detail in audit; agent add133ed9fac3bd05)
- **C1** no content dedup for WorkLog inserts (direct double-billing). **C2** GSID re-mint per hop. **C3** relay re-emission not suppressed. **H1** null SourceId+GSID = guaranteed dupe every pass. **H2/M4** inbound write + ledger write not atomic (partial-failure dupes). **H3** poller re-polls whole window on any item throw. **H4** reconciler counts only `Synced` as covered for WorkLogs (vs WorkItem counts Synced/Queued/Processing/Staged) → periodic re-queue drip. **M1** `findLocalId` LIMIT 50 newest-first masks existing dupes. **M2** sparse payload with `Hours:null` zeroes hours on update.

### Fix plan (prioritized)
1. **Content-based WorkLog dedup** in `processInboundItem`, as a FALLBACK only when ledger+GSID both miss. Key = **parent WorkItemLookup__c + WorkDateDate__c + HoursLoggedNumber__c(scale 2) + WorkDescriptionTxt__c**. ⚠️ `ResourceTitleTxt__c` is NOT on the outbound payload today (handler `:309-316` / reconciler `:356-365` omit it) — so it CANNOT be in the key unless senders add it. On content-match → convert to UPDATE + write the missing ledger row (auto-heal).
2. **Inherit GlobalSourceId from the inbound ledger** on WorkLog relay/reconcile (mirror `captureChanges:162-164`) so GSID is stable across hops — re-enables `:96-101` as a second line of defense.
3. **Relay re-emission**: keep ON (daisy chain MF→Nimba→dh-prod is intentional per project memory) — so do NOT disable `runAfterLogic`; rely on Fix 1+2. (Confirm topology with Glen.)
4. **Reconciler status parity** (`DeliverySyncReconciler.cls:273`): count WorkLog coverage as `IN ('Synced','Queued','Processing','Staged')` — stops periodic re-queue churn.
5. **Atomicity**: savepoint around record insert + `createLedgerEntry` so a ledger failure rolls back the record (closes H2/M4).

### Needs Glen / org data (can't determine from code)
- Intended WorkLog topology: Nimba forwards MF's logs to dh-prod (relay), or dh-prod pulls direct? (Memory says relay; confirm.) Determines whether Fix 3 stays "keep relay on."
- Whether dh-prod's actual dupes have ledger rows (which driver dominates: C1 vs H4 vs C2).
- Whether all senders populate SourceId + the 4 business fields (H1 exposure).

## Other DH-side follow-ups (lower priority)
- **Remove the `SnapshotTxt__c` 131,072 ceiling** (deferred from #859): ContentVersion storage + reference/hash. Own PR.
- **Observability on silent sync failures** (`DeliveryHubPoller.pollUpdates()` swallows exceptions; 13-day outage = zero alerts).

## Bottom line

Today's invoice does NOT wait on this — with sync **paused** no new dupes appear; mirror dh-prod to MF-Prod's canonical 236.5h and generate. But the sync engine has a **real, now-mapped code root cause** for the months-long WorkLog duplication, and the fix sequence above (content dedup + GSID inheritance) is the durable cure.

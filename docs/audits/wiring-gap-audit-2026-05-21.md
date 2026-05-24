# Wiring Gap Audit — 2026-05-21

> Cross-reference note: this audit is narrower than the Admin UX + E2E walkthrough audits. It looked at **deployment wiring** (triggers active, scheduler called, test classes registered, etc.) and found things mostly clean. The Admin UX audit + E2E walkthrough surfaced **discoverability + UX wiring** gaps that this audit didn't scope. Read all four together for the full picture.

## Headline

**Deployment wiring is clean.** Triggers active, handlers wired, scheduler orchestrated, GVS files present, test suite comprehensive, picklist values externalized. Two polish gaps + cross-references to issues already surfaced in other audits.

---

## 1. Trigger wiring — COMPLETE

- `FeatureTrigger.trigger` → `DeliveryFeatureTriggerHandler.handle()` ✅
- `FeatureToggleRequestTrigger.trigger` → `FeatureToggleRequestTriggerHandler.handle()` ✅
- Both `<status>Active</status>` ✅
- Both `after insert, after update` ✅

## 2. Scheduler wiring — COMPLETE

`DeliveryHubInstallHandler.onInstall()` → `scheduleSyncJobs()` → `DeliveryHubScheduler.scheduleAll()` (idempotent, aborts existing jobs before re-scheduling). All 9 cron-tick branches enqueue cleanly: weekly digest, invoice gen, overdue reminders, forecast alerts, and 5 sync ops.

**Note:** the audit agent claims "no `enqueueWatcherDigestIfDue()` — integrated into general digest framework." That's incorrect — PR-B's brief explicitly added a new dedicated method. Verify by reading `DeliveryHubScheduler.cls` post-merge; this is the one wiring claim that needs eyes-on confirmation.

## 3. Install handler completeness — COMPLETE (audit was wrong on the Watcher gap)

`onInstall()` runs: settings init → feature seed → legacy settings mirror → schedule sync jobs → backfill user permsets → backfill WI status defaults → enqueue reconciliation. Complete + idempotent.

**Original audit claimed the 3 Watcher per-signal flags were missing from `initializeDefaultSettings()`. Verified in actual main: this is INCORRECT.** Lines 74-76 of `DeliveryHubInstallHandler.cls` set all three:
```apex
EnableWatcherSLABreachDateTime__c           = now,
EnableWatcherStuckStageDateTime__c          = now,
EnableWatcherARAgingDateTime__c             = now,
```
Matching test assertions exist in `DeliveryHubInstallHandlerTest.cls` lines 26-31. Shipped in PR #809 commit `39ada64c`.

## 4. CustomNotificationType definitions — gap (per other audit)

No `customNotificationTypes/` directory exists. Bell notifications for approval requests / Watcher digest / onboarding complete don't fire. **Cross-reference: see `admin-ux-audit-2026-05-21.md` §8 for the same finding + remediation PR.**

## 5. Field defaults — COMPLETE

Same as §3 — original "polish gap" claim was incorrect, Watcher signal flags ARE defaulted on install.

## 6. Tab + App definitions — subscriber-blocking (per other audit)

**`Feature__c`, `FeatureToggleRequest__c`, `FeatureToggleApproval__c` have no tabs.** Not in `DeliveryHub` or `DeliveryHubAdmin` app navigation. **Cross-reference: see `admin-ux-audit-2026-05-21.md` §1-2** — the Admin UX audit identified 9 objects (the full new-object set, not just 3) with missing tabs/layouts/record pages.

## 7. Site Guest / Public perms — OK

No new public/guest routes. All new REST routes are X-Api-Key gated. No Site Guest config needed.

## 8. Namespace-prefix tripwires — CLEAN

No `Schema.getGlobalDescribe().get('Foo__c')` patterns in new code (hotfixes #797 + #800 closed the prior surface). All sObject + service references are typed (compile-time, namespace-safe). GVS files for picklists are external `.globalValueSet-meta.xml` so namespace is handled by metadata tooling.

## 9. Tests not in suite — CLEAN

All 6 new feature-cockpit + Watcher test classes registered in `unpackaged/post/testSuites/DH.testSuite-meta.xml` (PR #808 closed the 2 prior gaps).

## 10. TestDataFactory gaps — CLEAN

`buildFeature()` / `createFeature()` / `createFeatures()` / `buildFeatureToggleRequest()` / `createFeatureToggleRequest()` all present with safe picklist defaults + parent auto-mint.

## 11. Cross-tenant blockers (`ScratchOrgInstance__c`) — known gap

No `CreatedByNetworkEntityLookup__c` field. Acknowledged Low-risk in the REST API surface review. Acceptable for single-tenant developer-tooling use; deferred until multi-tenant ingest is wanted.

## 12. Picklist value drift — CLEAN

All new `__c` picklists use external GVS reference (`<valueSetName>`). All GVS files present. `__mdt` picklists correctly use inline `<valueSetDefinition>` per platform requirement (see [[mdt-picklists-must-be-inline]]).

---

## Verdict

**Deployment wiring is ship-ready.** Triggers fire, scheduler runs, picklists deploy, tests execute in CI.

**Cross-audit reconciliation** — this audit's "ship-ready" verdict ONLY covers wiring. The other 3 audits identified real subscriber-facing gaps:

| Wiring view | Admin UX view | E2E walkthrough view | Net |
|---|---|---|---|
| Triggers + scheduler + tests = ✅ ship | 9 new objects missing tabs/layouts/record pages, WatcherDigest__c has 0 field perms, no CustomNotificationTypes | 60% of user flows end-to-end; submission UI, approver assignment, audit-trail viewers all missing | **Ship the code; do NOT ship to subscribers without the Admin UX bundle + a submission UI PR** |

**Combined "subscriber-ready bundle"** (across all 4 audits, deduped):
1. Admin UX metadata (~3.5h) — tabs, layouts, WatcherDigest__c field perms, app menu updates
2. Approval submission LWC (~1-2d) — service exists, no caller
3. Approver auto-assignment (~1-2d) — null at create today
4. Audit-trail viewer LWCs (~2-3d) — ActivityLog, WatcherDigest history, OnboardingProgress
5. CustomNotificationType definitions + wiring (~1h + Apex callouts) — bell notifications for approval / digest / completion
6. ~~Watcher install-handler flag defaults~~ — **already shipped in PR #809; audit was wrong.**
7. Onboarding quiz retry gating + non-Manual evaluators (~2-3d) — UI + Apex evaluators
8. Documentation bundle (~7.5h) — README, REST API, setup guide, architecture diagrams

**Hard-blocking subset (must ship before any subscriber-facing release):** items #1, #2, #4, #5 — ~6-8 days of work.

**Polish that can ship in a follow-on cycle:** items #3, #6, #7, #8.

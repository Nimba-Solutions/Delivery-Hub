# Architecture + Governor Review — 2026-05-21

## Headline

The cockpit + Watcher ship cycle landed 20+ new Apex classes with **strong trigger discipline, correct governance patterns, and appropriate complexity suppression**. The architecture is clean and event-driven, with **no critical governor violations**. One minor code-path redundancy in `DeliveryPublicApiService` and a few low-priority polish items. **Production-ready.**

---

## 1. Trigger Architecture — PASS

| File:Line | Concern | Finding |
|---|---|---|
| `FeatureTrigger.trigger:9` | After-insert/update delegation | Fires after DML so sync service sees final state. Handler receives `Trigger.new`/`oldMap` as params — proper decoupling |
| `FeatureToggleRequestTrigger.trigger:10` | Same pattern | Delegates to handler; no `Trigger.X` static refs in handler logic |
| `DeliveryFeatureTriggerHandler:33-43` | Recursion guard | Checks `DeliveryFeatureSyncService.isInSyncContext()` before processing. Guard set/cleared via try/finally in `commitSettingsInSyncContext()` (L188). No re-entry risk |
| `DeliveryFeatureApprovalService:403-418` | Apply-context guard | `inApplyContext` checked at entry, set in try/finally (L479-492). Prevents re-entry from the request trigger when service flips features |
| All handlers | Bulk-safety | All handlers iterate `newRows` as lists, never assume size 1. No SOQL inside loops processing trigger rows |

## 2. Governor Exposure — PASS

| File:Line | Pattern | Finding |
|---|---|---|
| `DeliveryFeatureSyncService:60-81` | Bulk SOQL upfront | Single SOQL loads all FeatureDefinition__mdt rows; in-memory map iteration. No per-row SOQL |
| `DeliveryFeatureGraphService:68-74` | BFS upfront load | One SOQL loads all FeatureDependency__c rows (LIMIT 2000). BFS in memory with depth cap 10 + visited guard |
| `DeliveryFeatureCatalogController:53-79` | Catalog + runtime join | Two bulk SOQLs (defs + features) then in-memory DTO build |
| `DeliveryFeatureApprovalService:150-158` | Approval cascade insert | Single bulk `insert approvals` after in-memory build |
| `DeliveryHubInstallHandler:80-108` | Idempotent seed | Two SOQLs upfront, in-memory list build, single bulk insert. Re-running install won't duplicate |

**No DML inside loops anywhere.** All bulk patterns hold.

## 3. Coupling Smells — minor

| File:Line | Concern | Severity |
|---|---|---|
| `DeliveryPublicApiService:22-32, 79-89` | Rate-limit block duplicated between `handleGet()` + `handlePost()` (identical logic, different var names `rlSettings` / `rlSettings2`) | Low — extract `checkRateLimit(entity)` helper |
| `DeliveryFeatureApprovalService:110-121` vs `DeliveryFeatureCatalogController:147-165` | Both interpret hard/soft edges from `FeatureGraphNodeDTO` independently | Low — document edge semantics in the DTO's `@description` so both consumers reference the same contract |

## 4. Cyclomatic Post-Cleanup — ACCEPTABLE

All complex classes carry justified class-level `@SuppressWarnings`. Top 5 highest-cyclomatic methods all under 10:

1. `DeliveryFeatureApprovalService.applyIfFullyGranted()` — cyc ~6
2. `DeliveryFeatureApprovalService.flattenCascadeWithDepth()` — cyc ~5
3. `DeliveryFeatureGraphService.expandLayer()` — cyc ~7
4. `DeliveryFeatureSyncService.applyTimestampsToSettings()` — cyc ~5
5. `DeliveryFeatureCatalogController.toggleFeature()` — cyc ~4

No cleanup needed.

## 5. Naming Consistency — PASS

`*Service` for business logic; `*Controller` for LWC/REST entry points; `*TriggerHandler` for thin trigger wrappers; `*DTO` for inner-class payloads. Tight discipline across all 20+ new classes.

## 6. Install Handler Discipline — PASS

| Step | Method | Idempotent? |
|---|---|---|
| 1 | `initializeDefaultSettings()` (L47) | YES — `settings.Id != null` early-return (L49) |
| 2 | `seedFeaturesFromDefinitions()` (L80) | YES — `existingDefNames` set-check before insert (L98) |
| 3 | `syncLegacySettingsToFeatures()` (L37) | YES — service-level idempotent (only updates differing rows) |
| 4 | `scheduleSyncJobs()` (L125) | YES — `scheduleAll()` aborts matching jobs before re-scheduling |
| 5 | `backfillUserPermissionSets()` (L141) | YES |

Order-of-ops correct: seed (step 2) before sync (step 3).

## 7. Test Coverage + Quality — GOOD

Paired test classes present for every new service/controller/handler. No shared state between test classes. Recursion-guard state is `@TestVisible` to allow guard-behavior assertions. No SMT issues.

---

## Top 3 Surgical Cleanup PRs

| # | PR | Effort | Risk |
|---|---|---|---|
| 1 | Extract `checkRateLimit(entity)` helper in `DeliveryPublicApiService` (kills the duplicated block between handleGet + handlePost) | 15 min | Low — pure refactor + 1 helper test |
| 2 | Add `@see` ApexDoc in `FeatureGraphNodeDTO` linking to the hard/soft semantic used by both ApprovalService + CatalogController. Documentation-only | 30 min | None |
| 3 | (Stretch) Extract `DeliveryFeatureInstallService` from `DeliveryHubInstallHandler` to isolate feature-seed reusability for the future Watcher install path | 1h | Medium — touches install-on-upgrade path, needs smoke test |

## Architectural recommendations (next cycle)

1. **Event-driven approval notifications** — grant/reject decisions persist synchronously today. Consider enqueuing a `FeatureApprovalNotificationQueueable` so Slack/email side-effects don't block the approval transaction. Scales better when cascades exceed ~50 approval rows.
2. **Cascade depth UI pagination** — graph service caps depth at 10 but the cockpit UI renders the full tree. For deep cascades, lazy-load children in the approval-chain modal.
3. **Settings → Feature sync deprecation roadmap** — `DeliveryFeatureSyncService` is a temporary mirror. Document a PR timeline to retire the legacy `DeliveryHubSettings__c.Enable*DateTime__c` fields once all internal readers pivot to `Feature__c`. That removes the recursion-guard complexity.

---

## Bottom line

**Code quality is production-ready.** The three-layer service model (catalog → approval → graph) cleanly separates concerns, the recursion guard pattern prevents trigger feedback loops, and bulk-safe SOQL patterns pass all governor checks. Ship with high confidence. Cleanup PRs above are polish, not blockers.

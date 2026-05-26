# Delivery Hub — Design Principles

> The eight patterns that recur across every Apex service, every custom object, every test, and every PR review. New code that conflicts with one of these patterns is a flag for re-review, not an acceptable variation.

These principles were extracted from the project's CLAUDE.md, the recurring upload-beta and PR-feedback incidents documented in `feedback_*.md` memories, and the post-cycle audit reports under `docs/audits/`. Each section names the pattern, explains the failure mode it prevents, and points at a current call site.

---

## 1. DateTime stamps, not Booleans, for feature toggles

**Pattern.** Every feature-flag field on `DeliveryHubSettings__c` and `Feature__c` is a `DateTime` named `Enable*DateTime__c` (master) or `*EnabledDateTime__c` (per-feature runtime row). Truthy = `!= null`; the value is when the flag was last flipped on.

**Why.** Booleans answer "is it on?" but not "when did it go on?" or "who turned it on?". DateTime stamps unify the toggle state with the audit-trail metadata that admins, support, and the `DeliveryActivityChainService` all need. The same field powers the boolean check, the activation timestamp on `ActivityLog__c.ContextDataTxt__c`, and the "stabilization window" gate for follow-on features (e.g., Phase 2 Watcher uses its own `EnableWatcherDigestDateTime__c` to bootstrap the 14-day heartbeat window before Phase 3 auto-digest unlocks).

**Field-naming corollary.** Per `docs/FIELD_NAMING.md`:
- New flag → `Enable<Capability>DateTime__c`.
- Inverted boolean (e.g., suppress / disable) is forbidden in new code; use a positive `Enable*DateTime__c` name even when the default behaviour is "off until enabled."

**Anti-pattern.** `Checkbox` fields for new feature flags. The package is allowed to keep historical `Checkbox` fields (no retrofit), but any new flag goes in as DateTime.

**Reference.** `force-app/main/default/objects/DeliveryHubSettings__c/fields/Enable*DateTime__c.field-meta.xml` (40+ fields). Reader pattern: `DeliveryHubSettings__c.EnableWatcherDigestDateTime__c != null`.

---

## 2. GlobalValueSet from day one, no inline picklists

**Pattern.** Every new picklist field on a `__c` object must declare `<valueSetName>` referencing a `GlobalValueSet`. Inline `<valueSetDefinition>` is forbidden.

**Why.** Salesforce Known Issue `a028c00000qPzYUAA0`: unlocked packages do not reliably propagate **new** values added to restricted inline picklists on subscriber upgrades. The retrofit path is blocked too — Salesforce refuses to swap an existing inline-defined picklist over to a GVS reference ("Cannot change which global value set this picklist uses"). GVS from day one is the only durable path.

**Exception — `__mdt` only.** Salesforce platform forbids `<valueSetName>` on `__mdt` picklist fields. `__mdt` picklists must use inline `<valueSetDefinition>`. Reference patterns: `DashboardCard__mdt.CardTypePk__c`, `IntegrationProvider__mdt.HttpMethodPk__c`, `WorkflowEscalationRule__mdt`'s two picklists.

**Existing inline picklists.** Pre-2026 inline-defined picklists on `__c` objects stay `<restricted>false</restricted>` (so any value is accepted at the DML layer; data quality is a service-layer concern). There is **no longer a runtime picklist-allowlist trigger** — `DeliverySyncItemTriggerHandler.onBeforeInsertOrUpdate` is a documented no-op. Apex services that write picklist values should pass safe known values directly; `TestDataFactory` defaults to allowlist-compliant values for the same reason.

**Reference.** `force-app/main/default/globalValueSets/` (40+ GVS definitions). Schema example: `force-app/main/default/objects/FeatureToggleRequest__c/fields/StatusPk__c.field-meta.xml`.

---

## 3. `__c` vs `__mdt` — when each is appropriate

| Use `__c` (Custom Object) when... | Use `__mdt` (Custom Metadata Type) when... |
|---|---|
| Data is per-tenant or per-user runtime state | Data is package-shipped catalog or admin config |
| Records change at runtime via Apex / LWC | Records change at deploy time via metadata DML |
| Bulk insert / update / delete throughput matters | Tens-to-hundreds of records, mostly read-only |
| Sharing rules / record types / report types needed | Same record-shape across every subscriber org |
| Master-Detail / Lookup to other `__c` | Loose `Txt__c` cross-reference (`FeatureDefinitionTxt__c`) |

**Hybrid pattern (cockpit Layer 4).** `FeatureDefinition__mdt` ships the catalog (one record per shippable feature, common across every install). `Feature__c` ships the per-tenant runtime row (one per subscriber per feature, holds `EnabledDateTime__c`). The catalog joins to the runtime row via the `FeatureDefinitionTxt__c` external-id column. New features can be added by shipping a `FeatureDefinition__mdt` record + a single `DeliveryHubInstallHandler` seed entry; no schema change on `Feature__c`.

**Anti-pattern.** Putting per-tenant state on `__mdt` (subscribers can't write to it at runtime — `Metadata.DeployContainer` is async + admin-only). Putting catalog data on `__c` (no metadata propagation; subscriber upgrades won't pick up new entries).

**Reference.** `force-app/main/default/objects/FeatureDefinition__mdt/` + `force-app/main/default/objects/Feature__c/`.

---

## 4. Namespace-safe Apex — typed describe, no `Schema.getGlobalDescribe()`

**Pattern.** Use the typed `<SObject>__c.SObjectType.getDescribe()` pattern for any reference to a Delivery Hub custom object or field.

```apex
// CORRECT — works in both packaging context (delivery__) and non-namespaced scratch
Map<String, Schema.SObjectField> fields =
    DeliveryHubSettings__c.SObjectType.getDescribe().fields.getMap();

// WRONG — returns null in delivery__ packaging context
SObjectType t = Schema.getGlobalDescribe().get('DeliveryHubSettings__c');
```

**Why.** `Schema.getGlobalDescribe().get('Foo__c')` returns null when the calling code runs in the namespaced `delivery__` packaging context (publisher packaging org or any subscriber install). PR-level CI uses a non-namespaced scratch org so the bug isn't caught; the upload-beta job *is* namespaced, which is where it fails. This bit twice in PR #797 and PR #800 (production + test code paths separately).

**Corollary — `getLocalName()` not `getName()`.** For field / object API names, `field.getDescribe().getLocalName()` returns `MyField__c`; `getName()` returns `delivery__MyField__c` in packaging context. Use `getLocalName()` whenever the caller compares against an unprefixed string.

**Corollary — PermissionSetGroup DeveloperName queries.** `WHERE PermissionSetGroup.DeveloperName IN ('DeliveryHubAdmin', 'delivery__DeliveryHubAdmin')` — accept BOTH the bare and the namespaced developer name. Subscriber installs see the namespaced form; dev scratch sees the bare form.

**Corollary — `WITH SYSTEM_MODE`, not `WITH USER_MODE`.** `WITH USER_MODE` breaks in namespaced package test context. Use `WITH SYSTEM_MODE` (and rely on the `with sharing` / `without sharing` class declaration for the runtime gate).

**Reference.** `DeliveryHubDashboardController.isAdminUser()` (L582–L595) — canonical PSG-DeveloperName-tolerant query. `DeliveryFeatureSyncService.describeSettingsFields()` (post-PR #797) — typed describe call.

---

## 5. Receiver-side gate pattern (per-record DateTime + per-org opt-in DateTime)

**Pattern.** Any cross-org content class that opts in to receiving signals from another org gates inbound writes behind **two** DateTime stamps:

1. A **per-record** `<Capability>EligibleDateTime__c` (or similar) on the inbound payload — sender stamps this when the record is sender-side eligible.
2. A **per-org** `Enable<Capability>InboundDateTime__c` on `DeliveryHubSettings__c` — receiver org admin must opt in before any inbound write succeeds.

Both must be `!= null` for the receiver to accept the inbound write. Either one null = silent drop.

**Why.** Cross-org content classes (Slack inbound, depth-probe, sync-from-vendor, etc.) need both sender intent and receiver consent. A boolean on either side erases the audit-trail metadata (when did sender mark it eligible? when did receiver opt in?). Two DateTimes capture both. Glen validated this pattern in PR #747 (predecisional gate) and asked it be used for every future cross-org content class.

**Reference.** Slack inbound (`DeliverySlackInboundHandler` + `EnableSlackCommentSyncDateTime__c` + `SlackInboundEligibleDateTime__c` on `WorkItemComment__c`). Depth-probe (`DeliveryDepthProbeService` + per-org `EnableDepthProbeInboundDateTime__c`).

---

## 6. Admin permission checks via PSG `DeveloperName`

**Pattern.** Server-side admin gates query `PermissionSetAssignment` joined to `PermissionSetGroup.DeveloperName`, accepting both the bare and the namespaced developer name:

```apex
[
    SELECT Id FROM PermissionSetAssignment
    WHERE AssigneeId = :UserInfo.getUserId()
      AND PermissionSetGroup.DeveloperName
          IN ('DeliveryHubAdmin', 'delivery__DeliveryHubAdmin')
    LIMIT 1
]
```

**Why.** Two independent issues are fixed by this single pattern:
1. Subscriber orgs see the namespaced developer name (`delivery__DeliveryHubAdmin`); dev scratches see the bare name (`DeliveryHubAdmin`). Querying for only one form breaks one of the two contexts.
2. `PermissionSet.Name` (vs `PermissionSetGroup.DeveloperName`) returns the label, which can drift between releases. PSG DeveloperName is package-stable.

**Test-context corollary.** When `@IsTest` code inserts a fresh User and assigns the `DeliveryHubAdmin` PSG, the assignment isn't queryable until `Test.calculatePermissionSetGroup()` runs. The canonical test helper is in `TestDataFactory.makeAdminUser()` (post-PR #821). New admin-gated tests should call this helper, not roll their own.

**Reference.** `DeliveryHubDashboardController.isAdminUser()` (L582) — the canonical pattern. Also used by `DeliveryFeatureCatalogController` (L394), `DeliveryFeatureDepEditorController` (L167), `DeliverySyncDismissalService` (L225).

---

## 7. ActivityLog__c on every meaningful side effect

**Pattern.** Every Apex service that mutates state writes one `ActivityLog__c` row per side effect with:

| Field | Value |
|---|---|
| `ActionTypePk__c` | One of the GVS values (`Feature_Toggle`, `Approval_Granted`, `Onboarding_Completed`, `Watcher_Run`, etc.) |
| `ComponentNameTxt__c` | The calling class.method (`DeliveryFeatureSyncService.syncFeaturesToSettings`) |
| `RecordIdTxt__c` | The mutated record's Id (e.g., `Feature__c.Id` on a toggle) |
| `ContextDataTxt__c` | JSON blob: who, when, before/after values, reason |
| `NetworkEntityId__c` | When the side effect is scoped to a single tenant |

**Why.** Three downstream consumers depend on a complete activity log:
1. **Audit-chain hash** — `DeliveryAuditChainService.setHashOnInsert` SHA-256s each row in insertion order, creating an immutable tamper-detection chain that `DeliveryComplianceExportService` ships to subscribers on demand.
2. **Audit-trail viewer LWCs** — `deliveryActivityLog`, `deliveryWatcherDigestHistory`, `deliveryOnboardingHistory` (post-PR #820) all read `ActivityLog__c` directly.
3. **Retention policy** — `ActivityLogRetentionDaysNumber__c` on `DeliveryHubSettings__c` drives the cleanup batch; subscribers can dial retention up for compliance or down for storage.

**Service rule.** If your service flips a flag, posts to Slack, sends an email, fires a platform event, or completes an external sync — write an ActivityLog row. The audit-trail LWCs assume nothing happens silently.

**Reference.** `DeliveryFeatureSyncService.writeAuditRow()` (one row per Feature toggle), `DeliveryFeatureApprovalService.applyIfFullyGranted()` (one row when approval cascade applies), `DeliveryWatcherService.persistDigest()` (one row per Watcher run regardless of whether signals fired).

---

## 8. Hash-chain audit on REST mutations

**Pattern.** Every REST endpoint that mutates state through `DeliveryPublicApiService` writes the resulting `ActivityLog__c` row through the same `DeliveryAuditChainService` trigger path as in-org mutations. The endpoint **does not** compute hashes itself.

**Why.** The audit chain is only tamper-detectable if every link is in it. Letting REST endpoints bypass the chain (or computing hashes in a different code path) creates two ledgers and breaks `DeliveryAuditChainService.validateChain()`. The trigger-driven, single-code-path approach also means a REST PR can't accidentally ship a different hash algorithm — `DeliveryCryptoService.computeChainHash` is the single source of truth.

**Endpoint rule.** REST endpoints don't insert `ActivityLog__c` directly. They call the underlying service (e.g., `DeliveryFeatureApprovalService.grant()`), which inserts the activity-log row, which fires the trigger, which writes the hash. The chain is computed exactly once.

**Reference.** `DeliveryAuditChainService.setHashOnInsert` (the trigger handler) + `DeliveryFeatureApprovalService.applyIfFullyGranted()` (the REST-callable service that writes the row). PR #802 referenced this pattern for the four new cockpit REST routes.

---

## Cross-cutting: data integrity guard rails

Three rules that aren't a pattern per se but apply to every change:

1. **Never fabricate realistic financial data.** Sample loaders under `scripts/feature-data/` use obvious placeholder values (`Sample Vendor A`, `1.0` hours, `TDF / placeholder sample` descriptions). Sample data that looks realistic gets shipped to subscriber orgs that then post it to their CRM — and once it's there, it's nearly impossible to scrub. Placeholder-only is non-negotiable.
2. **Never DML against production.** All anonymous-apex iteration happens in scratch orgs first. `cci task run` against a production org requires explicit user confirmation in the PR description.
3. **Picklist values written by Apex services are passed directly.** `SyncItem__c.StatusPk__c` is not restricted; Salesforce will accept anything. The `DeliverySyncItemTriggerHandler` no-op trigger is intentional. Services that write picklist values should pass safe known values directly. `TestDataFactory` defaults to allowlist-compliant values.

---

## Related reading

- `docs/CONTRIBUTING.md` — how to apply these principles in a new PR (branch naming, test pattern, PMD ruleset, upload-beta gotcha checklist)
- `docs/ARCHITECTURE.md` — the object model + service-layer map
- `docs/FIELD_NAMING.md` — the typed-suffix field naming convention these principles assume
- `docs/audits/architecture-governor-review-2026-05-21.md` — the most recent audit showing where the patterns actually held in production code

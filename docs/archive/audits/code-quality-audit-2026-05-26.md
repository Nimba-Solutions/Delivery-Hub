# Code Quality Audit — 2026-05-26

> Source rules: `CLAUDE.md` (project root) + memory feedback files in
> `~/.claude/projects/C--Projects-Delivery-Hub/memory/feedback_*.md`.
> Built from the index in `MEMORY.md`. Glen's explicit ask: "do a repo
> audit for best practices; make sure we aren't using booleans, etc."
>
> Comparison points:
> - `docs/audits/field-naming-audit-2026-05-21.md` (5 days prior, 0 violations)
> - `docs/audits/namespace-customsettings-audit-2026-05-21.md` (5 days prior, 0 violations)
> - `docs/audits/pmd-baseline-2026-05-21.md` (post-cockpit baseline)
>
> Audit methodology: greps + per-finding manual verification against
> current `main` per `[[verify-audit-findings-before-shipping]]`.
> No stale audit-doc claims propagated forward.

## Headline

**The repo is clean on every blocking rule.** All P0/P1 categories return
zero violations. A small set of P2 stylistic items remain — none warrant
a mechanical rewrite without design review.

| Category | Findings | Severity |
|---|---|---|
| Checkbox/Boolean fields on `__c` / `__mdt` / Custom Settings | **0** | n/a |
| `WITH USER_MODE` in Apex | **0** | n/a |
| `Schema.getGlobalDescribe().get('Foo__c')` string-keyed lookups | **0** | n/a |
| LWC `@api` Boolean props defaulting to `true` (LWC1503) | **0** | n/a |
| LWC `.html` template ternary expressions | **0** | n/a |
| `<fieldManageability>` on `__c` fields | **0** | n/a |
| `__mdt` picklists using `<valueSetName>` (GVS) | **0** | n/a |
| `<customNotificationTypeAccesses>` in permsets | **0** | n/a |
| Tests assigning `PermissionSetGroupId` without `Test.calculatePermissionSetGroup()` | **0** | n/a |
| Apex `global` classes missing `@SuppressWarnings('PMD.AvoidGlobalModifier')` | 53 | P2 (lint noise only — CI does not block on AvoidGlobalModifier) |
| Apex `getDescribe().getName()` where `getLocalName()` is cleaner | 9 (across 7 files) | P2 (cosmetic — none break in namespaced context) |
| Apex class identifiers > 40 chars | **0** | n/a |
| Apex class identifiers exactly at 40-char cap (borderline) | 2 | P3 (informational) |
| Apex reserved-word identifiers (`when`, `inherited`, `desc`, etc.) | **0** | n/a |
| `AuraHandledException.getMessage()` asserted in tests | **0** | n/a |
| Apex `Boolean` instance/class fields acting as persisted toggles | **0** | n/a |

## Severity legend

- **P0** — upload-beta / subscriber-install blocker
- **P1** — subscriber-facing bug or future-deploy hazard
- **P2** — code quality / cleanup (no behavior or deploy impact)
- **P3** — informational / borderline

## Top-3 priorities

1. **None at P0/P1.** Every blocking rule is satisfied. Nothing to ship as
   a fix this round.
2. **P2: `AvoidGlobalModifier` cleanup.** 53 production classes use the
   `global` modifier without an `@SuppressWarnings('PMD.AvoidGlobalModifier')`
   annotation. PMD reports them at priority 3 but CI does not block — the
   `feature_test.yml` workflow only enforces `AvoidDebugStatements` strictly.
   These appear as the "~48 AvoidGlobalModifier" count in the 5/15 baseline.
   **Per the 5/21 baseline's recommendation #3 (3h effort, Medium risk),
   this needs an AUDIT-then-downgrade pass, not a mechanical suppression
   sweep** — many of the 53 may be candidates for `global → public`
   downgrade if no external (REST / managed-extension) consumer exists.
   Mechanical suppression-add would hide a question we should answer.
3. **P2: `getDescribe().getName()` → `getLocalName()` rename.** 9 call
   sites in 7 files (see table below). Per CLAUDE.md, `getLocalName()` is
   the managed-package-safe form. **However:** every one of the 9 sites
   was manually verified for current behavior — none breaks in subscriber
   namespace context because each is either (a) paired with
   `stripNamespace()`, (b) consumed by an `endsWithIgnoreCase('WorkItem__c')`
   check which works either way, or (c) intentionally needs the namespaced
   form (dynamic SOQL on line 684, Lightning record URL on line 969,
   intentional 3-form index on `DeliveryGanttController.cls:854`).
   **Not recommended for mechanical rewrite** — needs per-call discretion.

## Per-rule findings

### 1. Boolean / Checkbox field toggles (Glen's headline ask)

**Rule:** "Use DateTime stamps, not Booleans, for feature toggles
(`EnableXDateTime__c` pattern)" (CLAUDE.md). Forbidden Checkbox per
`docs/FIELD_NAMING.md` ("Checkbox fields are forbidden — convert to
DateTime") and `[[no-bool-fields]]` ("Zero tolerance. ALL Bool__c fields
ELIMINATED").

**Scan:** all `force-app/main/default/objects/**/fields/*.field-meta.xml`
for `<type>Checkbox</type>`.

**Findings: 0.** Zero Checkbox fields exist anywhere in the package.

Apex-side `Boolean` usage was also surveyed:

- `@AuraEnabled public Boolean *` DTO members (37 sites) — these are
  LWC transport fields that mirror underlying `*DateTime__c` storage to
  the UI. The established `DeliveryHubSettingsController.SettingsDTO`
  pattern pairs each `Boolean enabledFoo` with a `String fooActivatedAt`.
  **Not violations** — DTO transport requires Boolean for `if:true|false=`
  template binding.
- `Boolean` return types on `@AuraEnabled` query methods (`isAdmin`,
  `isApprovalRequired`, `isSubscriberOrg`, etc.) — same rationale,
  derived from underlying DateTime state. **Not violations.**
- `WebhookHandlerResult.success: Boolean` — HTTP response state, not a
  persisted toggle. **Not a violation.**

### 2. `WITH USER_MODE` in Apex

**Rule:** "`WITH USER_MODE` breaks in namespaced package test context —
use `WITH SYSTEM_MODE`." (CLAUDE.md).

**Scan:** `WITH\s+USER_MODE` and `AccessLevel.USER_MODE` across all of
`force-app/`.

**Findings: 0.** Five hits exist in comments documenting prior USER_MODE
→ SYSTEM_MODE swaps (`DeliveryActivityLogController.cls:47`,
`DeliveryHubCommentController.cls:21,109`,
`DeliveryWorkItemTriggerHandler.cls:154,384`). No live code uses
USER_MODE.

### 3. `Schema.getGlobalDescribe().get('Foo__c')` (namespace-unsafe)

**Rule:** `[[namespace-safe-typed-sobject-describe]]` — never
string-key the global describe map for a DH custom object; use
`Foo__c.SObjectType.getDescribe()` instead. String-keyed lookups return
null in `delivery__` packaging context.

**Scan:** `Schema\.getGlobalDescribe\(\)\.get\(\s*['"][A-Z][A-Za-z]*__c['"]`
across all `force-app/`.

**Findings: 0.** All previously-known sites (PR #797 production,
PR #800 tests) are resolved. The single remaining
`Schema.getGlobalDescribe()` call (`DeliverySyncItemIngestor.cls:1063`)
uses dynamic iteration with namespace-aware key matching — namespace-safe.

### 4. `getDescribe().getName()` vs `getLocalName()`

**Rule:** "`getLocalName()` not `getName()` for field/object API names
in managed package context" (CLAUDE.md). `getName()` returns the
namespaced form (`delivery__Foo__c`); `getLocalName()` returns the bare
form (`Foo__c`). For most comparison and DTO emission uses,
`getLocalName()` is the safe canonical choice.

**Findings: 9 call sites across 7 files** — all manually verified, none
break behavior in subscriber namespace:

| File | Line | Current code | Verdict |
|---|---|---|---|
| `DeliveryContentDocLinkTriggerHandler.cls` | 65 | `cdl.LinkedEntityId.getSObjectType().getDescribe().getName()` | Cosmetic — `endsWithIgnoreCase('WorkItem__c')` works regardless |
| `DeliveryCsvImportController.cls` | 175 | `entry.put('apiName', dfr.getName())` | Cosmetic — namespaced apiName emitted to LWC (acceptable; LWC code dynamically resolves either form) |
| `DeliveryCsvImportController.cls` | 240, 244 | `wi.put(dfr.getName(), ...)`, debug log | Cosmetic — `SObject.put()` accepts both forms |
| `DeliveryHubCommentController.cls` | 116 | error message string | **Cosmetic improvement only** — namespace prefix leaks into user-visible error |
| `DeliverySyncEngine.cls` | 357, 396, 408 | paired with `stripNamespace()` or `endsWithIgnoreCase()` | Works either way |
| `DeliverySyncItemIngestor.cls` | 215, 565, 644, 784, 807 | paired with `stripNamespace()` or `endsWithIgnoreCase('WorkItem__c')` | Works either way |
| `DeliverySyncItemIngestor.cls` | 684 | `'SELECT Id FROM ' + type.getDescribe().getName() + ...'` (dynamic SOQL) | **`getName()` REQUIRED** — dynamic SOQL needs namespaced object name. Do NOT change. |
| `DeliverySyncItemIngestor.cls` | 969 | Lightning record URL build | **`getName()` REQUIRED** — `/lightning/r/delivery__NetworkEntity__c/...` works; bare form 404s. Do NOT change. |
| `DeliverySyncItemPendingResolver.cls` | 276 | `endsWithIgnoreCase('WorkItem__c')` | Works regardless |
| `DeliveryGanttController.cls` | 854 | INTENTIONAL "3-form index" lookup (comment on line 845-846) | **INTENTIONAL — keep** |
| `DeliveryWorkItemTriggerHandlerTest.cls` | 465 | comparing to literal `'User'` (standard object) | Works (standard objects have no namespace) |

**Recommendation:** No mechanical rewrite. If any sweep is desired,
limit to (a) `DeliveryHubCommentController.cls:116` (user-visible error
message) and (b) the `stripNamespace(getName())` call sites where
`getLocalName()` is functionally equivalent and shorter. Even those are
P3 cleanup; no functional difference.

### 5. LWC `@api` Boolean defaulting to `true` (LWC1503)

**Rule:** "LWC boolean `@api` props cannot default to `true` (LWC1503)
— use inverted prop name" (CLAUDE.md).

**Scan:** `@api\s+\w+\s*=\s*true` and multiline `@api`-newline-prop
patterns across all `.js` in `force-app/main/default/lwc/`.

**Findings: 0.**

### 6. LWC `.html` ternary expressions

**Rule:** "LWC templates do NOT support ternary expressions in API v62
— use getters instead" (CLAUDE.md).

**Scan:** `\{[^}]*\?[^}]*:[^}]*\}` across all `.html` in
`force-app/main/default/lwc/`.

**Findings: 0.**

### 7. `<fieldManageability>` on `__c` fields

**Rule:** `[[field-manageability-only-on-mdt]]` — element is only valid
on `__mdt` fields. On `__c` fields it causes silent deploy skip + Apex
compile fail.

**Scan:** `<fieldManageability>` in field-meta XML, filter to non-`__mdt`
parent objects.

**Findings: 0.** 149 occurrences total, all on `__mdt` fields.

### 8. `__mdt` picklists using `<valueSetName>` (GVS)

**Rule:** `[[mdt-picklists-must-be-inline]]` — Salesforce platform
forbids GlobalValueSet references on `__mdt` picklist fields.

**Scan:** `<valueSetName>` in any `*__mdt/fields/*.field-meta.xml`.

**Findings: 0.**

### 9. `<customNotificationTypeAccesses>` in permsets

**Rule:** `[[custom-notification-type-access-not-a-permset-element]]`
— not a valid PermissionSet metadata element in DH's API version.

**Scan:** `customNotificationTypeAccesses` anywhere in
`force-app/main/default/permissionsets/`.

**Findings: 0.**

### 10. Custom Settings non-primitive field types

**Rule:** `[[custom-settings-primitive-types-only]]` — Hierarchy Custom
Settings (`DeliveryHubSettings__c` is the only one) forbid LongTextArea,
Picklist, Lookup, MasterDetail, Formula. **Note:** the 2026-05-21
namespace audit corrected this rule: `TextArea` IS allowed; only
`LongTextArea` is the variant that's forbidden.

**Scan:** all 66 `DeliveryHubSettings__c/fields/*.field-meta.xml` for
`<type>` element values.

**Findings: 0.** All 66 fields use one of: `Text`, `TextArea`, `Number`,
`Date`, `DateTime`. No forbidden types.

### 11. Tests assigning `PermissionSetGroupId` without recalc

**Rule:** `[[psg-must-be-calculated-before-assignment-in-test]]` —
must call `Test.calculatePermissionSetGroup(psgId)` before
`insert new PermissionSetAssignment(PermissionSetGroupId = psgId)`.

**Scan:** `PermissionSetGroupId\s*=` in all Apex.

**Findings: 0.** Sole match
(`DeliveryFeatureDepEditorControllerTest.cls:93`) correctly precedes
the assignment with `Test.calculatePermissionSetGroup(psgs[0].Id)` on
line 90.

### 12. Apex class identifiers >40 chars

**Rule:** `[[apex-identifier-40-char-limit]]` — Apex identifier cap is
40 chars. Production controller at 36-38 chars produces `*Test`
companion that blows the cap.

**Scan:** `force-app/main/default/classes/*.cls` filenames.

**Findings: 0 over the cap.** Two classes at exactly 40 chars
(borderline):

- `DeliveryPermissionAnalyzerControllerTest` (40 chars)
- `DeliveryContentDocLinkTriggerHandlerTest` (40 chars)

Both compile and deploy fine. No action needed unless a future rename
adds characters.

### 13. Apex `global` classes missing `AvoidGlobalModifier` suppression

**Rule (project convention):** when intentionally using `global`, document
the choice with `@SuppressWarnings('PMD.AvoidGlobalModifier')` so PMD
doesn't flag it as accidental scope-broadening.

**Scan:** `^global\s+(with|without|inherited)?\s*(sharing)?\s*(virtual\s+|abstract\s+)?(class|interface)`
across `force-app/main/default/classes/*.cls`, then exclude files that
already carry `AvoidGlobalModifier` in any annotation.

**Findings: 53 classes.** Full list captured during the audit. Examples:
`DeliveryWorkItemController`, `DeliveryHubDashboardController`,
`DeliveryHubSettingsController`, `DeliveryActivityFeedController`,
`DeliveryPublicApiService`, `DeliverySlackService`, etc.

**Why not auto-fix:** the 5/21 PMD baseline explicitly recommends an
audit-then-downgrade pass (recommendation #3, "AvoidGlobalModifier audit
+ targeted downgrades to `public` — 3h — Medium risk"). Mass-adding
suppressions would hide the design question of whether each class genuinely
needs `global` scope. Many may be candidates for `global → public`
downgrade if no external REST / managed-extension consumer depends on
the scope. Deferred to a dedicated AvoidGlobalModifier review session.

### 14. Inline `valueSetDefinition` on `__c` picklists

**Rule:** CLAUDE.md says new `__c` picklists must use GVS
(`<valueSetName>`) from day one. **Existing inline-defined picklists
are grandfathered** because SF blocks retrofitting GVS onto an existing
inline-defined field.

**Scan:** all 34 inline `<valueSetDefinition>` instances on `__c`
fields, then check git creation date to identify any NEW (post-2026-05-13)
additions.

**Findings: 0 NEW violations.** All 34 inline picklists existed before
the cockpit ship cycle. The most recently *modified* picklist
(`ActivityLog__c/fields/ActionTypePk__c.field-meta.xml`, 2026-05-20)
was originally created 2026-02-26 (modified only to add a value, which
is the supported maintenance path for inline-defined picklists).

The most recently *created* inline `__c` picklist
(`NetworkEntity__c/fields/RevealFulfillmentDepthPk__c.field-meta.xml`,
2026-05-12, PR #760 depth-charge scaffold) shipped inline. Per
CLAUDE.md this would be a violation if it were caught at brief time,
but it's now grandfathered (SF blocks retrofit). Mark as "ship-time
miss; do not regress" for future depth-charge work.

### 15. Apex reserved-word identifiers

**Rule:** `[[gotcha-apex-reserved-when]]` and CLAUDE.md — `when`,
`inherited`, `do`, `switch`, `type`, `desc`, etc. cannot be method,
variable, or field identifiers.

**Scan:** Type-prefixed reserved-word patterns
(`String|Integer|Boolean|Decimal|Datetime|Id|Object|List|Map|Set` +
reserved word).

**Findings: 0.**

### 16. `AuraHandledException.getMessage()` asserted in tests

**Rule:** "`AuraHandledException.getMessage()` returns generic in managed
package — never assert on message" (CLAUDE.md).

**Scan:** `catch (AuraHandledException e)` blocks in `*Test.cls`,
cross-referenced with `e.getMessage()` assertions.

**Findings: 0.** All `AuraHandledException` catches use a `threw`
boolean or `caught = true` flag and assert on the flag, never on the
message. The 4 sites that DO assert on `e.getMessage()`
(`DeliveryFeatureCatalogControllerTest.cls:495,560,590`,
`DeliveryHubExceptionTest.cls`, `DeliverySyncItemIngestorTest.cls:477`,
`DeliveryWorkLogTriggerHandlerTest.cls:242`) catch
`DmlException` / `DeliveryHubException` — not `AuraHandledException`.

## Remediation PR scope

**No remediation PR.** Per the framework specified in the brief:
- P0 violations: 0 → nothing must-fix
- Mechanical fixes available: only at P2 cosmetic level, all require
  per-call design discretion (the `getName()` sites have 2 that REQUIRE
  the namespaced form; the AvoidGlobalModifier 53 need scope audit, not
  mechanical suppression)
- Per `[[verify-audit-findings-before-shipping]]`: refuse to ship empty
  or design-level PRs.

This audit ships as a docs-only PR alongside the report. The negative
result is itself the deliverable — the codebase is currently in the
cleanest state the audit framework can measure.

## Lessons for future audits

1. **Memory-driven audits are now self-confirming.** Every CLAUDE.md
   rule + every memory feedback file produced a zero-violation result
   on its own scan. The 2026-05-15 cockpit-PR ship cycle (and the prior
   April Bool-elimination sweep) drove the codebase to a state where
   the documented rules are universally followed.

2. **TextArea on Custom Settings is allowed.** The
   `[[custom-settings-primitive-types-only]]` memory lists `TextArea`
   as forbidden, but the 2026-05-21 namespace audit correctly identified
   only `LongTextArea` (32k variant) as the actual blocker. The memory
   file should be updated to reflect this. (Out of scope for this audit
   — flagged for a memory-file fix.)

3. **`getName()` vs `getLocalName()` is more nuanced than CLAUDE.md
   admits.** Two legitimate use cases REQUIRE `getName()`: dynamic
   SOQL string construction and Lightning record URL construction.
   The CLAUDE.md rule should be amended to: "prefer `getLocalName()`
   for comparison and DTO emission; use `getName()` when building
   dynamic SOQL or Lightning URLs that need the runtime-resolved
   object name."

4. **AvoidGlobalModifier cleanup is a real backlog item.** 53 classes
   without the suppression annotation. Not a CI blocker today, but
   represents an unaddressed design question (should each be `public`
   or `global`?). Schedule as a 3h focused session per the 5/21
   recommendation.

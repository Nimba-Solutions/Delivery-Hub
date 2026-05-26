# Contributing to Delivery Hub

> Rules of the road for shipping new code, fixes, or docs to the Delivery Hub managed package. Companion to `docs/DESIGN_PRINCIPLES.md` (which explains *what* patterns to follow) — this doc explains *how* to ship them.

Aimed at outside contributors and at internal agent + human authors alike. Where this doc and `CLAUDE.md` conflict, follow `CLAUDE.md` (it captures the internal-tooling rules that govern day-to-day shipping).

---

## 1. Branch + PR workflow

- **Never commit directly to `main`.** Every change ships via branch + PR + CI.
- Branch naming: `feat/<topic>`, `fix/<topic>`, `chore/<topic>`, `docs/<topic>`, `refactor/<topic>`. Topic is hyphen-cased.
- PR titles use conventional commits: `feat(cockpit): ...`, `fix(watcher): ...`, etc.
- One concern per PR. The two-scratch-org cost of each PR (one for feature-test, one for upload-beta) means batching related fixes into fewer PRs is real money — but don't batch unrelated work. Reviewers can't separate it post-hoc.
- After-merge: every push to `main` triggers `beta_create.yml`. The cumulative beta becomes promoteable when `upload-beta` (not `install-beta`, which has a known flaky DeliveryHubSite failure) reports green.

---

## 2. Apex class naming

- Test class name = production class name + `Test` (no separator). E.g., `DeliveryFeatureApprovalService` → `DeliveryFeatureApprovalServiceTest`.
- Class name **including namespace prefix** must be ≤ 40 chars (Salesforce hard limit). Because the prefix is `delivery__` (10 chars) + `_Test` suffix (4 chars), production class names should stay **≤ 36 chars** so `*Test` still fits. Above 36 chars and the test class can't deploy.
- Service class names end in `Service`. Controller class names end in `Controller`. Trigger-handler class names end in `TriggerHandler`. DTO inner classes named `*DTO`. PR review will flag any naming drift.
- Inner classes used in `global` return / param signatures must themselves be `global`. Forgetting this surfaces as an upload-beta failure with a `Cannot reference non-global class` error.

---

## 3. SOQL + Apex conventions

- `WITH SYSTEM_MODE`, not `WITH USER_MODE`. `WITH USER_MODE` breaks in the namespaced package test context.
- `getLocalName()`, not `getName()`. The former returns the bare API name; the latter returns the namespace-prefixed name in packaging context.
- **Typed describe, not `Schema.getGlobalDescribe()`.** Use `<SObject>__c.SObjectType.getDescribe()`. The global-describe form returns null for namespaced custom objects in packaging context. See `docs/DESIGN_PRINCIPLES.md` §4.
- **PSG admin checks query DeveloperName, accept both forms.** `PermissionSetGroup.DeveloperName IN ('DeliveryHubAdmin', 'delivery__DeliveryHubAdmin')`. See `docs/DESIGN_PRINCIPLES.md` §6.
- `AuraHandledException.getMessage()` returns a generic string in managed-package context — never write a test that asserts on the message text.
- LWC boolean `@api` properties cannot default to `true` (LWC1503). Invert the prop name (e.g., `disableX` rather than `enableX` defaulting `true`).
- LWC templates do not support ternary expressions in API v62 — define a getter on the JS side and reference it from the template.

---

## 4. Custom Settings + Custom Object metadata

- `DeliveryHubSettings__c` is a hierarchy Custom Setting. **Custom Settings only support primitive types** (`Number`, `Text`, `Checkbox`, `DateTime`, `Date`, `Currency`, `Email`, `URL`). `LongTextArea`, `Picklist`, and `Lookup` are platform-forbidden — if your design needs one, convert to `Text(255)` (or move state to a `__c` object).
- Custom Object `.object-meta.xml` must set the three API-flag triplet consistently:
  - `enableSharing` (true if Sharing Rules / OWD writeable, false otherwise)
  - `enableBulkApi` (true unless platform reason to disable)
  - `enableStreamingApi` (true if record changes drive CDC / platform events)
  Mismatched values across the triplet are an upload-beta deploy failure.
- `<fieldManageability>` is only valid on `__mdt` fields. Adding it to a `__c` field is a silent deploy skip + an Apex compile failure at the next service that references the field.
- Picklist fields on `__c` must use `<valueSetName>` (GVS). Picklist fields on `__mdt` must use inline `<valueSetDefinition>`. The two platforms have opposite rules.
- **Always grep `docs/FIELD_NAMING.md` before drafting a new field name.** URL/Email/Phone fields drop the typed suffix; Formula fields suffix by return type, not source type; Master-Detail fields use `*Id__c`. Following CLAUDE.md alone is insufficient — the full table is only in `FIELD_NAMING.md`.

---

## 5. Permission set + permset group hygiene

- Every new `__c` object gets explicit field perms in **both** `DeliveryHubAdmin_App` (admin) and `DeliveryHubApp` (user) permsets if user-readable. Admin-only objects (`WatcherDigest__c`, `FeatureToggleApproval__c`, etc.) ship in `DeliveryHubAdmin_App` only.
- Object-level CRUD goes under `<objectPermissions>` in each permset. Missing object perms is one of the highest-frequency subscriber bug reports (admin can see fields but can't query).
- `DeliveryHubAdmin` PSG bundles `DeliveryHubAdmin_App`; `DeliveryHubUser` PSG bundles `DeliveryHubApp`. Field/object perms go in the **permsets**, not the PSGs — PSGs are routing only.
- New CustomTab entries on `__c` objects must appear in both `DeliveryHub.app-meta.xml` and `DeliveryHubAdmin.app-meta.xml` tab lists; otherwise the tab is invisible in the app launcher.

---

## 6. Test helpers + admin context in tests

- **Use `TestDataFactory`.** All new tests should construct test data via the helper class. It defaults to safe values for the high-frequency CI failure classes (Master-Detail FKs, reserved-word fields, picklist allowlist alignment) so individual tests don't have to.
- **Admin-gated tests must call `Test.calculatePermissionSetGroup()` before querying PSG membership.** A fresh PSG assignment isn't queryable in the same transaction until the platform finishes the asynchronous calculation; `Test.calculatePermissionSetGroup()` forces it synchronously in test context. The canonical helper is `TestDataFactory.makeAdminUser()` (post-PR #821).
- **`@IsTest`-only classes** for test infrastructure — `TestDataFactory` itself is `@IsTest`. Test infrastructure must not ship as runtime code (no `public` test helpers leaking into production).
- **Bracket inserts with `triggerDisabled` only when the trigger is the unit under test.** Otherwise let the trigger fire; the integration coverage matters.

---

## 7. PMD ruleset

- CI scanner is **`engine: pmd` only.** The ESLint engine is ignored at the project level — LWC lint runs locally only.
- **`AvoidDebugStatements` is strictly enforced.** Any `System.debug(...)` call in production code (excluding `@IsTest` classes) fails CI. Use comments or remove.
- **Severity threshold is 4.** Findings at severity 1-4 break CI; severity 5 is informational. Most ApexDoc / cyclomatic-complexity findings are severity 3-4 and **will** block.
- ApexDoc `@param` + `@return` are required on every `global` and `@AuraEnabled` method. PR #791 swept `DeliveryDocumentController` for this; new contributions should not regress.
- Cyclomatic complexity > 10 on a single method must be suppressed with `@SuppressWarnings('PMD.CyclomaticComplexity, PMD.StdCyclomaticComplexity')` at the class level, with a comment explaining why (e.g., REST routing tables that fan out by resource).

---

## 8. Pre-merge upload-beta gotcha checklist

The upload-beta job runs in the namespaced `delivery__` packaging context, so it surfaces a different class of failures than the PR-level feature-test job. Before approving a PR for merge, check:

- [ ] **No `Schema.getGlobalDescribe().get('Foo__c')`** anywhere in the diff. Use typed describe.
- [ ] **PSG admin checks include both forms** (`'DeliveryHubAdmin', 'delivery__DeliveryHubAdmin'`).
- [ ] **All `global` inner DTOs declared `global`**, not `public`.
- [ ] **Custom Setting fields are primitive types** (no LongTextArea / Picklist / Lookup on `DeliveryHubSettings__c`).
- [ ] **Custom Object API-flag triplet aligned** (`enableSharing` / `enableBulkApi` / `enableStreamingApi` consistent for the object's intent).
- [ ] **`<fieldManageability>` only on `__mdt` fields**, never on `__c`.
- [ ] **Master-Detail FK populated on test inserts** (PR #770 hotfix — `WorkLog__c.RequestId__c` required).
- [ ] **Reserved-word fields aren't used as Apex variable names** (`merge`, `share`, `update`, etc.) — Apex parser rejects them as identifiers.
- [ ] **Picklist fields on `__c` use `<valueSetName>` (GVS)**, not inline `<valueSetDefinition>`.
- [ ] **Picklist fields on `__mdt` use inline `<valueSetDefinition>`**, not `<valueSetName>` (platform forbids GVS on `__mdt`).
- [ ] **Rolling-window date assertions anchor on `Date.today()`**, not hardcoded dates — PR #771 hotfix.
- [ ] **Org-state assertions (e.g., `isSubscriberOrg`, `recommendedCciFlow`) tolerate both namespaced and bare context** — PR #805 / #806 hotfix.

The single most common upload-beta failure shape is "passes feature-test, fails upload-beta with a null deref on `Schema.getGlobalDescribe()` or a typed-describe miss." Grep the diff for `getGlobalDescribe` before approving.

---

## 9. Change log expectation

`docs/CHANGELOG.md` is **not** the source of truth for per-PR detail. Per-PR detail lives in the GitHub PR description. The changelog rolls up themes per release (e.g., "0.243 — 0.247: cockpit feature catalog, Watcher v1, onboarding tracks").

New contributors don't need to edit the changelog as part of a PR. The release-promote step folds the per-PR descriptions into the next changelog section.

---

## 10. Documentation expectation per PR type

| PR type | Doc expectation |
|---|---|
| `feat` shipping a new `__c` object | Update `docs/ARCHITECTURE.md` object-model table; add a one-line entry to `docs/FLOW_REFERENCE.md` if it touches a user flow |
| `feat` shipping a new `__mdt` type | Object-level `<description>` block in the `.object-meta.xml` (admin-readable in Setup) |
| `feat` shipping a new REST route | Inline ApexDoc on the route method (verb / path / body shape / status codes); `docs/PUBLIC_API_GUIDE.md` entry for external-facing routes |
| `feat` shipping a new LWC | Top-of-file `/** @description ... */` block in the `.js` file |
| `feat` shipping a new Custom Setting field | `<description>` AND `<inlineHelpText>` in the `.field-meta.xml`. Both — the description shows in Setup, the help text shows on the field edit page |
| `fix` resolving an audit finding | If the audit lives under `docs/audits/`, update the audit doc inline (mark the row resolved or correct the stale claim). PR #807-#816 introduced this discipline; honour it. |
| `docs` | No production code touched. README + setup + REST API guide and architecture-level docs (`DESIGN_PRINCIPLES`, `CONTRIBUTING`, `FLOW_REFERENCE`) are owned by docs PRs only. |

---

## 11. Org aliases

| Alias | Purpose |
|---|---|
| `MF-Prod` | Internal production for the cross-org sync partner |
| `nimba` | Sandbox where invoices are cut |
| `dh-prod` | Dev hub org (separate from Nimba) |

When running anonymous Apex against a subscriber org, always prefix with `delivery__` — the deploy artefact is namespaced and bare names won't resolve.

---

## 12. Reporting bugs + getting help

- GitHub Issues: https://github.com/Nimba-Solutions/Delivery-Hub/issues
- Docs hub: https://cloudnimbusllc.com/docs
- Internal: post in the relevant Fathom-tracked standup or surface to the next architecture review.

---

## Related reading

- `docs/DESIGN_PRINCIPLES.md` — the eight patterns this contributing guide assumes you'll follow
- `docs/ARCHITECTURE.md` — the object model + service-layer map
- `docs/FIELD_NAMING.md` — typed-suffix field naming convention
- `docs/PICKLIST_INTEGRITY.md` — GVS vs inline picklist deep-dive
- `docs/PUBLIC_API_GUIDE.md` — public REST surface
- `CLAUDE.md` — internal-tooling rules for the day-to-day shipping cadence

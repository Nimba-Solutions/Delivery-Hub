# Namespace + Custom-Settings Safety Audit — 2026-05-21

> Triggered after PRs #797, #800, #805, #807 all hit either the namespace-context or Custom-Settings type traps in the recent cockpit ship cycle. Goal: prove the repo is clean post-hotfixes.

## Headline

- **`Schema.getGlobalDescribe().get('Foo__c')` patterns:** **0** (all resolved by PRs #797 + #800)
- **Custom Setting field-type violations:** **0** (initial audit flagged `WeeklyDigestRecipientsTxt__c` as `TextArea` but **TextArea IS allowed on Custom Settings**; only `LongTextArea` is forbidden)
- **Custom Object API-flag triplet mismatches:** **0**
- **`WITH USER_MODE` in tests:** **0**

The repo is **clean** on all four risk vectors after the hotfixes landed.

## 1. `Schema.getGlobalDescribe` lookups

Production code: 0 unsafe patterns.

Test code: 0 unsafe patterns.

The single remaining `Schema.getGlobalDescribe()` call in the codebase (`DeliverySyncItemIngestor.cls:1063`) uses dynamic iteration over the full describe map (which is namespace-safe) rather than a hardcoded string-key lookup — no risk.

## 2. Custom Setting field-type violations

`DeliveryHubSettings__c` (Hierarchy Custom Setting) field types audited. All fields use types Salesforce permits on Custom Settings:

- ✅ Text (255 chars and below)
- ✅ TextArea (initially flagged by the audit agent as a violation; **it IS allowed on Hierarchy Custom Settings.** Only `LongTextArea` is forbidden — that's the bigger 32k-char variant.)
- ✅ DateTime
- ✅ Number
- ✅ Date, Email, Phone, URL, Currency, Percent, Checkbox (all permitted)

**Correction to original audit:** the agent's allowlist was missing `TextArea`. The single flagged field `DeliveryHubSettings__c.WeeklyDigestRecipientsTxt__c` is in the allowed set.

## 3. Custom Object API-flag triplet

7 custom objects have all three of `<enableSharing>`, `<enableBulkApi>`, `<enableStreamingApi>` declared. All 7 have them aligned (`true`/`true`/`true`):

- `Feature__c`, `FeatureDependency__c`, `FeatureToggleRequest__c`, `FeatureToggleApproval__c`
- `OnboardingProgress__c`
- `ScratchOrgInstance__c`
- `DatasetTemplate__c`, `DatasetTemplateAssignment__c`
- `WatcherDigest__c` (PR-A #807 — fixed in `d01a6478` after initial deploy failure)

Other objects omit one or more flags (rely on platform defaults); none have mixed explicit values.

## 4. `WITH USER_MODE` in tests

0 occurrences. All tests use `WITH SYSTEM_MODE` per CLAUDE.md.

## Recommended cleanup PR

**None.** Audit clean.

## Lessons captured for future agents

The risk vectors above produced 5 hotfix PRs this cycle (#797, #800, #805, #807-fix, #806). Reusable memories now saved:

- `[[namespace-safe-typed-sobject-describe]]` — never `Schema.getGlobalDescribe().get('Foo__c')`; use typed `Foo__c.SObjectType.getDescribe()`
- `[[custom-settings-primitive-types-only]]` — Custom Settings forbid `LongTextArea` (but **DO** allow `TextArea`); Custom Object API-flag triplet must align

Both are referenced from `MEMORY.md` and should be baked into every future agent brief that touches `DeliveryHubSettings__c` or creates a new custom object.

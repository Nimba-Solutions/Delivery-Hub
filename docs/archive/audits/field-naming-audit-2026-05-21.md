# Field-Naming Convention Audit — 2026-05-21

> Source of truth: `docs/FIELD_NAMING.md`. PMD enforces a subset of these rules via `category/xml/default.xml`; the rest are conventions audited manually.

## Headline

- **Total `__c` fields scanned:** 503
- **Strict violations:** **0**
- **Forbidden Checkbox fields:** 0
- **Custom Settings type violations:** 0
- **Master-Detail legacy `*Id__c` compliance:** 8/8 verified (per the immutable PR #590 list)

**This is the cleanest field-naming state in the repo's history** — driven by early PMD enforcement, the DateTime-based toggle pattern (no Booleans), and the immutable Master-Detail naming.

## Per-rule scan results

| Rule | Violations |
|---|---|
| URL fields with surplus `Txt__c` suffix | 0 |
| Picklist fields missing `Pk__c` | 0 |
| Number fields missing `Number__c` | 0 |
| LongTextArea fields missing `Txt__c` | 0 |
| Lookup fields missing `Lookup__c` | 0 |
| Checkbox fields (forbidden) | 0 |
| Formula return-type suffix mismatches | 0 |
| Custom Settings non-primitive types | 0 |

## This cycle's new objects — compliance scoreboard

All 14 new objects created during the cockpit ship cycle (PRs #793-#805) pass cleanly:

| Object | Field count | Violations |
|---|---|---|
| `Feature__c` | 7 | 0 |
| `FeatureDefinition__mdt` | 8 | 0 |
| `FeatureDependency__c` | 6 | 0 |
| `FeatureToggleRequest__c` | 9 | 0 |
| `FeatureToggleApproval__c` | 8 | 0 |
| `OnboardingTrack__mdt` | 5 | 0 |
| `OnboardingLesson__mdt` | 6 | 0 |
| `OnboardingQuiz__mdt` | 4 | 0 |
| `OnboardingChecklistItem__mdt` | 6 | 0 |
| `OnboardingProgress__c` | 11 | 0 |
| `ScratchOrgInstance__c` | 9 | 0 |
| `DevLoopGuide__mdt` | 9 | 0 |
| `DatasetTemplate__c` | 6 | 0 |
| `DatasetTemplateAssignment__c` | 8 | 0 |

## Master-Detail legacy compliance

Per `docs/FIELD_NAMING.md`, 8 immutable Master-Detail fields use the legacy `*Id__c` suffix — all verified intact:

- `BountyClaim__c.WorkItemId__c`
- `DeliveryDocument__c.NetworkEntityId__c`
- `DeliveryTransaction__c.DocumentId__c`
- `DocumentAction__c.DocumentId__c`
- `PortalAccess__c.NetworkEntityId__c`
- `WorkItemComment__c.WorkItemId__c`
- `WorkLog__c.RequestId__c`
- `WorkRequest__c.WorkItemId__c`

## Recommended cleanup PR

**None.** Zero strict violations. The repo is production-ready from a naming-convention perspective.

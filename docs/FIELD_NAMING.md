# Delivery Hub — Field Naming Convention

Every custom field in this package has a **type-indicating suffix** so you can tell what a field holds without opening the metadata. This is enforced by `scripts/validate-field-naming.py` which runs on every PR via the `Feature - Test (Unlocked)` workflow.

PMD does not cover SObject metadata naming — these are project conventions, not platform rules.

## The canonical table

| Salesforce type | Suffix | Example |
|---|---|---|
| Text / TextArea / LongTextArea / Html / EncryptedText | `Txt__c` | `BriefDescriptionTxt__c` |
| Picklist / MultiselectPicklist | `Pk__c` | `StageNamePk__c` |
| Number | `Number__c` | `EstimatedHoursNumber__c` |
| Currency | `Currency__c` | `BillableRateCurrency__c` |
| Date | `Date__c` | `DueDateDate__c` |
| DateTime | `DateTime__c` | `ActivatedDateTime__c` |
| Time | `Time__c` | (no instances yet) |
| Lookup / MasterDetail / Hierarchy | `Lookup__c` | `WorkItemLookup__c` |
| MetadataRelationship | `Mdt__c` | `WorkflowTypeMdt__c` |
| Percent | `Pct__c` | `BudgetUtilizationPct__c` |
| Roll-Up Summary | `Sum__c` | `TotalLoggedHoursSum__c` |
| Email | _no suffix — field name carries it_ | `ClaimantEmail__c` |
| Url | _no suffix_ | `WorkProofUrl__c` |
| Phone | _no suffix_ | `ContactPhone__c` |
| Location | `Geo__c` | (no instances yet) |
| Checkbox | **forbidden — convert to DateTime** | see below |
| Formula | suffix matches **return type** | `HoursVarianceNumber__c` (Formula→Number) |

## No booleans

Delivery Hub does not use Checkbox fields. Use a `*DateTime__c` field instead — `null` means "off / not yet", a populated timestamp means "on, since X". This gives you the audit trail for free.

If you need a checkbox in the UI, render it as `bound={!ISBLANK(SomeRequirementDateTime__c)}` (or the equivalent in LWC) — the underlying storage is still a DateTime.

The only suffix in this convention reserved for Checkbox is `Bool__c`. It exists so the validator can recognize a violation if anyone ever adds one. **Don't.**

## Edge cases the validator handles

- **Platform Events** cannot use Picklist fields — Salesforce stores them as Text. Use the `Txt` suffix even when the value is logically picklist-like (e.g., `DeliveryDocEvent__e.StatusTxt__c`). The validator knows about this and treats Text fields on `*__e` objects normally.

- **Email / Url / Phone** drop the suffix because the field name itself communicates the content type (`ClaimantEmail__c` is unambiguously an email). The validator allows these to end in the bare type word.

- **Formula fields** must use the suffix matching their return type, not a `Formula` suffix. The validator looks at `<formula>` and `<returnType>` to verify.

## Lookup vs Master-Detail

Both use the `Lookup__c` suffix because both are foreign-key relationships. The actual `<type>` element distinguishes them. Use Master-Detail only when:
- The child should not exist without the parent
- You want the parent to own roll-up summary fields based on child data
- You're OK with cascade-delete and record locking on save

Otherwise use Lookup with `<deleteConstraint>SetNull</deleteConstraint>`. **Never use Cascade** unless you have explicit business approval — accidental cascade-deletes are catastrophic and irreversible.

## How references work after rename

When you rename a Lookup field, the relationship traversal name changes too:
- Field: `WorkItemLookup__c`
- Traversal: `WorkItemLookup__r` (drop `__c`, add `__r`)
- In SOQL: `SELECT WorkItemLookup__r.Name FROM WorkLog__c`

The `<relationshipName>` element in the XML is **independent** of the field name — it's the child relationship label used in subqueries (`SELECT (SELECT Id FROM WorkLogs__r) FROM WorkItem__c`). Pick a name that reads naturally on the parent side; do not derive it mechanically from the field name.

## Validator

`scripts/validate-field-naming.py` runs as part of `feature_test.yml` on every PR. It exits non-zero on any violation, which fails the CI check. To run locally:

```bash
python scripts/validate-field-naming.py
```

The validator skips fields whose XML opts in via:

```xml
<!-- naming-validator: skip — reason here -->
```

…inside the `<CustomField>` element. Use this only when Salesforce metadata constraints make compliance impossible (e.g., a hardcoded standard field name on a managed package extension).

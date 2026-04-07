# Delivery Hub — Field Naming Convention

Every custom field in this package has a **type-indicating suffix** so you can tell what a field holds without opening the metadata. Enforced by the local PMD ruleset at `category/xml/default.xml`, which runs on every PR via the `apex-scan` job in `.github/workflows/feature_test.yml`.

The `*FieldNamingConvention` rules are XPath expressions over the field metadata XML — see `category/xml/default.xml` for the exact rules. All naming rules are priority 2 (blocking, fails CI when violated).

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
| Lookup / Hierarchy | `Lookup__c` | `WorkItemLookup__c` |
| MasterDetail | `Id__c` _(forever — see exception below)_ | `WorkItemId__c` |
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

The `CheckboxFieldsForbidden` rule in the PMD ruleset is priority 1 (blocking) and rejects any field with `<type>Checkbox</type>`. **Don't add any.**

## Edge cases

- **Platform Events** cannot use Picklist fields — Salesforce stores them as Text. Use the `Txt` suffix even when the value is logically picklist-like (e.g., `DeliveryDocEvent__e.StatusTxt__c`). PMD's TextArea/Text rules treat these as normal Text fields.

- **Email / Url / Phone** drop the suffix because the field name itself communicates the content type (`ClaimantEmail__c` is unambiguously an email). PMD enforces these as `*Email__c`, `*Url__c`, `*Phone__c`.

- **Formula fields** are not yet covered by the PMD ruleset because the `<type>` element holds the return type, not the literal "Formula" — there is no straightforward XPath to distinguish a formula field returning Number from a real Number field. Treat formula naming as a manual review item: the suffix should match the return type (e.g., `HoursVarianceNumber__c` for a formula that returns Number).

## Lookup vs Master-Detail

Both use the `Lookup__c` suffix because both are foreign-key relationships. The actual `<type>` element distinguishes them. Use Master-Detail only when:
- The child should not exist without the parent
- You want the parent to own roll-up summary fields based on child data
- You're OK with cascade-delete and record locking on save

Otherwise use Lookup with `<deleteConstraint>SetNull</deleteConstraint>`. **Never use Cascade** unless you have explicit business approval — accidental cascade-deletes are catastrophic and irreversible.

## Why Master-Detail fields use the legacy `*Id__c` suffix

PR #590 (commit `5f0c6c43`) attempted to rename 44 fields — including 7 Master-Detail relationships — to enforce the type-suffix convention package-wide. The Lookup renames worked. **The Master-Detail renames did not.** They blocked production installs.

**The Salesforce limitation:** Master-Detail relationship fields cannot be renamed via package upgrade. The platform refuses to delete the old MD field while child records still reference it, and refuses to create the new MD field while the old one still exists. There is no in-place rename operation for MD fields. The only "fix" is to delete every child record, then upgrade — which is not an option for production data.

**The 8 Master-Detail fields all use the `*Id__c` legacy pattern for consistency:**

| Object | Field |
|---|---|
| `BountyClaim__c` | `WorkItemId__c` |
| `DeliveryDocument__c` | `NetworkEntityId__c` |
| `DeliveryTransaction__c` | `DocumentId__c` |
| `DocumentAction__c` | `DocumentId__c` |
| `PortalAccess__c` | `NetworkEntityId__c` |
| `WorkItemComment__c` | `WorkItemId__c` |
| `WorkLog__c` | `RequestId__c` |
| `WorkRequest__c` | `WorkItemId__c` |

These field names are immutable. Do not attempt to rename them. The local PMD ruleset's `MasterDetailFieldNamingConvention` rule has been disabled (see `category/xml/default.xml`) so the build no longer flags them as violations.

**New Master-Detail fields must use the `*Id__c` suffix from day one.** Since renames are forever forbidden, the only safe convention is the same one already in use. Do not introduce a new suffix variant — pick `*Id__c` and stick with it.

Lookup fields (non-MD) still enforce the `*Lookup__c` suffix via `LookupFieldNamingConvention`, since Lookup fields **can** be renamed via package upgrade (Salesforce permits Lookup deletion + recreation in a single transaction).

## How references work after rename

When you rename a Lookup field, the relationship traversal name changes too:
- Field: `WorkItemLookup__c`
- Traversal: `WorkItemLookup__r` (drop `__c`, add `__r`)
- In SOQL: `SELECT WorkItemLookup__r.Name FROM WorkLog__c`

The `<relationshipName>` element in the XML is **independent** of the field name — it's the child relationship label used in subqueries (`SELECT (SELECT Id FROM WorkLogs__r) FROM WorkItem__c`). Pick a name that reads naturally on the parent side; do not derive it mechanically from the field name.

## Validator

PMD runs via the `apex-scan` job in `feature_test.yml`. The naming rules are at priority 2; the workflow's `severity-threshold: 4` blocks merges on any priority 1-4 violation.

To run locally (requires `@salesforce/sfdx-scanner`):

```bash
sf scanner run --target "force-app/main/default/objects/**/fields/*.field-meta.xml" --pmdconfig pmd-rules.xml --engine pmd
```

To skip enforcement on a specific field (only for unfixable cases like hardcoded standard field extensions), add a PMD suppression comment inside the field XML — see PMD docs for the exact syntax. Don't use this without a real reason.

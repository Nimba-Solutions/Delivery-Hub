# Picklist Integrity Architecture

## Why this exists

Salesforce has two ways to restrict the allowed values in a picklist:

1. **Inline `valueSetDefinition` with `<restricted>true</restricted>`** — the classic approach. SF enforces at DML time. Values live in the field-meta.xml itself.
2. **`valueSetName` referencing a `GlobalValueSet`** — values live in a shared metadata record. Multiple fields can reference the same GVS.

For **unlocked packages**, the inline path has a critical limitation:

> Adding new values to an existing `restricted=true` inline picklist does NOT reliably propagate to subscriber orgs on upgrade.
>
> — SF Known Issue [`a028c00000qPzYUAA0`](https://trailblazer.salesforce.com/issues_view?id=a028c00000qPzYUAA0).

DH was bit by this three separate times in early 2026: PR #453 (`DeliveryDocument.StatusPk`), commit `5037d993` (`SyncItem.ObjectTypePk`), and 2026-04-23 (`SyncItem.StatusPk` adding `Pending`).

And the "fix" — migrate existing inline-defined picklists to reference a GVS — is **blocked by SF at the metadata layer**:

> Cannot change which global value set this picklist uses.

This limitation was discovered on 2026-04-24 during PR #691. SF does not allow retrofitting GVS onto an existing inline-defined field. Once inline, always inline.

## DH's architecture (two patterns, by field vintage)

### New picklist fields — GVS from day one

All new picklist fields reference a `GlobalValueSet` via `<valueSetName>` and keep `<restricted>true</restricted>`. This is enforced by the rule in `CLAUDE.md`:

> Picklist fields must use `GlobalValueSet` references from day one (`<valueSetName>`), never inline `<valueSetDefinition>`.

Why: SF's restricted-picklist-propagation bug does NOT apply to GVS-backed picklists. New values added to a GVS propagate cleanly on package upgrade. The same GVS can also be reused by other fields.

### Legacy inline-defined fields — Apex trigger-layer allowlist

Four fields exist on main with inline `valueSetDefinition` and cannot be migrated:

| Object | Field |
|---|---|
| `SyncItem__c` | `StatusPk__c` |
| `SyncItem__c` | `ObjectTypePk__c` |
| `NotificationPreference__c` | `EventTypePk__c` |
| `ActivityLog__c` | `ActionTypePk__c` |

These fields are marked `<restricted>false</restricted>` because SF's upgrade-propagation bug would otherwise prevent shipping new values. Data integrity is enforced at the **Apex trigger layer** via `DeliveryPicklistIntegrityService`:

- Before-insert / before-update triggers on each of the 3 parent objects call `DeliveryPicklistIntegrityService.validate(record, fieldName, gvsName)`.
- The service reads the allowed values via `SObjectField.getDescribe().getPicklistValues()` — so the allowlist stays in sync with the field's defined values without hardcoding anything.
- Unknown values → `record.addError(fieldName, …)`, DML rejected.
- Values from bulk data loaders, managed-package callers, and external API integrations all pass through the trigger and are subject to the same guard.

This is the standard pattern enterprise Salesforce consultancies (Veeva, nCino, etc.) use when `restricted=true` isn't viable. It is NOT a workaround.

## Trade-offs accepted

- **Data integrity is Apex-layer, not platform-layer** for the 4 legacy fields. Equivalent in practice; different in appearance to an auditor looking at the schema alone.
- **Trigger execution overhead** on inserts/updates to those 3 objects. Negligible at DH's current scale; the `@TestVisible` describe cache keeps bulk runs O(1) per field.
- **Value additions** on the 4 legacy fields still require: (a) unrestrict via the field-meta.xml (already done), (b) modify source, (c) ship new package version, (d) subscribers upgrade. The integrity service auto-picks up the new value — no Apex change needed to allow it.

## Known follow-up: Path A — delete and recreate the 4 legacy fields as GVS-backed

Flagged for a future session (especially when DH has more developer capacity or hires help).

Path A would:
1. Export all row data from the 4 columns on all installed orgs (currently dh-prod, Nimba, MF-Prod — Glen controls all three)
2. Destructive change to remove each field from the package
3. Recreate each field with `<valueSetName>` referencing the appropriate GVS + `<restricted>true</restricted>`
4. Re-import the exported data

**Effort:** 24-48 hours of careful orchestration per field × 3 orgs. High-risk if any export-import step is missed (permanent data loss on sync/activity history).

**Payoff:** SF platform-layer enforcement of restricted picklists. Cleaner schema for an enterprise audit. Eliminates the trigger-layer overhead.

**When to reconsider:**
- When onboarding an enterprise client who audits the schema
- When DH has a second developer who can pair on the migration + rollback
- When any of the 4 fields needs to be referenced by process builder / flow decision nodes that require strict picklist semantics

Until one of those triggers, the trigger-layer pattern is the deliberate architecture. Not a stopgap.

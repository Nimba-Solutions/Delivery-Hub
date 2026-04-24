# Delivery Hub — Claude Code Rules

## Salesforce Development Rules
- Always use branch/PR workflow. NEVER commit directly to main.
- After any Apex change, run all related tests locally before pushing to CI when possible.
- Be aware of namespace/prefix issues across orgs (dh-prod, nimba, MF-Prod) — always confirm which org alias before running commands.
- LWC templates do NOT support ternary expressions in API v62 — use getters instead.
- `WITH USER_MODE` breaks in namespaced package test context — use `WITH SYSTEM_MODE`.
- `AuraHandledException.getMessage()` returns generic in managed package — never assert on message.
- `getLocalName()` not `getName()` for field/object API names in managed package context.
- LWC boolean `@api` props cannot default to `true` (LWC1503) — use inverted prop name.
- When making Apex classes `global`, ALL inner classes used as return/param types must also be `global`.
- Use DateTime stamps, not Booleans, for feature toggles (`EnableXDateTime__c` pattern).
- **Picklist fields must use `GlobalValueSet` references from day one (`<valueSetName>`), never inline `<valueSetDefinition>`.** Unlocked packages do not reliably propagate new values added to restricted inline picklists on subscriber upgrades (SF Known Issue `a028c00000qPzYUAA0`), and SF blocks retrofitting GVS onto an existing inline-defined field ("Cannot change which global value set this picklist uses"). GVS from day one is the only durable path.
- Existing inline-defined picklists stay `<restricted>false</restricted>`. Data integrity on those is enforced at the Apex service / trigger layer (see `DeliveryPicklistIntegrityService`), not via the field's restricted flag. This survives bulk-data-loader imports and subscriber customization.

## Org Aliases
- `MF-Prod` — glen.bradford@nimbasolutions.com.mf123 (MF production)
- `nimba` — Nimba sandbox (where invoices are cut)
- `dh-prod` — separate dev hub org (NOT Nimba)
- Always use `delivery__` namespace prefix when running anonymous Apex on subscriber orgs.

## CI/CD Rules
- CI scanner uses `engine: pmd` only — ESLint engines ignore project config.
- Pre-commit hook strips inline `/* eslint */` comments — must use config file.
- `install-beta` job is known to fail on DeliveryHubSite error — does NOT block. Safe to promote when `upload-beta` passes.
- Don't manually trigger `beta_create.yml` — it auto-runs on merge to main.
- Each PR check + each manual trigger = 2 scratch orgs. Batch related fixes into fewer PRs.
- `UNABLE_TO_LOCK_ROW` failures in CI are flaky scratch org contention — just re-run.

## Data Integrity
- NEVER fabricate realistic financial data, statistics, or quotes. Use obviously placeholder values and flag them.
- NEVER run DML against production orgs unless explicitly asked. Always sandbox first.
- SyncItem StatusPk__c is NOT restricted (legacy inline-defined field, unrestricted since 2026-04-23). Allowed values enforced via trigger at `DeliveryPicklistIntegrityService`. Never insert records with unknown picklist values — they will pass SF restriction but fail the trigger.

## Workflow Discipline
- Do NOT jump ahead or start building before the user confirms the approach.
- When user shares content for review, read it first — do not immediately start coding.
- Do NOT run parallel git operations from multiple agents on the same branch.
- When deploying LWC to scratch orgs, use `cci task run deploy` (handles namespace tokens), not raw `sf project deploy`.

## Report Metadata Patterns
- Use `$` not `.` for field references: `WorkLog__c$HoursLoggedNumber__c`
- Custom report types get `__c` suffix
- `enableReports=true` required on custom object
- Can't change reportType on existing report — use new DeveloperName
- `criteriaItems` not criterias, `booleanFilter` before `criteriaItems`

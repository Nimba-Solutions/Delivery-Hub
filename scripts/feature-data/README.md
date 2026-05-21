# Feature-Specific Data Loaders

Per-feature anonymous-Apex scripts that prime sample data for a single Delivery
Hub feature. Surfaced on the cockpit by Layer 7 (`DatasetTemplate__c` rows
point at these files via `ApexScriptPathTxt__c`).

## Convention

- One file per `FeatureDefinition__mdt.DeveloperName`, lower-snake-cased.
  - `Invoice_Generation` -> `invoice_generation.apex`
  - `Slack_Comment_Sync` -> `slack_comment_sync.apex`
- Each script:
  - inserts data with **obvious placeholder values** (per `CLAUDE.md` "NEVER
    fabricate realistic financial data" — use names like `Sample Vendor A`,
    hours like `1.0`, descriptions like `TDF / placeholder sample`)
  - is **idempotent** when re-run on the same org (guards on
    `IF EXISTS` SOQL counts)
  - logs an `INFO`-level `System.debug` summary at the end with the actual
    record counts inserted

## Running

Direct anonymous-apex invocation (the canonical path):

```bash
cci task run execute_anon --path scripts/feature-data/<feature>.apex --org <alias>
```

Or via the `load_feature_data` wrapper task (currently a stub — emits a
debug pointer; future PRs may expand it to parameterized routing):

```bash
cci task run load_feature_data --org <alias>
```

## Adding a new loader

1. Add the script under `scripts/feature-data/<feature>.apex`.
2. Add a `DatasetTemplate__c` row in your dev / packaging org pointing at it.
   (PR 10 ships the schema; PR 11+ will likely auto-seed these from
   `DatasetTemplateDefinition__mdt`.)
3. Test against a fresh scratch org: install the package, run the loader,
   verify the feature's UI surfaces the inserted records.

// =============================================================================
// Data Migration: WorkItem__c Renamed Fields + Bool→DateTime Backfills
// Run this script on each org (MF-Prod, Nimba, dh-prod) AFTER package upgrade.
//
// PART 1 — Original migrations (static SOQL, assumes orphan fields exist):
//   Developer__c           → DeveloperLookup__c       (Lookup to User)
//   Epic__c                → EpicTxt__c               (Text 255)
//   Tags__c                → TagsTxt__c               (Text 255)
//   EstimatedEffortNum__c  → EstimatedHoursNumber__c  (Number)
//   BudgetVarianceNum__c   → BudgetVarianceNumber__c  (Formula — no migration needed)
//   BountyMaxClaimsNum__c  → BountyMaxClaimsNumber__c (Number)
//
// PART 2 — Lookup field renames (dynamic SOQL, sections skip if orphan missing):
//   ClientNetworkEntityId__c    → ClientNetworkEntityLookup__c (Lookup → NetworkEntity)
//   ParentWorkItemId__c         → ParentWorkItemLookup__c      (Lookup → WorkItem)
//   ExternalRequesterEmailTxt__c → ExternalRequesterEmail__c    (Email)
//
// PART 3 — Type-change landmine (Text 18 → Lookup):
//   TemplateSourceId__c (Text 18) → TemplateSourceLookup__c (Lookup → WorkItem)
//
// PART 4 — Bool → DateTime backfills (use CreatedDate as upper-bound timestamp):
//   IsActiveBool__c     → ActivatedDateTime__c
//   IsBountyBool__c     → BountyEnabledDateTime__c
//   IsRecurringBool__c  → RecurringEnabledDateTime__c
//   IsTemplateBool__c   → TemplateMarkedDateTime__c
//
// Notes:
//   - BudgetVarianceNumber__c is a formula field — it recalculates automatically, no copy needed.
//   - Only copies where old field has data AND new field is null (safe to re-run).
//   - Uses allOrNone=false so partial failures don't block the batch.
//   - PARTS 2-4 use dynamic SOQL + try/catch — if a particular orphan field has been
//     manually deleted from the org, that section is skipped without aborting the script.
//   - After verifying data, manually delete the old fields from each org.
//
// IMPORTANT: Run via Execute Anonymous in Developer Console or VS Code.
//            Use the delivery__ namespace prefix on subscriber orgs.
// =============================================================================

// --- Configuration ---
Integer BATCH_SIZE = 200;
Integer totalDeveloper = 0;
Integer totalEpic = 0;
Integer totalTags = 0;
Integer totalEffort = 0;
Integer totalBountyMaxClaims = 0;
Integer totalErrors = 0;
Map<String, Integer> dynamicResults = new Map<String, Integer>();
Map<String, String> dynamicSkipped = new Map<String, String>();

// =============================================================================
// MIGRATION 1: Developer__c → DeveloperLookup__c
// =============================================================================
System.debug('=== MIGRATION 1: Developer__c → DeveloperLookup__c ===');

List<delivery__WorkItem__c> devItems = [
    SELECT Id, delivery__Developer__c, delivery__DeveloperLookup__c
    FROM delivery__WorkItem__c
    WHERE delivery__Developer__c != null
      AND delivery__DeveloperLookup__c = null
    LIMIT 10000
];

System.debug('Records to migrate (Developer): ' + devItems.size());

for (Integer i = 0; i < devItems.size(); i += BATCH_SIZE) {
    List<delivery__WorkItem__c> batch = new List<delivery__WorkItem__c>();
    for (Integer j = i; j < Math.min(i + BATCH_SIZE, devItems.size()); j++) {
        delivery__WorkItem__c wi = devItems[j];
        wi.delivery__DeveloperLookup__c = wi.delivery__Developer__c;
        batch.add(wi);
    }

    List<Database.SaveResult> results = Database.update(batch, false);
    for (Database.SaveResult sr : results) {
        if (sr.isSuccess()) {
            totalDeveloper++;
        } else {
            totalErrors++;
            for (Database.Error err : sr.getErrors()) {
                System.debug('ERROR (Developer) on ' + sr.getId() + ': ' + err.getMessage());
            }
        }
    }
}

System.debug('Developer migration complete: ' + totalDeveloper + ' records updated');

// =============================================================================
// MIGRATION 2: Epic__c → EpicTxt__c
// =============================================================================
System.debug('=== MIGRATION 2: Epic__c → EpicTxt__c ===');

List<delivery__WorkItem__c> epicItems = [
    SELECT Id, delivery__Epic__c, delivery__EpicTxt__c
    FROM delivery__WorkItem__c
    WHERE delivery__Epic__c != null
      AND delivery__EpicTxt__c = null
    LIMIT 10000
];

System.debug('Records to migrate (Epic): ' + epicItems.size());

for (Integer i = 0; i < epicItems.size(); i += BATCH_SIZE) {
    List<delivery__WorkItem__c> batch = new List<delivery__WorkItem__c>();
    for (Integer j = i; j < Math.min(i + BATCH_SIZE, epicItems.size()); j++) {
        delivery__WorkItem__c wi = epicItems[j];
        wi.delivery__EpicTxt__c = wi.delivery__Epic__c;
        batch.add(wi);
    }

    List<Database.SaveResult> results = Database.update(batch, false);
    for (Database.SaveResult sr : results) {
        if (sr.isSuccess()) {
            totalEpic++;
        } else {
            totalErrors++;
            for (Database.Error err : sr.getErrors()) {
                System.debug('ERROR (Epic) on ' + sr.getId() + ': ' + err.getMessage());
            }
        }
    }
}

System.debug('Epic migration complete: ' + totalEpic + ' records updated');

// =============================================================================
// MIGRATION 3: Tags__c → TagsTxt__c
// =============================================================================
System.debug('=== MIGRATION 3: Tags__c → TagsTxt__c ===');

List<delivery__WorkItem__c> tagsItems = [
    SELECT Id, delivery__Tags__c, delivery__TagsTxt__c
    FROM delivery__WorkItem__c
    WHERE delivery__Tags__c != null
      AND delivery__TagsTxt__c = null
    LIMIT 10000
];

System.debug('Records to migrate (Tags): ' + tagsItems.size());

for (Integer i = 0; i < tagsItems.size(); i += BATCH_SIZE) {
    List<delivery__WorkItem__c> batch = new List<delivery__WorkItem__c>();
    for (Integer j = i; j < Math.min(i + BATCH_SIZE, tagsItems.size()); j++) {
        delivery__WorkItem__c wi = tagsItems[j];
        wi.delivery__TagsTxt__c = wi.delivery__Tags__c;
        batch.add(wi);
    }

    List<Database.SaveResult> results = Database.update(batch, false);
    for (Database.SaveResult sr : results) {
        if (sr.isSuccess()) {
            totalTags++;
        } else {
            totalErrors++;
            for (Database.Error err : sr.getErrors()) {
                System.debug('ERROR (Tags) on ' + sr.getId() + ': ' + err.getMessage());
            }
        }
    }
}

System.debug('Tags migration complete: ' + totalTags + ' records updated');

// =============================================================================
// MIGRATION 4: EstimatedEffortNum__c → EstimatedHoursNumber__c
// (The field was renamed from EstimatedEffortNum__c to EstimatedHoursNumber__c)
// =============================================================================
System.debug('=== MIGRATION 4: EstimatedEffortNum__c → EstimatedHoursNumber__c ===');

List<delivery__WorkItem__c> effortItems = [
    SELECT Id, delivery__EstimatedEffortNum__c, delivery__EstimatedHoursNumber__c
    FROM delivery__WorkItem__c
    WHERE delivery__EstimatedEffortNum__c != null
      AND delivery__EstimatedHoursNumber__c = null
    LIMIT 10000
];

System.debug('Records to migrate (Effort): ' + effortItems.size());

for (Integer i = 0; i < effortItems.size(); i += BATCH_SIZE) {
    List<delivery__WorkItem__c> batch = new List<delivery__WorkItem__c>();
    for (Integer j = i; j < Math.min(i + BATCH_SIZE, effortItems.size()); j++) {
        delivery__WorkItem__c wi = effortItems[j];
        wi.delivery__EstimatedHoursNumber__c = wi.delivery__EstimatedEffortNum__c;
        batch.add(wi);
    }

    List<Database.SaveResult> results = Database.update(batch, false);
    for (Database.SaveResult sr : results) {
        if (sr.isSuccess()) {
            totalEffort++;
        } else {
            totalErrors++;
            for (Database.Error err : sr.getErrors()) {
                System.debug('ERROR (Effort) on ' + sr.getId() + ': ' + err.getMessage());
            }
        }
    }
}

System.debug('Effort migration complete: ' + totalEffort + ' records updated');

// =============================================================================
// MIGRATION 5: BountyMaxClaimsNum__c → BountyMaxClaimsNumber__c
// =============================================================================
System.debug('=== MIGRATION 5: BountyMaxClaimsNum__c → BountyMaxClaimsNumber__c ===');

List<delivery__WorkItem__c> bountyItems = [
    SELECT Id, delivery__BountyMaxClaimsNum__c, delivery__BountyMaxClaimsNumber__c
    FROM delivery__WorkItem__c
    WHERE delivery__BountyMaxClaimsNum__c != null
      AND delivery__BountyMaxClaimsNumber__c = null
    LIMIT 10000
];

System.debug('Records to migrate (BountyMaxClaims): ' + bountyItems.size());

for (Integer i = 0; i < bountyItems.size(); i += BATCH_SIZE) {
    List<delivery__WorkItem__c> batch = new List<delivery__WorkItem__c>();
    for (Integer j = i; j < Math.min(i + BATCH_SIZE, bountyItems.size()); j++) {
        delivery__WorkItem__c wi = bountyItems[j];
        wi.delivery__BountyMaxClaimsNumber__c = wi.delivery__BountyMaxClaimsNum__c;
        batch.add(wi);
    }

    List<Database.SaveResult> results = Database.update(batch, false);
    for (Database.SaveResult sr : results) {
        if (sr.isSuccess()) {
            totalBountyMaxClaims++;
        } else {
            totalErrors++;
            for (Database.Error err : sr.getErrors()) {
                System.debug('ERROR (BountyMaxClaims) on ' + sr.getId() + ': ' + err.getMessage());
            }
        }
    }
}

System.debug('BountyMaxClaims migration complete: ' + totalBountyMaxClaims + ' records updated');

// =============================================================================
// NOTE: BudgetVarianceNum__c → BudgetVarianceNumber__c
// BudgetVarianceNumber__c is a FORMULA field (EstimatedHoursNumber__c - TotalLoggedHoursNumber__c).
// No data migration needed — it recalculates automatically.
// =============================================================================

// =============================================================================
// PART 2 — Lookup field renames (dynamic SOQL — safe if orphan field is missing)
// =============================================================================
//
// All three pairs are simple Lookup→Lookup renames where the type is unchanged
// and only the API name moved. The old field still exists as an orphan custom
// field on subscriber orgs that ran prior versions, holding the old value.
//
// Each block is self-contained — if the orphan field has been manually deleted
// from this org, the block catches the SOQL exception and logs "skipped".
//

// --- Helper: copy old → new for a simple lookup or text field ---
// Builds the SOQL, finds records where old != null AND new == null, copies the
// value across, updates with allOrNone=false. Returns the count of records updated.
//
// Inlined as anonymous block fragments below because Apex Execute Anonymous
// doesn't support local function declarations.

// === MIGRATION 6: ClientNetworkEntityId__c → ClientNetworkEntityLookup__c ===
System.debug('=== MIGRATION 6: ClientNetworkEntityId__c → ClientNetworkEntityLookup__c ===');
try {
    String soql = 'SELECT Id, delivery__ClientNetworkEntityId__c, delivery__ClientNetworkEntityLookup__c '
                + 'FROM delivery__WorkItem__c '
                + 'WHERE delivery__ClientNetworkEntityId__c != null '
                + 'AND delivery__ClientNetworkEntityLookup__c = null '
                + 'LIMIT 10000';
    List<SObject> records = Database.query(soql);
    System.debug('  Records to migrate: ' + records.size());
    Integer migrated = 0;
    for (Integer i = 0; i < records.size(); i += BATCH_SIZE) {
        List<SObject> batch = new List<SObject>();
        for (Integer j = i; j < Math.min(i + BATCH_SIZE, records.size()); j++) {
            SObject rec = records[j];
            rec.put('delivery__ClientNetworkEntityLookup__c', rec.get('delivery__ClientNetworkEntityId__c'));
            batch.add(rec);
        }
        for (Database.SaveResult sr : Database.update(batch, false)) {
            if (sr.isSuccess()) { migrated++; }
            else { totalErrors++; for (Database.Error err : sr.getErrors()) { System.debug('  ERROR: ' + err.getMessage()); } }
        }
    }
    dynamicResults.put('ClientNetworkEntityId → Lookup', migrated);
} catch (Exception e) {
    dynamicSkipped.put('ClientNetworkEntityId → Lookup', e.getMessage());
    System.debug(LoggingLevel.WARN, '  SKIPPED (orphan field likely deleted): ' + e.getMessage());
}

// === MIGRATION 7: ParentWorkItemId__c → ParentWorkItemLookup__c ===
System.debug('=== MIGRATION 7: ParentWorkItemId__c → ParentWorkItemLookup__c ===');
try {
    String soql = 'SELECT Id, delivery__ParentWorkItemId__c, delivery__ParentWorkItemLookup__c '
                + 'FROM delivery__WorkItem__c '
                + 'WHERE delivery__ParentWorkItemId__c != null '
                + 'AND delivery__ParentWorkItemLookup__c = null '
                + 'LIMIT 10000';
    List<SObject> records = Database.query(soql);
    System.debug('  Records to migrate: ' + records.size());
    Integer migrated = 0;
    for (Integer i = 0; i < records.size(); i += BATCH_SIZE) {
        List<SObject> batch = new List<SObject>();
        for (Integer j = i; j < Math.min(i + BATCH_SIZE, records.size()); j++) {
            SObject rec = records[j];
            rec.put('delivery__ParentWorkItemLookup__c', rec.get('delivery__ParentWorkItemId__c'));
            batch.add(rec);
        }
        for (Database.SaveResult sr : Database.update(batch, false)) {
            if (sr.isSuccess()) { migrated++; }
            else { totalErrors++; for (Database.Error err : sr.getErrors()) { System.debug('  ERROR: ' + err.getMessage()); } }
        }
    }
    dynamicResults.put('ParentWorkItemId → Lookup', migrated);
} catch (Exception e) {
    dynamicSkipped.put('ParentWorkItemId → Lookup', e.getMessage());
    System.debug(LoggingLevel.WARN, '  SKIPPED (orphan field likely deleted): ' + e.getMessage());
}

// === MIGRATION 8: ExternalRequesterEmailTxt__c → ExternalRequesterEmail__c ===
System.debug('=== MIGRATION 8: ExternalRequesterEmailTxt__c → ExternalRequesterEmail__c ===');
try {
    String soql = 'SELECT Id, delivery__ExternalRequesterEmailTxt__c, delivery__ExternalRequesterEmail__c '
                + 'FROM delivery__WorkItem__c '
                + 'WHERE delivery__ExternalRequesterEmailTxt__c != null '
                + 'AND delivery__ExternalRequesterEmail__c = null '
                + 'LIMIT 10000';
    List<SObject> records = Database.query(soql);
    System.debug('  Records to migrate: ' + records.size());
    Integer migrated = 0;
    for (Integer i = 0; i < records.size(); i += BATCH_SIZE) {
        List<SObject> batch = new List<SObject>();
        for (Integer j = i; j < Math.min(i + BATCH_SIZE, records.size()); j++) {
            SObject rec = records[j];
            rec.put('delivery__ExternalRequesterEmail__c', rec.get('delivery__ExternalRequesterEmailTxt__c'));
            batch.add(rec);
        }
        for (Database.SaveResult sr : Database.update(batch, false)) {
            if (sr.isSuccess()) { migrated++; }
            else { totalErrors++; for (Database.Error err : sr.getErrors()) { System.debug('  ERROR: ' + err.getMessage()); } }
        }
    }
    dynamicResults.put('ExternalRequesterEmailTxt → Email', migrated);
} catch (Exception e) {
    dynamicSkipped.put('ExternalRequesterEmailTxt → Email', e.getMessage());
    System.debug(LoggingLevel.WARN, '  SKIPPED (orphan field likely deleted): ' + e.getMessage());
}

// =============================================================================
// PART 3 — Type-change landmine: Text 18 → Lookup
// =============================================================================
//
// TemplateSourceId__c was a Text(18) field storing a stringified Id of the
// template WorkItem. TemplateSourceLookup__c is a true Lookup. The cast is
// "wi.TemplateSourceLookup__c = (Id) wi.TemplateSourceId__c" but the old field
// might contain garbage strings or 15-char Ids that need normalization.
//
// Skip records where the cast throws — log and continue rather than aborting
// the whole script.
//

// === MIGRATION 9: TemplateSourceId__c (Text 18) → TemplateSourceLookup__c (Lookup) ===
System.debug('=== MIGRATION 9: TemplateSourceId__c → TemplateSourceLookup__c (TYPE CHANGE) ===');
try {
    String soql = 'SELECT Id, delivery__TemplateSourceId__c, delivery__TemplateSourceLookup__c '
                + 'FROM delivery__WorkItem__c '
                + 'WHERE delivery__TemplateSourceId__c != null '
                + 'AND delivery__TemplateSourceLookup__c = null '
                + 'LIMIT 10000';
    List<SObject> records = Database.query(soql);
    System.debug('  Records to migrate: ' + records.size());
    Integer migrated = 0;
    Integer invalidIds = 0;
    List<SObject> validBatch = new List<SObject>();
    for (SObject rec : records) {
        Object raw = rec.get('delivery__TemplateSourceId__c');
        if (raw == null) { continue; }
        String rawStr = String.valueOf(raw).trim();
        try {
            Id parsed = Id.valueOf(rawStr);
            rec.put('delivery__TemplateSourceLookup__c', parsed);
            validBatch.add(rec);
        } catch (Exception castEx) {
            invalidIds++;
            System.debug(LoggingLevel.WARN, '  Skipping invalid Id "' + rawStr + '" on ' + rec.get('Id'));
        }
        if (validBatch.size() >= BATCH_SIZE) {
            for (Database.SaveResult sr : Database.update(validBatch, false)) {
                if (sr.isSuccess()) { migrated++; }
                else { totalErrors++; for (Database.Error err : sr.getErrors()) { System.debug('  ERROR: ' + err.getMessage()); } }
            }
            validBatch = new List<SObject>();
        }
    }
    if (!validBatch.isEmpty()) {
        for (Database.SaveResult sr : Database.update(validBatch, false)) {
            if (sr.isSuccess()) { migrated++; }
            else { totalErrors++; for (Database.Error err : sr.getErrors()) { System.debug('  ERROR: ' + err.getMessage()); } }
        }
    }
    dynamicResults.put('TemplateSourceId → Lookup (cast)', migrated);
    if (invalidIds > 0) {
        System.debug('  ' + invalidIds + ' records had invalid Id strings — skipped.');
    }
} catch (Exception e) {
    dynamicSkipped.put('TemplateSourceId → Lookup (cast)', e.getMessage());
    System.debug(LoggingLevel.WARN, '  SKIPPED (orphan field likely deleted): ' + e.getMessage());
}

// =============================================================================
// PART 4 — Bool → DateTime backfills (use CreatedDate as upper-bound timestamp)
// =============================================================================
//
// In v0.146, these flags were Boolean. In v0.155 they were converted to DateTime
// fields where "non-null" means "true". Subscribers who relied on IsActiveBool=true
// have records where the new ActivatedDateTime is NULL — making them invisible to
// any code path that filters on the new field.
//
// The backfill sets the new DateTime to CreatedDate (the safest non-NULL value;
// guaranteed to be ≤ when the record was activated).
//

// --- Helper: Bool → DateTime via dynamic SOQL ---
List<List<String>> boolToDateTimeMap = new List<List<String>>{
    new List<String>{ 'IsActiveBool__c',    'ActivatedDateTime__c'        },
    new List<String>{ 'IsBountyBool__c',    'BountyEnabledDateTime__c'    },
    new List<String>{ 'IsRecurringBool__c', 'RecurringEnabledDateTime__c' },
    new List<String>{ 'IsTemplateBool__c',  'TemplateMarkedDateTime__c'   }
};

for (List<String> pair : boolToDateTimeMap) {
    String oldField = pair[0];
    String newField = pair[1];
    String label = oldField + ' → ' + newField;
    System.debug('=== BOOL→DATETIME: ' + label + ' ===');
    try {
        String soql = 'SELECT Id, CreatedDate, delivery__' + oldField + ', delivery__' + newField + ' '
                    + 'FROM delivery__WorkItem__c '
                    + 'WHERE delivery__' + oldField + ' = true '
                    + 'AND delivery__' + newField + ' = null '
                    + 'LIMIT 10000';
        List<SObject> records = Database.query(soql);
        System.debug('  Records to backfill: ' + records.size());
        Integer migrated = 0;
        for (Integer i = 0; i < records.size(); i += BATCH_SIZE) {
            List<SObject> batch = new List<SObject>();
            for (Integer j = i; j < Math.min(i + BATCH_SIZE, records.size()); j++) {
                SObject rec = records[j];
                rec.put('delivery__' + newField, rec.get('CreatedDate'));
                batch.add(rec);
            }
            for (Database.SaveResult sr : Database.update(batch, false)) {
                if (sr.isSuccess()) { migrated++; }
                else { totalErrors++; for (Database.Error err : sr.getErrors()) { System.debug('  ERROR: ' + err.getMessage()); } }
            }
        }
        dynamicResults.put(label, migrated);
    } catch (Exception e) {
        dynamicSkipped.put(label, e.getMessage());
        System.debug(LoggingLevel.WARN, '  SKIPPED (orphan Bool field likely deleted): ' + e.getMessage());
    }
}

// =============================================================================
// SUMMARY
// =============================================================================
System.debug('=== MIGRATION SUMMARY ===');
System.debug('Developer__c → DeveloperLookup__c   : ' + totalDeveloper + ' records');
System.debug('Epic__c → EpicTxt__c                : ' + totalEpic + ' records');
System.debug('Tags__c → TagsTxt__c                : ' + totalTags + ' records');
System.debug('EstimatedEffortNum → EstimatedHours : ' + totalEffort + ' records');
System.debug('BountyMaxClaimsNum → Number         : ' + totalBountyMaxClaims + ' records');
System.debug('BudgetVarianceNum → Number          : FORMULA (no migration needed)');
System.debug('---');
for (String label : dynamicResults.keySet()) {
    System.debug(label + ' : ' + dynamicResults.get(label) + ' records');
}
if (!dynamicSkipped.isEmpty()) {
    System.debug('--- SKIPPED SECTIONS (orphan field missing) ---');
    for (String label : dynamicSkipped.keySet()) {
        System.debug('  ' + label + ' : ' + dynamicSkipped.get(label));
    }
}
System.debug('Total errors                        : ' + totalErrors);
System.debug('=========================');
System.debug('NEXT STEPS:');
System.debug('1. Verify data by spot-checking records in the org.');
System.debug('2. Run scripts/migrate-related-objects.apex for cross-object renames.');
System.debug('3. Run scripts/migrate-settings-fields.apex for DeliveryHubSettings__c.');
System.debug('4. Once verified, manually delete old orphan fields from each org.');

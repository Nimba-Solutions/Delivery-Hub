// =============================================================================
// Data Migration: WorkItem__c Renamed Fields
// Run this script on each org (MF-Prod, Nimba, dh-prod) AFTER package upgrade.
//
// Migrates data from old field names to new field names:
//   Developer__c           → DeveloperLookupId__c  (Lookup to User)
//   Epic__c                → EpicTxt__c            (Text 255)
//   Tags__c                → TagsTxt__c            (Text 255)
//   EstimatedEffortNum__c  → EstimatedHoursNumber__c  (Number — already renamed in schema)
//   BudgetVarianceNum__c   → BudgetVarianceNumber__c  (Formula — no data migration needed)
//   BountyMaxClaimsNum__c  → BountyMaxClaimsNumber__c (Number)
//
// Notes:
//   - BudgetVarianceNumber__c is a formula field — it recalculates automatically, no copy needed.
//   - Only copies where old field has data AND new field is null (safe to re-run).
//   - Uses allOrNone=false so partial failures don't block the batch.
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

// =============================================================================
// MIGRATION 1: Developer__c → DeveloperLookupId__c
// =============================================================================
System.debug('=== MIGRATION 1: Developer__c → DeveloperLookupId__c ===');

List<delivery__WorkItem__c> devItems = [
    SELECT Id, delivery__Developer__c, delivery__DeveloperLookupId__c
    FROM delivery__WorkItem__c
    WHERE delivery__Developer__c != null
      AND delivery__DeveloperLookupId__c = null
    LIMIT 10000
];

System.debug('Records to migrate (Developer): ' + devItems.size());

for (Integer i = 0; i < devItems.size(); i += BATCH_SIZE) {
    List<delivery__WorkItem__c> batch = new List<delivery__WorkItem__c>();
    for (Integer j = i; j < Math.min(i + BATCH_SIZE, devItems.size()); j++) {
        delivery__WorkItem__c wi = devItems[j];
        wi.delivery__DeveloperLookupId__c = wi.delivery__Developer__c;
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
// SUMMARY
// =============================================================================
System.debug('=== MIGRATION SUMMARY ===');
System.debug('Developer__c → DeveloperLookupId__c : ' + totalDeveloper + ' records');
System.debug('Epic__c → EpicTxt__c               : ' + totalEpic + ' records');
System.debug('Tags__c → TagsTxt__c               : ' + totalTags + ' records');
System.debug('EstimatedEffortNum → EstimatedHours : ' + totalEffort + ' records');
System.debug('BountyMaxClaimsNum → Number         : ' + totalBountyMaxClaims + ' records');
System.debug('BudgetVarianceNum → Number          : FORMULA (no migration needed)');
System.debug('Total errors                        : ' + totalErrors);
System.debug('=========================');
System.debug('NEXT STEPS:');
System.debug('1. Verify data by spot-checking records in the org.');
System.debug('2. Confirm new fields have correct values.');
System.debug('3. Once verified, manually delete old fields:');
System.debug('   - WorkItem__c.Developer__c');
System.debug('   - WorkItem__c.Epic__c');
System.debug('   - WorkItem__c.Tags__c');
System.debug('   - WorkItem__c.EstimatedEffortNum__c');
System.debug('   - WorkItem__c.BountyMaxClaimsNum__c');
System.debug('   - WorkItem__c.BudgetVarianceNum__c (formula — safe to delete)');

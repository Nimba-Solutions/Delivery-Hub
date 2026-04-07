// =============================================================================
// Data Migration: Related Object Field Renames + Bool→DateTime Backfills
// Run this script on each org (MF-Prod, Nimba, dh-prod) AFTER package upgrade.
//
// SCOPE — Cross-object field renames the schema audit found in PR #606:
//   WorkLog__c.WorkItemId__c            → WorkItemLookup__c
//   SyncItem__c.WorkItemId__c           → WorkItemLookup__c
//   SyncItem__c.RequestId__c            → RequestLookup__c
//   SyncItem__c.WorkItemCommentId__c    → WorkItemCommentLookup__c
//   ActivityLog__c.NetworkEntityId__c   → NetworkEntityLookup__c
//   BountyClaim__c.ClaimantEntityId__c  → ClaimantEntityLookup__c
//   BountyClaim__c.ClaimantEmailTxt__c  → ClaimantEmail__c
//   BountyClaim__c.WorkProofUrlTxt__c   → WorkProofUrl__c
//   DeliveryDocument__c.PreviousVersionId__c → PreviousVersionLookup__c
//   DeliveryDocument__c.WorkItemId__c   → WorkItemLookup__c
//   WorkItemDependency__c.BlockedWorkItemId__c  → BlockedWorkItemLookup__c
//   WorkItemDependency__c.BlockingWorkItemId__c → BlockingWorkItemLookup__c
//   WorkRequest__c.DeliveryEntityId__c  → DeliveryEntityLookup__c
//   DeliverySavedFilter__c.IsDefaultBool__c → DefaultSetDateTime__c (CreatedDate)
//   NetworkEntity__c.EnableVendorPushBool__c → EnableVendorPushDateTime__c (CreatedDate)
//
// CRITICAL — Sync engine impact:
//   Without WorkLog__c.WorkItemLookup__c and SyncItem__c.WorkItemLookup__c populated,
//   inbound sync orphans every WorkLog and every SyncItem against the WorkItem they
//   belong to. The sync engine will silently drop or misroute records until this
//   script runs. Pause the outbound sync poller before installing the new beta on
//   any org, then immediately run this script after install.
//
// IDEMPOTENT: each block only updates rows where old != null AND new = null.
// SAFE: each block uses dynamic SOQL + try/catch — if a particular orphan field has
//       been manually deleted on this org, that block is skipped without aborting.
//
// IMPORTANT: Run via Execute Anonymous in Developer Console or VS Code.
//            Use the delivery__ namespace prefix on subscriber orgs.
// =============================================================================

Integer BATCH_SIZE = 200;
Integer totalErrors = 0;
Map<String, Integer> results = new Map<String, Integer>();
Map<String, String> skipped = new Map<String, String>();

// =============================================================================
// PART 1 — Simple Lookup→Lookup renames
// =============================================================================
//
// (object, oldField, newField) — value copy, no type change.
//
List<List<String>> simpleRenames = new List<List<String>>{
    new List<String>{ 'delivery__WorkLog__c',            'WorkItemId__c',         'WorkItemLookup__c'         },
    new List<String>{ 'delivery__SyncItem__c',           'WorkItemId__c',         'WorkItemLookup__c'         },
    new List<String>{ 'delivery__SyncItem__c',           'RequestId__c',          'RequestLookup__c'          },
    new List<String>{ 'delivery__SyncItem__c',           'WorkItemCommentId__c',  'WorkItemCommentLookup__c'  },
    new List<String>{ 'delivery__ActivityLog__c',        'NetworkEntityId__c',    'NetworkEntityLookup__c'    },
    new List<String>{ 'delivery__BountyClaim__c',        'ClaimantEntityId__c',   'ClaimantEntityLookup__c'   },
    new List<String>{ 'delivery__BountyClaim__c',        'ClaimantEmailTxt__c',   'ClaimantEmail__c'          },
    new List<String>{ 'delivery__BountyClaim__c',        'WorkProofUrlTxt__c',    'WorkProofUrl__c'           },
    new List<String>{ 'delivery__DeliveryDocument__c',   'PreviousVersionId__c',  'PreviousVersionLookup__c'  },
    new List<String>{ 'delivery__DeliveryDocument__c',   'WorkItemId__c',         'WorkItemLookup__c'         },
    new List<String>{ 'delivery__WorkItemDependency__c', 'BlockedWorkItemId__c',  'BlockedWorkItemLookup__c'  },
    new List<String>{ 'delivery__WorkItemDependency__c', 'BlockingWorkItemId__c', 'BlockingWorkItemLookup__c' },
    new List<String>{ 'delivery__WorkRequest__c',        'DeliveryEntityId__c',   'DeliveryEntityLookup__c'   }
};

for (List<String> triple : simpleRenames) {
    String objName = triple[0];
    String oldField = triple[1];
    String newField = triple[2];
    String label = objName + '.' + oldField + ' → ' + newField;
    System.debug('=== ' + label + ' ===');
    try {
        String soql = 'SELECT Id, delivery__' + oldField + ', delivery__' + newField + ' '
                    + 'FROM ' + objName + ' '
                    + 'WHERE delivery__' + oldField + ' != null '
                    + 'AND delivery__' + newField + ' = null '
                    + 'LIMIT 10000';
        List<SObject> records = Database.query(soql);
        System.debug('  Records to migrate: ' + records.size());
        Integer migrated = 0;
        for (Integer i = 0; i < records.size(); i += BATCH_SIZE) {
            List<SObject> batch = new List<SObject>();
            for (Integer j = i; j < Math.min(i + BATCH_SIZE, records.size()); j++) {
                SObject rec = records[j];
                rec.put('delivery__' + newField, rec.get('delivery__' + oldField));
                batch.add(rec);
            }
            for (Database.SaveResult sr : Database.update(batch, false)) {
                if (sr.isSuccess()) {
                    migrated++;
                } else {
                    totalErrors++;
                    for (Database.Error err : sr.getErrors()) {
                        System.debug(LoggingLevel.WARN, '  ERROR: ' + err.getMessage());
                    }
                }
            }
        }
        results.put(label, migrated);
    } catch (Exception e) {
        skipped.put(label, e.getMessage());
        System.debug(LoggingLevel.WARN, '  SKIPPED (orphan field likely deleted): ' + e.getMessage());
    }
}

// =============================================================================
// PART 2 — Bool → DateTime backfills (use CreatedDate as upper-bound timestamp)
// =============================================================================
//
// (object, oldBoolField, newDateTimeField)
//
List<List<String>> boolToDateTime = new List<List<String>>{
    new List<String>{ 'delivery__DeliverySavedFilter__c', 'IsDefaultBool__c',       'DefaultSetDateTime__c'     },
    new List<String>{ 'delivery__NetworkEntity__c',       'EnableVendorPushBool__c', 'EnableVendorPushDateTime__c' }
};

for (List<String> triple : boolToDateTime) {
    String objName = triple[0];
    String oldField = triple[1];
    String newField = triple[2];
    String label = objName + '.' + oldField + ' → ' + newField;
    System.debug('=== ' + label + ' ===');
    try {
        String soql = 'SELECT Id, CreatedDate, delivery__' + oldField + ', delivery__' + newField + ' '
                    + 'FROM ' + objName + ' '
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
                if (sr.isSuccess()) {
                    migrated++;
                } else {
                    totalErrors++;
                    for (Database.Error err : sr.getErrors()) {
                        System.debug(LoggingLevel.WARN, '  ERROR: ' + err.getMessage());
                    }
                }
            }
        }
        results.put(label, migrated);
    } catch (Exception e) {
        skipped.put(label, e.getMessage());
        System.debug(LoggingLevel.WARN, '  SKIPPED (orphan Bool field likely deleted): ' + e.getMessage());
    }
}

// =============================================================================
// SUMMARY
// =============================================================================
System.debug('=== RELATED-OBJECTS MIGRATION SUMMARY ===');
for (String label : results.keySet()) {
    System.debug('  ' + label + ' : ' + results.get(label) + ' records');
}
if (!skipped.isEmpty()) {
    System.debug('--- SKIPPED SECTIONS (orphan field missing — usually safe) ---');
    for (String label : skipped.keySet()) {
        System.debug('  ' + label + ' : ' + skipped.get(label));
    }
}
System.debug('Total errors: ' + totalErrors);
System.debug('==========================================');
System.debug('NEXT STEPS:');
System.debug('1. Verify sync engine processes new inbound items correctly.');
System.debug('2. Spot-check WorkLogs and SyncItems have populated Lookup fields.');
System.debug('3. Once verified, manually delete old orphan fields from each org.');

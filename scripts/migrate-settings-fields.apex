// =============================================================================
// Data Migration: DeliveryHubSettings__c Renamed Fields
// Run this script on each org (MF-Prod, Nimba, dh-prod) AFTER package upgrade.
//
// Migrates data from old field names to new field names:
//   FieldChangeRetentionDaysNum__c    → FieldChangeRetentionDaysNumber__c   (Number)
//   ActivityLogRetentionDaysNum__c    → ActivityLogRetentionDaysNumber__c   (Number)
//   RequireWorkLogApprovalDate__c     → RequireWorkLogApprovalDateTime__c   (DateTime)
//
// Notes:
//   - DeliveryHubSettings__c is a Custom Setting (Hierarchy) — typically 1 org-level record.
//   - Only copies where old field has data AND new field is null (safe to re-run).
//   - RequireWorkLogApprovalDate__c was a Date; new field is DateTime. Copies as start-of-day.
//
// IMPORTANT: Run via Execute Anonymous in Developer Console or VS Code.
//            Use the delivery__ namespace prefix on subscriber orgs.
// =============================================================================

Integer totalUpdated = 0;
Integer totalErrors = 0;
Integer totalSkipped = 0;

// Query all DeliveryHubSettings__c records (org defaults + any user/profile overrides)
List<delivery__DeliveryHubSettings__c> allSettings = [
    SELECT Id,
           delivery__FieldChangeRetentionDaysNum__c,
           delivery__FieldChangeRetentionDaysNumber__c,
           delivery__ActivityLogRetentionDaysNum__c,
           delivery__ActivityLogRetentionDaysNumber__c,
           delivery__RequireWorkLogApprovalDate__c,
           delivery__RequireWorkLogApprovalDateTime__c
    FROM delivery__DeliveryHubSettings__c
];

System.debug('=== SETTINGS MIGRATION ===');
System.debug('Total DeliveryHubSettings__c records found: ' + allSettings.size());

List<delivery__DeliveryHubSettings__c> toUpdate = new List<delivery__DeliveryHubSettings__c>();

for (delivery__DeliveryHubSettings__c s : allSettings) {
    Boolean needsUpdate = false;

    // Migration 1: FieldChangeRetentionDaysNum__c → FieldChangeRetentionDaysNumber__c
    if (s.delivery__FieldChangeRetentionDaysNum__c != null
        && s.delivery__FieldChangeRetentionDaysNumber__c == null) {
        s.delivery__FieldChangeRetentionDaysNumber__c = s.delivery__FieldChangeRetentionDaysNum__c;
        needsUpdate = true;
        System.debug('  Copying FieldChangeRetentionDays: ' + s.delivery__FieldChangeRetentionDaysNum__c);
    }

    // Migration 2: ActivityLogRetentionDaysNum__c → ActivityLogRetentionDaysNumber__c
    if (s.delivery__ActivityLogRetentionDaysNum__c != null
        && s.delivery__ActivityLogRetentionDaysNumber__c == null) {
        s.delivery__ActivityLogRetentionDaysNumber__c = s.delivery__ActivityLogRetentionDaysNum__c;
        needsUpdate = true;
        System.debug('  Copying ActivityLogRetentionDays: ' + s.delivery__ActivityLogRetentionDaysNum__c);
    }

    // Migration 3: RequireWorkLogApprovalDate__c → RequireWorkLogApprovalDateTime__c
    // Old field was Date, new field is DateTime. Convert Date → DateTime at midnight UTC.
    if (s.delivery__RequireWorkLogApprovalDate__c != null
        && s.delivery__RequireWorkLogApprovalDateTime__c == null) {
        Date oldDate = s.delivery__RequireWorkLogApprovalDate__c;
        DateTime newDt = DateTime.newInstance(oldDate, Time.newInstance(0, 0, 0, 0));
        s.delivery__RequireWorkLogApprovalDateTime__c = newDt;
        needsUpdate = true;
        System.debug('  Copying RequireWorkLogApproval: ' + oldDate + ' → ' + newDt);
    }

    if (needsUpdate) {
        toUpdate.add(s);
    } else {
        totalSkipped++;
    }
}

if (!toUpdate.isEmpty()) {
    List<Database.SaveResult> results = Database.update(toUpdate, false);
    for (Database.SaveResult sr : results) {
        if (sr.isSuccess()) {
            totalUpdated++;
        } else {
            totalErrors++;
            for (Database.Error err : sr.getErrors()) {
                System.debug('ERROR on ' + sr.getId() + ': ' + err.getMessage());
            }
        }
    }
}

// =============================================================================
// PART 2 — Bool → DateTime backfills (use CreatedDate as upper-bound timestamp)
// =============================================================================
//
// In v0.146 these were Boolean checkboxes; in v0.155 they were converted to
// DateTime fields where "non-null" means "enabled". Without backfill, every
// admin-side feature toggle silently flips OFF after upgrade — board metrics
// disappear, AI features turn off, notifications stop, etc.
//
// Each block uses dynamic SOQL + try/catch so missing orphan fields don't
// abort the script.
//

Map<String, Integer> boolBackfills = new Map<String, Integer>();
Map<String, String> boolSkipped = new Map<String, String>();

List<List<String>> settingsBoolToDateTime = new List<List<String>>{
    new List<String>{ 'EnableActivityLoggingBool__c',     'EnableActivityLoggingDateTime__c'     },
    new List<String>{ 'EnableFieldTrackingBool__c',       'EnableFieldTrackingDateTime__c'       },
    new List<String>{ 'EnableBellNotificationsBool__c',   'EnableBellNotificationsDateTime__c'   },
    new List<String>{ 'EnableNotificationsBool__c',       'EnableNotificationsDateTime__c'       },
    new List<String>{ 'EmailNotificationsEnabledBool__c', 'EnableEmailNotificationsDateTime__c'  },
    new List<String>{ 'WeeklyDigestEnabledBool__c',       'EnableWeeklyDigestDateTime__c'        },
    new List<String>{ 'StatusPageEnabledBool__c',         'EnableStatusPageDateTime__c'          },
    new List<String>{ 'ShowBoardMetricsBool__c',          'EnableBoardMetricsDateTime__c'        },
    new List<String>{ 'AutoSyncNetworkEntityBool__c',     'EnableAutoSyncNetworkEntityDateTime__c' },
    new List<String>{ 'AutoCreateWorkRequestBool__c',     'EnableAutoCreateWorkRequestDateTime__c' },
    new List<String>{ 'AutoGenerateDescriptionsBool__c',  'EnableAutoGenerateDescriptionsDateTime__c' },
    new List<String>{ 'AISuggestionsEnabledBool__c',      'EnableAISuggestionsDateTime__c'       },
    new List<String>{ 'AIEstimationEnabledBool__c',       'EnableAIEstimationDateTime__c'        },
    new List<String>{ 'OpenAiApiTestedBool__c',           'OpenAiApiTestedDateTime__c'           }
};

for (List<String> pair : settingsBoolToDateTime) {
    String oldField = pair[0];
    String newField = pair[1];
    String label = oldField + ' → ' + newField;
    System.debug('=== BOOL→DATETIME: ' + label + ' ===');
    try {
        String soql = 'SELECT Id, CreatedDate, delivery__' + oldField + ', delivery__' + newField + ' '
                    + 'FROM delivery__DeliveryHubSettings__c '
                    + 'WHERE delivery__' + oldField + ' = true '
                    + 'AND delivery__' + newField + ' = null '
                    + 'LIMIT 10000';
        List<SObject> records = Database.query(soql);
        System.debug('  Records to backfill: ' + records.size());
        Integer migrated = 0;
        List<SObject> batch = new List<SObject>();
        for (SObject rec : records) {
            rec.put('delivery__' + newField, rec.get('CreatedDate'));
            batch.add(rec);
        }
        if (!batch.isEmpty()) {
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
        boolBackfills.put(label, migrated);
    } catch (Exception e) {
        boolSkipped.put(label, e.getMessage());
        System.debug(LoggingLevel.WARN, '  SKIPPED (orphan Bool field likely deleted): ' + e.getMessage());
    }
}

// =============================================================================
// SUMMARY
// =============================================================================
System.debug('=== MIGRATION SUMMARY ===');
System.debug('Records updated (Part 1 renames) : ' + totalUpdated);
System.debug('Records skipped (Part 1 renames) : ' + totalSkipped);
System.debug('Errors                           : ' + totalErrors);
System.debug('--- Bool → DateTime backfills (Part 2) ---');
for (String label : boolBackfills.keySet()) {
    System.debug('  ' + label + ' : ' + boolBackfills.get(label) + ' records');
}
if (!boolSkipped.isEmpty()) {
    System.debug('--- SKIPPED Bool sections (orphan field missing — usually safe) ---');
    for (String label : boolSkipped.keySet()) {
        System.debug('  ' + label + ' : ' + boolSkipped.get(label));
    }
}
System.debug('=========================');
System.debug('NEXT STEPS:');
System.debug('1. Verify the org-level settings record has correct values in new fields.');
System.debug('2. Once verified, manually delete old fields:');
System.debug('   - DeliveryHubSettings__c.FieldChangeRetentionDaysNum__c');
System.debug('   - DeliveryHubSettings__c.ActivityLogRetentionDaysNum__c');
System.debug('   - DeliveryHubSettings__c.RequireWorkLogApprovalDate__c');
System.debug('   - All Settings *Bool__c fields once Part 2 backfill is verified.');

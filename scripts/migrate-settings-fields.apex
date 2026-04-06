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
// SUMMARY
// =============================================================================
System.debug('=== MIGRATION SUMMARY ===');
System.debug('Records updated : ' + totalUpdated);
System.debug('Records skipped : ' + totalSkipped + ' (already migrated or no old data)');
System.debug('Errors          : ' + totalErrors);
System.debug('=========================');
System.debug('NEXT STEPS:');
System.debug('1. Verify the org-level settings record has correct values in new fields.');
System.debug('2. Once verified, manually delete old fields:');
System.debug('   - DeliveryHubSettings__c.FieldChangeRetentionDaysNum__c');
System.debug('   - DeliveryHubSettings__c.ActivityLogRetentionDaysNum__c');
System.debug('   - DeliveryHubSettings__c.RequireWorkLogApprovalDate__c');

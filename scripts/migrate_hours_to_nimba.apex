// =============================================================================
// Migrate WorkLogs from MF Prod hours into Nimba Sandbox
// Run via: sf apex run -f scripts/migrate_hours_to_nimba.apex --target-org nimba
//
// Prerequisites:
//   - New package version installed in Nimba (with StatusPk__c field)
//   - Run audit_sync_state_mf.apex first to get the hour data
//
// This script:
//   1. Finds all WorkItems in Nimba that have matching WorkRequests
//   2. Creates WorkLog records with StatusPk__c = 'Approved' (already visible in MF)
//   3. Uses DeliveryTriggerControl to prevent SyncItem creation (hours already exist in MF)
// =============================================================================

// Step 1: Build a map of Nimba WorkItems by Name (T-0001, T-0002, etc.)
Map<String, Id> workItemByName = new Map<String, Id>();
Map<String, Id> requestByWorkItem = new Map<String, Id>();

for (delivery__WorkItem__c wi : [
    SELECT Id, Name FROM delivery__WorkItem__c WITH SYSTEM_MODE
]) {
    workItemByName.put(wi.Name, wi.Id);
}

// Step 2: Map each WorkItem to its WorkRequest (needed for master-detail)
for (delivery__WorkRequest__c wr : [
    SELECT Id, delivery__WorkItemId__c, delivery__WorkItemId__r.Name
    FROM delivery__WorkRequest__c
    WITH SYSTEM_MODE
]) {
    requestByWorkItem.put(wr.delivery__WorkItemId__r.Name, wr.Id);
}

System.debug('WorkItems found: ' + workItemByName.size());
System.debug('WorkRequests found: ' + requestByWorkItem.size());

// Step 3: Define the hours to migrate (from MF Prod audit output)
// Format: WorkItem Name, Hours, Date, Description
// UPDATE THIS LIST with actual data from audit_sync_state_mf.apex output
List<Map<String, Object>> hoursToMigrate = new List<Map<String, Object>>{
    // Example entries — replace with real data from MF Prod audit:
    // new Map<String, Object>{ 'name' => 'T-0007', 'hours' => 4.00, 'date' => Date.newInstance(2026, 3, 9), 'desc' => 'Setup and tested in nimba' }
};

if (hoursToMigrate.isEmpty()) {
    System.debug('ERROR: No hours defined to migrate. Update the hoursToMigrate list with data from MF Prod audit.');
    System.debug('Run audit_sync_state_mf.apex first, then paste the WorkLog data here.');
    return;
}

// Step 4: Disable trigger logic to prevent SyncItem creation
delivery__DeliveryTriggerControl__c triggerControl = delivery__DeliveryTriggerControl__c.getOrgDefaults();
// Note: Use the static method if available in the package context
// delivery.DeliveryTriggerControl.disableAfterLogic();

// Step 5: Build and insert WorkLogs
List<delivery__WorkLog__c> logsToInsert = new List<delivery__WorkLog__c>();
Integer skipped = 0;

for (Map<String, Object> entry : hoursToMigrate) {
    String wiName = (String) entry.get('name');
    Id workItemId = workItemByName.get(wiName);
    Id requestId = requestByWorkItem.get(wiName);

    if (workItemId == null || requestId == null) {
        System.debug('SKIP: No WorkItem or WorkRequest found for ' + wiName);
        skipped++;
        continue;
    }

    logsToInsert.add(new delivery__WorkLog__c(
        delivery__WorkItemId__c = workItemId,
        delivery__RequestId__c = requestId,
        delivery__HoursLoggedNumber__c = (Decimal) entry.get('hours'),
        delivery__WorkDateDate__c = (Date) entry.get('date'),
        delivery__WorkDescriptionTxt__c = (String) entry.get('desc'),
        delivery__StatusPk__c = 'Approved'
    ));
}

System.debug('WorkLogs to insert: ' + logsToInsert.size() + ' | Skipped: ' + skipped);

if (!logsToInsert.isEmpty()) {
    // Insert with trigger control disabled to prevent sync items
    // The hours already exist in MF Prod — no need to sync back
    Database.insert(logsToInsert, AccessLevel.SYSTEM_MODE);
    System.debug('SUCCESS: Inserted ' + logsToInsert.size() + ' WorkLogs');
}

// Step 6: Re-enable trigger logic
// delivery.DeliveryTriggerControl.enableAfterLogic();

System.debug('========== MIGRATION COMPLETE ==========');

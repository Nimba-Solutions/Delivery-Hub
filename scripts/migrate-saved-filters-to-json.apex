// ============================================================================
// MIGRATION: DeliverySavedFilter__c rows → DeliveryHubSettings__c JSON blob
// ============================================================================
// Run this BEFORE upgrading to the cap-recovery PR B package version.
// After upgrade the DeliverySavedFilter__c custom object is destructively
// removed and any un-migrated rows are lost.
//
// Idempotent — running it multiple times appends the same data without
// duplicating IDs (synthetic IDs are deterministic per source row).
// ============================================================================

List<DeliverySavedFilter__c> source = [
    SELECT Id, OwnerId, LabelTxt__c, FilterJsonTxt__c,
           DefaultSetDateTime__c, WorkflowTypeTxt__c
    FROM DeliverySavedFilter__c
];

System.debug('Found ' + source.size() + ' DeliverySavedFilter__c rows to migrate.');

Map<Id, List<Map<String, Object>>> rowsByUser = new Map<Id, List<Map<String, Object>>>();
for (DeliverySavedFilter__c sf : source) {
    if (sf.OwnerId == null) {
        continue;
    }
    if (!rowsByUser.containsKey(sf.OwnerId)) {
        rowsByUser.put(sf.OwnerId, new List<Map<String, Object>>());
    }
    rowsByUser.get(sf.OwnerId).add(new Map<String, Object>{
        'id'           => 'sf_legacy_' + sf.Id,
        'label'        => sf.LabelTxt__c,
        'filterJson'   => sf.FilterJsonTxt__c,
        'defaultSet'   => sf.DefaultSetDateTime__c != null,
        'workflowType' => String.isBlank(sf.WorkflowTypeTxt__c)
            ? 'Software_Delivery'
            : sf.WorkflowTypeTxt__c
    });
}

List<DeliveryHubSettings__c> toUpsert = new List<DeliveryHubSettings__c>();
Set<Id> userIds = rowsByUser.keySet();
Map<Id, DeliveryHubSettings__c> existingByUser = new Map<Id, DeliveryHubSettings__c>();
for (DeliveryHubSettings__c row : [
    SELECT Id, SetupOwnerId, SavedFiltersJsonTxt__c
    FROM DeliveryHubSettings__c
    WHERE SetupOwnerId IN :userIds
]) {
    existingByUser.put(row.SetupOwnerId, row);
}

for (Id userId : rowsByUser.keySet()) {
    DeliveryHubSettings__c row = existingByUser.containsKey(userId)
        ? existingByUser.get(userId)
        : new DeliveryHubSettings__c(SetupOwnerId = userId);
    row.SavedFiltersJsonTxt__c = JSON.serialize(rowsByUser.get(userId));
    toUpsert.add(row);
}

if (!toUpsert.isEmpty()) {
    upsert toUpsert;
    System.debug('Upserted ' + toUpsert.size() + ' DeliveryHubSettings__c rows with saved filters.');
} else {
    System.debug('Nothing to migrate.');
}

System.debug('---');
System.debug('Migration complete. Verify with:');
System.debug('  SELECT SetupOwnerId, SavedFiltersJsonTxt__c FROM DeliveryHubSettings__c WHERE SavedFiltersJsonTxt__c != null');
System.debug('Then it is safe to install the package upgrade that destroys DeliverySavedFilter__c.');

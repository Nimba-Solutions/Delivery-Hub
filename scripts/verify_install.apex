// =============================================================================
// Post-Install Verification (run against each org with managed package)
// Uses SOQL + describe calls only (no direct class calls — classes are public, not global)
// =============================================================================

// 1. Verify StatusPk__c field on WorkLog__c
System.debug('=== CHECK 1: WorkLog__c.StatusPk__c field ===');
try {
    Schema.DescribeFieldResult statusField = delivery__WorkLog__c.delivery__StatusPk__c.getDescribe();
    System.debug('PASS | StatusPk__c exists | Label: ' + statusField.getLabel() + ' | Type: ' + statusField.getType());
} catch (Exception e) {
    System.debug('FAIL | StatusPk__c: ' + e.getMessage());
}

// 2. Verify RequireWorkLogApprovalDate__c on DeliveryHubSettings__c
System.debug('=== CHECK 2: RequireWorkLogApprovalDate__c field ===');
try {
    delivery__DeliveryHubSettings__c settings = delivery__DeliveryHubSettings__c.getOrgDefaults();
    System.debug('PASS | Settings exist: ' + (settings.Id != null) + ' | ApprovalDate: ' + settings.delivery__RequireWorkLogApprovalDate__c);
} catch (Exception e) {
    System.debug('FAIL | Settings: ' + e.getMessage());
}

// 3. Verify Activity Feed data is queryable (proves the objects/fields exist)
System.debug('=== CHECK 3: Activity Feed data ===');
Integer commentCount = [SELECT COUNT() FROM delivery__WorkItemComment__c];
Integer workLogCount = [SELECT COUNT() FROM delivery__WorkLog__c];
Integer activityLogCount = [SELECT COUNT() FROM delivery__ActivityLog__c];
System.debug('PASS | Comments: ' + commentCount + ' | WorkLogs: ' + workLogCount + ' | ActivityLogs: ' + activityLogCount);

// 4. Verify NetworkEntity data for Data Lineage
System.debug('=== CHECK 4: Data Lineage (NetworkEntity) ===');
for (delivery__NetworkEntity__c ne : [
    SELECT Name, delivery__EntityTypePk__c, delivery__ConnectionStatusPk__c, delivery__StatusPk__c
    FROM delivery__NetworkEntity__c
    WHERE delivery__StatusPk__c = 'Active'
]) {
    System.debug('PASS | Entity: ' + ne.Name + ' | Type: ' + ne.delivery__EntityTypePk__c + ' | Connection: ' + ne.delivery__ConnectionStatusPk__c);
}

// 5. Verify SyncItem health data
System.debug('=== CHECK 5: Sync Health ===');
for (AggregateResult ar : [
    SELECT delivery__StatusPk__c status, COUNT(Id) cnt
    FROM delivery__SyncItem__c
    GROUP BY delivery__StatusPk__c
]) {
    System.debug('PASS | SyncItems: ' + ar.get('status') + ' = ' + ar.get('cnt'));
}

// 6. Verify WorkLog StatusPk__c values (new field has data?)
System.debug('=== CHECK 6: WorkLog Status Distribution ===');
for (AggregateResult ar : [
    SELECT delivery__StatusPk__c status, COUNT(Id) cnt
    FROM delivery__WorkLog__c
    GROUP BY delivery__StatusPk__c
]) {
    System.debug('PASS | WorkLog status: ' + (ar.get('status') != null ? ar.get('status') : 'null (legacy)') + ' = ' + ar.get('cnt'));
}

// 7. Check if approval is currently enabled
System.debug('=== CHECK 7: Approval Setting State ===');
delivery__DeliveryHubSettings__c s = delivery__DeliveryHubSettings__c.getOrgDefaults();
Boolean approvalOn = s.delivery__RequireWorkLogApprovalDate__c != null;
System.debug('PASS | Approval enabled: ' + approvalOn + (approvalOn ? ' (since ' + s.delivery__RequireWorkLogApprovalDate__c + ')' : ''));

System.debug('=== VERIFICATION COMPLETE ===');

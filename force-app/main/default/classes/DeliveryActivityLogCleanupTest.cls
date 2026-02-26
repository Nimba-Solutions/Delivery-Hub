/**
 * @description Tests for DeliveryActivityLogCleanup scheduled job.
 * Covers aggregation, purge, and the scheduled entry point.
 * @author Cloud Nimbus LLC
 */
@IsTest
private class DeliveryActivityLogCleanupTest {

    @TestSetup
    static void setupData() {
        Network_Entity__c entity = new Network_Entity__c(
            Name = 'Test Client Org',
            EntityTypePk__c = 'Client',
            StatusPk__c = 'Active'
        );
        insert entity;
    }

    @IsTest
    static void testAggregateUsageAnalytics() {
        Network_Entity__c entity = [SELECT Id FROM Network_Entity__c LIMIT 1];

        // Insert a batch of activity logs
        List<Delivery_Activity_Log__c> logs = new List<Delivery_Activity_Log__c>();
        for (Integer i = 0; i < 5; i++) {
            logs.add(new Delivery_Activity_Log__c(
                ActionTypePk__c = 'Navigation',
                ComponentNameTxt__c = 'deliveryHubBoard',
                UserIdTxt__c = UserInfo.getUserId(),
                NetworkEntityId__c = entity.Id,
                ContextDataTxt__c = '{"url":"https://test.salesforce.com"}'
            ));
        }
        logs.add(new Delivery_Activity_Log__c(
            ActionTypePk__c = 'Button_Click',
            ComponentNameTxt__c = 'deliveryGhostRecorder',
            UserIdTxt__c = UserInfo.getUserId(),
            NetworkEntityId__c = entity.Id,
            ContextDataTxt__c = '{"url":"https://test.salesforce.com/ghost"}'
        ));
        insert logs;

        Test.startTest();
        DeliveryActivityLogCleanup.aggregateUsageAnalytics();
        Test.stopTest();

        // Verify the JSON was written to the Network Entity
        Network_Entity__c updated = [
            SELECT UsageAnalyticsJsonTxt__c
            FROM Network_Entity__c
            WHERE Id = :entity.Id
        ];
        System.assertNotEquals(null, updated.UsageAnalyticsJsonTxt__c, 'Analytics JSON should be populated');
        System.assert(updated.UsageAnalyticsJsonTxt__c.contains('"totalActions"'), 'JSON should contain totalActions');
        System.assert(updated.UsageAnalyticsJsonTxt__c.contains('"uniqueUsers"'), 'JSON should contain uniqueUsers');
        System.assert(updated.UsageAnalyticsJsonTxt__c.contains('deliveryHubBoard'), 'JSON should contain component name');

        // Verify a Sync_Item__c was queued
        List<Sync_Item__c> syncItems = [
            SELECT ObjectTypePk__c, DirectionPk__c, StatusPk__c, PayloadTxt__c
            FROM Sync_Item__c
            WHERE ObjectTypePk__c = 'UsageAnalytics'
        ];
        System.assertEquals(1, syncItems.size(), 'One sync item should be queued');
        System.assertEquals('Outbound', syncItems[0].DirectionPk__c, 'Direction should be Outbound');
        System.assertEquals('Queued', syncItems[0].StatusPk__c, 'Status should be Queued');
    }

    @IsTest
    static void testBatchPurgesOldRecords() {
        // Insert a record and backdate it beyond retention
        Delivery_Activity_Log__c oldLog = new Delivery_Activity_Log__c(
            ActionTypePk__c = 'Navigation',
            ComponentNameTxt__c = 'deliveryHubBoard',
            UserIdTxt__c = UserInfo.getUserId()
        );
        insert oldLog;

        // Backdate via direct update (Test context allows this)
        Test.setCreatedDate(oldLog.Id, DateTime.now().addDays(-(DeliveryActivityLogCleanup.RETENTION_DAYS + 1)));

        // Also insert a recent one that should survive
        Delivery_Activity_Log__c recentLog = new Delivery_Activity_Log__c(
            ActionTypePk__c = 'Button_Click',
            ComponentNameTxt__c = 'deliveryGhostRecorder',
            UserIdTxt__c = UserInfo.getUserId()
        );
        insert recentLog;

        Test.startTest();
        Database.executeBatch(new DeliveryActivityLogCleanup(), 200);
        Test.stopTest();

        List<Delivery_Activity_Log__c> remaining = [
            SELECT Id FROM Delivery_Activity_Log__c
        ];
        System.assertEquals(1, remaining.size(), 'Only the recent log should remain');
        System.assertEquals(recentLog.Id, remaining[0].Id, 'Surviving record should be the recent one');
    }

    @IsTest
    static void testSchedulableEntryPoint() {
        Test.startTest();
        String jobId = System.schedule(
            'Test Activity Cleanup',
            '0 0 2 * * ?',
            new DeliveryActivityLogCleanup()
        );
        Test.stopTest();

        System.assertNotEquals(null, jobId, 'Scheduled job should be created');
    }

    @IsTest
    static void testAggregateWithNoData() {
        // Should complete without error even with no activity logs
        Test.startTest();
        DeliveryActivityLogCleanup.aggregateUsageAnalytics();
        Test.stopTest();

        Network_Entity__c entity = [SELECT UsageAnalyticsJsonTxt__c FROM Network_Entity__c LIMIT 1];
        System.assertEquals(null, entity.UsageAnalyticsJsonTxt__c,
            'Analytics should remain null when no activity logs exist');
    }
}

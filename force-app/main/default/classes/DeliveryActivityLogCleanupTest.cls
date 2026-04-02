/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Tests for DeliveryActivityLogCleanup scheduled job.
 * Covers aggregation, purge, and the scheduled entry point.
 * @author Cloud Nimbus LLC
 */
@IsTest
private class DeliveryActivityLogCleanupTest {

    private static User testUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];

    @TestSetup
    static void setupData() {
        NetworkEntity__c entity = new NetworkEntity__c(
            Name = 'Test Client Org',
            EntityTypePk__c = 'Client',
            StatusPk__c = 'Active'
        );
        insert entity;
    }

    @IsTest
    static void testAggregateUsageAnalytics() {
        System.runAs(testUser) {
            NetworkEntity__c entity = [SELECT Id FROM NetworkEntity__c LIMIT 1];

            // Insert a batch of activity logs
            List<ActivityLog__c> logs = new List<ActivityLog__c>();
            for (Integer i = 0; i < 5; i++) {
                logs.add(new ActivityLog__c(
                    ActionTypePk__c = 'Navigation',
                    ComponentNameTxt__c = 'deliveryHubBoard',
                    UserIdTxt__c = UserInfo.getUserId(),
                    NetworkEntityId__c = entity.Id,
                    ContextDataTxt__c = '{"url":"https://test.salesforce.com"}'
                ));
            }
            logs.add(new ActivityLog__c(
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
            NetworkEntity__c updated = [
                SELECT UsageAnalyticsJsonTxt__c
                FROM NetworkEntity__c
                WHERE Id = :entity.Id
            ];
            System.assertNotEquals(null, updated.UsageAnalyticsJsonTxt__c, 'Analytics JSON should be populated');
            System.assert(updated.UsageAnalyticsJsonTxt__c.contains('"totalActions"'), 'JSON should contain totalActions');
            System.assert(updated.UsageAnalyticsJsonTxt__c.contains('"uniqueUsers"'), 'JSON should contain uniqueUsers');
            System.assert(updated.UsageAnalyticsJsonTxt__c.contains('deliveryHubBoard'), 'JSON should contain component name');

            // Verify a SyncItem__c was queued
            List<SyncItem__c> syncItems = [
                SELECT ObjectTypePk__c, DirectionPk__c, StatusPk__c, PayloadTxt__c
                FROM SyncItem__c
                WHERE ObjectTypePk__c = 'UsageAnalytics'
            ];
            System.assertEquals(1, syncItems.size(), 'One sync item should be queued');
            System.assertEquals('Outbound', syncItems[0].DirectionPk__c, 'Direction should be Outbound');
            System.assertEquals('Queued', syncItems[0].StatusPk__c, 'Status should be Queued');
        }
    }

    @IsTest
    static void testBatchPurgesOldRecords() {
        System.runAs(testUser) {
            // Insert a record and backdate it beyond retention
            ActivityLog__c oldLog = new ActivityLog__c(
                ActionTypePk__c = 'Navigation',
                ComponentNameTxt__c = 'deliveryHubBoard',
                UserIdTxt__c = UserInfo.getUserId()
            );
            insert oldLog;

            // Backdate via direct update (Test context allows this)
            Test.setCreatedDate(oldLog.Id, DateTime.now().addDays(-(DeliveryActivityLogCleanup.retentionDays + 1)));

            // Also insert a recent one that should survive
            ActivityLog__c recentLog = new ActivityLog__c(
                ActionTypePk__c = 'Button_Click',
                ComponentNameTxt__c = 'deliveryGhostRecorder',
                UserIdTxt__c = UserInfo.getUserId()
            );
            insert recentLog;

            Test.startTest();
            Database.executeBatch(new DeliveryActivityLogCleanup(), 200);
            Test.stopTest();

            List<ActivityLog__c> remaining = [
                SELECT Id FROM ActivityLog__c
            ];
            System.assertEquals(1, remaining.size(), 'Only the recent log should remain');
            System.assertEquals(recentLog.Id, remaining[0].Id, 'Surviving record should be the recent one');
        }
    }

    @IsTest
    static void testPurgePreservesFieldChangeLogs() {
        System.runAs(testUser) {
            // Use a real Account Id to avoid PMD AvoidHardcodingId
            Account testAcct = new Account(Name = 'Field Change Retention Test');
            insert testAcct;

            // Insert a Field_Change log and backdate it beyond retention
            ActivityLog__c fieldChangeLog = new ActivityLog__c(
                ActionTypePk__c = 'Field_Change',
                ComponentNameTxt__c = 'IUW_Risk_Rating__c',
                UserIdTxt__c = UserInfo.getUserId(),
                RecordIdTxt__c = testAcct.Id,
                ContextDataTxt__c = '{"fieldName":"IUW_Risk_Rating__c","oldValue":"3","newValue":"4"}'
            );
            insert fieldChangeLog;
            Test.setCreatedDate(fieldChangeLog.Id, DateTime.now().addDays(-(DeliveryActivityLogCleanup.retentionDays + 1)));

            // Insert an old Navigation log that SHOULD be purged
            ActivityLog__c oldNavLog = new ActivityLog__c(
                ActionTypePk__c = 'Navigation',
                ComponentNameTxt__c = 'deliveryHubBoard',
                UserIdTxt__c = UserInfo.getUserId()
            );
            insert oldNavLog;
            Test.setCreatedDate(oldNavLog.Id, DateTime.now().addDays(-(DeliveryActivityLogCleanup.retentionDays + 1)));

            Test.startTest();
            Database.executeBatch(new DeliveryActivityLogCleanup(), 200);
            Test.stopTest();

            List<ActivityLog__c> remaining = [
                SELECT Id, ActionTypePk__c FROM ActivityLog__c WITH SYSTEM_MODE
            ];
            System.assertEquals(1, remaining.size(), 'Only the Field_Change log should survive');
            System.assertEquals('Field_Change', remaining[0].ActionTypePk__c,
                'Surviving record should be the Field_Change log');
        }
    }

    @IsTest
    static void testSchedulableEntryPoint() {
        System.runAs(testUser) {
            Test.startTest();
            String jobId = System.schedule(
                'Test Activity Cleanup',
                '0 0 2 * * ?',
                new DeliveryActivityLogCleanup()
            );
            Test.stopTest();

            System.assertNotEquals(null, jobId, 'Scheduled job should be created');
        }
    }

    @IsTest
    static void testAggregateWithNoData() {
        System.runAs(testUser) {
            // Should complete without error even with no activity logs
            Test.startTest();
            DeliveryActivityLogCleanup.aggregateUsageAnalytics();
            Test.stopTest();

            NetworkEntity__c entity = [SELECT UsageAnalyticsJsonTxt__c FROM NetworkEntity__c LIMIT 1];
            System.assertEquals(null, entity.UsageAnalyticsJsonTxt__c,
                'Analytics should remain null when no activity logs exist');
        }
    }

    @IsTest
    static void testFieldChangeRetentionPurgesOldFieldChanges() {
        System.runAs(testUser) {
            // Configure retention to 30 days
            DeliveryHubSettings__c settings = DeliveryHubSettings__c.getOrgDefaults();
            settings.FieldChangeRetentionDaysNumber__c = 30;
            upsert settings;

            Account testAcct = new Account(Name = 'Retention Purge Test');
            insert testAcct;

            // Insert a Field_Change log older than 30 days — should be purged
            ActivityLog__c oldFieldChange = new ActivityLog__c(
                ActionTypePk__c = 'Field_Change',
                ComponentNameTxt__c = 'PriorityPk__c',
                UserIdTxt__c = UserInfo.getUserId(),
                RecordIdTxt__c = testAcct.Id,
                ContextDataTxt__c = '{"fieldName":"PriorityPk__c","oldValue":"Low","newValue":"High"}'
            );
            insert oldFieldChange;
            Test.setCreatedDate(oldFieldChange.Id, DateTime.now().addDays(-31));

            // Insert a recent Field_Change log — should survive
            ActivityLog__c recentFieldChange = new ActivityLog__c(
                ActionTypePk__c = 'Field_Change',
                ComponentNameTxt__c = 'StatusPk__c',
                UserIdTxt__c = UserInfo.getUserId(),
                RecordIdTxt__c = testAcct.Id,
                ContextDataTxt__c = '{"fieldName":"StatusPk__c","oldValue":"Draft","newValue":"Active"}'
            );
            insert recentFieldChange;

            Test.startTest();
            Database.executeBatch(new DeliveryActivityLogCleanup(), 200);
            Test.stopTest();

            List<ActivityLog__c> remaining = [
                SELECT Id, ActionTypePk__c, ComponentNameTxt__c
                FROM ActivityLog__c
                WITH SYSTEM_MODE
            ];
            System.assertEquals(1, remaining.size(), 'Only the recent Field_Change log should survive');
            System.assertEquals(recentFieldChange.Id, remaining[0].Id,
                'Surviving record should be the recent Field_Change log');
        }
    }

    @IsTest
    static void testFieldChangeRetentionNullPreservesFieldChanges() {
        System.runAs(testUser) {
            // Ensure FieldChangeRetentionDaysNumber__c is null (default) — Field_Change preserved
            DeliveryHubSettings__c settings = DeliveryHubSettings__c.getOrgDefaults();
            settings.FieldChangeRetentionDaysNumber__c = null;
            upsert settings;

            Account testAcct = new Account(Name = 'Retention Null Test');
            insert testAcct;

            // Insert an old Field_Change log — should NOT be purged
            ActivityLog__c oldFieldChange = new ActivityLog__c(
                ActionTypePk__c = 'Field_Change',
                ComponentNameTxt__c = 'StageNamePk__c',
                UserIdTxt__c = UserInfo.getUserId(),
                RecordIdTxt__c = testAcct.Id,
                ContextDataTxt__c = '{"fieldName":"StageNamePk__c","oldValue":"Backlog","newValue":"Done"}'
            );
            insert oldFieldChange;
            Test.setCreatedDate(oldFieldChange.Id, DateTime.now().addDays(-(DeliveryActivityLogCleanup.retentionDays + 1)));

            // Insert an old Navigation log — should be purged
            ActivityLog__c oldNavLog = new ActivityLog__c(
                ActionTypePk__c = 'Navigation',
                ComponentNameTxt__c = 'deliveryHubBoard',
                UserIdTxt__c = UserInfo.getUserId()
            );
            insert oldNavLog;
            Test.setCreatedDate(oldNavLog.Id, DateTime.now().addDays(-(DeliveryActivityLogCleanup.retentionDays + 1)));

            Test.startTest();
            Database.executeBatch(new DeliveryActivityLogCleanup(), 200);
            Test.stopTest();

            List<ActivityLog__c> remaining = [
                SELECT Id, ActionTypePk__c FROM ActivityLog__c WITH SYSTEM_MODE
            ];
            System.assertEquals(1, remaining.size(), 'Only the Field_Change log should survive');
            System.assertEquals('Field_Change', remaining[0].ActionTypePk__c,
                'Surviving record should be the Field_Change log');
        }
    }

    @IsTest
    static void testFieldChangeRetentionZeroPreservesFieldChanges() {
        System.runAs(testUser) {
            // FieldChangeRetentionDaysNumber__c = 0 should behave same as null (preserve Field_Changes)
            DeliveryHubSettings__c settings = DeliveryHubSettings__c.getOrgDefaults();
            settings.FieldChangeRetentionDaysNumber__c = 0;
            upsert settings;

            Account testAcct = new Account(Name = 'Retention Zero Test');
            insert testAcct;

            // Insert an old Field_Change log — should NOT be purged
            ActivityLog__c oldFieldChange = new ActivityLog__c(
                ActionTypePk__c = 'Field_Change',
                ComponentNameTxt__c = 'Developer__c',
                UserIdTxt__c = UserInfo.getUserId(),
                RecordIdTxt__c = testAcct.Id,
                ContextDataTxt__c = '{"fieldName":"Developer__c","oldValue":"User A","newValue":"User B"}'
            );
            insert oldFieldChange;
            Test.setCreatedDate(oldFieldChange.Id, DateTime.now().addDays(-(DeliveryActivityLogCleanup.retentionDays + 1)));

            Test.startTest();
            Database.executeBatch(new DeliveryActivityLogCleanup(), 200);
            Test.stopTest();

            List<ActivityLog__c> remaining = [
                SELECT Id, ActionTypePk__c FROM ActivityLog__c WITH SYSTEM_MODE
            ];
            System.assertEquals(1, remaining.size(), 'Field_Change log should survive when retention is 0');
            System.assertEquals('Field_Change', remaining[0].ActionTypePk__c,
                'Surviving record should be the Field_Change log');
        }
    }

    /**
     * @description Verifies that ActivityLogRetentionDaysNumber__c controls the purge window.
     *              Sets retention to 30 days so a 35-day-old record is purged
     *              while a 25-day-old record survives.
     */
    @IsTest
    static void testCustomRetentionDaysSetting() {
        System.runAs(testUser) {
            // Configure retention to 30 days instead of the default 90
            DeliveryHubSettings__c settings = DeliveryHubSettings__c.getOrgDefaults();
            settings.ActivityLogRetentionDaysNumber__c = 30;
            upsert settings;

            // Insert a log that is 35 days old — beyond the 30-day window, should be purged
            ActivityLog__c oldLog = new ActivityLog__c(
                ActionTypePk__c = 'Navigation',
                ComponentNameTxt__c = 'deliveryHubBoard',
                UserIdTxt__c = UserInfo.getUserId()
            );
            insert oldLog;
            Test.setCreatedDate(oldLog.Id, DateTime.now().addDays(-35));

            // Insert a log that is 25 days old — within the 30-day window, should survive
            ActivityLog__c recentLog = new ActivityLog__c(
                ActionTypePk__c = 'Button_Click',
                ComponentNameTxt__c = 'deliveryGhostRecorder',
                UserIdTxt__c = UserInfo.getUserId()
            );
            insert recentLog;
            Test.setCreatedDate(recentLog.Id, DateTime.now().addDays(-25));

            Test.startTest();
            Database.executeBatch(new DeliveryActivityLogCleanup(), 200);
            Test.stopTest();

            List<ActivityLog__c> remaining = [
                SELECT Id FROM ActivityLog__c WITH SYSTEM_MODE
            ];
            System.assertEquals(1, remaining.size(),
                'Only the 25-day-old log should survive when retention is set to 30 days');
            System.assertEquals(recentLog.Id, remaining[0].Id,
                'Surviving record should be the one within the 30-day retention window');
        }
    }
}

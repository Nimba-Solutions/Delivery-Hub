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
                    NetworkEntityLookup__c = entity.Id,
                    ContextDataTxt__c = '{"url":"https://test.salesforce.com"}'
                ));
            }
            logs.add(new ActivityLog__c(
                ActionTypePk__c = 'Button_Click',
                ComponentNameTxt__c = 'deliveryGhostRecorder',
                UserIdTxt__c = UserInfo.getUserId(),
                NetworkEntityLookup__c = entity.Id,
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
                ComponentNameTxt__c = 'DeveloperLookup__c',
                UserIdTxt__c = UserInfo.getUserId(),
                RecordIdTxt__c = testAcct.Id,
                ContextDataTxt__c = '{"fieldName":"DeveloperLookup__c","oldValue":"User A","newValue":"User B"}'
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

    /**
     * @description Regression test for the MF-Prod "Too many query rows: 50001"
     *              crash (daily 2 AM cron dead since 2026-03-13): aggregation must
     *              scale past a single transaction's query scope. Seeds 450 logs
     *              and runs the stateful aggregation batch with scope 200 so it
     *              takes THREE execute() chunks — proving Database.Stateful
     *              accumulation across chunks produces the same totals the old
     *              (unbounded, crash-prone) synchronous LIMIT-50000 loop did.
     *              Test volumes can't literally reach 50K rows (10K DML-row
     *              governor), so multi-chunk correctness is the provable proxy
     *              for any-volume safety: the QueryLocator pattern has a 50M-row
     *              ceiling and each chunk only ever reads its own scope.
     */
    @IsTest
    static void testAggregationScalesAcrossBatchChunks() {
        System.runAs(testUser) {
            NetworkEntity__c entity = [SELECT Id FROM NetworkEntity__c LIMIT 1];

            List<ActivityLog__c> logs = new List<ActivityLog__c>();
            for (Integer i = 0; i < 450; i++) {
                logs.add(new ActivityLog__c(
                    ActionTypePk__c = Math.mod(i, 2) == 0 ? 'Navigation' : 'Button_Click',
                    ComponentNameTxt__c = 'deliveryHubBoard',
                    UserIdTxt__c = UserInfo.getUserId(),
                    NetworkEntityLookup__c = entity.Id
                ));
            }
            insert logs;

            Test.startTest();
            // Scope 200 forces 3 execute() chunks over the 450 rows.
            Database.executeBatch(new DeliveryUsageAnalyticsBatch(false), 200);
            Test.stopTest();

            NetworkEntity__c updated = [
                SELECT UsageAnalyticsJsonTxt__c FROM NetworkEntity__c WHERE Id = :entity.Id
            ];
            System.assertNotEquals(null, updated.UsageAnalyticsJsonTxt__c,
                'Analytics JSON should be populated by the batched aggregation');

            Map<String, Object> summary =
                (Map<String, Object>) JSON.deserializeUntyped(updated.UsageAnalyticsJsonTxt__c);
            System.assertEquals(450, (Integer) summary.get('totalActions'),
                'Stateful accumulation must count every row across all batch chunks');
            System.assertEquals(1, (Integer) summary.get('uniqueUsers'),
                'All rows share one user, so uniqueUsers must be 1 across chunks');

            Integer telemetryItems = [
                SELECT COUNT() FROM SyncItem__c WHERE ObjectTypePk__c = 'UsageAnalytics'
            ];
            System.assertEquals(1, telemetryItems,
                'Exactly one telemetry SyncItem should be queued (in finish(), not per chunk)');
        }
    }

    /**
     * @description Proves the purge lane also survives volumes larger than one
     *              batch chunk: 450 expired rows with scope 200 take three
     *              delete chunks and must all be removed, while a recent row
     *              survives.
     */
    @IsTest
    static void testPurgeScalesAcrossBatchChunks() {
        System.runAs(testUser) {
            List<ActivityLog__c> oldLogs = new List<ActivityLog__c>();
            for (Integer i = 0; i < 450; i++) {
                oldLogs.add(new ActivityLog__c(
                    ActionTypePk__c = 'Navigation',
                    ComponentNameTxt__c = 'deliveryHubBoard',
                    UserIdTxt__c = UserInfo.getUserId()
                ));
            }
            insert oldLogs;
            DateTime expired = DateTime.now().addDays(-(DeliveryActivityLogCleanup.retentionDays + 1));
            for (ActivityLog__c log : oldLogs) {
                Test.setCreatedDate(log.Id, expired);
            }

            ActivityLog__c recentLog = new ActivityLog__c(
                ActionTypePk__c = 'Button_Click',
                ComponentNameTxt__c = 'deliveryGhostRecorder',
                UserIdTxt__c = UserInfo.getUserId()
            );
            insert recentLog;

            Test.startTest();
            // Scope 200 forces 3 delete chunks over the 450 expired rows.
            Database.executeBatch(new DeliveryActivityLogCleanup(), 200);
            Test.stopTest();

            List<ActivityLog__c> remaining = [SELECT Id FROM ActivityLog__c WITH SYSTEM_MODE];
            System.assertEquals(1, remaining.size(),
                'All 450 expired rows must be purged across multiple chunks');
            System.assertEquals(recentLog.Id, remaining[0].Id,
                'The recent row must survive the multi-chunk purge');
        }
    }

    /**
     * @description runMaintenance() is the single daily entry point used by both
     *              DeliveryHubScheduler and the standalone Schedulable path. It
     *              must enqueue the aggregation batch (which completes and writes
     *              the summary at stopTest) instead of running any synchronous
     *              row-loop. Purge chaining from the aggregation batch's finish()
     *              is guarded out of test context (Apex forbids executeBatch from
     *              finish() in tests) and is covered by the direct purge tests.
     */
    @IsTest
    static void testRunMaintenanceRunsBatchedAggregation() {
        System.runAs(testUser) {
            NetworkEntity__c entity = [SELECT Id FROM NetworkEntity__c LIMIT 1];
            insert new ActivityLog__c(
                ActionTypePk__c = 'Navigation',
                ComponentNameTxt__c = 'deliveryHubBoard',
                UserIdTxt__c = UserInfo.getUserId(),
                NetworkEntityLookup__c = entity.Id
            );

            Test.startTest();
            DeliveryActivityLogCleanup.runMaintenance();
            Test.stopTest();

            Integer aggregationJobs = [
                SELECT COUNT() FROM AsyncApexJob
                WHERE ApexClass.Name = 'DeliveryUsageAnalyticsBatch'
            ];
            System.assert(aggregationJobs >= 1,
                'runMaintenance must enqueue the DeliveryUsageAnalyticsBatch job');

            NetworkEntity__c updated = [
                SELECT UsageAnalyticsJsonTxt__c FROM NetworkEntity__c WHERE Id = :entity.Id
            ];
            System.assertNotEquals(null, updated.UsageAnalyticsJsonTxt__c,
                'Aggregation summary should be written when the batch completes');
        }
    }
}

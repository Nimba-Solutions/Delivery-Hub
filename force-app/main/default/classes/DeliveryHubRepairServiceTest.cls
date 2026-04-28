/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Tests for DeliveryHubRepairService — verifies each repair
 *               key dispatches correctly and unknown keys throw cleanly.
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.ApexDoc')
@IsTest
private class DeliveryHubRepairServiceTest {

    @IsTest
    static void scheduleAllRepairCreatesCronTriggers() {
        Test.startTest();
        String message = DeliveryHubRepairService.runRepair('scheduleAll');
        Test.stopTest();
        System.assertNotEquals(null, message);
        Integer count = [
            SELECT COUNT() FROM CronTrigger
            WHERE CronJobDetail.Name LIKE 'Delivery Hub Sync%'
        ];
        System.assertEquals(4, count, 'scheduleAll repair should produce four cron slots');
    }

    @IsTest
    static void requeueFailedSyncsResetsRows() {
        // Create a Failed SyncItem to verify it gets reset.
        SyncItem__c failed = new SyncItem__c(
            ObjectTypePk__c = 'WorkItem__c',
            DirectionPk__c = 'Outbound',
            StatusPk__c = 'Failed',
            RetryCountNumber__c = 3,
            ErrorLogTxt__c = 'previous failure'
        );
        insert failed;

        Test.startTest();
        String message = DeliveryHubRepairService.runRepair('requeueFailedSyncs');
        Test.stopTest();

        SyncItem__c after = [SELECT StatusPk__c, RetryCountNumber__c, ErrorLogTxt__c
                             FROM SyncItem__c WHERE Id = :failed.Id];
        System.assertEquals('Queued', after.StatusPk__c);
        System.assertEquals(0, after.RetryCountNumber__c);
        System.assertEquals(null, after.ErrorLogTxt__c);
        System.assert(message.contains('1 Failed SyncItems'),
            'Repair message should include the count');
    }

    @IsTest
    static void backfillPermSetsDoesNotThrow() {
        Test.startTest();
        String message = DeliveryHubRepairService.runRepair('backfillPermSets');
        Test.stopTest();
        System.assertNotEquals(null, message);
    }

    @IsTest
    static void blankRepairKeyThrows() {
        Boolean threw = false;
        try {
            DeliveryHubRepairService.runRepair('');
        } catch (AuraHandledException e) {
            threw = true;
        }
        System.assertEquals(true, threw);
    }

    @IsTest
    static void unknownRepairKeyThrows() {
        Boolean threw = false;
        try {
            DeliveryHubRepairService.runRepair('not_a_real_repair');
        } catch (AuraHandledException e) {
            threw = true;
        }
        System.assertEquals(true, threw);
    }
}

/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Tests for DeliverySyncRetryController.
 * @author Cloud Nimbus LLC
 */
@IsTest
private class DeliverySyncRetryControllerTest {

    @TestSetup
    static void setup() {
        WorkItem__c workItem = new WorkItem__c(BriefDescriptionTxt__c = 'Test Work Item', StageNamePk__c = 'Backlog');
        insert workItem;

        List<SyncItem__c> items = new List<SyncItem__c>{
            new SyncItem__c(
                ObjectTypePk__c     = 'WorkItem__c',
                LocalRecordIdTxt__c = workItem.Id,
                WorkItemId__c         = workItem.Id,
                DirectionPk__c      = 'Outbound',
                StatusPk__c         = 'Failed',
                ErrorLogTxt__c      = 'Connection timeout'
            ),
            new SyncItem__c(
                ObjectTypePk__c     = 'WorkItem__c',
                LocalRecordIdTxt__c = workItem.Id,
                WorkItemId__c         = workItem.Id,
                DirectionPk__c      = 'Outbound',
                StatusPk__c         = 'Failed',
                ErrorLogTxt__c      = 'Auth error'
            ),
            new SyncItem__c(
                ObjectTypePk__c     = 'WorkItem__c',
                LocalRecordIdTxt__c = workItem.Id,
                WorkItemId__c         = workItem.Id,
                DirectionPk__c      = 'Outbound',
                StatusPk__c         = 'Synced',
                ErrorLogTxt__c      = null
            )
        };
        insert items;
    }

    @IsTest
    static void testGetSyncHealth() {
        Map<String, Object> health = DeliverySyncRetryController.getSyncHealth();

        Integer failedCount = (Integer) health.get('failedCount');
        System.assertEquals(2, failedCount, 'Should report 2 failed sync items');

        List<Object> errors = (List<Object>) health.get('recentErrors');
        System.assertEquals(2, errors.size(), 'Should return 2 error rows');
    }

    @IsTest
    static void testRetryFailed() {
        DeliverySyncRetryController.retryFailed();

        List<SyncItem__c> stillFailed = [
            SELECT Id FROM SyncItem__c WHERE StatusPk__c = 'Failed'
        ];
        System.assertEquals(0, stillFailed.size(), 'No items should remain in Failed status');

        List<SyncItem__c> queued = [
            SELECT Id, ErrorLogTxt__c FROM SyncItem__c WHERE StatusPk__c = 'Queued'
        ];
        System.assertEquals(2, queued.size(), 'Both failed items should be reset to Queued');
        for (SyncItem__c si : queued) {
            System.assertEquals(null, si.ErrorLogTxt__c, 'Error log should be cleared on retry');
        }
    }

    @IsTest
    static void testGetSyncHealthNoFailures() {
        // Reset all to Synced
        List<SyncItem__c> all = [SELECT Id FROM SyncItem__c WHERE StatusPk__c = 'Failed'];
        for (SyncItem__c si : all) { si.StatusPk__c = 'Synced'; }
        update all;

        Map<String, Object> health = DeliverySyncRetryController.getSyncHealth();
        Integer failedCount = (Integer) health.get('failedCount');
        System.assertEquals(0, failedCount, 'Should report 0 failed items');

        List<Object> errors = (List<Object>) health.get('recentErrors');
        System.assertEquals(0, errors.size(), 'Error list should be empty');
    }
}

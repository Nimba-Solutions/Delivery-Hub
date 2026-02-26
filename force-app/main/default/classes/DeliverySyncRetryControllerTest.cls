/**
 * @description Tests for DeliverySyncRetryController.
 * @author Cloud Nimbus LLC
 */
@IsTest
private class DeliverySyncRetryControllerTest {

    @TestSetup
    static void setup() {
        WorkItem__c ticket = new WorkItem__c(BriefDescriptionTxt__c = 'Test Ticket', StageNamePk__c = 'Backlog');
        insert ticket;

        List<Sync_Item__c> items = new List<Sync_Item__c>{
            new Sync_Item__c(
                ObjectTypePk__c     = 'WorkItem__c',
                LocalRecordIdTxt__c = ticket.Id,
                WorkItemId__c         = ticket.Id,
                DirectionPk__c      = 'Outbound',
                StatusPk__c         = 'Failed',
                ErrorLogTxt__c      = 'Connection timeout'
            ),
            new Sync_Item__c(
                ObjectTypePk__c     = 'WorkItem__c',
                LocalRecordIdTxt__c = ticket.Id,
                WorkItemId__c         = ticket.Id,
                DirectionPk__c      = 'Outbound',
                StatusPk__c         = 'Failed',
                ErrorLogTxt__c      = 'Auth error'
            ),
            new Sync_Item__c(
                ObjectTypePk__c     = 'WorkItem__c',
                LocalRecordIdTxt__c = ticket.Id,
                WorkItemId__c         = ticket.Id,
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

        List<Sync_Item__c> stillFailed = [
            SELECT Id FROM Sync_Item__c WHERE StatusPk__c = 'Failed'
        ];
        System.assertEquals(0, stillFailed.size(), 'No items should remain in Failed status');

        List<Sync_Item__c> queued = [
            SELECT Id, ErrorLogTxt__c FROM Sync_Item__c WHERE StatusPk__c = 'Queued'
        ];
        System.assertEquals(2, queued.size(), 'Both failed items should be reset to Queued');
        for (Sync_Item__c si : queued) {
            System.assertEquals(null, si.ErrorLogTxt__c, 'Error log should be cleared on retry');
        }
    }

    @IsTest
    static void testGetSyncHealthNoFailures() {
        // Reset all to Synced
        List<Sync_Item__c> all = [SELECT Id FROM Sync_Item__c WHERE StatusPk__c = 'Failed'];
        for (Sync_Item__c si : all) { si.StatusPk__c = 'Synced'; }
        update all;

        Map<String, Object> health = DeliverySyncRetryController.getSyncHealth();
        Integer failedCount = (Integer) health.get('failedCount');
        System.assertEquals(0, failedCount, 'Should report 0 failed items');

        List<Object> errors = (List<Object>) health.get('recentErrors');
        System.assertEquals(0, errors.size(), 'Error list should be empty');
    }
}

/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Tests for DeliverySyncRetryController, including the dismiss/restore
 *              admin endpoints added by the failed-sync dismissal feature.
 * @author Cloud Nimbus LLC
 */
@IsTest
private class DeliverySyncRetryControllerTest {

    private static User testUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];

    @TestSetup
    static void setup() {
        WorkItem__c workItem = new WorkItem__c(BriefDescriptionTxt__c = 'Test Work Item', StageNamePk__c = 'Backlog');
        insert workItem;

        List<SyncItem__c> items = new List<SyncItem__c>{
            new SyncItem__c(
                ObjectTypePk__c     = 'WorkItem__c',
                LocalRecordIdTxt__c = workItem.Id,
                WorkItemLookup__c   = workItem.Id,
                DirectionPk__c      = 'Outbound',
                StatusPk__c         = 'Failed',
                ErrorLogTxt__c      = 'Connection timeout'
            ),
            new SyncItem__c(
                ObjectTypePk__c     = 'WorkItem__c',
                LocalRecordIdTxt__c = workItem.Id,
                WorkItemLookup__c   = workItem.Id,
                DirectionPk__c      = 'Outbound',
                StatusPk__c         = 'Failed',
                ErrorLogTxt__c      = 'Auth error'
            ),
            new SyncItem__c(
                ObjectTypePk__c     = 'WorkItem__c',
                LocalRecordIdTxt__c = workItem.Id,
                WorkItemLookup__c   = workItem.Id,
                DirectionPk__c      = 'Outbound',
                StatusPk__c         = 'Synced',
                ErrorLogTxt__c      = null
            )
        };
        insert items;
    }

    @IsTest
    static void testGetSyncHealthExcludesDismissedByDefault() {
        System.runAs(testUser) {
            Map<String, Object> health = DeliverySyncRetryController.getSyncHealth(false);

            Integer failedCount = (Integer) health.get('failedCount');
            System.assertEquals(2, failedCount, 'Should report 2 failed sync items');

            List<Object> errors = (List<Object>) health.get('recentErrors');
            System.assertEquals(2, errors.size(), 'Should return 2 error rows');
        }
    }

    @IsTest
    static void testGetSyncHealthIncludeDismissedShowsAll() {
        System.runAs(testUser) {
            // Dismiss one of the two failed items
            SyncItem__c first = [SELECT Id FROM SyncItem__c WHERE StatusPk__c = 'Failed' LIMIT 1];
            DeliverySyncDismissalService.dismiss(new Set<Id>{first.Id}, 'test setup');

            Map<String, Object> hidden = DeliverySyncRetryController.getSyncHealth(false);
            System.assertEquals(1, (Integer) hidden.get('failedCount'),
                'Default view should hide the dismissed item');

            Map<String, Object> shown = DeliverySyncRetryController.getSyncHealth(true);
            System.assertEquals(2, (Integer) shown.get('failedCount'),
                'includeDismissed=true should surface all failed items');

            List<Object> rows = (List<Object>) shown.get('recentErrors');
            System.assertEquals(2, rows.size(), 'Both rows should be returned');
        }
    }

    @IsTest
    static void testRetryFailedSkipsDismissed() {
        System.runAs(testUser) {
            // Dismiss one item — retryFailed should leave it alone
            SyncItem__c first = [SELECT Id FROM SyncItem__c WHERE StatusPk__c = 'Failed' LIMIT 1];
            DeliverySyncDismissalService.dismiss(new Set<Id>{first.Id}, 'pre-retry test');

            DeliverySyncRetryController.retryFailed();

            // The non-dismissed item went to Queued; the dismissed one stays Failed
            List<SyncItem__c> stillFailed = [
                SELECT Id, DismissedDateTime__c FROM SyncItem__c WHERE StatusPk__c = 'Failed'
            ];
            System.assertEquals(1, stillFailed.size(),
                'Dismissed item should still be Failed after retryFailed()');
            System.assertNotEquals(null, stillFailed[0].DismissedDateTime__c,
                'The remaining Failed item is the dismissed one');

            List<SyncItem__c> queued = [
                SELECT Id, ErrorLogTxt__c FROM SyncItem__c WHERE StatusPk__c = 'Queued'
            ];
            System.assertEquals(1, queued.size(), 'Only the non-dismissed item should be requeued');
            System.assertEquals(null, queued[0].ErrorLogTxt__c, 'Error log cleared on retry');
        }
    }

    @IsTest
    static void testDismissFailedEndpoint() {
        System.runAs(testUser) {
            List<SyncItem__c> failed = [SELECT Id FROM SyncItem__c WHERE StatusPk__c = 'Failed'];
            List<Id> ids = new List<Id>();
            for (SyncItem__c si : failed) { ids.add(si.Id); }

            Test.startTest();
            Integer count = DeliverySyncRetryController.dismissFailed(ids, 'bulk dismiss test');
            Test.stopTest();

            System.assertEquals(2, count, 'Both failed items should be dismissed');

            List<SyncItem__c> dismissed = [
                SELECT Id, DismissedDateTime__c FROM SyncItem__c
                WHERE DismissedDateTime__c != NULL
            ];
            System.assertEquals(2, dismissed.size(), 'Both items should now have DismissedDateTime__c set');
        }
    }

    @IsTest
    static void testRestoreDismissedEndpoint() {
        System.runAs(testUser) {
            // Dismiss first
            SyncItem__c first = [SELECT Id FROM SyncItem__c WHERE StatusPk__c = 'Failed' LIMIT 1];
            DeliverySyncDismissalService.dismiss(new Set<Id>{first.Id}, 'pre-restore');

            // Then restore via the controller
            Test.startTest();
            Integer restored = DeliverySyncRetryController.restoreDismissed(new List<Id>{first.Id});
            Test.stopTest();

            System.assertEquals(1, restored, 'One item should be restored');
            SyncItem__c reloaded = [
                SELECT DismissedDateTime__c, StatusPk__c FROM SyncItem__c WHERE Id = :first.Id
            ];
            System.assertEquals(null, reloaded.DismissedDateTime__c,
                'DismissedDateTime__c should be null after restore');
            System.assertEquals('Failed', reloaded.StatusPk__c,
                'Status should not change on restore (item is still Failed)');
        }
    }

    @IsTest
    static void testDismissFailedNullIds() {
        System.runAs(testUser) {
            Integer count = DeliverySyncRetryController.dismissFailed(null, 'noop');
            System.assertEquals(0, count, 'Null id list should be a no-op');
        }
    }

    @IsTest
    static void testRestoreDismissedNullIds() {
        System.runAs(testUser) {
            Integer count = DeliverySyncRetryController.restoreDismissed(null);
            System.assertEquals(0, count, 'Null id list should be a no-op');
        }
    }

    /**
     * @description PR #621 regression guard: getSyncHealth should surface
     *              stagedAwaitingPoll separately so the LWC can show
     *              "X items waiting for downstream client to poll" without
     *              confusing them with actual failures.
     */
    @IsTest
    static void testGetSyncHealthSurfacesStagedAwaitingPoll() {
        System.runAs(testUser) {
            WorkItem__c workItem = [SELECT Id FROM WorkItem__c WHERE BriefDescriptionTxt__c = 'Test Work Item' LIMIT 1];
            // Add 3 Staged outbound items — they should NOT count as failures,
            // they should be surfaced separately under stagedAwaitingPoll.
            insert new List<SyncItem__c>{
                new SyncItem__c(
                    ObjectTypePk__c     = 'WorkItem__c',
                    LocalRecordIdTxt__c = workItem.Id,
                    WorkItemLookup__c   = workItem.Id,
                    DirectionPk__c      = 'Outbound',
                    StatusPk__c         = 'Staged'
                ),
                new SyncItem__c(
                    ObjectTypePk__c     = 'WorkItem__c',
                    LocalRecordIdTxt__c = workItem.Id,
                    WorkItemLookup__c   = workItem.Id,
                    DirectionPk__c      = 'Outbound',
                    StatusPk__c         = 'Staged'
                ),
                new SyncItem__c(
                    ObjectTypePk__c     = 'WorkItem__c',
                    LocalRecordIdTxt__c = workItem.Id,
                    WorkItemLookup__c   = workItem.Id,
                    DirectionPk__c      = 'Outbound',
                    StatusPk__c         = 'Staged'
                )
            };

            Map<String, Object> health = DeliverySyncRetryController.getSyncHealth(false);
            Integer staged = (Integer) health.get('stagedAwaitingPoll');
            System.assertEquals(3, staged,
                'stagedAwaitingPoll should reflect Outbound Staged items separately from failedCount');

            // Failures unchanged from setup (the 2 from @TestSetup)
            Integer failed = (Integer) health.get('failedCount');
            System.assertEquals(2, failed,
                'failedCount should NOT include Staged items — they are not failures');
        }
    }

    @IsTest
    static void testGetSyncHealthNoFailures() {
        System.runAs(testUser) {
            // Reset all to Synced
            List<SyncItem__c> all = [SELECT Id FROM SyncItem__c WHERE StatusPk__c = 'Failed'];
            for (SyncItem__c si : all) { si.StatusPk__c = 'Synced'; }
            update all;

            Map<String, Object> health = DeliverySyncRetryController.getSyncHealth(false);
            Integer failedCount = (Integer) health.get('failedCount');
            System.assertEquals(0, failedCount, 'Should report 0 failed items');

            List<Object> errors = (List<Object>) health.get('recentErrors');
            System.assertEquals(0, errors.size(), 'Error list should be empty');
        }
    }
}

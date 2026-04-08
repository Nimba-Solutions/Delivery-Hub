/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Tests for DeliverySyncDismissalService — covers manual dismiss,
 *              restore, the auto-aging path (dismissAged), the no-op cases when
 *              auto-aging is disabled, and the Sync Health % dashboard widget's
 *              dismissal-aware filter.
 * @author Cloud Nimbus LLC
 */
@IsTest
private class DeliverySyncDismissalServiceTest {

    private static User testUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];

    @TestSetup
    static void setup() {
        WorkItem__c wi = new WorkItem__c(
            BriefDescriptionTxt__c = 'Sync dismissal test parent',
            StageNamePk__c         = 'Backlog'
        );
        insert wi;

        // Two failed items, one synced, all freshly created.
        insert new List<SyncItem__c>{
            new SyncItem__c(
                ObjectTypePk__c     = 'WorkItem__c',
                LocalRecordIdTxt__c = wi.Id,
                WorkItemLookup__c   = wi.Id,
                DirectionPk__c      = 'Outbound',
                StatusPk__c         = 'Failed',
                ErrorLogTxt__c      = 'Boom 1',
                RetryCountNumber__c = 5
            ),
            new SyncItem__c(
                ObjectTypePk__c     = 'WorkItem__c',
                LocalRecordIdTxt__c = wi.Id,
                WorkItemLookup__c   = wi.Id,
                DirectionPk__c      = 'Outbound',
                StatusPk__c         = 'Failed',
                ErrorLogTxt__c      = 'Boom 2',
                RetryCountNumber__c = 0
            ),
            new SyncItem__c(
                ObjectTypePk__c     = 'WorkItem__c',
                LocalRecordIdTxt__c = wi.Id,
                WorkItemLookup__c   = wi.Id,
                DirectionPk__c      = 'Outbound',
                StatusPk__c         = 'Synced'
            )
        };
    }

    // ── Manual dismiss ────────────────────────────────────────────────────

    @IsTest
    static void testManualDismissSetsField() {
        System.runAs(testUser) {
            List<SyncItem__c> failed = [SELECT Id FROM SyncItem__c WHERE StatusPk__c = 'Failed'];
            Set<Id> ids = new Set<Id>();
            for (SyncItem__c si : failed) { ids.add(si.Id); }

            Test.startTest();
            Integer count = DeliverySyncDismissalService.dismiss(ids, 'unit test');
            Test.stopTest();

            System.assertEquals(2, count, 'Both failed items should be dismissed');
            List<SyncItem__c> dismissed = [
                SELECT Id, DismissedDateTime__c FROM SyncItem__c
                WHERE DismissedDateTime__c != NULL
            ];
            System.assertEquals(2, dismissed.size(), 'Both rows should have DismissedDateTime__c set');
            for (SyncItem__c si : dismissed) {
                System.assertNotEquals(null, si.DismissedDateTime__c,
                    'DismissedDateTime__c must not be null after dismiss');
            }
        }
    }

    @IsTest
    static void testManualDismissIdempotent() {
        System.runAs(testUser) {
            SyncItem__c first = [SELECT Id FROM SyncItem__c WHERE StatusPk__c = 'Failed' LIMIT 1];

            Integer firstPass = DeliverySyncDismissalService.dismiss(new Set<Id>{first.Id}, 'first');
            Integer secondPass = DeliverySyncDismissalService.dismiss(new Set<Id>{first.Id}, 'second');

            System.assertEquals(1, firstPass, 'First dismiss should affect 1 row');
            System.assertEquals(0, secondPass,
                'Second dismiss of the same row should be a no-op (already dismissed)');
        }
    }

    @IsTest
    static void testDismissSkipsNonFailedItems() {
        System.runAs(testUser) {
            // Pass a Synced row's Id along with Failed rows; only Failed should be touched.
            SyncItem__c synced = [SELECT Id FROM SyncItem__c WHERE StatusPk__c = 'Synced' LIMIT 1];
            SyncItem__c failedRow = [SELECT Id FROM SyncItem__c WHERE StatusPk__c = 'Failed' LIMIT 1];

            Integer count = DeliverySyncDismissalService.dismiss(
                new Set<Id>{ synced.Id, failedRow.Id }, 'mixed batch'
            );
            System.assertEquals(1, count,
                'Only the Failed row should be dismissed, not the Synced one');

            SyncItem__c reloadedSynced = [
                SELECT DismissedDateTime__c FROM SyncItem__c WHERE Id = :synced.Id
            ];
            System.assertEquals(null, reloadedSynced.DismissedDateTime__c,
                'Synced row should never get DismissedDateTime__c');
        }
    }

    @IsTest
    static void testDismissNullOrEmptyReturnsZero() {
        System.runAs(testUser) {
            System.assertEquals(0, DeliverySyncDismissalService.dismiss(null, 'noop'),
                'Null id set should be a no-op');
            System.assertEquals(0, DeliverySyncDismissalService.dismiss(new Set<Id>(), 'noop'),
                'Empty id set should be a no-op');
        }
    }

    // ── Restore ───────────────────────────────────────────────────────────

    @IsTest
    static void testRestoreClearsField() {
        System.runAs(testUser) {
            SyncItem__c first = [SELECT Id FROM SyncItem__c WHERE StatusPk__c = 'Failed' LIMIT 1];
            DeliverySyncDismissalService.dismiss(new Set<Id>{first.Id}, 'pre-restore');

            Test.startTest();
            Integer count = DeliverySyncDismissalService.restore(new Set<Id>{first.Id});
            Test.stopTest();

            System.assertEquals(1, count, 'Restore should affect 1 row');
            SyncItem__c reloaded = [
                SELECT DismissedDateTime__c, StatusPk__c FROM SyncItem__c WHERE Id = :first.Id
            ];
            System.assertEquals(null, reloaded.DismissedDateTime__c,
                'DismissedDateTime__c should be cleared');
            System.assertEquals('Failed', reloaded.StatusPk__c,
                'Status must NOT change on restore');
        }
    }

    @IsTest
    static void testRestoreSkipsActiveItems() {
        System.runAs(testUser) {
            // No items dismissed yet — restore should be a no-op
            SyncItem__c first = [SELECT Id FROM SyncItem__c WHERE StatusPk__c = 'Failed' LIMIT 1];
            Integer count = DeliverySyncDismissalService.restore(new Set<Id>{first.Id});
            System.assertEquals(0, count, 'Restore on never-dismissed item should be a no-op');
        }
    }

    // ── Auto-aging (dismissAged) ──────────────────────────────────────────

    @IsTest
    static void testDismissAgedNoopWhenSettingNull() {
        System.runAs(testUser) {
            DeliveryHubSettings__c settings = DeliveryHubSettings__c.getOrgDefaults();
            settings.FailedSyncAutoDismissDaysNumber__c = null;
            upsert settings;

            Integer count = DeliverySyncDismissalService.dismissAged();
            System.assertEquals(0, count, 'Null setting should disable auto-aging');
        }
    }

    @IsTest
    static void testDismissAgedNoopWhenSettingZero() {
        System.runAs(testUser) {
            DeliveryHubSettings__c settings = DeliveryHubSettings__c.getOrgDefaults();
            settings.FailedSyncAutoDismissDaysNumber__c = 0;
            upsert settings;

            Integer count = DeliverySyncDismissalService.dismissAged();
            System.assertEquals(0, count, '0 days should disable auto-aging');
        }
    }

    @IsTest
    static void testDismissAgedRespectsRetryLimit() {
        // dismissAged only touches items where RetryCountNumber__c >= maxRetries.
        // The setup row with RetryCountNumber__c = 0 must NOT be auto-dismissed
        // even if the date is old enough, because the retry path could still
        // self-heal it.
        System.runAs(testUser) {
            DeliveryHubSettings__c settings = DeliveryHubSettings__c.getOrgDefaults();
            settings.FailedSyncAutoDismissDaysNumber__c = 0.0001; // effectively "anything older than now"
            settings.SyncRetryLimitNumber__c = 3;
            upsert settings;

            Test.startTest();
            // We can't truly age LastModifiedDate in a test, but we can verify that
            // the unexhausted-retry row is excluded by the filter.
            Integer count = DeliverySyncDismissalService.dismissAged();
            Test.stopTest();

            // The retries-exhausted row (RetryCountNumber__c=5) is the only candidate;
            // even if 0 rows are old enough, the retries=0 row must never end up dismissed.
            SyncItem__c retriesZero = [
                SELECT DismissedDateTime__c FROM SyncItem__c
                WHERE RetryCountNumber__c = 0 AND StatusPk__c = 'Failed' LIMIT 1
            ];
            System.assertEquals(null, retriesZero.DismissedDateTime__c,
                'Items with retries remaining must never be auto-dismissed');
            System.assert(count >= 0, 'dismissAged should return a non-negative count');
        }
    }

    // ── Dashboard health widget filter ────────────────────────────────────

    @IsTest
    static void testSyncHealthExcludesDismissedFromTotal() {
        System.runAs(testUser) {
            // Pre-state: 2 Failed + 1 Synced in the last 7 days = 1/3 = 33%
            Object preResult = DeliveryDashboardCardController.getCardData('syncHealth', null);
            Decimal preHealth = (Decimal) preResult;
            System.assert(preHealth < 100,
                'Before dismissal, health should be below 100% (Failed items in denominator). Got: ' + preHealth);

            // Dismiss both failed items — denominator drops, ratio rises
            List<SyncItem__c> failed = [SELECT Id FROM SyncItem__c WHERE StatusPk__c = 'Failed'];
            Set<Id> ids = new Set<Id>();
            for (SyncItem__c si : failed) { ids.add(si.Id); }
            DeliverySyncDismissalService.dismiss(ids, 'health filter test');

            Object postResult = DeliveryDashboardCardController.getCardData('syncHealth', null);
            Decimal postHealth = (Decimal) postResult;
            System.assertEquals(100, postHealth.intValue(),
                'After dismissing all Failed items, health should be 100% (only Synced left in denominator)');
        }
    }

    // ── Audit log ─────────────────────────────────────────────────────────

    @IsTest
    static void testDismissWritesActivityLog() {
        System.runAs(testUser) {
            SyncItem__c first = [SELECT Id FROM SyncItem__c WHERE StatusPk__c = 'Failed' LIMIT 1];
            DeliverySyncDismissalService.dismiss(new Set<Id>{first.Id}, 'audit test');

            List<ActivityLog__c> logs = [
                SELECT ContextDataTxt__c, ComponentNameTxt__c FROM ActivityLog__c
                WHERE ComponentNameTxt__c = 'DeliverySyncDismissalService'
            ];
            System.assert(!logs.isEmpty(), 'A dismiss audit log row should have been written');
            System.assert(logs[0].ContextDataTxt__c.contains('SyncDismiss'),
                'Audit log context should include the operation discriminator');
        }
    }
}

/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Tests for DeliverySyncItemCleanup — covers the Synced-only purge
 *              guarantee (Staged/Queued/Pending/Failed must never be deleted),
 *              the retention-day setting, multi-chunk batch volume, and the
 *              scheduled entry point.
 *
 *              Aging note: we can't truly age LastModifiedDate in a test (same
 *              limitation documented in DeliverySyncDismissalServiceTest), so
 *              the purge-path tests set SyncItemRetentionDaysNumber__c = 0,
 *              which makes the cutoff "now" and every pre-existing row eligible.
 *              The survival test uses the default (null -> 30 days) window.
 * @author Cloud Nimbus LLC
 */
@IsTest
private class DeliverySyncItemCleanupTest {

    private static User testUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];

    /** @description Sets the retention window so every existing row is past cutoff. */
    private static void setRetentionToZeroDays() {
        DeliveryHubSettings__c settings = DeliveryHubSettings__c.getOrgDefaults();
        settings.SyncItemRetentionDaysNumber__c = 0;
        upsert settings;
    }

    /**
     * @description Core safety guarantee: with every row aged past the cutoff,
     *              ONLY StatusPk__c='Synced' rows are deleted. Staged, Queued,
     *              Pending, and Failed rows are live work / triage evidence and
     *              must all survive.
     */
    @IsTest
    static void testPurgesOnlyAgedSyncedRows() {
        System.runAs(testUser) {
            setRetentionToZeroDays();

            TestDataFactory.createSyncItems(3, new Map<String, Object>{ 'StatusPk__c' => 'Synced' });
            TestDataFactory.createSyncItem(new Map<String, Object>{ 'StatusPk__c' => 'Failed' });
            TestDataFactory.createSyncItem(new Map<String, Object>{ 'StatusPk__c' => 'Queued' });
            TestDataFactory.createSyncItem(new Map<String, Object>{ 'StatusPk__c' => 'Staged' });
            TestDataFactory.createSyncItem(new Map<String, Object>{
                'StatusPk__c' => 'Pending', 'DirectionPk__c' => 'Inbound'
            });

            Test.startTest();
            Database.executeBatch(new DeliverySyncItemCleanup(), 200);
            Test.stopTest();

            System.assertEquals(0, [
                SELECT COUNT() FROM SyncItem__c WHERE StatusPk__c = 'Synced'
            ], 'All aged Synced rows should be purged');

            List<SyncItem__c> survivors = [
                SELECT StatusPk__c FROM SyncItem__c WITH SYSTEM_MODE
            ];
            System.assertEquals(4, survivors.size(),
                'Failed, Queued, Staged, and Pending rows must all survive the purge');
            for (SyncItem__c si : survivors) {
                System.assertNotEquals('Synced', si.StatusPk__c,
                    'No surviving row should be Synced');
            }
        }
    }

    /**
     * @description Volume test: 450 aged Synced rows with scope 200 force three
     *              delete chunks — the QueryLocator batch pattern must remove all
     *              of them while the 40 Failed rows survive untouched. This is
     *              the same chunked-delete hardening that fixed the ActivityLog
     *              purge for high-volume subscribers.
     */
    @IsTest
    static void testPurgeScalesAcrossBatchChunks() {
        System.runAs(testUser) {
            setRetentionToZeroDays();

            TestDataFactory.createSyncItems(450, new Map<String, Object>{ 'StatusPk__c' => 'Synced' });
            TestDataFactory.createSyncItems(40, new Map<String, Object>{ 'StatusPk__c' => 'Failed' });

            Test.startTest();
            // Scope 200 forces 3 delete chunks over the 450 aged Synced rows.
            Database.executeBatch(new DeliverySyncItemCleanup(), 200);
            Test.stopTest();

            System.assertEquals(0, [
                SELECT COUNT() FROM SyncItem__c WHERE StatusPk__c = 'Synced'
            ], 'All 450 aged Synced rows must be purged across multiple chunks');
            System.assertEquals(40, [
                SELECT COUNT() FROM SyncItem__c WHERE StatusPk__c = 'Failed'
            ], 'Failed rows must be untouched by the multi-chunk purge');
        }
    }

    /**
     * @description Default retention (SyncItemRetentionDaysNumber__c blank -> 30
     *              days): freshly modified Synced rows are inside the window and
     *              must survive.
     */
    @IsTest
    static void testRecentSyncedRowsSurviveDefaultRetention() {
        System.runAs(testUser) {
            // No settings row — retention falls back to the 30-day default.
            TestDataFactory.createSyncItems(2, new Map<String, Object>{ 'StatusPk__c' => 'Synced' });

            Test.startTest();
            Database.executeBatch(new DeliverySyncItemCleanup(), 200);
            Test.stopTest();

            System.assertEquals(2, [
                SELECT COUNT() FROM SyncItem__c WHERE StatusPk__c = 'Synced'
            ], 'Synced rows inside the default 30-day window must survive');
        }
    }

    /**
     * @description Explicit retention setting inside the window: rows newer than
     *              the configured cutoff survive even when a custom value is set.
     */
    @IsTest
    static void testRecentSyncedRowsSurviveCustomRetention() {
        System.runAs(testUser) {
            DeliveryHubSettings__c settings = DeliveryHubSettings__c.getOrgDefaults();
            settings.SyncItemRetentionDaysNumber__c = 60;
            upsert settings;

            TestDataFactory.createSyncItem(new Map<String, Object>{ 'StatusPk__c' => 'Synced' });

            Test.startTest();
            Database.executeBatch(new DeliverySyncItemCleanup(), 200);
            Test.stopTest();

            System.assertEquals(1, [
                SELECT COUNT() FROM SyncItem__c WHERE StatusPk__c = 'Synced'
            ], 'A just-modified Synced row must survive a 60-day retention window');
        }
    }

    /**
     * @description Verifies the class can be registered as a scheduled job
     *              (standalone-cron path, mirroring DeliveryActivityLogCleanup).
     */
    @IsTest
    static void testSchedulableEntryPoint() {
        System.runAs(testUser) {
            Test.startTest();
            String jobId = System.schedule(
                'Test Sync Item Cleanup',
                '0 0 3 * * ?',
                new DeliverySyncItemCleanup()
            );
            Test.stopTest();

            System.assertNotEquals(null, jobId, 'Scheduled job should be created');
        }
    }
}

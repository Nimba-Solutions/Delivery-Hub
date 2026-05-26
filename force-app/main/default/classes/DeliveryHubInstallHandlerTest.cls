/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Tests for DeliveryHubInstallHandler.
 * @author Cloud Nimbus LLC
 */
@IsTest
private class DeliveryHubInstallHandlerTest {

    private static User testUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];

    @IsTest
    static void testInstallCreatesDefaultSettings() {
        System.runAs(testUser) {
            Test.testInstall(new DeliveryHubInstallHandler(), null, false);

            DeliveryHubSettings__c settings = DeliveryHubSettings__c.getOrgDefaults();
            System.assertNotEquals(null, settings.Id, 'Settings should be created on first install');
            System.assertNotEquals(null, settings.EnableNotificationsDateTime__c, 'Notifications should be enabled by default');
            System.assertNotEquals(null, settings.EnableAISuggestionsDateTime__c, 'AI suggestions should be enabled by default');
            System.assertEquals(14, settings.FailedSyncAutoDismissDaysNumber__c,
                'FailedSyncAutoDismissDaysNumber__c should default to 14 on fresh install');
            // Phase 2 Watcher v1 — top-3 signal flags default ON so PR-C can
            // ship signals 2+3 without an install-handler edit. Master flag
            // stays null — admins opt into Watcher explicitly.
            System.assertNotEquals(null, settings.EnableWatcherSLABreachDateTime__c,
                'Watcher SLA Breach signal default should be ON post-install');
            System.assertNotEquals(null, settings.EnableWatcherStuckStageDateTime__c,
                'Watcher Stuck Stage signal default should be ON post-install');
            System.assertNotEquals(null, settings.EnableWatcherARAgingDateTime__c,
                'Watcher AR Aging signal default should be ON post-install');
            System.assertEquals(null, settings.EnableWatcherDigestDateTime__c,
                'Watcher master flag must NOT default ON — admins flip this manually');
            System.assertEquals(null, settings.WatcherDigestRecipientUserIdsTxt__c,
                'Recipient list must NOT default — admins populate this manually');
        }
    }

    @IsTest
    static void testInstallDoesNotOverwriteExistingSettings() {
        System.runAs(testUser) {
            DeliveryHubSettings__c existing = new DeliveryHubSettings__c(
                SetupOwnerId                   = UserInfo.getOrganizationId(),
                EnableNotificationsDateTime__c = null
            );
            insert existing;

            Test.testInstall(new DeliveryHubInstallHandler(), null, false);

            DeliveryHubSettings__c settings = DeliveryHubSettings__c.getOrgDefaults();
            System.assertEquals(null, settings.EnableNotificationsDateTime__c, 'Existing settings should not be overwritten');
        }
    }

    @IsTest
    static void testInstallSchedulesSyncJobs() {
        System.runAs(testUser) {
            // Abort any existing scheduled jobs from prior test methods so we
            // observe a clean before/after state.
            for (CronTrigger ct : [
                SELECT Id FROM CronTrigger
                WHERE CronJobDetail.Name LIKE 'Delivery Hub Sync -%'
            ]) {
                System.abortJob(ct.Id);
            }

            Test.startTest();
            Test.testInstall(new DeliveryHubInstallHandler(), null, false);
            Test.stopTest();

            Integer scheduled = [
                SELECT COUNT() FROM CronTrigger
                WHERE CronJobDetail.Name LIKE 'Delivery Hub Sync -%'
            ];
            System.assertEquals(4, scheduled,
                'Install should schedule four 15-minute sync slots automatically');
        }
    }

    @IsTest
    static void testInstallBackfillsStaleStatusNewWorkItems() {
        System.runAs(testUser) {
            WorkItem__c stale = new WorkItem__c(
                BriefDescriptionTxt__c = 'Pre-upgrade stale WI',
                StageNamePk__c         = 'In Development',
                StatusPk__c            = 'New'
            );
            insert stale;
            Test.setCreatedDate(stale.Id, Datetime.now().addDays(-7));

            Test.testInstall(new DeliveryHubInstallHandler(), null, false);

            WorkItem__c reloaded = [SELECT StatusPk__c FROM WorkItem__c WHERE Id = :stale.Id];
            System.assertEquals('Active', reloaded.StatusPk__c,
                'Install handler should backfill pre-upgrade stale Status=New records');
        }
    }

    @IsTest
    static void testInstallSeedsFeatureCatalog() {
        System.runAs(testUser) {
            Integer defCount = [SELECT COUNT() FROM FeatureDefinition__mdt];

            Test.testInstall(new DeliveryHubInstallHandler(), null, false);

            Integer seeded = [
                SELECT COUNT() FROM Feature__c WHERE FeatureDefinitionTxt__c != null
            ];
            System.assertEquals(defCount, seeded,
                'Install should seed one Feature__c per FeatureDefinition__mdt row');
        }
    }

    @IsTest
    static void testInstallFeatureSeedIsIdempotent() {
        System.runAs(testUser) {
            Test.testInstall(new DeliveryHubInstallHandler(), null, false);
            Integer afterFirst = [
                SELECT COUNT() FROM Feature__c WHERE FeatureDefinitionTxt__c != null
            ];
            Test.testInstall(new DeliveryHubInstallHandler(), null, false);
            Integer afterSecond = [
                SELECT COUNT() FROM Feature__c WHERE FeatureDefinitionTxt__c != null
            ];
            System.assertEquals(afterFirst, afterSecond,
                'Re-running install should not duplicate seeded Feature__c rows');
        }
    }

    @IsTest
    static void testInstallIsIdempotentOnRepeatedScheduling() {
        System.runAs(testUser) {
            Test.testInstall(new DeliveryHubInstallHandler(), null, false);
            Integer afterFirst = [
                SELECT COUNT() FROM CronTrigger
                WHERE CronJobDetail.Name LIKE 'Delivery Hub Sync -%'
            ];
            Test.testInstall(new DeliveryHubInstallHandler(), null, false);
            Integer afterSecond = [
                SELECT COUNT() FROM CronTrigger
                WHERE CronJobDetail.Name LIKE 'Delivery Hub Sync -%'
            ];
            System.assertEquals(afterFirst, afterSecond,
                'Re-running install should not duplicate scheduled jobs');
        }
    }
}

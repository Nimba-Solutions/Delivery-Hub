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

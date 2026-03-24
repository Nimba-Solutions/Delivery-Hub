/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Tests for DeliveryHubInstallHandler.
 * @author Cloud Nimbus LLC
 */
@IsTest
private class DeliveryHubInstallHandlerTest {

    @IsTest
    static void testInstallCreatesDefaultSettings() {
        Test.testInstall(new DeliveryHubInstallHandler(), null, false);

        DeliveryHubSettings__c settings = DeliveryHubSettings__c.getOrgDefaults();
        System.assertNotEquals(null, settings.Id, 'Settings should be created on first install');
        System.assertNotEquals(null, settings.EnableNotificationsDateTime__c, 'Notifications should be enabled by default');
        System.assertNotEquals(null, settings.EnableAISuggestionsDateTime__c, 'AI suggestions should be enabled by default');
    }

    @IsTest
    static void testInstallDoesNotOverwriteExistingSettings() {
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

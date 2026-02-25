/**
 * @description Tests for DeliveryHubInstallHandler.
 * @author Cloud Nimbus LLC
 */
@IsTest
private class DeliveryHubInstallHandlerTest {

    @IsTest
    static void testInstallCreatesDefaultSettings() {
        Test.testInstall(new DeliveryHubInstallHandler(), null, false);

        Delivery_Hub_Settings__c settings = Delivery_Hub_Settings__c.getOrgDefaults();
        System.assertNotEquals(null, settings.Id, 'Settings should be created on first install');
        System.assertEquals(true, settings.EnableNotificationsBool__c, 'Notifications should be enabled by default');
        System.assertEquals(true, settings.AISuggestionsEnabledBool__c, 'AI suggestions should be enabled by default');
    }

    @IsTest
    static void testInstallDoesNotOverwriteExistingSettings() {
        Delivery_Hub_Settings__c existing = new Delivery_Hub_Settings__c(
            SetupOwnerId               = UserInfo.getOrganizationId(),
            EnableNotificationsBool__c = false
        );
        insert existing;

        Test.testInstall(new DeliveryHubInstallHandler(), null, false);

        Delivery_Hub_Settings__c settings = Delivery_Hub_Settings__c.getOrgDefaults();
        System.assertEquals(false, settings.EnableNotificationsBool__c, 'Existing settings should not be overwritten');
    }
}

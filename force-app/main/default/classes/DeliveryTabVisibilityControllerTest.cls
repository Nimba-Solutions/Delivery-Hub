/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Unit tests for DeliveryTabVisibilityController — the per-tab visibility
 *               toggles for the Delivery Hub workspace ("Delivery") tab, backed by inverted
 *               HideTab…DateTime__c fields on DeliveryHubSettings__c (null = shown,
 *               non-null = hidden).
 * @author       Cloud Nimbus LLC
 */
@isTest
private class DeliveryTabVisibilityControllerTest {

    private static final String KEY_BOARD = 'board';
    private static final String KEY_FORECAST = 'forecast';

    @isTest
    static void defaultsToAllShown() {
        Test.startTest();
        Map<String, Boolean> hidden = DeliveryTabVisibilityController.getHiddenWorkspaceTabs();
        Test.stopTest();

        System.assertEquals(11, hidden.size(), 'Expected all eleven non-admin tabs in the map');
        for (String key : hidden.keySet()) {
            System.assertEquals(false, hidden.get(key), 'No setting present → tab should be shown (not hidden): ' + key);
        }
    }

    @isTest
    static void hidingStampsTheField() {
        Map<String, Boolean> request = new Map<String, Boolean>{ KEY_BOARD => true };

        Test.startTest();
        Map<String, Boolean> result = DeliveryTabVisibilityController.setHiddenWorkspaceTabs(request);
        Test.stopTest();

        System.assertEquals(true, result.get(KEY_BOARD), 'Board tab should be hidden after stamping');
        System.assertEquals(false, result.get(KEY_FORECAST), 'Untouched tabs stay shown');

        DeliveryHubSettings__c settings = DeliveryHubSettings__c.getOrgDefaults();
        System.assertNotEquals(null, settings.HideTabBoardDateTime__c, 'Hide field should be stamped');
        System.assertEquals(null, settings.HideTabForecastDateTime__c, 'Untouched field stays null');
    }

    @isTest
    static void showingClearsTheField() {
        // First hide, then show again — must clear the stamp (fully reversible).
        DeliveryTabVisibilityController.setHiddenWorkspaceTabs(new Map<String, Boolean>{ KEY_BOARD => true });

        Test.startTest();
        Map<String, Boolean> result = DeliveryTabVisibilityController.setHiddenWorkspaceTabs(
            new Map<String, Boolean>{ KEY_BOARD => false });
        Test.stopTest();

        System.assertEquals(false, result.get(KEY_BOARD), 'Board tab should be shown again');
        DeliveryHubSettings__c settings = DeliveryHubSettings__c.getOrgDefaults();
        System.assertEquals(null, settings.HideTabBoardDateTime__c, 'Hide field should be cleared');
    }

    @isTest
    static void existingStampIsPreservedOnRepeatHide() {
        DeliveryTabVisibilityController.setHiddenWorkspaceTabs(new Map<String, Boolean>{ KEY_BOARD => true });
        Datetime firstStamp = DeliveryHubSettings__c.getOrgDefaults().HideTabBoardDateTime__c;

        Test.startTest();
        // Re-asserting "hidden" should not churn the existing timestamp.
        DeliveryTabVisibilityController.setHiddenWorkspaceTabs(new Map<String, Boolean>{ KEY_BOARD => true });
        Test.stopTest();

        Datetime secondStamp = DeliveryHubSettings__c.getOrgDefaults().HideTabBoardDateTime__c;
        System.assertEquals(firstStamp, secondStamp, 'Existing hide timestamp should be preserved');
    }

    @isTest
    static void nullRequestIsSafe() {
        Test.startTest();
        Map<String, Boolean> result = DeliveryTabVisibilityController.setHiddenWorkspaceTabs(null);
        Test.stopTest();

        System.assertEquals(11, result.size(), 'A null request is a no-op that still returns the full map');
        for (String key : result.keySet()) {
            System.assertEquals(false, result.get(key), 'Nothing hidden for a null request: ' + key);
        }
    }
}

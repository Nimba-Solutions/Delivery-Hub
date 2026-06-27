/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Unit tests for DeliveryHomeVisibilityController — the per-component
 *               Home-page visibility toggles backed by inverted HideHome…DateTime__c
 *               fields on DeliveryHubSettings__c (null = shown, non-null = hidden).
 * @author       Cloud Nimbus LLC
 */
@isTest
private class DeliveryHomeVisibilityControllerTest {

    private static final String KEY_BUDGET = 'deliveryBudgetSummary';
    private static final String KEY_PACING = 'deliveryPacingForecast';

    @isTest
    static void defaultsToAllShown() {
        Test.startTest();
        Map<String, Boolean> hidden = DeliveryHomeVisibilityController.getHiddenHomeComponents();
        Test.stopTest();

        System.assertEquals(6, hidden.size(), 'Expected all six components in the map');
        for (String key : hidden.keySet()) {
            System.assertEquals(false, hidden.get(key), 'No setting present → component should be shown (not hidden): ' + key);
        }
    }

    @isTest
    static void hidingStampsTheField() {
        Map<String, Boolean> request = new Map<String, Boolean>{ KEY_BUDGET => true };

        Test.startTest();
        Map<String, Boolean> result = DeliveryHomeVisibilityController.setHiddenHomeComponents(request);
        Test.stopTest();

        System.assertEquals(true, result.get(KEY_BUDGET), 'Budget Summary should be hidden after stamping');
        System.assertEquals(false, result.get(KEY_PACING), 'Untouched components stay shown');

        DeliveryHubSettings__c settings = DeliveryHubSettings__c.getOrgDefaults();
        System.assertNotEquals(null, settings.HideHomeBudgetSummaryDateTime__c, 'Hide field should be stamped');
        System.assertEquals(null, settings.HideHomePacingForecastDateTime__c, 'Untouched field stays null');
    }

    @isTest
    static void showingClearsTheField() {
        // First hide, then show again — must clear the stamp (fully reversible).
        DeliveryHomeVisibilityController.setHiddenHomeComponents(new Map<String, Boolean>{ KEY_BUDGET => true });

        Test.startTest();
        Map<String, Boolean> result = DeliveryHomeVisibilityController.setHiddenHomeComponents(
            new Map<String, Boolean>{ KEY_BUDGET => false });
        Test.stopTest();

        System.assertEquals(false, result.get(KEY_BUDGET), 'Budget Summary should be shown again');
        DeliveryHubSettings__c settings = DeliveryHubSettings__c.getOrgDefaults();
        System.assertEquals(null, settings.HideHomeBudgetSummaryDateTime__c, 'Hide field should be cleared');
    }

    @isTest
    static void existingStampIsPreservedOnRepeatHide() {
        DeliveryHomeVisibilityController.setHiddenHomeComponents(new Map<String, Boolean>{ KEY_BUDGET => true });
        Datetime firstStamp = DeliveryHubSettings__c.getOrgDefaults().HideHomeBudgetSummaryDateTime__c;

        Test.startTest();
        // Re-asserting "hidden" should not churn the existing timestamp.
        DeliveryHomeVisibilityController.setHiddenHomeComponents(new Map<String, Boolean>{ KEY_BUDGET => true });
        Test.stopTest();

        Datetime secondStamp = DeliveryHubSettings__c.getOrgDefaults().HideHomeBudgetSummaryDateTime__c;
        System.assertEquals(firstStamp, secondStamp, 'Existing hide timestamp should be preserved');
    }

    @isTest
    static void nullRequestIsSafe() {
        Test.startTest();
        Map<String, Boolean> result = DeliveryHomeVisibilityController.setHiddenHomeComponents(null);
        Test.stopTest();

        System.assertEquals(6, result.size(), 'A null request is a no-op that still returns the full map');
        for (String key : result.keySet()) {
            System.assertEquals(false, result.get(key), 'Nothing hidden for a null request: ' + key);
        }
    }
}

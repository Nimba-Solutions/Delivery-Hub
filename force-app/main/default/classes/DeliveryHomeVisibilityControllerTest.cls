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
    private static final String KEY_INTAKE = 'deliveryIntakeQueue';
    private static final String KEY_APPROVAL_QUEUE = 'deliveryApprovalQueue';

    // Every hideable home-page component the controller is expected to map.
    private static final Integer EXPECTED_COMPONENT_COUNT = 11;

    @isTest
    static void defaultsToAllShown() {
        Test.startTest();
        Map<String, Boolean> hidden = DeliveryHomeVisibilityController.getHiddenHomeComponents();
        Test.stopTest();

        System.assertEquals(EXPECTED_COMPONENT_COUNT, hidden.size(), 'Expected all hideable components in the map');
        for (String key : hidden.keySet()) {
            System.assertEquals(false, hidden.get(key), 'No setting present → component should be shown (not hidden): ' + key);
        }
        // The components added in the second wave must be present and keyed by LWC name.
        System.assertEquals(true, hidden.containsKey(KEY_INTAKE), 'Intake queue should be a hideable component');
        System.assertEquals(true, hidden.containsKey(KEY_APPROVAL_QUEUE), 'Approval queue should be a hideable component');
        System.assertEquals(true, hidden.containsKey('deliveryApprovalSummaryCard'), 'Approval summary card should be a hideable component');
        System.assertEquals(true, hidden.containsKey('deliveryFeatureCockpit'), 'Feature cockpit should be a hideable component');
        System.assertEquals(true, hidden.containsKey('deliveryClientDashboard'), 'Client dashboard should be a hideable component');
    }

    @isTest
    static void hidingStampsANewlyAddedComponent() {
        Map<String, Boolean> request = new Map<String, Boolean>{ KEY_INTAKE => true };

        Test.startTest();
        Map<String, Boolean> result = DeliveryHomeVisibilityController.setHiddenHomeComponents(request);
        Test.stopTest();

        System.assertEquals(true, result.get(KEY_INTAKE), 'Intake queue should be hidden after stamping');
        System.assertEquals(false, result.get(KEY_APPROVAL_QUEUE), 'Untouched components stay shown');

        DeliveryHubSettings__c settings = DeliveryHubSettings__c.getOrgDefaults();
        System.assertNotEquals(null, settings.HideHomeIntakeQueueDateTime__c, 'Hide field should be stamped');
        System.assertEquals(null, settings.HideHomeApprovalQueueDateTime__c, 'Untouched field stays null');
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

        System.assertEquals(EXPECTED_COMPONENT_COUNT, result.size(), 'A null request is a no-op that still returns the full map');
        for (String key : result.keySet()) {
            System.assertEquals(false, result.get(key), 'Nothing hidden for a null request: ' + key);
        }
    }
}

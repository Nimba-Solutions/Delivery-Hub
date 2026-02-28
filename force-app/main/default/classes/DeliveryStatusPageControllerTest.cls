/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Tests for DeliveryStatusPageController — validates public status page
 *               data retrieval, error handling, and the VF page property accessors.
 * @author Cloud Nimbus LLC
 */
@IsTest
private class DeliveryStatusPageControllerTest {

    @TestSetup
    static void setupData() {
        // Enable status page in org defaults
        DeliveryHubSettings__c settings = DeliveryHubSettings__c.getOrgDefaults();
        settings.StatusPageEnabledBool__c = true;
        settings.StatusPageTokenTxt__c = 'test-token';
        upsert settings;

        // Create a client network entity
        NetworkEntity__c entity = new NetworkEntity__c(
            Name = 'Acme Corp',
            EntityTypePk__c = 'Client',
            StatusPk__c = 'Active'
        );
        insert entity;

        // Create work items across various stages scoped to the entity
        List<WorkItem__c> workItems = new List<WorkItem__c>{
            new WorkItem__c(
                BriefDescriptionTxt__c = 'Setup environment',
                StageNamePk__c = 'Backlog',
                PriorityPk__c = 'Medium',
                ClientNetworkEntityId__c = entity.Id,
                SLATargetDate__c = Date.today().addDays(10)
            ),
            new WorkItem__c(
                BriefDescriptionTxt__c = 'Build feature A',
                StageNamePk__c = 'In Development',
                PriorityPk__c = 'High',
                ClientNetworkEntityId__c = entity.Id,
                SLATargetDate__c = Date.today().addDays(2)
            ),
            new WorkItem__c(
                BriefDescriptionTxt__c = 'Deploy v1.0',
                StageNamePk__c = 'Done',
                PriorityPk__c = 'Low',
                ClientNetworkEntityId__c = entity.Id,
                SLATargetDate__c = Date.today().addDays(-5)
            ),
            new WorkItem__c(
                BriefDescriptionTxt__c = 'Fix login bug',
                StageNamePk__c = 'Done',
                PriorityPk__c = 'Critical',
                ClientNetworkEntityId__c = entity.Id,
                SLATargetDate__c = Date.today().addDays(-2)
            ),
            new WorkItem__c(
                BriefDescriptionTxt__c = 'Overdue item',
                StageNamePk__c = 'In Progress',
                PriorityPk__c = 'Critical',
                ClientNetworkEntityId__c = entity.Id,
                SLATargetDate__c = Date.today().addDays(-1)
            )
        };
        insert workItems;
    }

    @IsTest
    static void testValidEntityToken() {
        Test.startTest();
        Map<String, Object> result = DeliveryStatusPageController.getStatusPageData('Acme Corp');
        Test.stopTest();

        System.assert(!result.containsKey('error'), 'Should not return an error for valid entity');
        System.assertEquals('Acme Corp', (String) result.get('entityName'));

        // Active count — items not in terminal stages
        Integer activeCount = (Integer) result.get('activeCount');
        System.assert(activeCount > 0, 'Should have active items');

        // Completed count
        Integer completedCount = (Integer) result.get('completedCount');
        System.assert(completedCount >= 2, 'Should have at least 2 completed items');

        // Overall health
        String health = (String) result.get('overallHealth');
        System.assert(
            health == 'Healthy' || health == 'At Risk' || health == 'Critical',
            'Health should be one of the three valid values'
        );

        // Last updated
        System.assert(result.containsKey('lastUpdated'), 'Should include lastUpdated');
    }

    @IsTest
    static void testPhaseDistribution() {
        Test.startTest();
        Map<String, Object> result = DeliveryStatusPageController.getStatusPageData('Acme Corp');
        Test.stopTest();

        Map<String, Integer> phases = (Map<String, Integer>) result.get('phaseDistribution');
        System.assertNotEquals(null, phases, 'Phase distribution should not be null');
        System.assert(phases.containsKey('Planning'), 'Should contain Planning phase');
        System.assert(phases.containsKey('Development'), 'Should contain Development phase');
    }

    @IsTest
    static void testSLAHealth() {
        Test.startTest();
        Map<String, Object> result = DeliveryStatusPageController.getStatusPageData('Acme Corp');
        Test.stopTest();

        Map<String, Integer> sla = (Map<String, Integer>) result.get('slaHealth');
        System.assertNotEquals(null, sla, 'SLA health should not be null');

        Integer onTrack = sla.get('onTrack');
        Integer atRisk = sla.get('atRisk');
        Integer breached = sla.get('breached');

        System.assert(onTrack >= 1, 'Should have at least 1 on-track item');
        System.assert(atRisk >= 1, 'Should have at least 1 at-risk item');
        System.assert(breached >= 1, 'Should have at least 1 breached item');
    }

    @IsTest
    static void testRecentCompletions() {
        Test.startTest();
        Map<String, Object> result = DeliveryStatusPageController.getStatusPageData('Acme Corp');
        Test.stopTest();

        List<Object> recentRaw = (List<Object>) result.get('recentCompletions');
        System.assert(recentRaw.size() >= 2, 'Should have at least 2 recent completions');

        // Verify shape — each item has title and completedDate
        Map<String, String> firstItem = (Map<String, String>) recentRaw[0];
        System.assert(firstItem.containsKey('title'), 'Completion should have title');
        System.assert(firstItem.containsKey('completedDate'), 'Completion should have completedDate');
    }

    @IsTest
    static void testInvalidToken() {
        Test.startTest();
        Map<String, Object> result = DeliveryStatusPageController.getStatusPageData('Nonexistent Entity');
        Test.stopTest();

        System.assert(result.containsKey('error'), 'Should return error for invalid token');
        System.assertEquals('Invalid or inactive entity token.', (String) result.get('error'));
    }

    @IsTest
    static void testMissingToken() {
        Test.startTest();
        Map<String, Object> result = DeliveryStatusPageController.getStatusPageData('');
        Test.stopTest();

        System.assert(result.containsKey('error'), 'Should return error for blank token');
        System.assertEquals('Missing entity token.', (String) result.get('error'));
    }

    @IsTest
    static void testNullToken() {
        Test.startTest();
        Map<String, Object> result = DeliveryStatusPageController.getStatusPageData(null);
        Test.stopTest();

        System.assert(result.containsKey('error'), 'Should return error for null token');
        System.assertEquals('Missing entity token.', (String) result.get('error'));
    }

    @IsTest
    static void testDisabledStatusPage() {
        // Disable the status page
        DeliveryHubSettings__c settings = DeliveryHubSettings__c.getOrgDefaults();
        settings.StatusPageEnabledBool__c = false;
        upsert settings;

        Test.startTest();
        Map<String, Object> result = DeliveryStatusPageController.getStatusPageData('Acme Corp');
        Test.stopTest();

        System.assert(result.containsKey('error'), 'Should return error when disabled');
        System.assertEquals('Status page is not enabled.', (String) result.get('error'));
    }

    @IsTest
    static void testVfPageProperties() {
        // Set up the VF page reference with the token parameter
        PageReference pageRef = Page.DeliveryStatusPage;
        pageRef.getParameters().put('token', 'Acme Corp');
        Test.setCurrentPage(pageRef);

        // Test the VF page property accessors through the controller
        DeliveryStatusPageController ctrl = new DeliveryStatusPageController();

        Test.startTest();
        String eName = ctrl.entityName;
        String health = ctrl.overallHealth;
        String updated = ctrl.lastUpdated;
        Integer active = ctrl.activeCount;
        Integer completed = ctrl.completedCount;
        String rate = ctrl.completionRate;
        Integer onTrack = ctrl.slaOnTrack;
        Integer atRisk = ctrl.slaAtRisk;
        Integer breached = ctrl.slaBreached;
        Map<String, Integer> ph = ctrl.phases;
        Integer phTotal = ctrl.phaseTotal;
        List<Map<String, String>> recent = ctrl.recentCompletions;
        List<DeliveryStatusPageController.CompletionItem> items = ctrl.completionItems;
        String pTitle = ctrl.pageTitle;
        Boolean hasRecent = ctrl.hasRecentCompletions;
        String hColor = ctrl.healthColor;
        String hBgColor = ctrl.healthBgColor;
        Boolean hasErr = ctrl.hasError;
        Test.stopTest();

        System.assertEquals('Acme Corp', eName, 'VF entity name should match');
        System.assertEquals(false, hasErr, 'Should not have error for valid token');
        System.assert(active > 0, 'VF activeCount should be positive');
        System.assert(completed >= 2, 'VF completedCount should be at least 2');
        System.assertNotEquals(null, health, 'VF health should not be null');
        System.assertNotEquals(null, hColor, 'VF healthColor should not be null');
        System.assertNotEquals(null, hBgColor, 'VF healthBgColor should not be null');
    }

    @IsTest
    static void testVfPageErrorState() {
        PageReference pageRef = Page.DeliveryStatusPage;
        pageRef.getParameters().put('token', 'Nonexistent');
        Test.setCurrentPage(pageRef);

        DeliveryStatusPageController ctrl = new DeliveryStatusPageController();

        Test.startTest();
        Boolean hasErr = ctrl.hasError;
        String errMsg = ctrl.errorMessage;
        Test.stopTest();

        System.assertEquals(true, hasErr, 'Should have error for invalid token');
        System.assertNotEquals(null, errMsg, 'Error message should not be null');
    }
}

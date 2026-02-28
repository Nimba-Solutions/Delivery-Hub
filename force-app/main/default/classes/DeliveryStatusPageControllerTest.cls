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

        // Create a second entity with no work items for edge-case testing
        NetworkEntity__c emptyEntity = new NetworkEntity__c(
            Name = 'Empty Org',
            EntityTypePk__c = 'Client',
            StatusPk__c = 'Active'
        );
        insert emptyEntity;

        // Create work items across various stages scoped to the entity
        // SLAStatusTxt__c is a formula based on SLATargetDate__c and stage:
        //   - On Track: SLATargetDate > today + 2 and non-terminal stage
        //   - At Risk:  SLATargetDate within 2 days of today and non-terminal stage
        //   - Breached: SLATargetDate < today and non-terminal stage
        //   - Met:      terminal stage (Done, Cancelled, Deployed to Prod)
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

    // ---------------------------------------------------------------
    // Static method tests — getStatusPageData()
    // ---------------------------------------------------------------

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
    static void testEntityWithNoWorkItems() {
        // Use the empty entity to verify zero-count and 'No activity' paths
        Test.startTest();
        Map<String, Object> result = DeliveryStatusPageController.getStatusPageData('Empty Org');
        Test.stopTest();

        System.assert(!result.containsKey('error'), 'Should not return error for valid empty entity');
        System.assertEquals('Empty Org', (String) result.get('entityName'));
        System.assertEquals(0, (Integer) result.get('activeCount'), 'Active count should be 0');
        System.assertEquals(0, (Integer) result.get('completedCount'), 'Completed count should be 0');
        System.assertEquals('Healthy', (String) result.get('overallHealth'),
            'Health should be Healthy when no SLA items exist');
        System.assertEquals('No activity', (String) result.get('lastUpdated'),
            'Last updated should be No activity when no items');

        // Phase distribution should have all zero counts
        Map<String, Integer> phases = (Map<String, Integer>) result.get('phaseDistribution');
        System.assertNotEquals(null, phases, 'Phase distribution should not be null');
        for (Integer cnt : phases.values()) {
            System.assertEquals(0, cnt, 'All phase counts should be 0 for empty entity');
        }

        // SLA health should all be zero
        Map<String, Integer> sla = (Map<String, Integer>) result.get('slaHealth');
        System.assertEquals(0, sla.get('onTrack'), 'onTrack should be 0');
        System.assertEquals(0, sla.get('atRisk'), 'atRisk should be 0');
        System.assertEquals(0, sla.get('breached'), 'breached should be 0');

        // Recent completions should be empty
        List<Object> recent = (List<Object>) result.get('recentCompletions');
        System.assertEquals(0, recent.size(), 'Should have no recent completions');
    }

    // ---------------------------------------------------------------
    // VF controller tests — property accessors with valid data
    // ---------------------------------------------------------------

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
        String errMsg = ctrl.errorMessage;
        Test.stopTest();

        System.assertEquals('Acme Corp', eName, 'VF entity name should match');
        System.assertEquals(false, hasErr, 'Should not have error for valid token');
        System.assertEquals(null, errMsg, 'Error message should be null for valid token');
        System.assert(active > 0, 'VF activeCount should be positive');
        System.assert(completed >= 2, 'VF completedCount should be at least 2');
        System.assertNotEquals(null, health, 'VF health should not be null');
        System.assertNotEquals(null, hColor, 'VF healthColor should not be null');
        System.assertNotEquals(null, hBgColor, 'VF healthBgColor should not be null');
        System.assert(rate.endsWith('%'), 'Completion rate should end with %');
        System.assert(String.isNotBlank(pTitle), 'Page title should not be blank');
        System.assert(pTitle.contains('Acme Corp'), 'Page title should contain entity name');
        System.assert(pTitle.contains('Live Status'), 'Page title should contain Live Status');
        System.assert(hasRecent, 'Should have recent completions');
        System.assert(items.size() >= 2, 'Should have at least 2 completion items');
        System.assertNotEquals(null, items[0].title, 'Completion item title should not be null');
        System.assertNotEquals(null, items[0].completedDate, 'Completion item date should not be null');
        System.assert(phTotal > 0, 'Phase total should be positive with active items');
    }

    // ---------------------------------------------------------------
    // VF controller tests — error states covering all property fallbacks
    // ---------------------------------------------------------------

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

    @IsTest
    static void testVfPageErrorAllPropertyFallbacks() {
        // Exercise every VF property in an error state to cover null-fallback paths
        PageReference pageRef = Page.DeliveryStatusPage;
        pageRef.getParameters().put('token', 'Nonexistent');
        Test.setCurrentPage(pageRef);

        DeliveryStatusPageController ctrl = new DeliveryStatusPageController();

        Test.startTest();
        // Trigger ensureLoaded which sets errorMsg, cachedData stays null
        Boolean hasErr = ctrl.hasError;
        String errMsg = ctrl.errorMessage;

        // All these properties should return safe defaults when cachedData is null
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
        Test.stopTest();

        System.assertEquals(true, hasErr, 'Should have error');
        System.assert(String.isNotBlank(errMsg), 'Error message should be populated');
        System.assertEquals('', eName, 'Entity name should be empty on error');
        System.assertEquals('', health, 'Health should be empty on error');
        System.assertEquals('', updated, 'Last updated should be empty on error');
        System.assertEquals(0, active, 'Active count should be 0 on error');
        System.assertEquals(0, completed, 'Completed count should be 0 on error');
        System.assertEquals('0%', rate, 'Completion rate should be 0% on error');
        System.assertEquals(0, onTrack, 'slaOnTrack should be 0 on error');
        System.assertEquals(0, atRisk, 'slaAtRisk should be 0 on error');
        System.assertEquals(0, breached, 'slaBreached should be 0 on error');
        System.assert(ph.isEmpty(), 'Phases should be empty on error');
        System.assertEquals(0, phTotal, 'Phase total should be 0 on error');
        System.assert(recent.isEmpty(), 'Recent completions should be empty on error');
        System.assert(items.isEmpty(), 'Completion items should be empty on error');
        System.assertEquals('Delivery Hub - Status', pTitle,
            'Page title should be fallback on error');
        System.assertEquals(false, hasRecent, 'hasRecentCompletions should be false on error');
        // Default color path (no health match)
        System.assertEquals('#706e6b', hColor, 'Health color should be default gray on error');
        System.assertEquals('#f4f6f9', hBgColor, 'Health bg color should be default gray on error');
    }

    @IsTest
    static void testVfPageMissingTokenParam() {
        // No token parameter set at all — covers blank token path through VF controller
        PageReference pageRef = Page.DeliveryStatusPage;
        Test.setCurrentPage(pageRef);

        DeliveryStatusPageController ctrl = new DeliveryStatusPageController();

        Test.startTest();
        Boolean hasErr = ctrl.hasError;
        String errMsg = ctrl.errorMessage;
        String pTitle = ctrl.pageTitle;
        Test.stopTest();

        System.assertEquals(true, hasErr, 'Should have error for missing token');
        System.assert(String.isNotBlank(errMsg), 'Error message should be set');
        System.assertEquals('Delivery Hub - Status', pTitle,
            'Page title should use fallback when no token');
    }

    @IsTest
    static void testVfPageDisabledStatusPage() {
        // Disable status page via settings, then exercise VF controller
        DeliveryHubSettings__c settings = DeliveryHubSettings__c.getOrgDefaults();
        settings.StatusPageEnabledBool__c = false;
        upsert settings;

        PageReference pageRef = Page.DeliveryStatusPage;
        pageRef.getParameters().put('token', 'Acme Corp');
        Test.setCurrentPage(pageRef);

        DeliveryStatusPageController ctrl = new DeliveryStatusPageController();

        Test.startTest();
        Boolean hasErr = ctrl.hasError;
        String errMsg = ctrl.errorMessage;
        String eName = ctrl.entityName;
        String rate = ctrl.completionRate;
        Test.stopTest();

        System.assertEquals(true, hasErr, 'Should have error when disabled');
        System.assertEquals('Status page is not enabled.', errMsg);
        System.assertEquals('', eName, 'Entity name should be empty when disabled');
        System.assertEquals('0%', rate, 'Completion rate should be 0% when disabled');
    }

    // ---------------------------------------------------------------
    // VF controller tests — entity with no work items (zero-count paths)
    // ---------------------------------------------------------------

    @IsTest
    static void testVfPageEmptyEntity() {
        // Exercise VF properties for an entity that has zero work items
        PageReference pageRef = Page.DeliveryStatusPage;
        pageRef.getParameters().put('token', 'Empty Org');
        Test.setCurrentPage(pageRef);

        DeliveryStatusPageController ctrl = new DeliveryStatusPageController();

        Test.startTest();
        Boolean hasErr = ctrl.hasError;
        String eName = ctrl.entityName;
        String health = ctrl.overallHealth;
        String updated = ctrl.lastUpdated;
        Integer active = ctrl.activeCount;
        Integer completed = ctrl.completedCount;
        String rate = ctrl.completionRate;
        Integer onTrack = ctrl.slaOnTrack;
        Integer atRisk = ctrl.slaAtRisk;
        Integer breached = ctrl.slaBreached;
        Integer phTotal = ctrl.phaseTotal;
        Boolean hasRecent = ctrl.hasRecentCompletions;
        List<DeliveryStatusPageController.CompletionItem> items = ctrl.completionItems;
        String hColor = ctrl.healthColor;
        String hBgColor = ctrl.healthBgColor;
        String pTitle = ctrl.pageTitle;
        Test.stopTest();

        System.assertEquals(false, hasErr, 'Should not have error for valid empty entity');
        System.assertEquals('Empty Org', eName, 'Entity name should match');
        System.assertEquals('Healthy', health, 'Health should be Healthy with no items');
        System.assertEquals('No activity', updated, 'Last updated should say No activity');
        System.assertEquals(0, active, 'Active should be 0');
        System.assertEquals(0, completed, 'Completed should be 0');
        System.assertEquals('0%', rate, 'Rate should be 0% when total is 0');
        System.assertEquals(0, onTrack, 'SLA on track should be 0');
        System.assertEquals(0, atRisk, 'SLA at risk should be 0');
        System.assertEquals(0, breached, 'SLA breached should be 0');
        System.assertEquals(0, phTotal, 'Phase total should be 0');
        System.assertEquals(false, hasRecent, 'No recent completions');
        System.assert(items.isEmpty(), 'Completion items should be empty');
        // Health = 'Healthy' -> green colors
        System.assertEquals('#04844b', hColor, 'Healthy color should be green');
        System.assertEquals('#e6f7ee', hBgColor, 'Healthy bg color should be light green');
        System.assert(pTitle.contains('Empty Org'), 'Page title should contain entity name');
    }

    // ---------------------------------------------------------------
    // VF controller tests — CompletionItem wrapper coverage
    // ---------------------------------------------------------------

    @IsTest
    static void testCompletionItemWrapper() {
        // Directly test the CompletionItem inner class
        DeliveryStatusPageController.CompletionItem item = new DeliveryStatusPageController.CompletionItem();
        item.title = 'Test Feature';
        item.completedDate = 'Feb 28, 2026';

        System.assertEquals('Test Feature', item.title, 'Title should be set');
        System.assertEquals('Feb 28, 2026', item.completedDate, 'Completed date should be set');
    }

    // ---------------------------------------------------------------
    // VF controller tests — StatusPageData wrapper coverage
    // ---------------------------------------------------------------

    @IsTest
    static void testStatusPageDataWrapper() {
        // Directly test the StatusPageData inner class
        DeliveryStatusPageController.StatusPageData data = new DeliveryStatusPageController.StatusPageData();
        data.entityName = 'Test Entity';
        data.overallHealth = 'Healthy';
        data.lastUpdated = 'Feb 28, 2026 10:00 AM';
        data.activeCount = 5;
        data.completedCount = 10;
        data.phaseDistribution = new Map<String, Integer>{ 'Planning' => 2, 'Development' => 3 };
        data.slaHealth = new Map<String, Integer>{ 'onTrack' => 3, 'atRisk' => 1, 'breached' => 1 };
        data.recentCompletions = new List<Map<String, String>>();
        data.completionItems = new List<DeliveryStatusPageController.CompletionItem>();

        System.assertEquals('Test Entity', data.entityName);
        System.assertEquals('Healthy', data.overallHealth);
        System.assertEquals(5, data.activeCount);
        System.assertEquals(10, data.completedCount);
        System.assertNotEquals(null, data.phaseDistribution);
        System.assertNotEquals(null, data.slaHealth);
    }

    // ---------------------------------------------------------------
    // VF controller tests — token with whitespace (trim path)
    // ---------------------------------------------------------------

    @IsTest
    static void testVfPageTokenWithWhitespace() {
        // Token with leading/trailing whitespace should be trimmed
        PageReference pageRef = Page.DeliveryStatusPage;
        pageRef.getParameters().put('token', '  Acme Corp  ');
        Test.setCurrentPage(pageRef);

        DeliveryStatusPageController ctrl = new DeliveryStatusPageController();

        Test.startTest();
        Boolean hasErr = ctrl.hasError;
        String eName = ctrl.entityName;
        Test.stopTest();

        System.assertEquals(false, hasErr, 'Should not have error for trimmed valid token');
        System.assertEquals('Acme Corp', eName, 'Entity name should match after trim');
    }
}

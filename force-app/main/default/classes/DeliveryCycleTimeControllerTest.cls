/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Test class for DeliveryCycleTimeController.
 *              Covers getCycleTimeData (3 cases) and getCurrentStageAges (3 cases).
 * @author Cloud Nimbus LLC
 */
@IsTest
private class DeliveryCycleTimeControllerTest {

    // ── Setup ─────────────────────────────────────────────────────────────────

    /**
     * @description Creates org-level settings and work items in various stages
     * for cycle time analytics testing.
     */
    @TestSetup
    static void setupTestData() {
        DeliveryHubSettings__c settings = new DeliveryHubSettings__c(
            SetupOwnerId = UserInfo.getOrganizationId()
        );
        insert settings;

        List<WorkItem__c> items = new List<WorkItem__c>();

        // Completed items (terminal stage "Done")
        items.add(new WorkItem__c(
            BriefDescriptionTxt__c = 'Completed item 1',
            StageNamePk__c = 'Done',
            PriorityPk__c = 'High',
            WorkflowTypeTxt__c = 'Software_Delivery'
        ));
        items.add(new WorkItem__c(
            BriefDescriptionTxt__c = 'Completed item 2',
            StageNamePk__c = 'Done',
            PriorityPk__c = 'Medium',
            WorkflowTypeTxt__c = 'Software_Delivery'
        ));

        // Active items in various stages
        items.add(new WorkItem__c(
            BriefDescriptionTxt__c = 'Active dev item',
            StageNamePk__c = 'In Development',
            PriorityPk__c = 'High',
            WorkflowTypeTxt__c = 'Software_Delivery',
            StageEnteredDateTime__c = Datetime.now().addDays(-3)
        ));
        items.add(new WorkItem__c(
            BriefDescriptionTxt__c = 'Active QA item',
            StageNamePk__c = 'QA In Progress',
            PriorityPk__c = 'Medium',
            WorkflowTypeTxt__c = 'Software_Delivery',
            StageEnteredDateTime__c = Datetime.now().addDays(-7)
        ));
        items.add(new WorkItem__c(
            BriefDescriptionTxt__c = 'Active backlog item no timestamp',
            StageNamePk__c = 'Backlog',
            PriorityPk__c = 'Low',
            WorkflowTypeTxt__c = 'Software_Delivery'
        ));

        insert items;
    }

    // ── getCycleTimeData Tests ────────────────────────────────────────────────

    /**
     * @description Happy path: completed items exist, returns weekly grouped data.
     */
    @IsTest
    static void testGetCycleTimeDataReturnsWeeklyData() {
        Test.startTest();
        List<Map<String, Object>> result = DeliveryCycleTimeController.getCycleTimeData('Software_Delivery');
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null.');
        System.assert(!result.isEmpty(), 'Should return at least one week of data.');

        Map<String, Object> firstWeek = result[0];
        System.assert(firstWeek.containsKey('weekLabel'), 'Each entry should have a weekLabel.');
        System.assert(firstWeek.containsKey('avgCycleDays'), 'Each entry should have avgCycleDays.');
        System.assert(firstWeek.containsKey('itemCount'), 'Each entry should have itemCount.');
    }

    /**
     * @description Blank workflow type defaults to Software_Delivery, returns data.
     */
    @IsTest
    static void testGetCycleTimeDataDefaultsWorkflowType() {
        Test.startTest();
        List<Map<String, Object>> result = DeliveryCycleTimeController.getCycleTimeData('');
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null with blank type.');
        System.assert(!result.isEmpty(), 'Should return data using default workflow type.');
    }

    /**
     * @description No completed items for a non-existent workflow type returns empty.
     */
    @IsTest
    static void testGetCycleTimeDataNoItemsReturnsEmpty() {
        Test.startTest();
        List<Map<String, Object>> result = DeliveryCycleTimeController.getCycleTimeData('NonExistent_Type');
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null.');
        System.assert(result.isEmpty(), 'Should return empty list for unknown workflow type.');
    }

    // ── getCurrentStageAges Tests ─────────────────────────────────────────────

    /**
     * @description Happy path: active items exist, returns stage-grouped data sorted by avgDays desc.
     */
    @IsTest
    static void testGetCurrentStageAgesReturnsStageData() {
        Test.startTest();
        List<Map<String, Object>> result = DeliveryCycleTimeController.getCurrentStageAges('Software_Delivery');
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null.');
        System.assert(!result.isEmpty(), 'Should return at least one stage.');

        Map<String, Object> firstStage = result[0];
        System.assert(firstStage.containsKey('stageName'), 'Each entry should have a stageName.');
        System.assert(firstStage.containsKey('avgDays'), 'Each entry should have avgDays.');
        System.assert(firstStage.containsKey('itemCount'), 'Each entry should have itemCount.');
    }

    /**
     * @description Results are sorted by avgDays descending (slowest stages first).
     */
    @IsTest
    static void testGetCurrentStageAgesSortedDescending() {
        Test.startTest();
        List<Map<String, Object>> result = DeliveryCycleTimeController.getCurrentStageAges('Software_Delivery');
        Test.stopTest();

        if (result.size() >= 2) {
            Decimal firstAvg = (Decimal) result[0].get('avgDays');
            Decimal secondAvg = (Decimal) result[1].get('avgDays');
            System.assert(firstAvg >= secondAvg, 'First stage should have >= avgDays than second (desc sort).');
        }
    }

    /**
     * @description No active items for a non-existent workflow type returns empty.
     */
    @IsTest
    static void testGetCurrentStageAgesNoItemsReturnsEmpty() {
        Test.startTest();
        List<Map<String, Object>> result = DeliveryCycleTimeController.getCurrentStageAges('NonExistent_Type');
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null.');
        System.assert(result.isEmpty(), 'Should return empty list for unknown workflow type.');
    }
}

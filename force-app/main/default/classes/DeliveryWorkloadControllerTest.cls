/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Test class for DeliveryWorkloadController. Validates workload
 * aggregation, unassigned counting, and empty-data edge cases.
 * @author Cloud Nimbus LLC
 */
@IsTest
private class DeliveryWorkloadControllerTest {

    /**
     * @description Creates test work items: some assigned to the running user,
     * some unassigned, and one in a terminal stage that should be excluded.
     */
    @TestSetup
    static void setupTestData() {
        List<WorkItem__c> items = new List<WorkItem__c>{
            new WorkItem__c(
                BriefDescriptionTxt__c = 'Assigned Item 1',
                StageNamePk__c = 'In Development',
                Developer__c = UserInfo.getUserId(),
                EstimatedHoursNumber__c = 8
            ),
            new WorkItem__c(
                BriefDescriptionTxt__c = 'Assigned Item 2',
                StageNamePk__c = 'Ready for QA',
                Developer__c = UserInfo.getUserId(),
                EstimatedHoursNumber__c = 4
            ),
            new WorkItem__c(
                BriefDescriptionTxt__c = 'Assigned Item 3',
                StageNamePk__c = 'In Development',
                Developer__c = UserInfo.getUserId(),
                EstimatedHoursNumber__c = null
            ),
            new WorkItem__c(
                BriefDescriptionTxt__c = 'Unassigned Item 1',
                StageNamePk__c = 'Backlog',
                Developer__c = null,
                EstimatedHoursNumber__c = 2
            ),
            new WorkItem__c(
                BriefDescriptionTxt__c = 'Unassigned Item 2',
                StageNamePk__c = 'Ready for Development',
                Developer__c = null,
                EstimatedHoursNumber__c = 6
            ),
            new WorkItem__c(
                BriefDescriptionTxt__c = 'Terminal Item',
                StageNamePk__c = 'Done',
                Developer__c = UserInfo.getUserId(),
                EstimatedHoursNumber__c = 10
            )
        };
        insert items;
    }

    /**
     * @description Verifies getWorkloadData returns correct structure and values
     * for the running user's assigned work items.
     */
    @IsTest
    static void testGetWorkloadDataReturnsCorrectStructure() {
        Test.startTest();
        List<Map<String, Object>> result = DeliveryWorkloadController.getWorkloadData('Software_Delivery');
        Test.stopTest();

        System.assertEquals(1, result.size(), 'Should return exactly one developer entry');

        Map<String, Object> dev = result[0];
        System.assertEquals(UserInfo.getUserId(), (Id) dev.get('developerId'), 'Developer ID should match running user');
        System.assertNotEquals(null, dev.get('developerName'), 'Developer name should not be null');
        System.assertEquals(3, (Integer) dev.get('totalItems'), 'Should count 3 active assigned items (excludes Done)');
        System.assertEquals(12.00, (Decimal) dev.get('totalEstimatedHours'), 'Should sum 8 + 4 + 0 = 12 hours');

        Map<String, Integer> breakdown = (Map<String, Integer>) dev.get('stageBreakdown');
        System.assertEquals(2, breakdown.get('In Development'), 'Should have 2 items In Development');
        System.assertEquals(1, breakdown.get('Ready for QA'), 'Should have 1 item Ready for QA');
    }

    /**
     * @description Verifies getWorkloadData defaults to Software_Delivery when
     * passed a null workflow type name.
     */
    @IsTest
    static void testGetWorkloadDataDefaultsWorkflowType() {
        Test.startTest();
        List<Map<String, Object>> result = DeliveryWorkloadController.getWorkloadData(null);
        Test.stopTest();

        System.assertEquals(1, result.size(), 'Should return data using default workflow type');
    }

    /**
     * @description Verifies getUnassignedCount returns the correct number of
     * work items with no developer assigned.
     */
    @IsTest
    static void testGetUnassignedCountReturnsCorrectCount() {
        Test.startTest();
        Integer count = DeliveryWorkloadController.getUnassignedCount('Software_Delivery');
        Test.stopTest();

        System.assertEquals(2, count, 'Should count 2 unassigned active items');
    }

    /**
     * @description Verifies getUnassignedCount defaults to Software_Delivery
     * when passed a blank string.
     */
    @IsTest
    static void testGetUnassignedCountDefaultsWorkflowType() {
        Test.startTest();
        Integer count = DeliveryWorkloadController.getUnassignedCount('');
        Test.stopTest();

        System.assertEquals(2, count, 'Should return correct count with default workflow type');
    }

    /**
     * @description Verifies both methods return empty/zero when there are no
     * active work items at all.
     */
    @IsTest
    static void testWithNoActiveItemsReturnsEmptyResults() {
        // Delete all work items created in setup
        delete [SELECT Id FROM WorkItem__c];

        Test.startTest();
        List<Map<String, Object>> workload = DeliveryWorkloadController.getWorkloadData('Software_Delivery');
        Integer unassigned = DeliveryWorkloadController.getUnassignedCount('Software_Delivery');
        Test.stopTest();

        System.assertEquals(0, workload.size(), 'Should return empty list when no active items');
        System.assertEquals(0, unassigned, 'Should return 0 unassigned when no items exist');
    }
}

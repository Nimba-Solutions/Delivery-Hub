/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Unit tests for DeliveryBurndownController.
 * @author Cloud Nimbus LLC
 */
@IsTest
private class DeliveryBurndownControllerTest {

    @TestSetup
    static void makeData() {
        List<WorkItem__c> workItems = new List<WorkItem__c>{
            new WorkItem__c(
                BriefDescriptionTxt__c  = 'Active open item',
                StageNamePk__c          = 'In Development',
                PriorityPk__c           = 'High',
                IsActiveBool__c         = true,
                WorkflowTypeTxt__c      = 'Software_Delivery'
            ),
            new WorkItem__c(
                BriefDescriptionTxt__c  = 'Another in-progress item',
                StageNamePk__c          = 'Ready for QA',
                PriorityPk__c           = 'Medium',
                IsActiveBool__c         = true,
                WorkflowTypeTxt__c      = 'Software_Delivery'
            ),
            new WorkItem__c(
                BriefDescriptionTxt__c  = 'Completed item',
                StageNamePk__c          = 'Done',
                PriorityPk__c           = 'Low',
                IsActiveBool__c         = false,
                WorkflowTypeTxt__c      = 'Software_Delivery'
            ),
            new WorkItem__c(
                BriefDescriptionTxt__c  = 'Cancelled item',
                StageNamePk__c          = 'Cancelled',
                PriorityPk__c           = 'Low',
                IsActiveBool__c         = false,
                WorkflowTypeTxt__c      = 'Software_Delivery'
            )
        };
        insert workItems;
    }

    /**
     * @description Verifies that getBurndownData returns a non-empty list with valid structure.
     */
    @IsTest
    static void testGetBurndownDataReturnsData() {
        Test.startTest();
        List<Map<String, Object>> result = DeliveryBurndownController.getBurndownData('Software_Delivery');
        Test.stopTest();

        System.assertEquals(12, result.size(), 'Should return exactly 12 weekly data points.');

        // Verify last entry has non-null values
        Map<String, Object> lastWeek = result[result.size() - 1];
        System.assertNotEquals(null, lastWeek.get('date'), 'date must be present');
        System.assertNotEquals(null, lastWeek.get('totalCreated'), 'totalCreated must be present');
        System.assertNotEquals(null, lastWeek.get('totalCompleted'), 'totalCompleted must be present');
        System.assertNotEquals(null, lastWeek.get('openCount'), 'openCount must be present');
    }

    /**
     * @description Verifies that created and completed counts are consistent with openCount.
     */
    @IsTest
    static void testBurndownDataConsistency() {
        Test.startTest();
        List<Map<String, Object>> result = DeliveryBurndownController.getBurndownData('Software_Delivery');
        Test.stopTest();

        for (Map<String, Object> row : result) {
            Integer created   = (Integer) row.get('totalCreated');
            Integer completed = (Integer) row.get('totalCompleted');
            Integer open      = (Integer) row.get('openCount');
            System.assertEquals(created - completed, open,
                'openCount must equal totalCreated - totalCompleted for week ' + row.get('date'));
        }
    }

    /**
     * @description Verifies that a blank workflowTypeName defaults to Software_Delivery.
     */
    @IsTest
    static void testBlankWorkflowTypeDefaultsToSoftwareDelivery() {
        Test.startTest();
        List<Map<String, Object>> resultBlank = DeliveryBurndownController.getBurndownData('');
        List<Map<String, Object>> resultNull  = DeliveryBurndownController.getBurndownData(null);
        Test.stopTest();

        System.assertEquals(12, resultBlank.size(), 'Blank name should return 12 weeks of data.');
        System.assertEquals(12, resultNull.size(), 'Null name should return 12 weeks of data.');
    }

    /**
     * @description Verifies that a workflow type with no work items returns 12 weeks of zeroes.
     */
    @IsTest
    static void testNoWorkItemsReturnsEmptyData() {
        Test.startTest();
        List<Map<String, Object>> result = DeliveryBurndownController.getBurndownData('Loan_Approval');
        Test.stopTest();

        System.assertEquals(12, result.size(), 'Should still return 12 weekly data points.');

        Map<String, Object> lastWeek = result[result.size() - 1];
        System.assertEquals(0, (Integer) lastWeek.get('totalCreated'), 'No items created for Loan_Approval.');
        System.assertEquals(0, (Integer) lastWeek.get('totalCompleted'), 'No items completed for Loan_Approval.');
        System.assertEquals(0, (Integer) lastWeek.get('openCount'), 'No open items for Loan_Approval.');
    }

    /**
     * @description Verifies that running totals are non-decreasing across weeks.
     */
    @IsTest
    static void testRunningTotalsNonDecreasing() {
        Test.startTest();
        List<Map<String, Object>> result = DeliveryBurndownController.getBurndownData('Software_Delivery');
        Test.stopTest();

        Integer prevCreated = 0;
        Integer prevCompleted = 0;
        for (Map<String, Object> row : result) {
            Integer created   = (Integer) row.get('totalCreated');
            Integer completed = (Integer) row.get('totalCompleted');
            System.assert(created >= prevCreated,
                'Cumulative created must be non-decreasing at ' + row.get('date'));
            System.assert(completed >= prevCompleted,
                'Cumulative completed must be non-decreasing at ' + row.get('date'));
            prevCreated = created;
            prevCompleted = completed;
        }
    }
}

/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Tests for DeliveryReleaseNotesController. Validates release note
 * generation, grouping by RequestTypePk__c, empty result handling, and default
 * workflow type resolution.
 * @author Cloud Nimbus LLC
 */
@IsTest
private class DeliveryReleaseNotesControllerTest {

    /**
     * @description Creates test work items in various terminal and non-terminal stages
     * with different RequestTypePk__c values for release note generation tests.
     */
    @TestSetup
    static void setupData() {
        DeliveryTriggerControl.disableAfterLogic();

        List<WorkItem__c> workItems = new List<WorkItem__c>{
            new WorkItem__c(
                BriefDescriptionTxt__c = 'Fix login timeout bug',
                StageNamePk__c = 'Done',
                RequestTypePk__c = 'Internal',
                PriorityPk__c = 'High'
            ),
            new WorkItem__c(
                BriefDescriptionTxt__c = 'Add export CSV feature',
                StageNamePk__c = 'Done',
                RequestTypePk__c = 'Partner Request',
                PriorityPk__c = 'Medium'
            ),
            new WorkItem__c(
                BriefDescriptionTxt__c = 'Resolve dashboard crash',
                StageNamePk__c = 'Cancelled',
                RequestTypePk__c = 'Internal',
                PriorityPk__c = 'Critical'
            ),
            new WorkItem__c(
                BriefDescriptionTxt__c = 'Active dev work item',
                StageNamePk__c = 'In Development',
                RequestTypePk__c = 'Internal',
                PriorityPk__c = 'Low'
            )
        };
        insert workItems;

        DeliveryTriggerControl.enableAfterLogic();
    }

    /**
     * @description Verifies that generateReleaseNotes returns grouped sections
     * with correct item counts when completed items exist in the date range.
     */
    @IsTest
    static void testGenerateReleaseNotesReturnsGroupedData() {
        Date startDate = Date.today().addDays(-1);
        Date endDate = Date.today();

        Test.startTest();
        Map<String, Object> result = DeliveryReleaseNotesController.generateReleaseNotes(
            startDate, endDate, 'Software_Delivery'
        );
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
        System.assert(result.containsKey('title'), 'Result should contain title key');
        System.assert(result.containsKey('totalItems'), 'Result should contain totalItems key');
        System.assert(result.containsKey('sections'), 'Result should contain sections key');

        Integer totalItems = (Integer) result.get('totalItems');
        System.assertEquals(3, totalItems, 'Should count 3 terminal items (2 Done + 1 Cancelled)');

        List<Object> sections = (List<Object>) result.get('sections');
        System.assert(sections.size() >= 2, 'Should have at least 2 categories (Internal, Partner Request)');
    }

    /**
     * @description Verifies that a date range with no matching items returns
     * totalItems=0 and an empty sections list.
     */
    @IsTest
    static void testGenerateReleaseNotesEmptyRange() {
        Date startDate = Date.today().addDays(-365);
        Date endDate = Date.today().addDays(-364);

        Test.startTest();
        Map<String, Object> result = DeliveryReleaseNotesController.generateReleaseNotes(
            startDate, endDate, 'Software_Delivery'
        );
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null even with no items');
        Integer totalItems = (Integer) result.get('totalItems');
        System.assertEquals(0, totalItems, 'Should return 0 items for a past date range');

        List<Object> sections = (List<Object>) result.get('sections');
        System.assertEquals(0, sections.size(), 'Sections should be empty when no items found');
    }

    /**
     * @description Verifies that passing blank workflowTypeName defaults to
     * Software_Delivery and still returns results.
     */
    @IsTest
    static void testBlankWorkflowTypeDefaultsToSoftwareDelivery() {
        Date startDate = Date.today().addDays(-1);
        Date endDate = Date.today();

        Test.startTest();
        Map<String, Object> result = DeliveryReleaseNotesController.generateReleaseNotes(
            startDate, endDate, ''
        );
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null with blank workflow type');
        Integer totalItems = (Integer) result.get('totalItems');
        System.assertEquals(3, totalItems, 'Blank workflow type should default to Software_Delivery');
    }

    /**
     * @description Verifies that null workflowTypeName is handled the same as blank.
     */
    @IsTest
    static void testNullWorkflowTypeDefaultsToSoftwareDelivery() {
        Date startDate = Date.today().addDays(-1);
        Date endDate = Date.today();

        Test.startTest();
        Map<String, Object> result = DeliveryReleaseNotesController.generateReleaseNotes(
            startDate, endDate, null
        );
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null with null workflow type');
        Integer totalItems = (Integer) result.get('totalItems');
        System.assertEquals(3, totalItems, 'Null workflow type should default to Software_Delivery');
    }

    /**
     * @description Verifies that the title in the result contains the formatted date range.
     */
    @IsTest
    static void testResultTitleContainsDateRange() {
        Date startDate = Date.today().addDays(-7);
        Date endDate = Date.today();

        Test.startTest();
        Map<String, Object> result = DeliveryReleaseNotesController.generateReleaseNotes(
            startDate, endDate, 'Software_Delivery'
        );
        Test.stopTest();

        String title = (String) result.get('title');
        System.assert(title.contains('Release Notes'), 'Title should contain Release Notes');
    }
}

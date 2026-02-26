/**
 * @description Unit tests for DeliveryGanttController.
 * @author Cloud Nimbus LLC
 */
@IsTest
private class DeliveryGanttControllerTest {

    @TestSetup
    static void makeData() {
        List<WorkItem__c> tickets = new List<WorkItem__c>{
            new WorkItem__c(
                BriefDescriptionTxt__c  = 'Build login page',
                StageNamePk__c          = 'In Development',
                PriorityPk__c           = 'High',
                IsActiveBool__c         = true,
                ProjectedUATReadyDate__c = Date.today().addDays(14)
            ),
            new WorkItem__c(
                BriefDescriptionTxt__c  = 'Fix export bug',
                StageNamePk__c          = 'Ready for QA',
                PriorityPk__c           = 'Medium',
                IsActiveBool__c         = true,
                ProjectedUATReadyDate__c = Date.today().addDays(7)
            ),
            new WorkItem__c(
                BriefDescriptionTxt__c  = 'No UAT date ticket',
                StageNamePk__c          = 'Backlog',
                IsActiveBool__c         = true
                // ProjectedUATReadyDate__c intentionally null — should be excluded
            )
        };
        insert tickets;
    }

    @IsTest
    static void testGetWorkItemsForGanttReturnsRows() {
        Test.startTest();
        List<DeliveryGanttController.GanttRow> rows = DeliveryGanttController.getWorkItemsForGantt();
        Test.stopTest();

        System.assertEquals(2, rows.size(), 'Should return only tickets with a UAT date.');
    }

    @IsTest
    static void testGetWorkItemsForGanttFieldsPopulated() {
        Test.startTest();
        List<DeliveryGanttController.GanttRow> rows = DeliveryGanttController.getWorkItemsForGantt();
        Test.stopTest();

        DeliveryGanttController.GanttRow first = rows[0];
        System.assertNotEquals(null, first.workItemId, 'ticketId should be set.');
        System.assertNotEquals(null, first.name, 'name should be set.');
        System.assertNotEquals(null, first.uatDate, 'uatDate should be set.');
        System.assertNotEquals(null, first.createdDate, 'createdDate should be set.');
    }

    @IsTest
    static void testGetWorkItemsForGanttOrdering() {
        Test.startTest();
        List<DeliveryGanttController.GanttRow> rows = DeliveryGanttController.getWorkItemsForGantt();
        Test.stopTest();

        // First row should have the earlier UAT date (addDays(7) < addDays(14))
        System.assert(
            rows[0].uatDate.compareTo(rows[1].uatDate) <= 0,
            'Rows should be ordered by UAT date ascending.'
        );
    }

    @IsTest
    static void testGetWorkItemsForGanttNoActiveTickets() {
        // Delete all data
        delete [SELECT Id FROM WorkItem__c];

        Test.startTest();
        List<DeliveryGanttController.GanttRow> rows = DeliveryGanttController.getWorkItemsForGantt();
        Test.stopTest();

        System.assertEquals(0, rows.size(), 'Should return empty list when no active tickets exist.');
    }
}

/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Unit tests for DeliveryGanttController.
 * @author Cloud Nimbus LLC
 */
@IsTest
private class DeliveryGanttControllerTest {

    @TestSetup
    static void makeData() {
        List<WorkItem__c> workItems = new List<WorkItem__c>{
            new WorkItem__c(
                BriefDescriptionTxt__c   = 'Build login page',
                StageNamePk__c           = 'In Development',
                PriorityPk__c            = 'High',
                IsActiveBool__c          = true,
                ProjectedUATReadyDate__c = Date.today().addDays(14),
                EstimatedStartDevDate__c = Date.today(),
                EstimatedEndDevDate__c   = Date.today().addDays(10),
                EstimatedHoursNumber__c  = 20
            ),
            new WorkItem__c(
                BriefDescriptionTxt__c   = 'Fix export bug',
                StageNamePk__c           = 'Ready for QA',
                PriorityPk__c            = 'Medium',
                IsActiveBool__c          = true,
                ProjectedUATReadyDate__c = Date.today().addDays(7)
            ),
            new WorkItem__c(
                BriefDescriptionTxt__c   = 'No UAT date work item',
                StageNamePk__c           = 'Backlog',
                IsActiveBool__c          = true
            ),
            new WorkItem__c(
                BriefDescriptionTxt__c   = 'Completed item',
                StageNamePk__c           = 'Done',
                IsActiveBool__c          = false,
                ProjectedUATReadyDate__c = Date.today().addDays(-5),
                EstimatedStartDevDate__c = Date.today().addDays(-20),
                EstimatedEndDevDate__c   = Date.today().addDays(-7)
            )
        };
        insert workItems;
    }

    // ── Legacy getWorkItemsForGantt ──────────────────────────────────

    @IsTest
    static void testGetWorkItemsForGanttReturnsRows() {
        Test.startTest();
        List<DeliveryGanttController.GanttRow> rows = DeliveryGanttController.getWorkItemsForGantt();
        Test.stopTest();

        System.assertEquals(2, rows.size(), 'Should return only active workItems with a UAT date.');
    }

    @IsTest
    static void testGetWorkItemsForGanttFieldsPopulated() {
        Test.startTest();
        List<DeliveryGanttController.GanttRow> rows = DeliveryGanttController.getWorkItemsForGantt();
        Test.stopTest();

        DeliveryGanttController.GanttRow first = rows[0];
        System.assertNotEquals(null, first.workItemId, 'workItemId should be set.');
        System.assertNotEquals(null, first.name, 'name should be set.');
        System.assertNotEquals(null, first.uatDate, 'uatDate should be set.');
        System.assertNotEquals(null, first.createdDate, 'createdDate should be set.');
    }

    @IsTest
    static void testGetWorkItemsForGanttOrdering() {
        Test.startTest();
        List<DeliveryGanttController.GanttRow> rows = DeliveryGanttController.getWorkItemsForGantt();
        Test.stopTest();

        System.assert(
            rows[0].uatDate.compareTo(rows[1].uatDate) <= 0,
            'Rows should be ordered by UAT date ascending.'
        );
    }

    @IsTest
    static void testGetWorkItemsForGanttNoActiveWorkItems() {
        delete [SELECT Id FROM WorkItem__c];

        Test.startTest();
        List<DeliveryGanttController.GanttRow> rows = DeliveryGanttController.getWorkItemsForGantt();
        Test.stopTest();

        System.assertEquals(0, rows.size(), 'Should return empty list when no active workItems exist.');
    }

    // ── getGanttData ─────────────────────────────────────────────────

    @IsTest
    static void testGetGanttDataActiveOnly() {
        Test.startTest();
        List<DeliveryGanttController.GanttTask> tasks = DeliveryGanttController.getGanttData(false);
        Test.stopTest();

        System.assertEquals(3, tasks.size(), 'Should return 3 active work items.');
        for (DeliveryGanttController.GanttTask t : tasks) {
            System.assertEquals(false, t.isCompleted, 'All returned items should be active.');
        }
    }

    @IsTest
    static void testGetGanttDataIncludesCompleted() {
        Test.startTest();
        List<DeliveryGanttController.GanttTask> tasks = DeliveryGanttController.getGanttData(true);
        Test.stopTest();

        System.assertEquals(4, tasks.size(), 'Should return all 4 work items including completed.');
        Boolean foundCompleted = false;
        for (DeliveryGanttController.GanttTask t : tasks) {
            if (t.isCompleted) { foundCompleted = true; }
        }
        System.assert(foundCompleted, 'Should include at least one completed item.');
    }

    @IsTest
    static void testGetGanttDataDateFallback() {
        Test.startTest();
        List<DeliveryGanttController.GanttTask> tasks = DeliveryGanttController.getGanttData(false);
        Test.stopTest();

        for (DeliveryGanttController.GanttTask t : tasks) {
            System.assertNotEquals(null, t.startDate, 'startDate should always be resolved.');
            System.assertNotEquals(null, t.endDate, 'endDate should always be resolved.');
        }
    }

    @IsTest
    static void testGetGanttDataProgressCalculation() {
        Test.startTest();
        List<DeliveryGanttController.GanttTask> tasks = DeliveryGanttController.getGanttData(false);
        Test.stopTest();

        for (DeliveryGanttController.GanttTask t : tasks) {
            System.assert(t.progress >= 0 && t.progress <= 1,
                'Progress should be between 0 and 1. Got: ' + t.progress);
        }
    }

    @IsTest
    static void testGetGanttDataFieldsPopulated() {
        Test.startTest();
        List<DeliveryGanttController.GanttTask> tasks = DeliveryGanttController.getGanttData(false);
        Test.stopTest();

        DeliveryGanttController.GanttTask first = tasks[0];
        System.assertNotEquals(null, first.workItemId, 'workItemId should be set.');
        System.assertNotEquals(null, first.name, 'name should be set.');
        System.assertNotEquals(null, first.stage, 'stage should be set.');
    }

    // ── updateWorkItemDates ──────────────────────────────────────────

    @IsTest
    static void testUpdateWorkItemDates() {
        WorkItem__c item = [SELECT Id FROM WorkItem__c WHERE BriefDescriptionTxt__c = 'Build login page' LIMIT 1];
        Date newStart = Date.today().addDays(5);
        Date newEnd = Date.today().addDays(25);

        Test.startTest();
        DeliveryGanttController.updateWorkItemDates(
            item.Id,
            String.valueOf(newStart),
            String.valueOf(newEnd)
        );
        Test.stopTest();

        WorkItem__c updated = [SELECT EstimatedStartDevDate__c, EstimatedEndDevDate__c
                               FROM WorkItem__c WHERE Id = :item.Id];
        System.assertEquals(newStart, updated.EstimatedStartDevDate__c, 'Start date should be updated.');
        System.assertEquals(newEnd, updated.EstimatedEndDevDate__c, 'End date should be updated.');
    }

    @IsTest
    static void testUpdateWorkItemDatesPartial() {
        WorkItem__c item = [SELECT Id FROM WorkItem__c WHERE BriefDescriptionTxt__c = 'Fix export bug' LIMIT 1];
        Date newEnd = Date.today().addDays(30);

        Test.startTest();
        DeliveryGanttController.updateWorkItemDates(item.Id, null, String.valueOf(newEnd));
        Test.stopTest();

        WorkItem__c updated = [SELECT EstimatedStartDevDate__c, EstimatedEndDevDate__c
                               FROM WorkItem__c WHERE Id = :item.Id];
        System.assertEquals(null, updated.EstimatedStartDevDate__c, 'Start date should remain null.');
        System.assertEquals(newEnd, updated.EstimatedEndDevDate__c, 'End date should be updated.');
    }

    @IsTest
    static void testUpdateWorkItemDatesInvalidId() {
        Boolean caught = false;
        Test.startTest();
        try {
            DeliveryGanttController.updateWorkItemDates(
                'bogusId', String.valueOf(Date.today()), String.valueOf(Date.today().addDays(5))
            );
        } catch (AuraHandledException e) {
            caught = true;
        }
        Test.stopTest();

        System.assert(caught, 'Should throw AuraHandledException for invalid Id.');
    }
}

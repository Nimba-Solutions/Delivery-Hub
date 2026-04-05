/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Unit tests for DeliveryGanttController.
 * @author Cloud Nimbus LLC
 */
@IsTest
private class DeliveryGanttControllerTest {

    private static User testUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];

    @TestSetup
    static void makeData() {
        List<WorkItem__c> workItems = new List<WorkItem__c>{
            new WorkItem__c(
                BriefDescriptionTxt__c   = 'Build login page',
                StageNamePk__c           = 'In Development',
                PriorityPk__c            = 'High',
                ActivatedDateTime__c     = Datetime.now(),
                ProjectedUATReadyDate__c = Date.today().addDays(14),
                EstimatedStartDevDate__c = Date.today(),
                EstimatedEndDevDate__c   = Date.today().addDays(10),
                EstimatedHoursNumber__c  = 20
            ),
            new WorkItem__c(
                BriefDescriptionTxt__c   = 'Fix export bug',
                StageNamePk__c           = 'Ready for QA',
                PriorityPk__c            = 'Medium',
                ActivatedDateTime__c     = Datetime.now(),
                ProjectedUATReadyDate__c = Date.today().addDays(7)
            ),
            new WorkItem__c(
                BriefDescriptionTxt__c   = 'No UAT date work item',
                StageNamePk__c           = 'Backlog',
                ActivatedDateTime__c     = Datetime.now()
            ),
            new WorkItem__c(
                BriefDescriptionTxt__c   = 'Completed item',
                StageNamePk__c           = 'Done',
                ProjectedUATReadyDate__c = Date.today().addDays(-5),
                EstimatedStartDevDate__c = Date.today().addDays(-20),
                EstimatedEndDevDate__c   = Date.today().addDays(-7)
            )
        };
        insert workItems;

        // Deactivate the completed item (trigger auto-sets ActivatedDateTime on insert)
        WorkItem__c completed = [SELECT Id FROM WorkItem__c WHERE BriefDescriptionTxt__c = 'Completed item' LIMIT 1];
        completed.ActivatedDateTime__c = null;
        update completed;
    }

    // ── Legacy getWorkItemsForGantt ──────────────────────────────────

    @IsTest
    static void testGetWorkItemsForGanttReturnsRows() {
        System.runAs(testUser) {
            Test.startTest();
            List<DeliveryGanttController.GanttRow> rows = DeliveryGanttController.getWorkItemsForGantt();
            Test.stopTest();

            System.assertEquals(2, rows.size(), 'Should return only active workItems with a UAT date.');
        }
    }

    @IsTest
    static void testGetWorkItemsForGanttFieldsPopulated() {
        System.runAs(testUser) {
            Test.startTest();
            List<DeliveryGanttController.GanttRow> rows = DeliveryGanttController.getWorkItemsForGantt();
            Test.stopTest();

            DeliveryGanttController.GanttRow first = rows[0];
            System.assertNotEquals(null, first.workItemId, 'workItemId should be set.');
            System.assertNotEquals(null, first.name, 'name should be set.');
            System.assertNotEquals(null, first.uatDate, 'uatDate should be set.');
            System.assertNotEquals(null, first.createdDate, 'createdDate should be set.');
        }
    }

    @IsTest
    static void testGetWorkItemsForGanttOrdering() {
        System.runAs(testUser) {
            Test.startTest();
            List<DeliveryGanttController.GanttRow> rows = DeliveryGanttController.getWorkItemsForGantt();
            Test.stopTest();

            System.assert(
                rows[0].uatDate.compareTo(rows[1].uatDate) <= 0,
                'Rows should be ordered by UAT date ascending.'
            );
        }
    }

    @IsTest
    static void testGetWorkItemsForGanttNoActiveWorkItems() {
        System.runAs(testUser) {
            delete [SELECT Id FROM WorkItem__c];

            Test.startTest();
            List<DeliveryGanttController.GanttRow> rows = DeliveryGanttController.getWorkItemsForGantt();
            Test.stopTest();

            System.assertEquals(0, rows.size(), 'Should return empty list when no active workItems exist.');
        }
    }

    // ── getGanttData ─────────────────────────────────────────────────

    @IsTest
    static void testGetGanttDataActiveOnly() {
        System.runAs(testUser) {
            Test.startTest();
            List<DeliveryGanttController.GanttTask> tasks = DeliveryGanttController.getGanttData(false);
            Test.stopTest();

            System.assertEquals(3, tasks.size(), 'Should return 3 active work items.');
            for (DeliveryGanttController.GanttTask t : tasks) {
                System.assertEquals(false, t.isCompleted, 'All returned items should be active.');
            }
        }
    }

    @IsTest
    static void testGetGanttDataIncludesCompleted() {
        System.runAs(testUser) {
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
    }

    @IsTest
    static void testGetGanttDataDateFallback() {
        System.runAs(testUser) {
            Test.startTest();
            List<DeliveryGanttController.GanttTask> tasks = DeliveryGanttController.getGanttData(false);
            Test.stopTest();

            for (DeliveryGanttController.GanttTask t : tasks) {
                System.assertNotEquals(null, t.startDate, 'startDate should always be resolved.');
                System.assertNotEquals(null, t.endDate, 'endDate should always be resolved.');
            }
        }
    }

    @IsTest
    static void testGetGanttDataProgressCalculation() {
        System.runAs(testUser) {
            Test.startTest();
            List<DeliveryGanttController.GanttTask> tasks = DeliveryGanttController.getGanttData(false);
            Test.stopTest();

            for (DeliveryGanttController.GanttTask t : tasks) {
                System.assert(t.progress >= 0 && t.progress <= 1,
                    'Progress should be between 0 and 1. Got: ' + t.progress);
            }
        }
    }

    @IsTest
    static void testGetGanttDataFieldsPopulated() {
        System.runAs(testUser) {
            Test.startTest();
            List<DeliveryGanttController.GanttTask> tasks = DeliveryGanttController.getGanttData(false);
            Test.stopTest();

            DeliveryGanttController.GanttTask first = tasks[0];
            System.assertNotEquals(null, first.workItemId, 'workItemId should be set.');
            System.assertNotEquals(null, first.name, 'name should be set.');
            System.assertNotEquals(null, first.stage, 'stage should be set.');
        }
    }

    // ── updateWorkItemDates ──────────────────────────────────────────

    @IsTest
    static void testUpdateWorkItemDates() {
        System.runAs(testUser) {
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
    }

    @IsTest
    static void testUpdateWorkItemDatesPartial() {
        System.runAs(testUser) {
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
    }

    @IsTest
    static void testUpdateWorkItemDatesInvalidId() {
        System.runAs(testUser) {
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
}

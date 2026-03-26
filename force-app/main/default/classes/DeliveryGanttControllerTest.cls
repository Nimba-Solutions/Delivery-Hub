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
                BriefDescriptionTxt__c  = 'No UAT date work item',
                StageNamePk__c          = 'Backlog',
                IsActiveBool__c         = true
                // ProjectedUATReadyDate__c intentionally null — should be excluded
            )
        };
        insert workItems;
    }

    @IsTest
    static void testGetWorkItemsForGanttReturnsRows() {
        Test.startTest();
        List<DeliveryGanttController.GanttRow> rows = DeliveryGanttController.getWorkItemsForGantt();
        Test.stopTest();

        System.assertEquals(2, rows.size(), 'Should return only workItems with a UAT date.');
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

        // First row should have the earlier UAT date (addDays(7) < addDays(14))
        System.assert(
            rows[0].uatDate.compareTo(rows[1].uatDate) <= 0,
            'Rows should be ordered by UAT date ascending.'
        );
    }

    @IsTest
    static void testGetWorkItemsForGanttNoActiveWorkItems() {
        // Delete all data
        delete [SELECT Id FROM WorkItem__c];

        Test.startTest();
        List<DeliveryGanttController.GanttRow> rows = DeliveryGanttController.getWorkItemsForGantt();
        Test.stopTest();

        System.assertEquals(0, rows.size(), 'Should return empty list when no active workItems exist.');
    }

    @IsTest
    static void testGetGanttDependenciesReturnsResults() {
        List<WorkItem__c> items = [SELECT Id FROM WorkItem__c WHERE IsActiveBool__c = true ORDER BY CreatedDate ASC LIMIT 2];

        WorkItemDependency__c dep = new WorkItemDependency__c(
            BlockedWorkItemId__c  = items[0].Id,
            BlockingWorkItemId__c = items[1].Id,
            TypePk__c             = 'Blocks'
        );
        insert dep;

        Test.startTest();
        List<DeliveryGanttController.GanttDependency> deps = DeliveryGanttController.getGanttDependencies();
        Test.stopTest();

        System.assertEquals(1, deps.size(), 'Should return 1 dependency.');
        System.assertEquals(items[1].Id, deps[0].source, 'Source should be the blocking work item.');
        System.assertEquals(items[0].Id, deps[0].target, 'Target should be the blocked work item.');
        System.assertEquals('Blocks', deps[0].dependencyType, 'Dependency type should match.');
    }

    @IsTest
    static void testGetGanttDependenciesEmpty() {
        delete [SELECT Id FROM WorkItemDependency__c];

        Test.startTest();
        List<DeliveryGanttController.GanttDependency> deps = DeliveryGanttController.getGanttDependencies();
        Test.stopTest();

        System.assertEquals(0, deps.size(), 'Should return empty list when no dependencies exist.');
    }

    @IsTest
    static void testUpdateWorkItemSortOrder() {
        WorkItem__c item = [SELECT Id, SortOrderNumber__c FROM WorkItem__c WHERE IsActiveBool__c = true LIMIT 1];

        Test.startTest();
        DeliveryGanttController.updateWorkItemSortOrder(item.Id, 42);
        Test.stopTest();

        WorkItem__c updated = [SELECT SortOrderNumber__c FROM WorkItem__c WHERE Id = :item.Id];
        System.assertEquals(42, updated.SortOrderNumber__c, 'Sort order should be updated to 42.');
    }

    @IsTest
    static void testUpdateWorkItemDates() {
        WorkItem__c item = [SELECT Id FROM WorkItem__c WHERE IsActiveBool__c = true LIMIT 1];

        Test.startTest();
        DeliveryGanttController.updateWorkItemDates(item.Id, '2026-04-01', '2026-04-15');
        Test.stopTest();

        WorkItem__c updated = [SELECT EstimatedStartDevDate__c, EstimatedEndDevDate__c FROM WorkItem__c WHERE Id = :item.Id];
        System.assertEquals(Date.valueOf('2026-04-01'), updated.EstimatedStartDevDate__c, 'Start date should be updated.');
        System.assertEquals(Date.valueOf('2026-04-15'), updated.EstimatedEndDevDate__c, 'End date should be updated.');
    }

    @IsTest
    static void testGanttRowNewFieldsPopulated() {
        // Update a work item with start/end dates to verify new DTO fields
        WorkItem__c item = [SELECT Id FROM WorkItem__c WHERE IsActiveBool__c = true AND ProjectedUATReadyDate__c != null LIMIT 1];
        item.EstimatedStartDevDate__c = Date.today();
        item.EstimatedEndDevDate__c = Date.today().addDays(10);
        update item;

        Test.startTest();
        List<DeliveryGanttController.GanttRow> rows = DeliveryGanttController.getWorkItemsForGantt();
        Test.stopTest();

        Boolean foundWithDates = false;
        for (DeliveryGanttController.GanttRow row : rows) {
            if (row.workItemId == item.Id) {
                System.assertNotEquals(null, row.startDate, 'startDate should be set.');
                System.assertNotEquals(null, row.endDate, 'endDate should be set.');
                foundWithDates = true;
            }
        }
        System.assert(foundWithDates, 'Should find the work item with dates set.');
    }
}

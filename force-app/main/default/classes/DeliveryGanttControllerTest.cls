/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Unit tests for DeliveryGanttController — covers both the legacy
 *              getWorkItemsForGantt method and the DHTMLX-oriented getGanttData method.
 * @author Cloud Nimbus LLC
 */
@IsTest
private class DeliveryGanttControllerTest {

    @TestSetup
    static void makeData() {
        NetworkEntity__c entity = new NetworkEntity__c(
            Name = 'Acme Corp'
        );
        insert entity;

        List<WorkItem__c> workItems = new List<WorkItem__c>{
            new WorkItem__c(
                BriefDescriptionTxt__c     = 'Build login page',
                StageNamePk__c             = 'In Development',
                PriorityPk__c              = 'High',
                IsActiveBool__c            = true,
                ProjectedUATReadyDate__c   = Date.today().addDays(14),
                EstimatedStartDevDate__c   = Date.today(),
                EstimatedEndDevDate__c     = Date.today().addDays(14),
                EstimatedHoursNumber__c    = 40,
                TotalLoggedHoursNumber__c  = 20,
                ClientNetworkEntityId__c   = entity.Id
            ),
            new WorkItem__c(
                BriefDescriptionTxt__c     = 'Fix export bug',
                StageNamePk__c             = 'Ready for QA',
                PriorityPk__c              = 'Medium',
                IsActiveBool__c            = true,
                ProjectedUATReadyDate__c   = Date.today().addDays(7),
                EstimatedHoursNumber__c    = 8,
                TotalLoggedHoursNumber__c  = 8,
                ClientNetworkEntityId__c   = entity.Id
            ),
            new WorkItem__c(
                BriefDescriptionTxt__c     = 'No UAT date work item',
                StageNamePk__c             = 'Backlog',
                IsActiveBool__c            = true
                // No dates, no entity — should only appear in getGanttData
            ),
            new WorkItem__c(
                BriefDescriptionTxt__c     = 'Completed item',
                StageNamePk__c             = 'Done',
                IsActiveBool__c            = false,
                ProjectedUATReadyDate__c   = Date.today().addDays(-7),
                EstimatedStartDevDate__c   = Date.today().addDays(-21),
                EstimatedEndDevDate__c     = Date.today().addDays(-7),
                EstimatedHoursNumber__c    = 16,
                TotalLoggedHoursNumber__c  = 18,
                ClientNetworkEntityId__c   = entity.Id
            )
        };
        insert workItems;
    }

    // ── Legacy getWorkItemsForGantt tests ────────────────────────────────────

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

    // ── getGanttData tests ───────────────────────────────────────────────────

    @IsTest
    static void testGetGanttDataActiveOnly() {
        Test.startTest();
        List<DeliveryGanttController.DhtmlxGanttTask> tasks =
            DeliveryGanttController.getGanttData(false);
        Test.stopTest();

        // 3 active items (login, export bug, backlog)
        System.assertEquals(3, tasks.size(),
            'Should return only active (non-template) items when showCompleted=false.');
    }

    @IsTest
    static void testGetGanttDataIncludesCompleted() {
        Test.startTest();
        List<DeliveryGanttController.DhtmlxGanttTask> tasks =
            DeliveryGanttController.getGanttData(true);
        Test.stopTest();

        // All 4 items
        System.assertEquals(4, tasks.size(),
            'Should return all items including inactive when showCompleted=true.');
    }

    @IsTest
    static void testGetGanttDataFieldsPopulated() {
        Test.startTest();
        List<DeliveryGanttController.DhtmlxGanttTask> tasks =
            DeliveryGanttController.getGanttData(false);
        Test.stopTest();

        DeliveryGanttController.DhtmlxGanttTask loginTask;
        for (DeliveryGanttController.DhtmlxGanttTask t : tasks) {
            if (t.description == 'Build login page') {
                loginTask = t;
                break;
            }
        }

        System.assertNotEquals(null, loginTask, 'Should find the login page item.');
        System.assertNotEquals(null, loginTask.workItemId, 'workItemId should be set.');
        System.assertNotEquals(null, loginTask.name, 'name should be set.');
        System.assertNotEquals(null, loginTask.startDate, 'startDate should be set.');
        System.assertNotEquals(null, loginTask.endDate, 'endDate should be set.');
        System.assertEquals('In Development', loginTask.stage, 'stage should match.');
        System.assertEquals('High', loginTask.priority, 'priority should match.');
        System.assertEquals(40, loginTask.estimatedHours, 'estimatedHours should be 40.');
        System.assertEquals(20, loginTask.loggedHours, 'loggedHours should be 20.');
        System.assertEquals('Acme Corp', loginTask.entityName, 'entityName should match.');
        System.assertEquals(false, loginTask.isCompleted, 'Active item should not be completed.');
    }

    @IsTest
    static void testGetGanttDataProgressCalculation() {
        Test.startTest();
        List<DeliveryGanttController.DhtmlxGanttTask> tasks =
            DeliveryGanttController.getGanttData(false);
        Test.stopTest();

        DeliveryGanttController.DhtmlxGanttTask loginTask;
        DeliveryGanttController.DhtmlxGanttTask exportTask;
        DeliveryGanttController.DhtmlxGanttTask backlogTask;

        for (DeliveryGanttController.DhtmlxGanttTask t : tasks) {
            if (t.description == 'Build login page') { loginTask = t; }
            else if (t.description == 'Fix export bug') { exportTask = t; }
            else if (t.description == 'No UAT date work item') { backlogTask = t; }
        }

        // login: 20/40 = 0.5
        System.assertEquals(0.5, loginTask.progress, 'Progress should be 0.5 (20/40).');
        // export: 8/8 = 1.0 (capped)
        System.assertEquals(1.0, exportTask.progress, 'Progress should be 1.0 (8/8, capped).');
        // backlog: no hours = 0
        System.assertEquals(0, backlogTask.progress, 'Progress should be 0 when no hours estimated.');
    }

    @IsTest
    static void testGetGanttDataProgressCappedAtOne() {
        Test.startTest();
        List<DeliveryGanttController.DhtmlxGanttTask> tasks =
            DeliveryGanttController.getGanttData(true);
        Test.stopTest();

        DeliveryGanttController.DhtmlxGanttTask completedTask;
        for (DeliveryGanttController.DhtmlxGanttTask t : tasks) {
            if (t.description == 'Completed item') {
                completedTask = t;
                break;
            }
        }

        System.assertNotEquals(null, completedTask, 'Should find the completed item.');
        System.assertEquals(true, completedTask.isCompleted, 'Inactive item should be completed.');
        // 18/16 > 1.0, should be capped at 1.0
        System.assertEquals(1.0, completedTask.progress,
            'Progress should be capped at 1.0 even when logged > estimated.');
    }

    @IsTest
    static void testGetGanttDataDateFallbacks() {
        Test.startTest();
        List<DeliveryGanttController.DhtmlxGanttTask> tasks =
            DeliveryGanttController.getGanttData(false);
        Test.stopTest();

        DeliveryGanttController.DhtmlxGanttTask backlogTask;
        for (DeliveryGanttController.DhtmlxGanttTask t : tasks) {
            if (t.description == 'No UAT date work item') {
                backlogTask = t;
                break;
            }
        }

        System.assertNotEquals(null, backlogTask, 'Should find the backlog item.');
        // No explicit dates → startDate falls back to CreatedDate, endDate to start+14
        System.assertNotEquals(null, backlogTask.startDate,
            'startDate should fallback to CreatedDate.');
        System.assertNotEquals(null, backlogTask.endDate,
            'endDate should fallback to start+14.');
        System.assertEquals('Unassigned', backlogTask.entityName,
            'entityName should be Unassigned when no client entity.');
    }

    @IsTest
    static void testGetGanttDataNullShowCompleted() {
        Test.startTest();
        List<DeliveryGanttController.DhtmlxGanttTask> tasks =
            DeliveryGanttController.getGanttData(null);
        Test.stopTest();

        // null should behave like false (active only)
        System.assertEquals(3, tasks.size(),
            'null showCompleted should default to active-only (3 items).');
    }

    @IsTest
    static void testGetGanttDataEmptyResult() {
        delete [SELECT Id FROM WorkItem__c];

        Test.startTest();
        List<DeliveryGanttController.DhtmlxGanttTask> tasks =
            DeliveryGanttController.getGanttData(false);
        Test.stopTest();

        System.assertEquals(0, tasks.size(),
            'Should return empty list when no work items exist.');
    }

    @IsTest
    static void testGetGanttDataEntityGrouping() {
        Test.startTest();
        List<DeliveryGanttController.DhtmlxGanttTask> tasks =
            DeliveryGanttController.getGanttData(false);
        Test.stopTest();

        Set<String> entityNames = new Set<String>();
        for (DeliveryGanttController.DhtmlxGanttTask t : tasks) {
            entityNames.add(t.entityName);
        }

        System.assert(entityNames.contains('Acme Corp'),
            'Should contain Acme Corp entity.');
        System.assert(entityNames.contains('Unassigned'),
            'Should contain Unassigned for items without entity.');
    }
}

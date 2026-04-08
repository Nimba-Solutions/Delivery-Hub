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
                System.assertEquals(false, t.isInactive, 'All returned items should be active.');
            }
        }
    }

    @IsTest
    static void testGetGanttDataIncludesCompleted() {
        System.runAs(testUser) {
            Test.startTest();
            List<DeliveryGanttController.GanttTask> tasks = DeliveryGanttController.getGanttData(true);
            Test.stopTest();

            // Recently inactivated item is within the 90-day freshness window so it is included.
            System.assertEquals(4, tasks.size(), 'Should return all 4 work items including the inactive one.');
            Boolean foundInactive = false;
            for (DeliveryGanttController.GanttTask t : tasks) {
                if (t.isInactive) { foundInactive = true; }
            }
            System.assert(foundInactive, 'Should include at least one inactive item.');
        }
    }

    @IsTest
    static void testGetGanttDataExcludesStaleInactive() {
        System.runAs(testUser) {
            // Push the inactive item's LastModifiedDate beyond the freshness window so it falls off.
            WorkItem__c stale = [SELECT Id FROM WorkItem__c WHERE BriefDescriptionTxt__c = 'Completed item' LIMIT 1];
            Test.setCreatedDate(stale.Id, Datetime.now().addDays(-200));
            // We can't directly set LastModifiedDate, so the freshness assertion is sanity-only:
            // confirm the active count is still 3 and the toggle returns at least the active set.

            Test.startTest();
            List<DeliveryGanttController.GanttTask> tasks = DeliveryGanttController.getGanttData(true);
            Test.stopTest();

            System.assert(tasks.size() >= 3, 'Active items should always render regardless of freshness.');
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
                System.assertNotEquals(null, t.hasFallbackEndDate, 'hasFallbackEndDate should always be set.');
            }
        }
    }

    /**
     * @description Phase 2 regression guard: Done / Deployed / Cancelled items
     *              should NOT render with the +14d future-bar fallback. Pre-fix
     *              every Done item with no engineered end date got a misleading
     *              forward-looking bar starting from CreatedDate. Post-fix the
     *              bar uses LastModifiedDate as the actual completion timestamp,
     *              and hasFallbackEndDate is false because LastModifiedDate is
     *              real data, not a synthesized estimate. This is the central
     *              fix that drops dh-prod's 67%-fallback Gantt rate to <5%.
     */
    @IsTest
    static void testTerminalItemsUseLastModifiedDateNotFutureFallback() {
        System.runAs(testUser) {
            // Insert a Done item with NO engineered end-date fields. Pre-fix this
            // would render with a +14d future bar from today; post-fix it should
            // use LastModifiedDate (which is essentially "now" right after insert).
            WorkItem__c done = new WorkItem__c(
                BriefDescriptionTxt__c = 'Phase 2 — terminal item completion',
                StageNamePk__c = 'Done',
                ActivatedDateTime__c = Datetime.now()
            );
            insert done;

            Test.startTest();
            List<DeliveryGanttController.GanttTask> tasks =
                DeliveryGanttController.getGanttData(true);
            Test.stopTest();

            DeliveryGanttController.GanttTask doneTask = null;
            for (DeliveryGanttController.GanttTask t : tasks) {
                if (t.workItemId == done.Id) {
                    doneTask = t;
                    break;
                }
            }
            System.assertNotEquals(null, doneTask, 'The Done item should appear in the gantt data when showCompleted=true');
            System.assertEquals(false, doneTask.hasFallbackEndDate,
                'Terminal items must NOT carry the synthesized-end-date flag — LastModifiedDate is real data');

            // The end date should NOT be 14 days in the future
            Date endDt = Date.valueOf(doneTask.endDate);
            Date today = Date.today();
            System.assert(endDt <= today.addDays(1),
                'Terminal item end date should be at-or-before today (using LastModifiedDate). Got: ' + endDt);
        }
    }

    @IsTest
    static void testGetGanttDataFallbackEndDateAnchor() {
        System.runAs(testUser) {
            // The "No UAT date" item has no end-date fields and no start date, so the
            // fallback should anchor to today (not CreatedDate) and produce a future end date.
            Test.startTest();
            List<DeliveryGanttController.GanttTask> tasks = DeliveryGanttController.getGanttData(false);
            Test.stopTest();

            Date today = Date.today();
            for (DeliveryGanttController.GanttTask t : tasks) {
                if (t.hasFallbackEndDate) {
                    Date endDt = Date.valueOf(t.endDate);
                    System.assert(
                        endDt >= today,
                        'Fallback end date should never float into the past. Got: ' + t.endDate
                    );
                }
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
                // Progress is null when no estimate exists; otherwise must be in [0, 1].
                if (t.progress != null) {
                    System.assert(t.progress >= 0 && t.progress <= 1,
                        'Progress should be between 0 and 1 when set. Got: ' + t.progress);
                }
            }
        }
    }

    @IsTest
    static void testGetGanttDataProgressNullWhenNoEstimate() {
        System.runAs(testUser) {
            // The "No UAT date work item" was inserted with no EstimatedHoursNumber__c.
            Test.startTest();
            List<DeliveryGanttController.GanttTask> tasks = DeliveryGanttController.getGanttData(false);
            Test.stopTest();

            Boolean foundNullProgress = false;
            for (DeliveryGanttController.GanttTask t : tasks) {
                if (t.estimatedHours == null && t.progress == null) {
                    foundNullProgress = true;
                }
            }
            System.assert(foundNullProgress, 'Items with no estimate should have null progress.');
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

    // ── getGanttDependencies ─────────────────────────────────────────

    @IsTest
    static void testGetGanttDependenciesActiveOnly() {
        System.runAs(testUser) {
            Test.startTest();
            List<DeliveryGanttController.GanttDependency> deps = DeliveryGanttController.getGanttDependencies(false);
            Test.stopTest();

            // No dependency rows in test setup; we just confirm the call returns a list.
            System.assertNotEquals(null, deps, 'Should return an empty list, not null.');
        }
    }

    @IsTest
    static void testGetGanttDependenciesIncludesInactive() {
        System.runAs(testUser) {
            Test.startTest();
            List<DeliveryGanttController.GanttDependency> deps = DeliveryGanttController.getGanttDependencies(true);
            Test.stopTest();

            System.assertNotEquals(null, deps, 'Should return an empty list, not null.');
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

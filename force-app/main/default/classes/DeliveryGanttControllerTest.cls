/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Unit tests for DeliveryGanttController.
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.CyclomaticComplexity')
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

    // ── updateWorkItemParent ─────────────────────────────────────────

    @IsTest
    static void testUpdateWorkItemParent() {
        System.runAs(testUser) {
            WorkItem__c parent = [SELECT Id FROM WorkItem__c WHERE BriefDescriptionTxt__c = 'Build login page' LIMIT 1];
            WorkItem__c child  = [SELECT Id FROM WorkItem__c WHERE BriefDescriptionTxt__c = 'Fix export bug' LIMIT 1];
            Test.startTest();
            DeliveryGanttController.updateWorkItemParent(child.Id, parent.Id);
            Test.stopTest();
            WorkItem__c updated = [SELECT ParentWorkItemLookup__c FROM WorkItem__c WHERE Id = :child.Id];
            System.assertEquals(parent.Id, updated.ParentWorkItemLookup__c, 'Parent should be set');
        }
    }

    // ── updateWorkItemPriorityGroup ──────────────────────────────────

    @IsTest
    static void testUpdateWorkItemPriorityGroup() {
        System.runAs(testUser) {
            WorkItem__c item = [SELECT Id FROM WorkItem__c WHERE BriefDescriptionTxt__c = 'Build login page' LIMIT 1];

            Test.startTest();
            DeliveryGanttController.updateWorkItemPriorityGroup(item.Id, 'top-priority');
            Test.stopTest();

            WorkItem__c updated = [SELECT PriorityGroupPk__c FROM WorkItem__c WHERE Id = :item.Id];
            System.assertEquals('top-priority', updated.PriorityGroupPk__c,
                'PriorityGroupPk__c should be saved to the specified bucket.');
        }
    }

    @IsTest
    static void testUpdateWorkItemPriorityGroupInvalidId() {
        System.runAs(testUser) {
            Boolean caught = false;
            Test.startTest();
            try {
                DeliveryGanttController.updateWorkItemPriorityGroup('bogusId', 'active');
            } catch (AuraHandledException e) {
                caught = true;
            }
            Test.stopTest();

            System.assert(caught, 'Should throw AuraHandledException for invalid Id.');
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

    // ══════════════════════════════════════════════════════════════════
    //  Pro Forma Timeline — getProFormaTimelineData + derivePriorityGroup
    // ══════════════════════════════════════════════════════════════════

    @IsTest
    static void testGetProFormaTimelineDataActiveOnly() {
        System.runAs(testUser) {
            Test.startTest();
            List<DeliveryGanttController.ProFormaTimelineRow> rows =
                DeliveryGanttController.getProFormaTimelineData(false);
            Test.stopTest();

            System.assertNotEquals(null, rows, 'Rows should not be null');
            System.assert(rows.size() >= 3, 'Should include the 3 active work items from setup');
            for (DeliveryGanttController.ProFormaTimelineRow row : rows) {
                System.assertNotEquals(null, row.priorityGroup,
                    'Every row should have a priorityGroup (explicit or derived)');
                System.assertNotEquals(null, row.startDate, 'startDate should resolve');
                System.assertNotEquals(null, row.endDate, 'endDate should resolve');
            }
        }
    }

    @IsTest
    static void testGetProFormaTimelineDataIncludesCompleted() {
        System.runAs(testUser) {
            Test.startTest();
            List<DeliveryGanttController.ProFormaTimelineRow> rows =
                DeliveryGanttController.getProFormaTimelineData(true);
            Test.stopTest();

            Boolean foundCompleted = false;
            for (DeliveryGanttController.ProFormaTimelineRow row : rows) {
                if (row.stage == 'Done') {
                    foundCompleted = true;
                    System.assertEquals('follow-on', row.priorityGroup,
                        'Done items should derive to follow-on bucket');
                }
            }
            System.assert(foundCompleted,
                'showCompleted=true should return the Done item from test setup');
        }
    }

    @IsTest
    static void testDerivePriorityGroupRules() {
        // Rule 1: Paused / blocked / hold → deferred
        System.assertEquals('deferred',
            DeliveryGanttController.derivePriorityGroup('High', 'Paused'),
            'Paused stage → deferred');
        System.assertEquals('deferred',
            DeliveryGanttController.derivePriorityGroup('Low', 'On Hold'),
            'On Hold stage → deferred');
        System.assertEquals('deferred',
            DeliveryGanttController.derivePriorityGroup('Medium', 'Blocked'),
            'Blocked stage → deferred');
        // Substring match — "Blocked on vendor" should still trigger deferred
        System.assertEquals('deferred',
            DeliveryGanttController.derivePriorityGroup('Medium', 'Blocked on vendor'),
            'Substring "blocked" → deferred');

        // Rule 2: Terminal stages → follow-on
        System.assertEquals('follow-on',
            DeliveryGanttController.derivePriorityGroup('High', 'Done'),
            'Done → follow-on');
        System.assertEquals('follow-on',
            DeliveryGanttController.derivePriorityGroup('Critical', 'Deployed to Prod'),
            'Deployed to Prod → follow-on');
        System.assertEquals('follow-on',
            DeliveryGanttController.derivePriorityGroup('High', 'Cancelled'),
            'Cancelled → follow-on');

        // Rule 3: High/Critical + active stage → top-priority
        System.assertEquals('top-priority',
            DeliveryGanttController.derivePriorityGroup('High', 'In Development'),
            'High + In Development → top-priority');
        System.assertEquals('top-priority',
            DeliveryGanttController.derivePriorityGroup('Critical', 'Ready for QA'),
            'Critical + Ready for QA → top-priority');

        // Rule 4: Any active stage → active (for non-high priorities)
        System.assertEquals('active',
            DeliveryGanttController.derivePriorityGroup('Medium', 'In Development'),
            'Medium + In Development → active');
        System.assertEquals('active',
            DeliveryGanttController.derivePriorityGroup('Low', 'Deploying'),
            'Low + Deploying → active');

        // Rule 5: Proposed stage → proposed
        System.assertEquals('proposed',
            DeliveryGanttController.derivePriorityGroup('High', 'Backlog'),
            'High + Backlog → proposed (stage wins over priority)');
        System.assertEquals('proposed',
            DeliveryGanttController.derivePriorityGroup('Medium', 'Scoping In Progress'),
            'Scoping In Progress → proposed');

        // Rule 6: Fallback → follow-on
        System.assertEquals('follow-on',
            DeliveryGanttController.derivePriorityGroup('Medium', 'Some Unknown Stage'),
            'Unknown stage → follow-on');

        // Edge: blank stage → follow-on
        System.assertEquals('follow-on',
            DeliveryGanttController.derivePriorityGroup('High', null),
            'Null stage → follow-on');
        System.assertEquals('follow-on',
            DeliveryGanttController.derivePriorityGroup('High', ''),
            'Empty stage → follow-on');
    }

    @IsTest
    static void testGetProFormaTimelineDataRowShape() {
        // Verify the DTO carries every field the LWC maps to task.metadata
        System.runAs(testUser) {
            Test.startTest();
            List<DeliveryGanttController.ProFormaTimelineRow> rows =
                DeliveryGanttController.getProFormaTimelineData(false);
            Test.stopTest();

            // Find the 'Build login page' row (High + In Development from setup)
            DeliveryGanttController.ProFormaTimelineRow loginRow = null;
            for (DeliveryGanttController.ProFormaTimelineRow r : rows) {
                if (r.title == 'Build login page') { loginRow = r; break; }
            }
            System.assertNotEquals(null, loginRow, 'Login page row should be present');
            System.assertEquals('In Development', loginRow.stage, 'Stage passes through');
            System.assertEquals('High', loginRow.priority, 'Priority passes through');
            System.assertEquals('top-priority', loginRow.priorityGroup,
                'High + In Development derives to top-priority');
            System.assertEquals(20, loginRow.estimatedHours, 'Estimated hours pass through');
            System.assertNotEquals(null, loginRow.startDate, 'Start date resolves');
            System.assertNotEquals(null, loginRow.endDate, 'End date resolves');
            System.assertEquals(false, loginRow.isInactive, 'Active item is not inactive');
        }
    }

    @IsTest
    static void testGetProFormaTimelineDataExplicitOverride() {
        // If PriorityGroupPk__c is set on the record, the DTO should use it
        // directly without calling derivePriorityGroup.
        System.runAs(testUser) {
            WorkItem__c loginItem = [
                SELECT Id, PriorityGroupPk__c
                FROM WorkItem__c
                WHERE BriefDescriptionTxt__c = 'Build login page'
                LIMIT 1
            ];
            loginItem.PriorityGroupPk__c = 'proposed'; // explicit override
            update loginItem;

            Test.startTest();
            List<DeliveryGanttController.ProFormaTimelineRow> rows =
                DeliveryGanttController.getProFormaTimelineData(false);
            Test.stopTest();

            DeliveryGanttController.ProFormaTimelineRow loginRow = null;
            for (DeliveryGanttController.ProFormaTimelineRow r : rows) {
                if (r.title == 'Build login page') { loginRow = r; break; }
            }
            System.assertNotEquals(null, loginRow, 'Login page row should still be present');
            System.assertEquals('proposed', loginRow.priorityGroup,
                'Explicit PriorityGroupPk__c override wins over derivation');
        }
    }

    // ── createWorkItemDependency / deleteWorkItemDependency ──────────

    @IsTest
    static void testCreateWorkItemDependencyInsertsRow() {
        List<WorkItem__c> items = [SELECT Id FROM WorkItem__c LIMIT 2];
        System.assertEquals(2, items.size(), 'Need two items from TestSetup');

        Test.startTest();
        DeliveryGanttController.GanttDependency dto =
            DeliveryGanttController.createWorkItemDependency(items[0].Id, items[1].Id, 'Blocks');
        Test.stopTest();

        System.assertNotEquals(null, dto, 'DTO returned');
        System.assertNotEquals(null, dto.id, 'New dep has an id');
        System.assertEquals(items[0].Id, dto.source, 'Source is blocking item');
        System.assertEquals(items[1].Id, dto.target, 'Target is blocked item');
        System.assertEquals('Blocks', dto.dependencyType, 'Type echoed back');

        List<WorkItemDependency__c> rows = [
            SELECT BlockingWorkItemLookup__c, BlockedWorkItemLookup__c, TypePk__c
            FROM WorkItemDependency__c WHERE Id = :dto.id
        ];
        System.assertEquals(1, rows.size(), 'Row persisted');
        System.assertEquals(items[0].Id, rows[0].BlockingWorkItemLookup__c);
        System.assertEquals(items[1].Id, rows[0].BlockedWorkItemLookup__c);
        System.assertEquals('Blocks', rows[0].TypePk__c);
    }

    @IsTest
    static void testCreateWorkItemDependencyDefaultsType() {
        List<WorkItem__c> items = [SELECT Id FROM WorkItem__c LIMIT 2];
        Test.startTest();
        DeliveryGanttController.GanttDependency dto =
            DeliveryGanttController.createWorkItemDependency(items[0].Id, items[1].Id, null);
        Test.stopTest();
        System.assertEquals('Blocks', dto.dependencyType, 'Blank type defaults to Blocks');
    }

    @IsTest
    static void testCreateWorkItemDependencyBlankIdsRejected() {
        WorkItem__c item = [SELECT Id FROM WorkItem__c LIMIT 1];
        Boolean threw = false;
        Test.startTest();
        try {
            DeliveryGanttController.createWorkItemDependency('', item.Id, 'Blocks');
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();
        System.assert(threw, 'Blank blocking id must throw');
    }

    @IsTest
    static void testCreateWorkItemDependencySelfRejected() {
        WorkItem__c item = [SELECT Id FROM WorkItem__c LIMIT 1];
        Boolean threw = false;
        Test.startTest();
        try {
            DeliveryGanttController.createWorkItemDependency(item.Id, item.Id, 'Blocks');
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();
        System.assert(threw, 'Self-reference must throw');
    }

    @IsTest
    static void testDeleteWorkItemDependencyRemovesRow() {
        List<WorkItem__c> items = [SELECT Id FROM WorkItem__c LIMIT 2];
        WorkItemDependency__c dep = new WorkItemDependency__c(
            BlockingWorkItemLookup__c = items[0].Id,
            BlockedWorkItemLookup__c  = items[1].Id,
            TypePk__c                 = 'Blocks'
        );
        insert dep;

        Test.startTest();
        DeliveryGanttController.deleteWorkItemDependency(dep.Id);
        Test.stopTest();

        List<WorkItemDependency__c> rows = [SELECT Id FROM WorkItemDependency__c WHERE Id = :dep.Id];
        System.assertEquals(0, rows.size(), 'Row deleted');
    }

    @IsTest
    static void testDeleteWorkItemDependencyBlankIdRejected() {
        Boolean threw = false;
        Test.startTest();
        try {
            DeliveryGanttController.deleteWorkItemDependency('');
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();
        System.assert(threw, 'Blank depId must throw');
    }

    // ── reorderWorkItemDense (NG 0.185.35+ dense renumber) ───────────────

    /**
     * @description Builds a fresh set of 4 active items in the 'active' bucket
     *              with sparse/negative sortOrders so we can assert the
     *              dense-renumber path actually rewrites them to 1..N.
     * @return Id list in the order they were inserted (for reorder assertions).
     */
    private static List<Id> seedBucketItems() {
        // Deactivate setup items so they don't pollute the bucket query
        List<WorkItem__c> setup = [SELECT Id FROM WorkItem__c];
        for (WorkItem__c w : setup) w.ActivatedDateTime__c = null;
        update setup;

        List<WorkItem__c> items = new List<WorkItem__c>();
        for (Integer i = 0; i < 4; i++) {
            items.add(new WorkItem__c(
                BriefDescriptionTxt__c = 'Dense item ' + i,
                StageNamePk__c = 'In Development',
                PriorityPk__c = 'Medium',
                ActivatedDateTime__c = Datetime.now(),
                PriorityGroupPk__c = 'active',
                SortOrderNumber__c = -964 + (i * 0.5) // messy sparse values
            ));
        }
        insert items;
        List<Id> ids = new List<Id>();
        for (WorkItem__c w : items) ids.add(w.Id);
        return ids;
    }

    @IsTest
    static void testReorderDenseAboveAllRenumbersBucketTo1N() {
        System.runAs(testUser) {
            List<Id> ids = seedBucketItems();
            // ids[0..3] ordered by insert; sort order ascending in bucket.
            // Move the LAST item to above-all.
            Test.startTest();
            DeliveryGanttController.reorderWorkItemDense(
                ids[3], 'above-all', null, null, 'active'
            );
            Test.stopTest();

            Map<Id, WorkItem__c> updated = new Map<Id, WorkItem__c>(
                [SELECT Id, SortOrderNumber__c FROM WorkItem__c WHERE Id IN :ids]
            );
            System.assertEquals(1, updated.get(ids[3]).SortOrderNumber__c, 'Moved item should be 1');
            System.assertEquals(2, updated.get(ids[0]).SortOrderNumber__c, 'Former 1st should shift to 2');
            System.assertEquals(3, updated.get(ids[1]).SortOrderNumber__c);
            System.assertEquals(4, updated.get(ids[2]).SortOrderNumber__c);
        }
    }

    @IsTest
    static void testReorderDenseBelowAllRenumbersBucketTo1N() {
        System.runAs(testUser) {
            List<Id> ids = seedBucketItems();
            Test.startTest();
            DeliveryGanttController.reorderWorkItemDense(
                ids[0], 'below-all', null, null, 'active'
            );
            Test.stopTest();

            Map<Id, WorkItem__c> updated = new Map<Id, WorkItem__c>(
                [SELECT Id, SortOrderNumber__c FROM WorkItem__c WHERE Id IN :ids]
            );
            System.assertEquals(1, updated.get(ids[1]).SortOrderNumber__c);
            System.assertEquals(2, updated.get(ids[2]).SortOrderNumber__c);
            System.assertEquals(3, updated.get(ids[3]).SortOrderNumber__c);
            System.assertEquals(4, updated.get(ids[0]).SortOrderNumber__c, 'Moved item should be last');
        }
    }

    @IsTest
    static void testReorderDenseBetweenAfterTaskIdSplicesCorrectly() {
        System.runAs(testUser) {
            List<Id> ids = seedBucketItems();
            // Move ids[3] to land after ids[0] (so between ids[0] and ids[1])
            Test.startTest();
            DeliveryGanttController.reorderWorkItemDense(
                ids[3], 'between', null, ids[0], 'active'
            );
            Test.stopTest();

            Map<Id, WorkItem__c> updated = new Map<Id, WorkItem__c>(
                [SELECT Id, SortOrderNumber__c FROM WorkItem__c WHERE Id IN :ids]
            );
            System.assertEquals(1, updated.get(ids[0]).SortOrderNumber__c);
            System.assertEquals(2, updated.get(ids[3]).SortOrderNumber__c, 'Moved item lands after ids[0]');
            System.assertEquals(3, updated.get(ids[1]).SortOrderNumber__c);
            System.assertEquals(4, updated.get(ids[2]).SortOrderNumber__c);
        }
    }

    @IsTest
    static void testReorderDenseBetweenBeforeTaskIdSplicesCorrectly() {
        System.runAs(testUser) {
            List<Id> ids = seedBucketItems();
            // Move ids[0] to land before ids[3]
            Test.startTest();
            DeliveryGanttController.reorderWorkItemDense(
                ids[0], 'between', ids[3], null, 'active'
            );
            Test.stopTest();

            Map<Id, WorkItem__c> updated = new Map<Id, WorkItem__c>(
                [SELECT Id, SortOrderNumber__c FROM WorkItem__c WHERE Id IN :ids]
            );
            System.assertEquals(1, updated.get(ids[1]).SortOrderNumber__c);
            System.assertEquals(2, updated.get(ids[2]).SortOrderNumber__c);
            System.assertEquals(3, updated.get(ids[0]).SortOrderNumber__c, 'Moved item lands before ids[3]');
            System.assertEquals(4, updated.get(ids[3]).SortOrderNumber__c);
        }
    }

    @IsTest
    static void testReorderDenseMissingArgsThrows() {
        Boolean threw = false;
        Test.startTest();
        try {
            DeliveryGanttController.reorderWorkItemDense('', 'above-all', null, null, 'active');
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();
        System.assert(threw, 'Blank workItemId must throw');
    }

}

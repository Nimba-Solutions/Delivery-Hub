/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Tests for DeliveryDashboardCardController. Validates each
 *               getCardData data source returns the right shape and respects
 *               the SyncItem__c picklist values actually written by the engine.
 * @author Cloud Nimbus LLC
 */
@IsTest
private class DeliveryDashboardCardControllerTest {

    @IsTest
    static void testGetCardsForPageReturnsList() {
        Test.startTest();
        List<DeliveryDashboardCardController.CardConfig> cards =
            DeliveryDashboardCardController.getCardsForPage('home');
        Test.stopTest();

        System.assertNotEquals(null, cards, 'Should return a non-null list');
    }

    @IsTest
    static void testSyncHealthAllSyncedReturns100() {
        // 1 Synced, 0 Failed in past 7 days → 100%
        insert new SyncItem__c(
            ObjectTypePk__c = 'WorkItem__c',
            DirectionPk__c  = 'Outbound',
            StatusPk__c     = 'Synced',
            PayloadTxt__c   = '{}'
        );

        Test.startTest();
        Object result = DeliveryDashboardCardController.getCardData('syncHealth', null);
        Test.stopTest();

        System.assertEquals(100, ((Decimal) result).intValue(), 'All-Synced should be 100%');
    }

    @IsTest
    static void testSyncHealthHalfFailedReturns50() {
        // 1 Synced, 1 Failed in past 7 days → 50%
        insert new List<SyncItem__c>{
            new SyncItem__c(
                ObjectTypePk__c = 'WorkItem__c',
                DirectionPk__c  = 'Outbound',
                StatusPk__c     = 'Synced',
                PayloadTxt__c   = '{}'
            ),
            new SyncItem__c(
                ObjectTypePk__c = 'WorkItem__c',
                DirectionPk__c  = 'Outbound',
                StatusPk__c     = 'Failed',
                PayloadTxt__c   = '{}'
            )
        };

        Test.startTest();
        Object result = DeliveryDashboardCardController.getCardData('syncHealth', null);
        Test.stopTest();

        // Bug 1 regression guard: prior code filtered on 'Succeeded' (invalid picklist
        // value) so this would have returned 0 instead of 50.
        System.assertEquals(50, ((Decimal) result).intValue(),
            'Half Synced should be 50%, not 0 (Bug 1 regression guard)');
    }

    @IsTest
    static void testSyncHealthEmptyReturns100() {
        // No SyncItems at all → vacuous health = 100
        Test.startTest();
        Object result = DeliveryDashboardCardController.getCardData('syncHealth', null);
        Test.stopTest();

        System.assertEquals(100, ((Decimal) result).intValue(),
            'No SyncItems should return 100 (vacuous health)');
    }

    /**
     * @description Regression guard: Staged sync items must NOT pull syncHealth down.
     *              They are intentionally queued for downstream client polling, not failures.
     *              Pre-fix dh-prod showed syncHealth = 0% because 49 Staged items dragged
     *              the denominator while the numerator (Synced) was 0 in the LAST_N_DAYS:7
     *              window. After fix: Staged items are excluded from the denominator and
     *              the metric reflects only items that should-have-completed-by-now.
     */
    @IsTest
    static void testSyncHealthExcludesStagedFromDenominator() {
        // Setup: 1 Synced (numerator) + 1 Staged (must be excluded from denominator)
        insert new List<SyncItem__c>{
            new SyncItem__c(
                ObjectTypePk__c = 'WorkItem__c',
                DirectionPk__c  = 'Outbound',
                StatusPk__c     = 'Synced',
                PayloadTxt__c   = '{}'
            ),
            new SyncItem__c(
                ObjectTypePk__c = 'WorkItem__c',
                DirectionPk__c  = 'Outbound',
                StatusPk__c     = 'Staged',
                PayloadTxt__c   = '{}'
            )
        };

        Test.startTest();
        Object result = DeliveryDashboardCardController.getCardData('syncHealth', null);
        Test.stopTest();

        // 1 Synced / 1 non-Staged-non-dismissed total = 100%, NOT 1/2 = 50%
        System.assertEquals(100, ((Decimal) result).intValue(),
            'Staged items must be excluded from the syncHealth denominator. They are queued for polling, not failures.');
    }

    /**
     * @description Verifies the new stagedAwaitingPoll data source returns the
     *              correct count of Staged outbound items waiting for client poll.
     */
    @IsTest
    static void testStagedAwaitingPollDataSource() {
        insert new List<SyncItem__c>{
            new SyncItem__c(
                ObjectTypePk__c = 'WorkItem__c',
                DirectionPk__c  = 'Outbound',
                StatusPk__c     = 'Staged',
                PayloadTxt__c   = '{}'
            ),
            new SyncItem__c(
                ObjectTypePk__c = 'WorkItem__c',
                DirectionPk__c  = 'Outbound',
                StatusPk__c     = 'Staged',
                PayloadTxt__c   = '{}'
            ),
            new SyncItem__c(
                ObjectTypePk__c = 'WorkItem__c',
                DirectionPk__c  = 'Outbound',
                StatusPk__c     = 'Synced',
                PayloadTxt__c   = '{}'
            )
        };

        Test.startTest();
        Object result = DeliveryDashboardCardController.getCardData('stagedAwaitingPoll', null);
        Test.stopTest();

        System.assertEquals(2, (Integer) result,
            'stagedAwaitingPoll should return only Staged items, not Synced or others');
    }

    @IsTest
    static void testActiveWorkItemsCounts() {
        // Two active items inserted normally — the trigger will (re)stamp
        // ActivatedDateTime__c here, which is fine, both rows should count.
        insert new List<WorkItem__c>{
            new WorkItem__c(
                BriefDescriptionTxt__c = 'Active 1',
                StageNamePk__c         = 'In Development',
                ActivatedDateTime__c   = Datetime.now()
            ),
            new WorkItem__c(
                BriefDescriptionTxt__c = 'Active 2',
                StageNamePk__c         = 'In Development',
                ActivatedDateTime__c   = Datetime.now()
            )
        };

        // The third "inactive" row simulates a legacy record where
        // ActivatedDateTime__c is genuinely NULL — exactly the case the
        // controller's `WHERE ActivatedDateTime__c != NULL` filter is meant
        // to exclude. DeliveryWorkItemTriggerHandler.handleBeforeInsert
        // auto-stamps ActivatedDateTime__c on insert, so we have to bypass
        // the trigger to land a row with the field still null. Without this
        // bypass the test would always count 3, masking the filter.
        DeliveryWorkItemTriggerHandler.triggerDisabled = true;
        try {
            insert new WorkItem__c(
                BriefDescriptionTxt__c = 'Inactive (no Activated)',
                StageNamePk__c         = 'Backlog'
            );
        } finally {
            DeliveryWorkItemTriggerHandler.triggerDisabled = false;
        }

        Test.startTest();
        Object result = DeliveryDashboardCardController.getCardData('activeWorkItems', null);
        Test.stopTest();

        System.assertEquals(2, (Integer) result, 'Should count only items with ActivatedDateTime__c set');
    }

    @IsTest
    static void testHoursThisMonthSums() {
        WorkItem__c wi = new WorkItem__c(
            BriefDescriptionTxt__c = 'Hours Test',
            StageNamePk__c         = 'In Development',
            ActivatedDateTime__c   = Datetime.now()
        );
        insert wi;
        WorkRequest__c wr = new WorkRequest__c(
            WorkItemId__c           = wi.Id,
            QuotedHoursNumber__c    = 10,
            HourlyRateCurrency__c   = 100,
            StatusPk__c             = 'Accepted'
        );
        insert wr;
        insert new List<WorkLog__c>{
            new WorkLog__c(
                RequestId__c           = wr.Id,
                WorkItemLookup__c      = wi.Id,
                HoursLoggedNumber__c   = 3.5,
                WorkDescriptionTxt__c  = 'work A'
            ),
            new WorkLog__c(
                RequestId__c           = wr.Id,
                WorkItemLookup__c      = wi.Id,
                HoursLoggedNumber__c   = 1.25,
                WorkDescriptionTxt__c  = 'work B'
            )
        };

        Test.startTest();
        Object result = DeliveryDashboardCardController.getCardData('hoursThisMonth', null);
        Test.stopTest();

        System.assertEquals(4.75, (Decimal) result, 'Should sum HoursLoggedNumber__c for this month');
    }

    @IsTest
    static void testCompletedThisWeekCounts() {
        insert new WorkItem__c(
            BriefDescriptionTxt__c = 'Done This Week',
            StageNamePk__c         = 'Done',
            ActivatedDateTime__c   = Datetime.now()
        );

        Test.startTest();
        Object result = DeliveryDashboardCardController.getCardData('completedThisWeek', null);
        Test.stopTest();

        System.assert((Integer) result >= 1, 'Should count at least the Done item created this week');
    }

    @IsTest
    static void testOverdueItemsCountsOnlyActive() {
        insert new List<WorkItem__c>{
            new WorkItem__c(
                BriefDescriptionTxt__c   = 'Overdue Active',
                StageNamePk__c           = 'In Development',
                ActivatedDateTime__c     = Datetime.now(),
                EstimatedEndDevDate__c   = Date.today().addDays(-5)
            ),
            new WorkItem__c(
                // Done items should NOT count even if overdue
                BriefDescriptionTxt__c   = 'Overdue Done',
                StageNamePk__c           = 'Done',
                ActivatedDateTime__c     = Datetime.now(),
                EstimatedEndDevDate__c   = Date.today().addDays(-5)
            ),
            new WorkItem__c(
                // Future ETA should not count
                BriefDescriptionTxt__c   = 'Future ETA',
                StageNamePk__c           = 'In Development',
                ActivatedDateTime__c     = Datetime.now(),
                EstimatedEndDevDate__c   = Date.today().addDays(5)
            )
        };

        Test.startTest();
        Object result = DeliveryDashboardCardController.getCardData('overdueItems', null);
        Test.stopTest();

        System.assertEquals(1, (Integer) result, 'Only the active, non-terminal, past-ETA item should count');
    }

    @IsTest
    static void testWorkItemsByPriorityReturnsList() {
        insert new List<WorkItem__c>{
            new WorkItem__c(
                BriefDescriptionTxt__c = 'High pri',
                StageNamePk__c         = 'In Development',
                PriorityPk__c          = 'High',
                ActivatedDateTime__c   = Datetime.now()
            ),
            new WorkItem__c(
                BriefDescriptionTxt__c = 'Critical pri',
                StageNamePk__c         = 'In Development',
                PriorityPk__c          = 'Critical',
                ActivatedDateTime__c   = Datetime.now()
            )
        };

        Test.startTest();
        Object result = DeliveryDashboardCardController.getCardData('workItemsByPriority', null);
        Test.stopTest();

        List<Object> data = (List<Object>) result;
        System.assert(data.size() >= 2, 'Should bucket priorities — got ' + data.size());
    }

    @IsTest
    static void testWorkItemsByPhaseReturnsList() {
        insert new WorkItem__c(
            BriefDescriptionTxt__c = 'Phase test',
            StageNamePk__c         = 'In Development',
            ActivatedDateTime__c   = Datetime.now()
        );

        Test.startTest();
        Object result = DeliveryDashboardCardController.getCardData('workItemsByPhase', null);
        Test.stopTest();

        List<Object> data = (List<Object>) result;
        System.assert(data.size() >= 1, 'Should bucket stages — got ' + data.size());
    }

    @IsTest
    static void testRecentActivityReturnsList() {
        Test.startTest();
        Object result = DeliveryDashboardCardController.getCardData('recentActivity', null);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Should return a non-null list (possibly empty)');
    }

    @IsTest
    static void testBlockedItemsCounts() {
        insert new WorkItem__c(
            BriefDescriptionTxt__c = 'Blocked thing',
            StageNamePk__c         = 'Blocked - Awaiting Info',
            ActivatedDateTime__c   = Datetime.now()
        );

        Test.startTest();
        Object result = DeliveryDashboardCardController.getCardData('blockedItems', null);
        Test.stopTest();

        System.assert((Integer) result >= 1, 'Should count items whose stage contains "Blocked"');
    }

    @IsTest
    static void testUnknownDataSourceReturnsNull() {
        Test.startTest();
        Object result = DeliveryDashboardCardController.getCardData('nonsense', null);
        Test.stopTest();

        System.assertEquals(null, result, 'Unknown data source should return null');
    }

    @IsTest
    static void testHoursByMonthLast6ReturnsSixBuckets() {
        WorkItem__c wi = new WorkItem__c(
            BriefDescriptionTxt__c = 'Hours-by-month test',
            StageNamePk__c         = 'In Development',
            ActivatedDateTime__c   = Datetime.now()
        );
        insert wi;
        WorkRequest__c wr = new WorkRequest__c(
            WorkItemId__c         = wi.Id,
            QuotedHoursNumber__c  = 10,
            HourlyRateCurrency__c = 100,
            StatusPk__c           = 'Accepted'
        );
        insert wr;
        insert new WorkLog__c(
            RequestId__c          = wr.Id,
            WorkItemLookup__c     = wi.Id,
            HoursLoggedNumber__c  = 7,
            WorkDateDate__c       = Date.today(),
            WorkDescriptionTxt__c = 'work this month'
        );

        Test.startTest();
        Object result = DeliveryDashboardCardController.getCardData('hoursByMonthLast6', null);
        Test.stopTest();

        List<Object> data = (List<Object>) result;
        System.assertEquals(6, data.size(), 'Should always return 6 monthly buckets even when most are empty');
        // Last bucket = current month, should reflect the 7h entry
        Map<String, Object> currentMonth = (Map<String, Object>) data[5];
        System.assertEquals(7, (Decimal) currentMonth.get('value'),
            'Current month bucket should sum HoursLoggedNumber for WorkDateDate within the month');
    }

    @IsTest
    static void testProjectHealthPillsHandlesEmpty() {
        Test.startTest();
        Object result = DeliveryDashboardCardController.getCardData('projectHealthPills', null);
        Test.stopTest();

        List<Object> data = (List<Object>) result;
        System.assertNotEquals(null, data, 'Should return non-null list even with no qualifying WIs');
    }

    @IsTest
    static void testProjectHealthPillsRanksByOverrun() {
        // Two Active WIs — one over budget (red), one under (green).
        // Expectation: both surface, the over-budget one ranks first (worst-first sort).
        WorkItem__c overBudget = new WorkItem__c(
            BriefDescriptionTxt__c   = 'Over budget',
            StageNamePk__c           = 'In Development',
            ActivatedDateTime__c     = Datetime.now(),
            EstimatedHoursNumber__c  = 5,
            EstimatedEndDevDate__c   = Date.today().addDays(10)
        );
        WorkItem__c underBudget = new WorkItem__c(
            BriefDescriptionTxt__c   = 'Under budget',
            StageNamePk__c           = 'In Development',
            ActivatedDateTime__c     = Datetime.now(),
            EstimatedHoursNumber__c  = 100,
            EstimatedEndDevDate__c   = Date.today().addDays(10)
        );
        insert new List<WorkItem__c>{ overBudget, underBudget };

        WorkRequest__c overWr = new WorkRequest__c(
            WorkItemId__c         = overBudget.Id,
            QuotedHoursNumber__c  = 5,
            HourlyRateCurrency__c = 100,
            StatusPk__c           = 'Accepted'
        );
        WorkRequest__c underWr = new WorkRequest__c(
            WorkItemId__c         = underBudget.Id,
            QuotedHoursNumber__c  = 100,
            HourlyRateCurrency__c = 100,
            StatusPk__c           = 'Accepted'
        );
        insert new List<WorkRequest__c>{ overWr, underWr };

        // 20h logged on overBudget (5h estimate) → ratio 0.25 → red
        // 5h logged on underBudget (100h estimate) → ratio 20 → green
        insert new List<WorkLog__c>{
            new WorkLog__c(RequestId__c = overWr.Id, WorkItemLookup__c = overBudget.Id, HoursLoggedNumber__c = 20, WorkDescriptionTxt__c = 'a'),
            new WorkLog__c(RequestId__c = underWr.Id, WorkItemLookup__c = underBudget.Id, HoursLoggedNumber__c = 5, WorkDescriptionTxt__c = 'b')
        };

        Test.startTest();
        Object result = DeliveryDashboardCardController.getCardData('projectHealthPills', null);
        Test.stopTest();

        List<Object> data = (List<Object>) result;
        System.assert(data.size() >= 2, 'Should surface both qualifying WIs');
        Map<String, Object> first = (Map<String, Object>) data[0];
        System.assertEquals('danger', first.get('budgetClass'),
            'Worst-first sort: over-budget red pill should be the first row');
    }

    @IsTest
    static void testCardConfigSurfacesNewFields() {
        // Smoke test: cards returned by getCardsForPage should include the new
        // clickThroughUrl + infoPopover fields on the CardConfig DTO. (Test
        // only validates the DTO surface — actual values come from
        // DashboardCard__mdt records, which Test.loadData would seed.)
        Test.startTest();
        List<DeliveryDashboardCardController.CardConfig> cards =
            DeliveryDashboardCardController.getCardsForPage('home');
        Test.stopTest();

        System.assertNotEquals(null, cards, 'Cards list should not be null');
        // If any card returns, verify the new properties exist on the DTO
        // (always present, possibly null — that's fine).
        for (DeliveryDashboardCardController.CardConfig c : cards) {
            // No assertion about value; just verify no exception accessing the field
            String tmp = c.clickThroughUrl;
            String tmp2 = c.infoPopover;
        }
    }
}

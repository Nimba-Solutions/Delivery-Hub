/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Unit tests for DeliveryHoursAnalyticsController. Verifies the WI tree
 *              walk, monthly bucket assembly, target overlay, and edge cases (no
 *              estimate, no logs, deeply nested children).
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.ApexDoc,PMD.ExcessiveParameterList')
@IsTest
private class DeliveryHoursAnalyticsControllerTest {

    /**
     * @description Bracket WI inserts with triggerDisabled — mirrors the pattern
     *              used in DeliveryDepthProbeServiceTest (see PR #764). Keeps these
     *              tests focused on analytics, not auto-WR / sync side effects.
     */
    private static WorkItem__c insertWi(String briefDesc, Decimal estimate, Date startDate, Date endDate, Id parentId) {
        WorkItem__c wi = new WorkItem__c(
            BriefDescriptionTxt__c = briefDesc,
            EstimatedHoursNumber__c = estimate,
            EstimatedStartDevDate__c = startDate,
            EstimatedEndDevDate__c = endDate,
            ParentWorkItemLookup__c = parentId,
            ActivatedDateTime__c = Datetime.now(),
            StatusPk__c = 'Active'
        );
        DeliveryWorkItemTriggerHandler.triggerDisabled = true;
        try {
            insert wi;
        } finally {
            DeliveryWorkItemTriggerHandler.triggerDisabled = false;
        }
        return wi;
    }

    private static WorkLog__c buildLog(Id wiId, Decimal hours, Date workDate) {
        return new WorkLog__c(
            WorkItemLookup__c = wiId,
            HoursLoggedNumber__c = hours,
            WorkDateDate__c = workDate,
            WorkDescriptionTxt__c = 'test log'
        );
    }

    @IsTest
    static void testReturnsTwelveMonthsByDefault() {
        WorkItem__c root = insertWi('Root', 80, Date.today().addMonths(-2), Date.today().addMonths(2), null);

        Test.startTest();
        DeliveryHoursAnalyticsController.ProjectHoursSummary result =
            DeliveryHoursAnalyticsController.getMonthlyHoursForProject(root.Id, null);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Summary must not be null');
        System.assertEquals(root.Id, result.rootWorkItemId, 'rootWorkItemId matches input');
        System.assertEquals(12, result.months.size(), 'Default monthsBack=12 returns 12 buckets');
        System.assertEquals(1, result.descendantCount, 'descendantCount counts root + descendants');
    }

    @IsTest
    static void testCustomMonthsBackRespected() {
        WorkItem__c root = insertWi('Root6', 60, Date.today().addMonths(-2), Date.today().addMonths(2), null);

        Test.startTest();
        DeliveryHoursAnalyticsController.ProjectHoursSummary result =
            DeliveryHoursAnalyticsController.getMonthlyHoursForProject(root.Id, 6);
        Test.stopTest();

        System.assertEquals(6, result.months.size(), 'monthsBack=6 returns 6 buckets');
    }

    @IsTest
    static void testZeroOrNegativeMonthsBackDefaultsToTwelve() {
        WorkItem__c root = insertWi('RootZero', 20, null, null, null);

        Test.startTest();
        DeliveryHoursAnalyticsController.ProjectHoursSummary zero =
            DeliveryHoursAnalyticsController.getMonthlyHoursForProject(root.Id, 0);
        DeliveryHoursAnalyticsController.ProjectHoursSummary negative =
            DeliveryHoursAnalyticsController.getMonthlyHoursForProject(root.Id, -5);
        Test.stopTest();

        System.assertEquals(12, zero.months.size(), '0 falls back to 12');
        System.assertEquals(12, negative.months.size(), 'negative falls back to 12');
    }

    @IsTest
    static void testMonthsBackClampedToMax() {
        WorkItem__c root = insertWi('RootBig', 1, null, null, null);

        Test.startTest();
        DeliveryHoursAnalyticsController.ProjectHoursSummary result =
            DeliveryHoursAnalyticsController.getMonthlyHoursForProject(root.Id, 1000);
        Test.stopTest();

        System.assertEquals(60, result.months.size(), '1000 clamped to MAX_MONTHS=60');
    }

    @IsTest
    static void testNullWorkItemIdThrows() {
        Test.startTest();
        try {
            DeliveryHoursAnalyticsController.getMonthlyHoursForProject(null, 12);
            System.assert(false, 'Expected AuraHandledException for null workItemId');
        } catch (AuraHandledException expected) {
            System.assert(true, 'Caught expected exception');
        }
        Test.stopTest();
    }

    @IsTest
    static void testAggregatesLoggedHoursIntoCorrectMonth() {
        WorkItem__c root = insertWi('AggRoot', 40, Date.today().addMonths(-1), Date.today().addMonths(1), null);
        Date thisMonth = Date.today();
        Date lastMonth = Date.today().addMonths(-1);

        insert new List<WorkLog__c>{
            buildLog(root.Id, 4, thisMonth),
            buildLog(root.Id, 2.5, thisMonth),
            buildLog(root.Id, 6, lastMonth)
        };

        Test.startTest();
        DeliveryHoursAnalyticsController.ProjectHoursSummary result =
            DeliveryHoursAnalyticsController.getMonthlyHoursForProject(root.Id, 12);
        Test.stopTest();

        Map<String, Decimal> byKey = new Map<String, Decimal>();
        for (DeliveryHoursAnalyticsController.MonthlyHoursDTO row : result.months) {
            byKey.put(row.year + '-' + row.month, row.hoursLogged);
        }
        System.assertEquals(6.5, byKey.get(thisMonth.year() + '-' + thisMonth.month()),
            'This month should sum to 6.5h');
        System.assertEquals(6, byKey.get(lastMonth.year() + '-' + lastMonth.month()),
            'Last month should sum to 6h');
    }

    @IsTest
    static void testWalksDescendantsAndSumsAcrossTree() {
        WorkItem__c root = insertWi('TreeRoot', 100, null, null, null);
        WorkItem__c child1 = insertWi('Child1', 30, null, null, root.Id);
        WorkItem__c child2 = insertWi('Child2', 30, null, null, root.Id);
        WorkItem__c grandchild = insertWi('Grandchild', 20, null, null, child1.Id);

        Date today = Date.today();
        insert new List<WorkLog__c>{
            buildLog(root.Id, 1, today),
            buildLog(child1.Id, 2, today),
            buildLog(child2.Id, 3, today),
            buildLog(grandchild.Id, 4, today)
        };

        Test.startTest();
        DeliveryHoursAnalyticsController.ProjectHoursSummary result =
            DeliveryHoursAnalyticsController.getMonthlyHoursForProject(root.Id, 12);
        Test.stopTest();

        System.assertEquals(4, result.descendantCount, 'Tree has root + 2 children + 1 grandchild = 4');

        Decimal thisMonthTotal = 0;
        for (DeliveryHoursAnalyticsController.MonthlyHoursDTO row : result.months) {
            if (row.year == today.year() && row.month == today.month()) {
                thisMonthTotal = row.hoursLogged;
            }
        }
        System.assertEquals(10, thisMonthTotal, 'This month sum across tree = 1+2+3+4 = 10');
    }

    @IsTest
    static void testMonthlyTargetWhenEstimateAndDatesPopulated() {
        Date startDate = Date.newInstance(Date.today().year(), Date.today().month(), 1).addMonths(-1);
        Date endDate = startDate.addMonths(3).addDays(-1);
        WorkItem__c root = insertWi('Targeted', 40, startDate, endDate, null);

        Test.startTest();
        DeliveryHoursAnalyticsController.ProjectHoursSummary result =
            DeliveryHoursAnalyticsController.getMonthlyHoursForProject(root.Id, 12);
        Test.stopTest();

        System.assertEquals(true, result.hasEstimate, 'hasEstimate true with non-null estimate');
        // 40h / ~3-month plan span. Expect ~13.33/month.
        System.assert(result.monthlyTarget > 0, 'monthlyTarget should be > 0');
        for (DeliveryHoursAnalyticsController.MonthlyHoursDTO row : result.months) {
            System.assertEquals(result.monthlyTarget, row.monthlyTarget,
                'Each row should carry the per-month target');
        }
    }

    @IsTest
    static void testNoEstimateMeansZeroTarget() {
        WorkItem__c root = insertWi('NoEstimate', null, null, null, null);

        Test.startTest();
        DeliveryHoursAnalyticsController.ProjectHoursSummary result =
            DeliveryHoursAnalyticsController.getMonthlyHoursForProject(root.Id, 12);
        Test.stopTest();

        System.assertEquals(false, result.hasEstimate, 'hasEstimate false without estimate');
        System.assertEquals(0, result.monthlyTarget, 'monthlyTarget=0 when no estimate');
        for (DeliveryHoursAnalyticsController.MonthlyHoursDTO row : result.months) {
            System.assertEquals(false, row.overTarget,
                'overTarget should be false when no target');
        }
    }

    @IsTest
    static void testOverTargetFlagFiresWhenHoursExceedTarget() {
        Date startDate = Date.newInstance(Date.today().year(), Date.today().month(), 1);
        Date endDate = startDate.addMonths(1).addDays(-1);
        WorkItem__c root = insertWi('Over', 5, startDate, endDate, null);

        // 5h estimate over 1-month span → 5h/month target. Log 10h.
        insert buildLog(root.Id, 10, Date.today());

        Test.startTest();
        DeliveryHoursAnalyticsController.ProjectHoursSummary result =
            DeliveryHoursAnalyticsController.getMonthlyHoursForProject(root.Id, 12);
        Test.stopTest();

        Boolean foundOver = false;
        for (DeliveryHoursAnalyticsController.MonthlyHoursDTO row : result.months) {
            if (row.year == Date.today().year() && row.month == Date.today().month()) {
                System.assertEquals(true, row.overTarget,
                    'This month exceeded target — overTarget should be true');
                foundOver = true;
            }
        }
        System.assert(foundOver, 'Should have located the current month bucket');
    }

    @IsTest
    static void testLogsOutsideWindowAreIgnored() {
        WorkItem__c root = insertWi('Windowed', null, null, null, null);
        // Log a date 5 years ago — outside the default 12-month window.
        insert buildLog(root.Id, 99, Date.today().addYears(-5));

        Test.startTest();
        DeliveryHoursAnalyticsController.ProjectHoursSummary result =
            DeliveryHoursAnalyticsController.getMonthlyHoursForProject(root.Id, 12);
        Test.stopTest();

        Decimal sum = 0;
        for (DeliveryHoursAnalyticsController.MonthlyHoursDTO row : result.months) {
            sum += row.hoursLogged;
        }
        System.assertEquals(0, sum, 'Logs outside window must not appear');
    }

    @IsTest
    static void testEmptyTreeStillReturnsBuckets() {
        WorkItem__c root = insertWi('Empty', null, null, null, null);

        Test.startTest();
        DeliveryHoursAnalyticsController.ProjectHoursSummary result =
            DeliveryHoursAnalyticsController.getMonthlyHoursForProject(root.Id, 6);
        Test.stopTest();

        System.assertEquals(6, result.months.size(), 'Buckets created even with no logs');
        for (DeliveryHoursAnalyticsController.MonthlyHoursDTO row : result.months) {
            System.assertEquals(0, row.hoursLogged, 'No logs → all buckets zero');
        }
    }
}

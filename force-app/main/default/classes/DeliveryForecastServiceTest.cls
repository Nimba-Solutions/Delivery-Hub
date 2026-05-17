/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Unit tests for DeliveryForecastService. Verifies tree walk,
 *              weekly history assembly, rolling-window velocity, projection
 *              extrapolation, confidence band, and edge cases (no estimate,
 *              no logs, already over scope, single-week history).
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.ApexDoc,PMD.ExcessiveParameterList')
@IsTest
private class DeliveryForecastServiceTest {

    /**
     * @description Thin wrapper around TestDataFactory.createWorkItem. Factory
     *              brackets the DML with triggerDisabled so this test focuses
     *              on forecast math, not auto-WR / sync side effects.
     */
    private static WorkItem__c insertWi(String briefDesc, Decimal estimate, Date startDate, Date endDate, Id parentId) {
        return TestDataFactory.createWorkItem(new Map<String, Object>{
            'BriefDescriptionTxt__c' => briefDesc,
            'EstimatedHoursNumber__c' => estimate,
            'EstimatedStartDevDate__c' => startDate,
            'EstimatedEndDevDate__c' => endDate,
            'ParentWorkItemLookup__c' => parentId
        });
    }

    /**
     * @description Thin wrapper around TestDataFactory.buildWorkLog — the
     *              factory owns the per-WI WorkRequest__c bridge cache so
     *              RequestId__c (required MD per PR #770 feedback)
     *              auto-populates.
     */
    private static WorkLog__c buildLog(Id wiId, Decimal hours, Date workDate) {
        return TestDataFactory.buildWorkLog(wiId, hours, workDate,
            new Map<String, Object>{ 'WorkDescriptionTxt__c' => 'forecast test log' });
    }

    @IsTest
    static void testNullWorkItemIdThrows() {
        Test.startTest();
        try {
            DeliveryForecastService.calculateProjectForecast(null);
            System.assert(false, 'Expected AuraHandledException');
        } catch (AuraHandledException expected) {
            System.assert(true, 'Caught expected exception');
        }
        Test.stopTest();
    }

    @IsTest
    static void testEmptyTreeReturnsEmptyForecast() {
        WorkItem__c root = insertWi('NoLogs', 40, Date.today(), Date.today().addDays(28), null);

        Test.startTest();
        DeliveryForecastService.ProjectForecast f =
            DeliveryForecastService.calculateProjectForecast(root.Id);
        Test.stopTest();

        System.assertEquals(root.Id, f.rootWorkItemId, 'rootWorkItemId echoed');
        System.assertEquals(0, f.totalLoggedHours, 'No hours logged');
        System.assertEquals(40, f.totalEstimatedHours, 'Estimate echoed');
        System.assertEquals(true, f.hasEstimate, 'hasEstimate true');
        System.assertEquals(false, f.hasVelocity, 'hasVelocity false with no logs');
        System.assertEquals(null, f.projectedCompletionDate, 'No projection without velocity');
        System.assertEquals(0, f.history.size(), 'history empty');
        System.assertEquals(0, f.projection.size(), 'projection empty');
    }

    @IsTest
    static void testTotalLoggedSumsAcrossTree() {
        WorkItem__c root = insertWi('TreeRoot', 100, null, null, null);
        WorkItem__c childA = insertWi('ChildA', 30, null, null, root.Id);
        WorkItem__c childB = insertWi('ChildB', 30, null, null, root.Id);

        insert new List<WorkLog__c>{
            buildLog(root.Id, 5, Date.today().addDays(-14)),
            buildLog(childA.Id, 7, Date.today().addDays(-7)),
            buildLog(childB.Id, 3, Date.today())
        };

        Test.startTest();
        DeliveryForecastService.ProjectForecast f =
            DeliveryForecastService.calculateProjectForecast(root.Id);
        Test.stopTest();

        System.assert(f.history.size() >= 1, 'history populated');
        Decimal cumulativeAtEnd = f.history[f.history.size() - 1].cumulativeHours;
        System.assertEquals(15, cumulativeAtEnd, 'Cumulative across tree = 5+7+3');
    }

    @IsTest
    static void testVelocityComputedFromRollingWindow() {
        WorkItem__c root = insertWi('Velocity', 200, Date.today().addDays(-21), Date.today().addDays(60), null);

        // 4 weekly buckets of 10h each, anchored at today (no trailing empty
        // bucket — without the today-anchor log the most-recent week is empty
        // and the 4-week rolling window averages [10,10,10,0]/4 = 7.5).
        insert new List<WorkLog__c>{
            buildLog(root.Id, 10, Date.today().addDays(-21)),
            buildLog(root.Id, 10, Date.today().addDays(-14)),
            buildLog(root.Id, 10, Date.today().addDays(-7)),
            buildLog(root.Id, 10, Date.today())
        };

        Test.startTest();
        DeliveryForecastService.ProjectForecast f =
            DeliveryForecastService.calculateProjectForecast(root.Id);
        Test.stopTest();

        System.assertEquals(true, f.hasVelocity, 'hasVelocity true with ≥2 weeks');
        System.assertEquals(10, f.currentVelocityHoursPerWeek, 'Velocity = 10h/wk over flat window');
        System.assertEquals(0, f.velocityStdDev, 'StdDev = 0 over flat window');
        System.assertNotEquals(null, f.projectedCompletionDate, 'Projection populated');
        System.assertNotEquals(null, f.confidenceLowDate, 'Confidence band populated');
        System.assertNotEquals(null, f.confidenceHighDate, 'Confidence band populated');
    }

    @IsTest
    static void testProjectionExtendsPastTodayWhenScopeRemains() {
        WorkItem__c root = insertWi('Project', 100, Date.today().addDays(-28), Date.today().addDays(60), null);

        // Log 40h over 4 weeks at 10h/wk. 60h remaining → 6 weeks to finish.
        insert new List<WorkLog__c>{
            buildLog(root.Id, 10, Date.today().addDays(-28)),
            buildLog(root.Id, 10, Date.today().addDays(-21)),
            buildLog(root.Id, 10, Date.today().addDays(-14)),
            buildLog(root.Id, 10, Date.today().addDays(-7))
        };

        Test.startTest();
        DeliveryForecastService.ProjectForecast f =
            DeliveryForecastService.calculateProjectForecast(root.Id);
        Test.stopTest();

        System.assert(f.projection.size() > 0, 'Projection has future weeks');
        System.assertEquals(100, f.projectedFinalHours, 'Projected final = scope when on track');
        System.assert(f.projectedCompletionDate > Date.today(), 'Completion in the future');
    }

    @IsTest
    static void testOverBudgetTrajectoryWhenPastDeadline() {
        Date deadline = Date.today().addDays(7);
        WorkItem__c root = insertWi('TightDeadline', 200, Date.today().addDays(-28), deadline, null);

        // 4 weeks at 10h/wk → 10h/wk velocity. Remaining 160h would take 16 weeks.
        // Deadline is 1 week from today. → over-budget trajectory.
        insert new List<WorkLog__c>{
            buildLog(root.Id, 10, Date.today().addDays(-28)),
            buildLog(root.Id, 10, Date.today().addDays(-21)),
            buildLog(root.Id, 10, Date.today().addDays(-14)),
            buildLog(root.Id, 10, Date.today().addDays(-7))
        };

        Test.startTest();
        DeliveryForecastService.ProjectForecast f =
            DeliveryForecastService.calculateProjectForecast(root.Id);
        Test.stopTest();

        System.assertEquals(true, f.isOverBudgetTrajectory,
            'Velocity slips past deadline → isOverBudgetTrajectory true');
    }

    @IsTest
    static void testAlreadyAtScopeProducesEmptyProjection() {
        WorkItem__c root = insertWi('Done', 20, Date.today().addDays(-14), Date.today().addDays(-1), null);
        insert new List<WorkLog__c>{
            buildLog(root.Id, 10, Date.today().addDays(-14)),
            buildLog(root.Id, 10, Date.today().addDays(-7))
        };

        Test.startTest();
        DeliveryForecastService.ProjectForecast f =
            DeliveryForecastService.calculateProjectForecast(root.Id);
        Test.stopTest();

        System.assertEquals(0, f.weeksRemaining, 'weeksRemaining=0 when scope reached');
        System.assertEquals(Date.today(), f.projectedCompletionDate, 'Completion = today when scope reached');
        System.assertEquals(false, f.isOverBudgetTrajectory, 'Not over budget — exactly on scope');
    }

    @IsTest
    static void testNoEstimateMeansNoProjection() {
        WorkItem__c root = insertWi('NoEstimate', null, null, null, null);
        insert new List<WorkLog__c>{
            buildLog(root.Id, 5, Date.today().addDays(-14)),
            buildLog(root.Id, 5, Date.today().addDays(-7))
        };

        Test.startTest();
        DeliveryForecastService.ProjectForecast f =
            DeliveryForecastService.calculateProjectForecast(root.Id);
        Test.stopTest();

        System.assertEquals(false, f.hasEstimate, 'hasEstimate false');
        System.assertEquals(null, f.projectedCompletionDate, 'No projection without scope');
        System.assertEquals(0, f.projection.size(), 'projection empty');
        System.assert(f.history.size() > 0, 'history still populated');
    }

    @IsTest
    static void testSingleWeekHistorySetsVelocityButNoConfidence() {
        WorkItem__c root = insertWi('SingleWeek', 40, Date.today().addDays(-7), Date.today().addDays(28), null);
        // Anchor on today so the log lands in the SAME weekly bucket as the
        // window cursor. addDays(-3) leaks into the prior week's bucket on most
        // weekdays (and creates 2 buckets: [8, 0], giving mean 4 instead of 8).
        insert buildLog(root.Id, 8, Date.today());

        Test.startTest();
        DeliveryForecastService.ProjectForecast f =
            DeliveryForecastService.calculateProjectForecast(root.Id);
        Test.stopTest();

        // With 1 week of history, populateVelocityStats sets velocity to last week's hours
        // but flags hasVelocity=false (need ≥2 weeks for confidence).
        System.assertEquals(8, f.currentVelocityHoursPerWeek, 'Single-week velocity point estimate');
        System.assertEquals(false, f.hasVelocity,
            'hasVelocity false with <2 weeks — projection suppressed');
    }
}

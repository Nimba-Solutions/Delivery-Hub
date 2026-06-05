/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Unit tests for DeliveryHoursAnalyticsController. Verifies the WI tree
 *              walk, monthly bucket assembly, target overlay, and edge cases (no
 *              estimate, no logs, deeply nested children).
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.ApexDoc,PMD.ExcessiveParameterList,PMD.CyclomaticComplexity')
@IsTest
private class DeliveryHoursAnalyticsControllerTest {

    /**
     * @description Thin wrapper around TestDataFactory.createWorkItem for backward
     *              compatibility with existing tests in this class. Factory bypasses
     *              triggers by default so tests focus on analytics, not auto-WR /
     *              sync side effects.
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
     * @description Thin wrapper around TestDataFactory.buildWorkLog — the factory
     *              owns the per-WI WorkRequest__c bridge cache so RequestId__c
     *              (required MD per PR #770 feedback) auto-populates.
     */
    private static WorkLog__c buildLog(Id wiId, Decimal hours, Date workDate) {
        return TestDataFactory.buildWorkLog(wiId, hours, workDate, null);
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

    // ════════════════════════════════════════════════════════════════════
    // getPortfolioPacing — account/org-level pacing across active roots
    // ════════════════════════════════════════════════════════════════════

    /** @description Sum of logged hours across all periods. */
    private static Decimal totalLogged(DeliveryHoursAnalyticsController.PortfolioPacingDTO dto) {
        Decimal sum = 0;
        for (DeliveryHoursAnalyticsController.PacingPeriodDTO p : dto.periods) {
            sum += p.loggedHours;
        }
        return sum;
    }

    @IsTest
    static void testPortfolioPacingBuildsBackAndForwardPeriods() {
        // Two active roots, each with descendants + logs across recent months.
        WorkItem__c rootA = insertWi('PortRootA', 80, Date.today().addMonths(-2), Date.today().addMonths(2), null);
        WorkItem__c childA = insertWi('PortChildA', 20, null, null, rootA.Id);
        WorkItem__c rootB = insertWi('PortRootB', 40, Date.today().addMonths(-1), Date.today().addMonths(1), null);

        insert new List<WorkLog__c>{
            buildLog(rootA.Id, 5, Date.today()),
            buildLog(childA.Id, 3, Date.today().addMonths(-1)),
            buildLog(rootB.Id, 7, Date.today())
        };

        Test.startTest();
        DeliveryHoursAnalyticsController.PortfolioPacingDTO dto =
            DeliveryHoursAnalyticsController.getPortfolioPacing('Month', 6, 3);
        Test.stopTest();

        System.assertNotEquals(null, dto, 'DTO must not be null');
        System.assertEquals('Month', dto.granularity, 'Granularity echoed');
        System.assertEquals(9, dto.periods.size(), '6 history + 3 forecast = 9 periods');
        System.assertEquals(2, dto.rootCount, 'Two active roots in scope');

        Integer forecastCount = 0;
        for (DeliveryHoursAnalyticsController.PacingPeriodDTO p : dto.periods) {
            if (p.isForecast) {
                forecastCount++;
            }
        }
        System.assertEquals(3, forecastCount, 'Last 3 periods flagged as forecast');

        // 5 + 3 + 7 = 15h logged across the window.
        System.assertEquals(15, totalLogged(dto), 'Portfolio logged hours summed across roots + descendants');
        System.assertEquals(140, dto.totalEstimatedHours, 'Estimate summed across the portfolio tree');
    }

    @IsTest
    static void testPortfolioPacingForecastPresentOnForwardPeriods() {
        WorkItem__c root = insertWi('FcRoot', 200, Date.today().addMonths(-3), Date.today().addMonths(6), null);
        // Log meaningful recent hours so the run-rate is non-zero.
        insert new List<WorkLog__c>{
            buildLog(root.Id, 10, Date.today()),
            buildLog(root.Id, 10, Date.today().addMonths(-1)),
            buildLog(root.Id, 10, Date.today().addMonths(-2))
        };

        Test.startTest();
        DeliveryHoursAnalyticsController.PortfolioPacingDTO dto =
            DeliveryHoursAnalyticsController.getPortfolioPacing('Month', 6, 3);
        Test.stopTest();

        System.assert(dto.runRateHoursPerPeriod > 0, 'Run-rate should be positive given recent logs');

        Decimal forwardForecast = 0;
        for (DeliveryHoursAnalyticsController.PacingPeriodDTO p : dto.periods) {
            if (p.isForecast) {
                forwardForecast += p.forecastHours;
            } else {
                System.assertEquals(0, p.forecastHours, 'History periods carry no forecast');
            }
        }
        System.assert(forwardForecast > 0, 'Forward periods should carry forecast hours');
        System.assert(dto.projectedFinalHours >= dto.totalLoggedHours,
            'Projected final >= logged hours');
    }

    @IsTest
    static void testPortfolioForecastCappedAtRemainingEstimate() {
        // Small estimate, high recent run-rate → forecast must cap at remaining scope.
        WorkItem__c root = insertWi('CapRoot', 30, Date.today().addMonths(-2), Date.today().addMonths(4), null);
        insert new List<WorkLog__c>{
            buildLog(root.Id, 20, Date.today()),
            buildLog(root.Id, 20, Date.today().addMonths(-1))
        };

        Test.startTest();
        DeliveryHoursAnalyticsController.PortfolioPacingDTO dto =
            DeliveryHoursAnalyticsController.getPortfolioPacing('Month', 6, 12);
        Test.stopTest();

        // totalLogged ~40 already exceeds the 30 estimate → remaining clamps to 0 → no forecast added.
        Decimal forwardForecast = 0;
        for (DeliveryHoursAnalyticsController.PacingPeriodDTO p : dto.periods) {
            if (p.isForecast) {
                forwardForecast += p.forecastHours;
            }
        }
        System.assertEquals(0, forwardForecast,
            'When logged already exceeds estimate, forecast caps at 0');
        System.assertEquals(true, dto.isOverBudgetTrajectory,
            'Logged past estimate → over-budget trajectory');
    }

    @IsTest
    static void testPortfolioPacingQuarterGranularity() {
        WorkItem__c root = insertWi('QRoot', 90, Date.today().addMonths(-6), Date.today().addMonths(6), null);
        insert new List<WorkLog__c>{
            buildLog(root.Id, 8, Date.today()),
            buildLog(root.Id, 4, Date.today().addMonths(-4))
        };

        Test.startTest();
        DeliveryHoursAnalyticsController.PortfolioPacingDTO dto =
            DeliveryHoursAnalyticsController.getPortfolioPacing('Quarter', 4, 2);
        Test.stopTest();

        System.assertEquals('Quarter', dto.granularity, 'Quarter granularity echoed');
        System.assertEquals(6, dto.periods.size(), '4 history + 2 forecast quarters');
        for (DeliveryHoursAnalyticsController.PacingPeriodDTO p : dto.periods) {
            System.assert(p.label.startsWith('Q'), 'Quarter labels start with Q: ' + p.label);
        }
        // Both logs fall inside the 4-quarter back window → 12h total.
        System.assertEquals(12, totalLogged(dto), 'Both logs land inside the quarter window');
    }

    @IsTest
    static void testPortfolioPacingWeekGranularity() {
        WorkItem__c root = insertWi('WkRoot', 50, Date.today().addDays(-30), Date.today().addDays(30), null);
        insert new List<WorkLog__c>{
            buildLog(root.Id, 6, Date.today()),
            buildLog(root.Id, 3, Date.today().addDays(-7))
        };

        Test.startTest();
        DeliveryHoursAnalyticsController.PortfolioPacingDTO dto =
            DeliveryHoursAnalyticsController.getPortfolioPacing('Week', 8, 4);
        Test.stopTest();

        System.assertEquals('Week', dto.granularity, 'Week granularity echoed');
        System.assertEquals(12, dto.periods.size(), '8 history + 4 forecast weeks');
        System.assertEquals(9, totalLogged(dto), 'This week 6h + last week 3h = 9h');
    }

    @IsTest
    static void testPortfolioPacingDefaultsAndClamps() {
        insertWi('DefRoot', 10, null, null, null);

        Test.startTest();
        DeliveryHoursAnalyticsController.PortfolioPacingDTO defaults =
            DeliveryHoursAnalyticsController.getPortfolioPacing(null, null, null);
        DeliveryHoursAnalyticsController.PortfolioPacingDTO clamped =
            DeliveryHoursAnalyticsController.getPortfolioPacing('bogus', 1000, 1000);
        Test.stopTest();

        System.assertEquals('Month', defaults.granularity, 'Null granularity defaults to Month');
        System.assertEquals(9, defaults.periods.size(), 'Defaults: 6 back + 3 forward');
        System.assert(clamped.periods.size() <= 60,
            'Total periods clamped to MAX_PERIODS=60, got ' + clamped.periods.size());
    }

    @IsTest
    static void testPortfolioTargetAmortizedAcrossPeriods() {
        // Single root with a clean 1-month plan span → target concentrates in that month.
        Date startDate = Date.newInstance(Date.today().year(), Date.today().month(), 1);
        Date endDate = startDate.addMonths(1).addDays(-1);
        insertWi('TgtRoot', 60, startDate, endDate, null);

        Test.startTest();
        DeliveryHoursAnalyticsController.PortfolioPacingDTO dto =
            DeliveryHoursAnalyticsController.getPortfolioPacing('Month', 6, 3);
        Test.stopTest();

        System.assertEquals(true, dto.hasEstimate, 'Estimate present');
        Decimal targetSum = 0;
        for (DeliveryHoursAnalyticsController.PacingPeriodDTO p : dto.periods) {
            targetSum += p.targetHours;
        }
        System.assert(targetSum > 0, 'Some target hours allocated across the planned span');
    }

    @IsTest
    static void testPortfolioBlendedRateWhenSingleActiveRate() {
        insertWi('RateRoot', 20, null, null, null);
        TestDataFactory.createNetworkEntity(new Map<String, Object>{
            'EntityTypePk__c' => 'Client',
            'DefaultHourlyRateCurrency__c' => 125
        });

        Test.startTest();
        DeliveryHoursAnalyticsController.PortfolioPacingDTO dto =
            DeliveryHoursAnalyticsController.getPortfolioPacing('Month', 6, 3);
        Test.stopTest();

        System.assertEquals(125, dto.blendedRate,
            'Single active rated NetworkEntity surfaces as the blended rate');
    }

    @IsTest
    static void testPortfolioBlendedRateNullWhenAmbiguous() {
        insertWi('RateRoot2', 20, null, null, null);
        TestDataFactory.createNetworkEntity(new Map<String, Object>{
            'DefaultHourlyRateCurrency__c' => 100
        });
        TestDataFactory.createNetworkEntity(new Map<String, Object>{
            'DefaultHourlyRateCurrency__c' => 200
        });

        Test.startTest();
        DeliveryHoursAnalyticsController.PortfolioPacingDTO dto =
            DeliveryHoursAnalyticsController.getPortfolioPacing('Month', 6, 3);
        Test.stopTest();

        System.assertEquals(null, dto.blendedRate,
            'Multiple distinct rates → ambiguous → null blended rate');
    }

    @IsTest
    static void testPortfolioExcludesTerminalAndArchivedRoots() {
        // Active root counts; terminal-stage + archived roots are excluded from scope.
        insertWi('LiveRoot', 10, null, null, null);
        WorkItem__c doneRoot = insertWi('DoneRoot', 10, null, null, null);
        WorkItem__c archived = insertWi('ArchivedRoot', 10, null, null, null);
        // Mutate state via a trigger-bypassed update so the test isolates the
        // scope filter from auto-WR / sync side effects.
        Boolean prev = DeliveryWorkItemTriggerHandler.triggerDisabled;
        DeliveryWorkItemTriggerHandler.triggerDisabled = true;
        try {
            doneRoot.StageNamePk__c = 'Done';
            archived.ArchivedDateTime__c = Datetime.now();
            update new List<WorkItem__c>{ doneRoot, archived };
        } finally {
            DeliveryWorkItemTriggerHandler.triggerDisabled = prev;
        }

        Test.startTest();
        DeliveryHoursAnalyticsController.PortfolioPacingDTO dto =
            DeliveryHoursAnalyticsController.getPortfolioPacing('Month', 6, 3);
        Test.stopTest();

        System.assertEquals(1, dto.rootCount,
            'Only the live, non-terminal, non-archived root is in scope');
    }

    @IsTest
    static void testPortfolioPacingEmptyOrgReturnsSkeleton() {
        // No WorkItems at all — should still return a well-formed skeleton.
        Test.startTest();
        DeliveryHoursAnalyticsController.PortfolioPacingDTO dto =
            DeliveryHoursAnalyticsController.getPortfolioPacing('Month', 6, 3);
        Test.stopTest();

        System.assertEquals(0, dto.rootCount, 'No roots');
        System.assertEquals(9, dto.periods.size(), 'Skeleton still built');
        System.assertEquals(0, totalLogged(dto), 'No logged hours');
        System.assertEquals(false, dto.hasEstimate, 'No estimate');
    }

    // ════════════════════════════════════════════════════════════════════
    // Schedule-based forecast + accurate (all-scope) actuals
    // ════════════════════════════════════════════════════════════════════

    /**
     * @description CHANGE 1: actuals count ALL WorkLog hours — including logs on a
     *              terminal (completed) WorkItem that the active-portfolio scope
     *              would have dropped. The historical bars + totalLoggedHours must
     *              include the completed item's hours.
     */
    @IsTest
    static void testActualsCountAllHoursIncludingCompletedWork() {
        // One active root with an in-window log.
        WorkItem__c liveRoot = insertWi('LiveActuals', 40, Date.today().addMonths(-1), Date.today().addMonths(2), null);
        // One COMPLETED (terminal) root — excluded from the active scope, but its
        // logged hours must STILL count toward the actuals.
        WorkItem__c doneRoot = insertWi('DoneActuals', 20, null, null, null);

        insert new List<WorkLog__c>{
            buildLog(liveRoot.Id, 5, Date.today()),
            buildLog(doneRoot.Id, 8, Date.today())
        };

        // Flip the completed root to a terminal stage post-insert (trigger-bypassed).
        Boolean prev = DeliveryWorkItemTriggerHandler.triggerDisabled;
        DeliveryWorkItemTriggerHandler.triggerDisabled = true;
        try {
            doneRoot.StageNamePk__c = 'Done';
            update doneRoot;
        } finally {
            DeliveryWorkItemTriggerHandler.triggerDisabled = prev;
        }

        Test.startTest();
        DeliveryHoursAnalyticsController.PortfolioPacingDTO dto =
            DeliveryHoursAnalyticsController.getPortfolioPacing('Month', 6, 3);
        Test.stopTest();

        // Only the live root is "in scope", but actuals count BOTH logs = 13h.
        System.assertEquals(1, dto.rootCount, 'Only the live root is an active root');
        System.assertEquals(13, dto.totalLoggedHours,
            'Actuals count ALL hours (5 live + 8 completed), not just active-scope');
        System.assertEquals(13, totalLogged(dto),
            'Per-period bars also count the completed item\'s hours');
    }

    /**
     * @description CHANGE 2: a single in-flight item with 60h remaining and a
     *              2-month forward schedule spreads ~30h into each of the two
     *              covered forecast months — not a flat run-rate.
     */
    @IsTest
    static void testScheduleSpreadPlacesRemainingAcrossCoveredMonths() {
        // Estimate 60h, no logs yet → 60h remaining. Schedule starts this month and
        // ends ~2 months out so it covers the first two forward periods.
        Date start = Date.today().toStartOfMonth();
        Date theEnd = start.addMonths(2).addDays(-1); // spans current + next month region
        insertWi('SpreadItem', 60, start, theEnd, null);

        Test.startTest();
        DeliveryHoursAnalyticsController.PortfolioPacingDTO dto =
            DeliveryHoursAnalyticsController.getPortfolioPacing('Month', 6, 4);
        Test.stopTest();

        System.assertEquals(0, dto.unscheduledRemainingHours,
            'Dated item is fully schedulable — nothing unscheduled');
        System.assertEquals(60, dto.totalRemainingHours, 'Remaining = full 60h estimate');

        // Sum forecast across forward periods = the full remaining (60h).
        Decimal forwardForecast = 0;
        Integer touchedPeriods = 0;
        for (DeliveryHoursAnalyticsController.PacingPeriodDTO p : dto.periods) {
            if (p.isForecast && p.forecastHours > 0) {
                forwardForecast += p.forecastHours;
                touchedPeriods++;
            }
        }
        System.assertEquals(60, forwardForecast,
            'All 60h remaining is placed across the forward schedule');
        System.assert(touchedPeriods >= 1 && touchedPeriods <= 3,
            'Remaining spread across the covered forward months, got ' + touchedPeriods);
    }

    /**
     * @description CHANGE 2 (unscheduled bucket): an in-flight item with an estimate
     *              but NO usable start/end dates can't be placed on the calendar, so
     *              its remaining accumulates into unscheduledRemainingHours instead
     *              of being silently dropped.
     */
    @IsTest
    static void testUnscheduledBucketCapturesUndatedRemaining() {
        // 50h estimate, no logs, NO dates → 50h unscheduled.
        insertWi('UndatedItem', 50, null, null, null);

        Test.startTest();
        DeliveryHoursAnalyticsController.PortfolioPacingDTO dto =
            DeliveryHoursAnalyticsController.getPortfolioPacing('Month', 6, 3);
        Test.stopTest();

        System.assertEquals(50, dto.unscheduledRemainingHours,
            'Un-dated remaining lands in the unscheduled bucket');
        System.assertEquals(50, dto.totalRemainingHours, 'Remaining still counted in the total');

        Decimal forwardForecast = 0;
        for (DeliveryHoursAnalyticsController.PacingPeriodDTO p : dto.periods) {
            if (p.isForecast) {
                forwardForecast += p.forecastHours;
            }
        }
        System.assertEquals(0, forwardForecast,
            'Nothing placed on the forecast bars — it is all unscheduled');
    }

    /**
     * @description An in-flight item whose end date is in the PAST cannot be placed
     *              forward, so its remaining also routes to the unscheduled bucket.
     */
    @IsTest
    static void testPastDueRemainingIsUnscheduled() {
        // Estimate 30h, schedule entirely in the past → 30h unscheduled.
        insertWi('PastDue', 30, Date.today().addMonths(-4), Date.today().addMonths(-2), null);

        Test.startTest();
        DeliveryHoursAnalyticsController.PortfolioPacingDTO dto =
            DeliveryHoursAnalyticsController.getPortfolioPacing('Month', 6, 3);
        Test.stopTest();

        System.assertEquals(30, dto.unscheduledRemainingHours,
            'A past-due schedule cannot be placed forward — remaining is unscheduled');
    }

    /**
     * @description CHANGE 2 headline: projectedFinalHours == totalLoggedHours +
     *              Σ remaining across all in-flight items, and remaining nets out
     *              logged-so-far (summed from WorkLogs).
     */
    @IsTest
    static void testProjectedFinalEqualsLoggedPlusRemaining() {
        // Item: 100h estimate, 30h already logged → 70h remaining.
        WorkItem__c item = insertWi('NetItem', 100, Date.today().toStartOfMonth(), Date.today().addMonths(2), null);
        insert new List<WorkLog__c>{
            buildLog(item.Id, 20, Date.today()),
            buildLog(item.Id, 10, Date.today().addDays(-3))
        };

        Test.startTest();
        DeliveryHoursAnalyticsController.PortfolioPacingDTO dto =
            DeliveryHoursAnalyticsController.getPortfolioPacing('Month', 6, 4);
        Test.stopTest();

        System.assertEquals(30, dto.totalLoggedHours, 'All logged hours counted (20 + 10)');
        System.assertEquals(70, dto.totalRemainingHours,
            'Remaining nets logged-so-far: 100 estimate - 30 logged = 70');
        System.assertEquals(100, dto.projectedFinalHours,
            'Projected final = 30 logged + 70 remaining = 100');
    }

    /**
     * @description Remaining clamps at 0 when logged-so-far already exceeds the
     *              estimate — an over-logged item adds no remaining, and the
     *              over-budget trajectory flag fires off the all-scope logged total.
     */
    @IsTest
    static void testOverLoggedItemAddsNoRemaining() {
        // 10h estimate but 25h logged → remaining clamps to 0.
        WorkItem__c item = insertWi('OverLogged', 10, Date.today().toStartOfMonth(), Date.today().addMonths(1), null);
        insert buildLog(item.Id, 25, Date.today());

        Test.startTest();
        DeliveryHoursAnalyticsController.PortfolioPacingDTO dto =
            DeliveryHoursAnalyticsController.getPortfolioPacing('Month', 6, 3);
        Test.stopTest();

        System.assertEquals(0, dto.totalRemainingHours, 'Over-logged item contributes 0 remaining');
        System.assertEquals(25, dto.projectedFinalHours,
            'Projected final = 25 logged + 0 remaining');
        System.assertEquals(true, dto.isOverBudgetTrajectory,
            'Logged past estimate → over-budget trajectory');
    }
}

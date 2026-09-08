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

        // 5 + 3 + 7 = 15h logged across the window (logged stays INCLUSIVE — real WorkLog
        // history is never a parent↔child rollup, so it isn't leaf-filtered).
        System.assertEquals(15, totalLogged(dto), 'Portfolio logged hours summed across roots + descendants');
        // Leaf-only (0.269): rootA (80h) is a CONTAINER parent of childA, so its rollup
        // estimate is excluded; only leaves count = childA(20) + rootB(40) = 60.
        System.assertEquals(60, dto.totalEstimatedHours,
            'Leaf-only: container parent rootA excluded; childA 20 + rootB 40 = 60');
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
    static void testProjectedFinalCountsRemainingBeyondWindow() {
        // Large estimate with most remaining work falling FAR beyond the 3-period
        // forward window. Recent logs are small, so the windowed run-rate forecast
        // can only spread a few hours across the 3 forward periods — the OLD headline
        // (logged + windowed cumulativeForecast) would badly undercount. The FIXED
        // headline = logged + ALL remaining = ~estimate when on-budget.
        WorkItem__c root = insertWi('LongRunRoot', 1000, Date.today().addMonths(-1), Date.today().addMonths(24), null);
        insert new List<WorkLog__c>{
            buildLog(root.Id, 30, Date.today()),
            buildLog(root.Id, 20, Date.today().addMonths(-1))
        };

        Test.startTest();
        DeliveryHoursAnalyticsController.PortfolioPacingDTO dto =
            DeliveryHoursAnalyticsController.getPortfolioPacing('Month', 6, 3);
        Test.stopTest();

        // 50h logged, estimate 1000 → remaining 950 → on-budget projected ≈ estimate.
        System.assertEquals(50, dto.totalLoggedHours, '30 + 20 = 50h logged');
        System.assertEquals(1000, dto.totalEstimatedHours, 'Single 1000h estimate');

        // Headline must count the full out-of-window remaining (950h), NOT just the
        // 3-period windowed forecast — so projected ≈ logged + remaining ≈ estimate.
        System.assertEquals(1000, dto.projectedFinalHours,
            'Projected final = logged(50) + all remaining(950) = 1000 ≈ estimate, ' +
            'independent of the 3-period display window');
        System.assertEquals(false, dto.isOverBudgetTrajectory,
            'On-budget (projected == estimate) is NOT an over-budget trajectory');

        // Sanity: the windowed forecast bars are a tiny fraction of remaining — proving
        // the headline did NOT come from cumulativeForecast (the old, buggy source).
        Decimal forwardForecast = 0;
        for (DeliveryHoursAnalyticsController.PacingPeriodDTO p : dto.periods) {
            if (p.isForecast) {
                forwardForecast += p.forecastHours;
            }
        }
        System.assert(dto.projectedFinalHours > dto.totalLoggedHours + forwardForecast,
            'Headline exceeds logged + windowed forecast, confirming out-of-window ' +
            'remaining is counted (was the bug: ' + forwardForecast + ' windowed vs 950 total)');
    }

    @IsTest
    static void testProjectedFinalExceedsEstimateOnlyWhenOverBudget() {
        // One on-budget item (200 est / 50 logged → 150 remaining) plus one genuinely
        // over-budget item (40 est / 100 logged → 0 remaining, floored). Projected =
        // logged(150) + remaining(150 + 0) = 300; estimate = 240 → over-budget because
        // the over-budget item's logged is already counted while its remaining floors at 0.
        WorkItem__c onBudget = insertWi('OnBudget', 200, Date.today().addMonths(-1), Date.today().addMonths(6), null);
        WorkItem__c overBudget = insertWi('OverBudget', 40, Date.today().addMonths(-1), Date.today().addMonths(1), null);
        insert new List<WorkLog__c>{
            buildLog(onBudget.Id, 50, Date.today()),
            buildLog(overBudget.Id, 100, Date.today())
        };

        Test.startTest();
        DeliveryHoursAnalyticsController.PortfolioPacingDTO dto =
            DeliveryHoursAnalyticsController.getPortfolioPacing('Month', 6, 3);
        Test.stopTest();

        System.assertEquals(150, dto.totalLoggedHours, '50 + 100 = 150h logged');
        System.assertEquals(240, dto.totalEstimatedHours, '200 + 40 = 240h estimate');
        // remaining = max(0, 200-50) + max(0, 40-100) = 150 + 0 = 150.
        System.assertEquals(300, dto.projectedFinalHours,
            'logged(150) + remaining(150) = 300 — over-budget item floors remaining at 0 ' +
            'but its logged still counts');
        System.assertEquals(true, dto.isOverBudgetTrajectory,
            'Projected 300 > estimate 240 → over-budget trajectory');
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
    static void testPortfolioScopeExcludesNonActiveAndTemplateDescendants() {
        // The pacing item universe must match the board's canonical "Active"
        // definition (DeliveryGanttController.getProFormaTimelineData with
        // showCompleted=false): ActivatedDateTime__c != null AND
        // TemplateMarkedDateTime__c = null. Before the collectPortfolioTree
        // gate, the BFS pulled in EVERY descendant regardless of activation /
        // template state, inflating the forecast's active-item universe above
        // the board count (the live 99-vs-95 drift on MF prod).
        WorkItem__c root = insertWi('ScopeRoot', 50, Date.today().addMonths(-1), Date.today().addMonths(1), null);
        // Activated, non-template child — IN scope (counts toward totals).
        WorkItem__c activeChild = insertWi('ScopeActiveChild', 20, null, null, root.Id);
        // Non-activated child — the board never draws it, so it must be OUT.
        WorkItem__c inactiveChild = TestDataFactory.createWorkItem(new Map<String, Object>{
            'BriefDescriptionTxt__c' => 'ScopeInactiveChild',
            'EstimatedHoursNumber__c' => 999,
            'ParentWorkItemLookup__c' => root.Id,
            'ActivatedDateTime__c' => null
        });
        // Template-marked child — also OUT regardless of activation.
        WorkItem__c templateChild = TestDataFactory.createWorkItem(new Map<String, Object>{
            'BriefDescriptionTxt__c' => 'ScopeTemplateChild',
            'EstimatedHoursNumber__c' => 777,
            'ParentWorkItemLookup__c' => root.Id,
            'TemplateMarkedDateTime__c' => Datetime.now()
        });

        insert new List<WorkLog__c>{
            buildLog(root.Id, 4, Date.today()),
            buildLog(activeChild.Id, 6, Date.today()),
            // Logs on the excluded children must NOT surface in the portfolio.
            buildLog(inactiveChild.Id, 50, Date.today()),
            buildLog(templateChild.Id, 50, Date.today())
        };

        Test.startTest();
        DeliveryHoursAnalyticsController.PortfolioPacingDTO dto =
            DeliveryHoursAnalyticsController.getPortfolioPacing('Month', 6, 3);
        Test.stopTest();

        // Scope = root + activeChild, but the 0.269 LEAF-ONLY rule counts only
        // items with no in-scope child — the root is a container parent of the
        // in-scope activeChild, so its 50 is a planning rollup and contributes
        // nothing. In-scope leaves = activeChild = 20. The 999 + 777 from the
        // non-active / template children stay fully excluded.
        System.assertEquals(20, dto.totalEstimatedHours,
            'Estimate counts in-scope leaves only and excludes non-activated + template descendants');
        // Only root (4) + activeChild (6) logged = 10. The 50 + 50 are excluded.
        System.assertEquals(10, dto.totalLoggedHours,
            'Logged hours must exclude non-activated + template descendants');
        System.assertEquals(10, totalLogged(dto),
            'Per-period logged hours must exclude the off-scope children too');
        // Root is the only active root in scope.
        System.assertEquals(1, dto.rootCount, 'One active root in scope');
    }

    @IsTest
    static void testPortfolioScopeKeepsActivatedGrandchildUnderInactiveParent() {
        // The walk follows EVERY child link (so traversal is never cut by a
        // non-active mid-tree parent), but only board-active descendants join
        // the scope. An activated grandchild under a non-activated parent stays
        // reachable — mirroring the board's flat, parent-state-independent view.
        WorkItem__c root = insertWi('GcRoot', 10, null, null, null);
        WorkItem__c inactiveParent = TestDataFactory.createWorkItem(new Map<String, Object>{
            'BriefDescriptionTxt__c' => 'GcInactiveParent',
            'EstimatedHoursNumber__c' => 999,
            'ParentWorkItemLookup__c' => root.Id,
            'ActivatedDateTime__c' => null
        });
        // Activated grandchild — board would draw it; must be IN scope.
        WorkItem__c activeGrandchild = insertWi('GcActiveGrandchild', 15, null, null, inactiveParent.Id);

        insert new List<WorkLog__c>{
            buildLog(root.Id, 2, Date.today()),
            buildLog(activeGrandchild.Id, 5, Date.today())
        };

        Test.startTest();
        DeliveryHoursAnalyticsController.PortfolioPacingDTO dto =
            DeliveryHoursAnalyticsController.getPortfolioPacing('Month', 6, 3);
        Test.stopTest();

        // root (10) + activeGrandchild (15) = 25; the inactive parent's 999 is out.
        System.assertEquals(25, dto.totalEstimatedHours,
            'Activated grandchild stays in scope; inactive mid-tree parent stays out');
        System.assertEquals(7, dto.totalLoggedHours,
            'root 2h + grandchild 5h = 7h; inactive parent contributes nothing');
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

    // ────────────────────────────────────────────────────────────────────
    // Schedule-based forecast — each item's remaining spread over its OWN dates
    // ────────────────────────────────────────────────────────────────────

    /** @description Sum of forecastHours across the forecast periods. */
    private static Decimal totalForecast(DeliveryHoursAnalyticsController.PortfolioPacingDTO dto) {
        Decimal sum = 0;
        for (DeliveryHoursAnalyticsController.PacingPeriodDTO p : dto.periods) {
            if (p.isForecast) {
                sum += p.forecastHours;
            }
        }
        return sum;
    }

    @IsTest
    static void testScheduleForecastSpreadsRemainingOverOwnFutureDates() {
        // Item planned to start at the first of NEXT month and run for exactly 3
        // forecast months. With back=6, forecast periods are indices 6,7,8 (next,
        // +2, +3 months) and we request 4 forward so index 9 (+4 months) sits BEYOND
        // the item's end. No logs → full estimate is the remaining work to spread.
        Date nextMonthStart = Date.today().toStartOfMonth().addMonths(1);
        Date spanEnd = nextMonthStart.addMonths(3).addDays(-1); // covers next 3 months
        WorkItem__c root = insertWi('SchedRoot', 90, nextMonthStart, spanEnd, null);

        Test.startTest();
        DeliveryHoursAnalyticsController.PortfolioPacingDTO dto =
            DeliveryHoursAnalyticsController.getPortfolioPacing('Month', 6, 4);
        Test.stopTest();

        // Index map: 0-5 history (5 = current month), 6/7/8 = next/+2/+3, 9 = +4.
        List<DeliveryHoursAnalyticsController.PacingPeriodDTO> periods = dto.periods;
        System.assertEquals(10, periods.size(), '6 history + 4 forecast = 10 periods');

        // The first three forecast periods (overlapping the span) each carry a positive
        // proportional share; the fourth (beyond the item's end) carries ~0.
        System.assert(periods[6].forecastHours > 0, 'Next month overlaps span → forecast > 0');
        System.assert(periods[7].forecastHours > 0, '+2 months overlaps span → forecast > 0');
        System.assert(periods[8].forecastHours > 0, '+3 months overlaps span → forecast > 0');
        System.assertEquals(0, periods[9].forecastHours,
            'Period beyond the item end carries no forecast (NOT a flat run-rate spread)');

        // Sum of placed forecast ≈ the full 90h remaining (current month is the FIRST
        // of the planned span, but the item starts next month so nothing is lost to the
        // current/history period — the whole span lands in forecast periods).
        Decimal placed = totalForecast(dto);
        System.assert(placed >= 89.9 && placed <= 90.1,
            'Placed forecast sums to ~90h remaining across the 3 overlapping periods, got ' + placed);

        // Nothing unscheduled — the item has dates and its window is in the future.
        System.assertEquals(0, dto.unscheduledRemainingHours,
            'Dated, future-windowed item is fully scheduled');
    }

    @IsTest
    static void testScheduleForecastPartialLoggedSpreadsOnlyRemaining() {
        // Estimate 100, 40 already logged → 60 remaining spread over the item's future.
        Date nextMonthStart = Date.today().toStartOfMonth().addMonths(1);
        Date spanEnd = nextMonthStart.addMonths(2).addDays(-1); // next 2 months
        WorkItem__c root = insertWi('PartialRoot', 100, nextMonthStart, spanEnd, null);
        insert buildLog(root.Id, 40, Date.today());

        Test.startTest();
        DeliveryHoursAnalyticsController.PortfolioPacingDTO dto =
            DeliveryHoursAnalyticsController.getPortfolioPacing('Month', 6, 4);
        Test.stopTest();

        Decimal placed = totalForecast(dto);
        System.assert(placed >= 59.9 && placed <= 60.1,
            'Only the 60h REMAINING is spread (not the full 100h estimate), got ' + placed);
        System.assertEquals(0, dto.unscheduledRemainingHours, 'Future-dated item is scheduled');
    }

    @IsTest
    static void testNoDatesItemRemainingGoesToUnscheduledNotBars() {
        // Item with an estimate + remaining work but NO start/end dates cannot be
        // placed on the future timeline → its remaining goes to unscheduled, NOT bars.
        insertWi('NoDatesRoot', 50, null, null, null);

        Test.startTest();
        DeliveryHoursAnalyticsController.PortfolioPacingDTO dto =
            DeliveryHoursAnalyticsController.getPortfolioPacing('Month', 6, 4);
        Test.stopTest();

        System.assertEquals(0, totalForecast(dto),
            'No-date item contributes nothing to period bars');
        System.assertEquals(50, dto.unscheduledRemainingHours,
            'Full 50h remaining accrues to the unscheduled total');
    }

    @IsTest
    static void testOverdueItemRemainingGoesToUnscheduled() {
        // Item whose planned end is already in the PAST while work remains (overdue):
        // its window has elapsed, so remaining can't sit on the future timeline.
        Date pastStart = Date.today().toStartOfMonth().addMonths(-4);
        Date pastEnd = Date.today().toStartOfMonth().addMonths(-2).addDays(-1);
        insertWi('OverdueRoot', 80, pastStart, pastEnd, null);

        Test.startTest();
        DeliveryHoursAnalyticsController.PortfolioPacingDTO dto =
            DeliveryHoursAnalyticsController.getPortfolioPacing('Month', 6, 4);
        Test.stopTest();

        System.assertEquals(0, totalForecast(dto),
            'Overdue item (end < today) contributes nothing to FUTURE bars');
        System.assertEquals(80, dto.unscheduledRemainingHours,
            'Overdue remaining accrues to the unscheduled total');
    }

    @IsTest
    static void testPlacedForecastPlusUnscheduledApproximatesTotalRemaining() {
        // Mix: one future-dated item (spreads onto bars) + one no-date item
        // (unscheduled). placed + unscheduled ≈ total remaining (within rounding).
        Date nextMonthStart = Date.today().toStartOfMonth().addMonths(1);
        Date spanEnd = nextMonthStart.addMonths(2).addDays(-1);
        WorkItem__c scheduled = insertWi('MixSched', 90, nextMonthStart, spanEnd, null);
        insertWi('MixNoDate', 30, null, null, null);
        // 20h logged on the scheduled item → its remaining is 70; no-date remaining 30.
        insert buildLog(scheduled.Id, 20, Date.today());

        Test.startTest();
        DeliveryHoursAnalyticsController.PortfolioPacingDTO dto =
            DeliveryHoursAnalyticsController.getPortfolioPacing('Month', 6, 4);
        Test.stopTest();

        Decimal placed = totalForecast(dto);
        Decimal unscheduled = dto.unscheduledRemainingHours;
        // Total remaining = (90-20) + 30 = 100.
        Decimal totalRemaining = (dto.totalEstimatedHours - dto.totalLoggedHours);
        System.assertEquals(120, dto.totalEstimatedHours, '90 + 30 estimate');
        System.assertEquals(20, dto.totalLoggedHours, '20h logged');
        System.assertEquals(100, totalRemaining, 'remaining = 100');
        System.assert(unscheduled >= 29.95 && unscheduled <= 30.05,
            'No-date item 30h is unscheduled, got ' + unscheduled);
        System.assert((placed + unscheduled) >= 99.9 && (placed + unscheduled) <= 100.1,
            'placed(' + placed + ') + unscheduled(' + unscheduled + ') ≈ total remaining(100)');
    }

    // ────────────────────────────────────────────────────────────────────
    // getPacing — PacingData JSON serialization for the NG in-gantt subtab
    // ────────────────────────────────────────────────────────────────────

    @SuppressWarnings('PMD.ApexUnitTestClassShouldHaveAsserts')
    @IsTest
    static void testGetPacingSerializesPacingDataShape() {
        WorkItem__c root = insertWi('PacingRoot', 80, Date.today().addMonths(-2), Date.today().addMonths(2), null);
        insert new List<WorkLog__c>{
            buildLog(root.Id, 6, Date.today()),
            buildLog(root.Id, 4, Date.today().addMonths(-1))
        };

        Test.startTest();
        String pacingJson = DeliveryHoursAnalyticsController.getPacing('Week', 6, 6);
        Test.stopTest();

        System.assertNotEquals(null, pacingJson, 'getPacing returns a JSON string');
        Map<String, Object> data = (Map<String, Object>) JSON.deserializeUntyped(pacingJson);
        System.assertEquals('week', (String) data.get('bucket'), 'Granularity Week -> bucket "week"');
        System.assertEquals(true, (Boolean) data.get('authoritative'), 'PacingData marked authoritative');

        List<Object> buckets = (List<Object>) data.get('buckets');
        System.assertNotEquals(null, buckets, 'buckets present');
        System.assert(!buckets.isEmpty(), 'at least one bucket built');
        Map<String, Object> b0 = (Map<String, Object>) buckets[0];
        // Contract keys NG's renderer reads.
        System.assert(b0.containsKey('key'), 'bucket has key');
        System.assert(b0.containsKey('actual'), 'bucket has actual');
        System.assert(b0.containsKey('forecast'), 'bucket has forecast');
        System.assert(b0.containsKey('target'), 'bucket has target');
        System.assert(b0.containsKey('isPast'), 'bucket has isPast');
        System.assert(b0.containsKey('items'), 'bucket has items[] (forecast periods composed server-side)');

        Map<String, Object> summary = (Map<String, Object>) data.get('summary');
        System.assertNotEquals(null, summary, 'summary present');
        System.assertEquals(80, ((Decimal) summary.get('estimatedHours')), 'estimate summed');
        System.assertEquals(10, ((Decimal) summary.get('loggedHours')), 'logged summed (6 + 4)');
        System.assertEquals(1, ((Integer) summary.get('activeItems')), 'one active root');
    }

    @IsTest
    static void testGetPacingSurfacesUnscheduledHours() {
        // A no-date item with remaining work must surface in summary.unscheduledHours.
        insertWi('JsonNoDate', 45, null, null, null);

        Test.startTest();
        String pacingJson = DeliveryHoursAnalyticsController.getPacing('Month', 6, 3);
        Test.stopTest();

        Map<String, Object> data = (Map<String, Object>) JSON.deserializeUntyped(pacingJson);
        Map<String, Object> summary = (Map<String, Object>) data.get('summary');
        System.assertEquals(45, ((Decimal) summary.get('unscheduledHours')),
            'No-date remaining work surfaces as summary.unscheduledHours');
    }

    @IsTest
    static void testGetPacingEmptyOrgStillReturnsJson() {
        Test.startTest();
        String pacingJson = DeliveryHoursAnalyticsController.getPacing('Month', 6, 3);
        Test.stopTest();

        System.assertNotEquals(null, pacingJson, 'JSON returned even with no data');
        Map<String, Object> data = (Map<String, Object>) JSON.deserializeUntyped(pacingJson);
        System.assertEquals('month', (String) data.get('bucket'), 'default-ish month bucket');
        Map<String, Object> summary = (Map<String, Object>) data.get('summary');
        System.assertEquals(0, ((Integer) summary.get('activeItems')), 'no active roots');
    }

    // ────────────────────────────────────────────────────────────────────
    // getPacing — per-period drill-down items[] (schedule-based composition)
    // ────────────────────────────────────────────────────────────────────

    /** @description Pulls the buckets list out of a getPacing JSON payload. */
    private static List<Object> bucketsOf(String pacingJson) {
        Map<String, Object> data = (Map<String, Object>) JSON.deserializeUntyped(pacingJson);
        return (List<Object>) data.get('buckets');
    }

    /** @description Sums the items[] forecast hours across a bucket. */
    private static Decimal sumBucketItemHours(Map<String, Object> bucket) {
        Decimal sum = 0;
        for (Object o : (List<Object>) bucket.get('items')) {
            sum += (Decimal) ((Map<String, Object>) o).get('hours');
        }
        return sum;
    }

    @IsTest
    static void testForecastBucketHasNonEmptyItemsWithRequiredKeys() {
        // Future-dated item spanning the next 3 months → its forecast buckets carry
        // a per-item drill-down row (the fix: no more "0 items" on a forecast bucket).
        Date nextMonthStart = Date.today().toStartOfMonth().addMonths(1);
        Date spanEnd = nextMonthStart.addMonths(3).addDays(-1);
        insertWi('DrillItem', 90, nextMonthStart, spanEnd, null);

        Test.startTest();
        String pacingJson = DeliveryHoursAnalyticsController.getPacing('Month', 6, 4);
        Test.stopTest();

        Boolean sawForecastWithItems = false;
        for (Object o : bucketsOf(pacingJson)) {
            Map<String, Object> b = (Map<String, Object>) o;
            Decimal forecast = (Decimal) b.get('forecast');
            List<Object> items = (List<Object>) b.get('items');
            if (forecast != null && forecast > 0) {
                System.assert(!items.isEmpty(),
                    'A forecast (forecast>0) bucket now carries a non-empty items[] drill-down');
                sawForecastWithItems = true;
                Map<String, Object> first = (Map<String, Object>) items[0];
                System.assertNotEquals(null, first.get('id'), 'item carries id (WorkItem Id)');
                System.assertNotEquals(null, first.get('hours'), 'item carries hours (this period)');
                System.assertNotEquals(null, first.get('estimatedHours'), 'item carries estimate');
                System.assertNotEquals(null, first.get('loggedHours'), 'item carries logged');
                System.assertNotEquals(null, first.get('remainingHours'), 'item carries remaining');
                System.assertEquals(90, (Decimal) first.get('estimatedHours'), 'estimate echoed');
                System.assertEquals(0, (Decimal) first.get('loggedHours'), 'no logs → 0 logged');
                System.assertEquals(90, (Decimal) first.get('remainingHours'),
                    'remaining = max(0, est − logged)');
            }
        }
        System.assert(sawForecastWithItems, 'At least one forecast bucket had drill-down items');
    }

    @IsTest
    static void testItemAppearsOnlyInPeriodsItSpans() {
        // Item spans EXACTLY the next 3 forecast months (indices 6,7,8 with back=6).
        // It must NOT appear on a forecast period beyond its end (index 9).
        Date nextMonthStart = Date.today().toStartOfMonth().addMonths(1);
        Date spanEnd = nextMonthStart.addMonths(3).addDays(-1);
        insertWi('SpanItem', 60, nextMonthStart, spanEnd, null);

        Test.startTest();
        String pacingJson = DeliveryHoursAnalyticsController.getPacing('Month', 6, 4);
        Test.stopTest();

        List<Object> buckets = bucketsOf(pacingJson);
        System.assertEquals(10, buckets.size(), '6 history + 4 forecast = 10 buckets');
        // Indices 6,7,8 overlap the span → have the item; 9 is beyond end → empty.
        for (Integer i = 6; i <= 8; i++) {
            List<Object> items = (List<Object>) ((Map<String, Object>) buckets[i]).get('items');
            System.assert(!items.isEmpty(),
                'Forecast period ' + i + ' overlaps the span → item present');
        }
        List<Object> beyond = (List<Object>) ((Map<String, Object>) buckets[9]).get('items');
        System.assert(beyond.isEmpty(),
            'Forecast period beyond the item end carries no items[]');
        // History periods (0-5) carry no schedule-based forecast items either.
        for (Integer i = 0; i <= 5; i++) {
            List<Object> items = (List<Object>) ((Map<String, Object>) buckets[i]).get('items');
            System.assert(items.isEmpty(), 'History period ' + i + ' has no forecast items[]');
        }
    }

    @IsTest
    static void testSumOfItemHoursAcrossPeriodsMatchesPlacedRemaining() {
        // One item, partially logged: Σ hoursThisPeriod across its buckets ≈ its
        // placed REMAINING (estimate − logged), within rounding tolerance.
        Date nextMonthStart = Date.today().toStartOfMonth().addMonths(1);
        Date spanEnd = nextMonthStart.addMonths(2).addDays(-1);
        WorkItem__c wi = insertWi('SumItem', 100, nextMonthStart, spanEnd, null);
        insert buildLog(wi.Id, 40, Date.today()); // remaining = 60

        Test.startTest();
        String pacingJson = DeliveryHoursAnalyticsController.getPacing('Month', 6, 4);
        Test.stopTest();

        Decimal totalItemHours = 0;
        for (Object o : bucketsOf(pacingJson)) {
            totalItemHours += sumBucketItemHours((Map<String, Object>) o);
        }
        System.assert(totalItemHours >= 59.8 && totalItemHours <= 60.2,
            'Σ item hoursThisPeriod ≈ placed remaining (60h), got ' + totalItemHours);
    }

    // ────────────────────────────────────────────────────────────────────
    // getPacing — cohort/commitment-tier split (the stacked hockey-stick).
    // Item 8: greenlit (Committed) = APPROVAL TRUTH — an item is greenlit
    // iff ClientPreApprovedHoursNumber__c > 0, regardless of lane.
    // Unapproved items map by lane: top-priority/active/follow-on→predicted,
    // proposed/deferred→ready; blank/unknown→predicted. Per-bucket `segments`
    // sum to forecast; items carry `tier`; top-level segments[] advertises
    // only tiers that carry hours.
    // ────────────────────────────────────────────────────────────────────

    /** @description Active future-dated root WorkItem with an explicit priority lane. */
    private static WorkItem__c insertTieredWi(String briefDesc, Decimal estimate, Date startDate, Date endDate, String priorityGroup) {
        return TestDataFactory.createWorkItem(new Map<String, Object>{
            'BriefDescriptionTxt__c' => briefDesc,
            'EstimatedHoursNumber__c' => estimate,
            'EstimatedStartDevDate__c' => startDate,
            'EstimatedEndDevDate__c' => endDate,
            'PriorityGroupPk__c' => priorityGroup,
            'ActivatedDateTime__c' => System.now()
        });
    }

    /** @description Same as insertTieredWi but client-approved (the greenlit membership signal). */
    @SuppressWarnings('PMD.ExcessiveParameterList')
    private static WorkItem__c insertApprovedWi(String briefDesc, Decimal estimate, Date startDate, Date endDate, String priorityGroup, Decimal approvedHours) {
        return TestDataFactory.createWorkItem(new Map<String, Object>{
            'BriefDescriptionTxt__c' => briefDesc,
            'EstimatedHoursNumber__c' => estimate,
            'EstimatedStartDevDate__c' => startDate,
            'EstimatedEndDevDate__c' => endDate,
            'PriorityGroupPk__c' => priorityGroup,
            'ClientPreApprovedHoursNumber__c' => approvedHours,
            'ActivatedDateTime__c' => System.now()
        });
    }

    /** @description Pulls the top-level segments[] defs out of a getPacing payload. */
    private static List<Object> segmentDefsOf(String pacingJson) {
        Map<String, Object> data = (Map<String, Object>) JSON.deserializeUntyped(pacingJson);
        return (List<Object>) data.get('segments');
    }

    @IsTest
    static void testCohortSplitTiersBucketsAndItems() {
        // Three active roots over the SAME future window → their forecast buckets carry
        // all three commitment tiers. Greenlit = client-approved (item 8); the other
        // two map from PriorityGroupPk__c.
        Date nextMonthStart = Date.today().toStartOfMonth().addMonths(1);
        Date spanEnd = nextMonthStart.addMonths(3).addDays(-1);
        insertApprovedWi('CommittedWI', 90, nextMonthStart, spanEnd, 'active', 90); // approved → greenlit
        insertTieredWi('PredictedWI', 60, nextMonthStart, spanEnd, 'follow-on');    // → predicted
        insertTieredWi('ProposedWI',  30, nextMonthStart, spanEnd, 'proposed');     // → ready

        Test.startTest();
        String pacingJson = DeliveryHoursAnalyticsController.getPacing('Month', 6, 4);
        Test.stopTest();

        // Top-level segment defs: greenlit/predicted/ready present, in stack order, no recurring.
        List<Object> defs = segmentDefsOf(pacingJson);
        System.assertNotEquals(null, defs, 'segments[] defs are emitted when tiers carry hours');
        List<String> ids = new List<String>();
        for (Object o : defs) {
            ids.add((String) ((Map<String, Object>) o).get('id'));
        }
        System.assertEquals(new List<String>{ 'greenlit', 'predicted', 'ready' }, ids,
            'segment defs are the three non-empty tiers in stack order (no recurring — seam off)');
        Map<String, Object> firstDef = (Map<String, Object>) defs[0];
        System.assertEquals('Committed', firstDef.get('label'), 'greenlit labelled Committed');
        System.assertEquals('#059669', firstDef.get('color'), 'greenlit color matches NG default');

        // A forecast bucket overlapping the span: segments map sums to the bucket forecast,
        // and every drill-down item carries the tier its lane maps to.
        Boolean checkedABucket = false;
        for (Object o : bucketsOf(pacingJson)) {
            Map<String, Object> b = (Map<String, Object>) o;
            Decimal forecast = (Decimal) b.get('forecast');
            if (forecast == null || forecast <= 0) {
                continue;
            }
            Map<String, Object> segs = (Map<String, Object>) b.get('segments');
            System.assertNotEquals(null, segs, 'a forecast bucket carries a segments map');
            Decimal segSum = 0;
            for (Object v : segs.values()) {
                segSum += (Decimal) v;
            }
            System.assert(Math.abs(segSum - forecast) <= 0.2,
                'Σ per-tier segment hours (' + segSum + ') ≈ bucket forecast (' + forecast + ')');
            System.assert(segs.containsKey('greenlit') && segs.containsKey('predicted')
                && segs.containsKey('ready'), 'all three tiers contribute to the overlapping bucket');

            for (Object io : (List<Object>) b.get('items')) {
                Map<String, Object> item = (Map<String, Object>) io;
                String name = (String) item.get('name');
                String tier = (String) item.get('tier');
                if (name == 'CommittedWI') {
                    System.assertEquals('greenlit', tier, 'client-approved item → greenlit');
                } else if (name == 'PredictedWI') {
                    System.assertEquals('predicted', tier, 'follow-on lane → predicted');
                } else if (name == 'ProposedWI') {
                    System.assertEquals('ready', tier, 'proposed lane → ready');
                }
            }
            checkedABucket = true;
        }
        System.assert(checkedABucket, 'at least one forecast bucket was asserted');
    }

    @IsTest
    static void testBlankLaneFallsBackToPredictedNoVanish() {
        // A future-dated UNAPPROVED item with NO priority lane must still land in a tier,
        // so its forecast hours never vanish from the stack (Σ segments == forecast).
        // Item 8: the no-vanish fallback is 'predicted' — never 'greenlit', because
        // greenlit membership is approval truth only.
        Date nextMonthStart = Date.today().toStartOfMonth().addMonths(1);
        Date spanEnd = nextMonthStart.addMonths(2).addDays(-1);
        insertTieredWi('NoLaneWI', 50, nextMonthStart, spanEnd, null);

        Test.startTest();
        String pacingJson = DeliveryHoursAnalyticsController.getPacing('Month', 6, 4);
        Test.stopTest();

        List<String> ids = new List<String>();
        for (Object o : segmentDefsOf(pacingJson)) {
            ids.add((String) ((Map<String, Object>) o).get('id'));
        }
        System.assertEquals(new List<String>{ 'predicted' }, ids,
            'blank lane on an unapproved item folds into the single predicted tier (no-vanish fallback)');
        for (Object o : bucketsOf(pacingJson)) {
            Map<String, Object> b = (Map<String, Object>) o;
            Decimal forecast = (Decimal) b.get('forecast');
            if (forecast != null && forecast > 0) {
                Map<String, Object> segs = (Map<String, Object>) b.get('segments');
                System.assertEquals(forecast, (Decimal) segs.get('predicted'),
                    'all forecast hours land in predicted when no lane is set and nothing is approved');
            }
        }
    }

    @IsTest
    static void testGreenlitMembershipIsApprovalTruthNotLane() {
        // Item 8 acceptance pair: an APPROVED item lands greenlit even from the
        // lowliest lane ('proposed'), and an UNAPPROVED top-priority item does NOT
        // land greenlit (it keeps its lane-derived tier, 'predicted').
        Date nextMonthStart = Date.today().toStartOfMonth().addMonths(1);
        Date spanEnd = nextMonthStart.addMonths(2).addDays(-1);
        insertApprovedWi('ApprovedProposedWI', 40, nextMonthStart, spanEnd, 'proposed', 40);
        insertTieredWi('UnapprovedTopWI', 80, nextMonthStart, spanEnd, 'top-priority');

        Test.startTest();
        String pacingJson = DeliveryHoursAnalyticsController.getPacing('Month', 6, 4);
        Test.stopTest();

        Boolean sawApproved = false;
        Boolean sawUnapproved = false;
        for (Object o : bucketsOf(pacingJson)) {
            Map<String, Object> b = (Map<String, Object>) o;
            List<Object> items = (List<Object>) b.get('items');
            if (items == null) {
                continue;
            }
            for (Object io : items) {
                Map<String, Object> item = (Map<String, Object>) io;
                String name = (String) item.get('name');
                String tier = (String) item.get('tier');
                if (name == 'ApprovedProposedWI') {
                    System.assertEquals('greenlit', tier,
                        'Approved item is greenlit regardless of its (proposed) lane');
                    sawApproved = true;
                } else if (name == 'UnapprovedTopWI') {
                    System.assertEquals('predicted', tier,
                        'Unapproved top-priority item must NOT be greenlit');
                    sawUnapproved = true;
                }
            }
        }
        System.assert(sawApproved && sawUnapproved,
            'Both items appear in the forecast drill-down');
    }

    @IsTest
    static void testHistoryBucketsCarryNoSegments() {
        // History (non-forecast) buckets must not emit a segments map — actuals aren't tiered.
        insertTieredWi('HistWI', 40, Date.today().addMonths(-1), Date.today().addMonths(2), 'active');

        Test.startTest();
        String pacingJson = DeliveryHoursAnalyticsController.getPacing('Month', 6, 4);
        Test.stopTest();

        for (Object o : bucketsOf(pacingJson)) {
            Map<String, Object> b = (Map<String, Object>) o;
            if (((Boolean) b.get('isPast')) == true) {
                System.assertEquals(null, b.get('segments'),
                    'history/past buckets carry no segments map');
            }
        }
    }

    // ────────────────────────────────────────────────────────────────────
    // Leaf-only counting — a container parent's rollup estimate must NOT be
    // double-counted with its children's estimates.
    // ────────────────────────────────────────────────────────────────────

    @IsTest
    static void testLeafOnlyExcludesParentRollupEstimate() {
        // Container parent (200h) whose three leaf children sum to the same 200h — the
        // live MF-Prod RR-ENGINE-PARENT shape. Counting both = 400h double-count.
        Date start = Date.today().toStartOfMonth().addMonths(1);
        Date spanEnd = start.addMonths(2).addDays(-1);
        WorkItem__c parent = insertWi('RollupParent', 200, start, spanEnd, null);
        insertWi('Leaf1', 80, start, spanEnd, parent.Id);
        insertWi('Leaf2', 70, start, spanEnd, parent.Id);
        insertWi('Leaf3', 50, start, spanEnd, parent.Id);

        Test.startTest();
        DeliveryHoursAnalyticsController.PortfolioPacingDTO dto =
            DeliveryHoursAnalyticsController.getPortfolioPacing('Month', 6, 4);
        Test.stopTest();

        System.assertEquals(200, dto.totalEstimatedHours,
            'Leaf-only: 3 children (80+70+50) count; parent rollup excluded — not 400');
        System.assertEquals(200, dto.projectedFinalHours,
            'Projected = 0 logged + 200 leaf remaining; parent 200 not double-counted');
        Decimal placed = totalForecast(dto);
        System.assert(placed >= 199.5 && placed <= 200.5,
            'Forecast bars spread the 200h of leaf work once, got ' + placed);
    }

    @IsTest
    static void testParentWithNoChildrenStillCounts() {
        // A childless root is itself a leaf — its estimate must still count (the fix only
        // strips parents that HAVE in-scope children).
        Date start = Date.today().toStartOfMonth().addMonths(1);
        insertWi('SoloLeaf', 90, start, start.addMonths(2).addDays(-1), null);

        Test.startTest();
        DeliveryHoursAnalyticsController.PortfolioPacingDTO dto =
            DeliveryHoursAnalyticsController.getPortfolioPacing('Month', 6, 4);
        Test.stopTest();

        System.assertEquals(90, dto.totalEstimatedHours,
            'A childless item is a leaf — its estimate is counted, not dropped');
    }

    // ────────────────────────────────────────────────────────────────────
    // Recurring tier — synthetic steady-state intake from the per-org setting.
    // ────────────────────────────────────────────────────────────────────

    @IsTest
    static void testRecurringTierFromSettingScaledByBucket() {
        DeliveryHubSettings__c settings = DeliveryHubSettings__c.getOrgDefaults();
        settings.RecurringHoursPerMonthNumber__c = 69;
        upsert settings;
        Date start = Date.today().toStartOfMonth().addMonths(1);
        insertTieredWi('RecBase', 40, start, start.addMonths(2).addDays(-1), 'active');

        Test.startTest();
        String monthJson = DeliveryHoursAnalyticsController.getPacing('Month', 6, 4);
        Test.stopTest();

        Boolean sawRecurringDef = false;
        for (Object o : segmentDefsOf(monthJson)) {
            if ('recurring' == (String) ((Map<String, Object>) o).get('id')) {
                sawRecurringDef = true;
            }
        }
        System.assert(sawRecurringDef, 'recurring tier advertised when the setting is > 0');
        Boolean sawRecurringBucket = false;
        for (Object o : bucketsOf(monthJson)) {
            Map<String, Object> b = (Map<String, Object>) o;
            if (((Boolean) b.get('isPast')) == true) {
                continue;
            }
            Map<String, Object> segs = (Map<String, Object>) b.get('segments');
            if (segs != null && segs.containsKey('recurring')) {
                System.assertEquals(69, (Decimal) segs.get('recurring'),
                    'Month bucket recurring = the monthly rate (69)');
                sawRecurringBucket = true;
            }
        }
        System.assert(sawRecurringBucket, 'at least one forecast bucket carries the recurring tier');
    }

    @IsTest
    static void testRecurringTierAbsentWhenSettingZero() {
        // Default (no setting) → recurring tier off, prod behavior unchanged.
        Date start = Date.today().toStartOfMonth().addMonths(1);
        insertTieredWi('NoRec', 40, start, start.addMonths(2).addDays(-1), 'active');

        Test.startTest();
        String json = DeliveryHoursAnalyticsController.getPacing('Month', 6, 4);
        Test.stopTest();

        for (Object o : segmentDefsOf(json)) {
            System.assertNotEquals('recurring', (String) ((Map<String, Object>) o).get('id'),
                'recurring tier absent when the setting is unset/0');
        }
    }

    // ────────────────────────────────────────────────────────────────────
    // Drill-down name fallback + scope label (0.271).
    // ────────────────────────────────────────────────────────────────────

    @IsTest
    static void testDrillDownNameFallsBackToWorkItemNameNotRawId() {
        // A future-dated active item with NO brief description (like the CF big rocks) must
        // render its WorkItem Name (auto-number) in the drill-down, never the raw 18-char Id.
        Date start = Date.today().toStartOfMonth().addMonths(1);
        Date spanEnd = start.addMonths(2).addDays(-1);
        WorkItem__c wi = TestDataFactory.createWorkItem(new Map<String, Object>{
            'BriefDescriptionTxt__c' => null,
            'EstimatedHoursNumber__c' => 60,
            'EstimatedStartDevDate__c' => start,
            'EstimatedEndDevDate__c' => spanEnd,
            'ActivatedDateTime__c' => System.now()
        });
        WorkItem__c refreshed = [SELECT Name FROM WorkItem__c WHERE Id = :wi.Id];

        Test.startTest();
        String json = DeliveryHoursAnalyticsController.getPacing('Month', 6, 4);
        Test.stopTest();

        Boolean checked = false;
        for (Object o : bucketsOf(json)) {
            for (Object io : (List<Object>) ((Map<String, Object>) o).get('items')) {
                Map<String, Object> item = (Map<String, Object>) io;
                if (String.valueOf(wi.Id) == (String) item.get('id')) {
                    System.assertEquals(refreshed.Name, (String) item.get('name'),
                        'blank brief → name is the WorkItem Name, not the raw Id');
                    System.assertNotEquals(String.valueOf(wi.Id), (String) item.get('name'),
                        'drill-down never renders the raw 18-char Id');
                    checked = true;
                }
            }
        }
        System.assert(checked, 'the no-brief item appeared in a forecast bucket and was asserted');
    }

    @IsTest
    static void testSummaryCarriesScopeLabel() {
        Date start = Date.today().toStartOfMonth().addMonths(1);
        insertTieredWi('ScopeItem', 40, start, start.addMonths(2).addDays(-1), 'active');

        Test.startTest();
        // NB: local var is NOT named 'json' — Apex identifiers are case-insensitive, so a
        // local 'json' shadows the System.JSON class and breaks JSON.deserializeUntyped(...).
        String pacingJson = DeliveryHoursAnalyticsController.getPacing('Month', 6, 4);
        Test.stopTest();

        Map<String, Object> data = (Map<String, Object>) JSON.deserializeUntyped(pacingJson);
        Map<String, Object> summary = (Map<String, Object>) data.get('summary');
        System.assert(String.isNotBlank((String) summary.get('scopeLabel')),
            'summary carries a scopeLabel for NG\'s pacing scope banner');
    }

    // ────────────────────────────────────────────────────────────────────
    // Terminal-stage descendants — dead work must NOT contribute remaining /
    // forecast / projectedFinal, but its already-logged actuals stay counted.
    // ────────────────────────────────────────────────────────────────────

    /**
     * @description Flips a WorkItem's stage via a trigger-bypassed update so the test
     *              isolates the analytics from auto-WR / sync side effects (mirrors the
     *              pattern in testPortfolioExcludesTerminalAndArchivedRoots).
     */
    private static void setStage(WorkItem__c wi, String stage) {
        Boolean prev = DeliveryWorkItemTriggerHandler.triggerDisabled;
        DeliveryWorkItemTriggerHandler.triggerDisabled = true;
        try {
            wi.StageNamePk__c = stage;
            update wi;
        } finally {
            DeliveryWorkItemTriggerHandler.triggerDisabled = prev;
        }
    }

    @IsTest
    static void testTerminalDescendantContributesNoRemainingOrForecast() {
        // Active root (Backlog) with a future-dated active child AND a Cancelled child
        // that has POSITIVE remaining (estimate 50 > logged 10). The Cancelled child's
        // 50h estimate / 40h remaining is dead work — it must NOT inflate
        // totalRemainingHours, projectedFinalHours, the forecast bars, or unscheduled —
        // but its 10h LOGGED is real history and must stay in totalLoggedHours + the
        // actual series.
        Date nextMonthStart = Date.today().toStartOfMonth().addMonths(1);
        Date spanEnd = nextMonthStart.addMonths(2).addDays(-1);
        // 0-estimate container root (its work lives in the children) — mirrors the
        // sibling testTerminalRootSiblingExcludedFromForecastButLoggedKept pattern. A
        // non-zero root estimate would contribute its own remaining and is orthogonal to
        // what this test isolates (terminal-stage exclusion); the projected math below
        // assumes the root adds nothing.
        WorkItem__c root = insertWi('TermRoot', 0, nextMonthStart, spanEnd, null);
        WorkItem__c activeChild = insertWi('TermActiveChild', 60, nextMonthStart, spanEnd, root.Id);
        // Cancelled child: scheduled in the future with positive remaining, so absent the
        // fix it WOULD spread 40h onto the forecast bars.
        WorkItem__c cancelledChild = insertWi('TermCancelledChild', 50, nextMonthStart, spanEnd, root.Id);

        insert new List<WorkLog__c>{
            buildLog(activeChild.Id, 10, Date.today()),
            buildLog(cancelledChild.Id, 10, Date.today())
        };
        setStage(cancelledChild, 'Cancelled');

        Test.startTest();
        DeliveryHoursAnalyticsController.PortfolioPacingDTO dto =
            DeliveryHoursAnalyticsController.getPortfolioPacing('Month', 6, 4);
        Test.stopTest();

        // LOGGED actuals: both children's 10h logged stays counted (20h total) — the
        // Cancelled child's history is NOT dropped.
        System.assertEquals(20, dto.totalLoggedHours,
            'Terminal child logged actuals stay counted: 10 (active) + 10 (cancelled) = 20');
        System.assertEquals(20, totalLogged(dto),
            'Both children appear in the actual series (period logged sum)');

        // REMAINING / forecast / projected: only the ACTIVE child contributes remaining.
        // Active child remaining = 60 - 10 = 50; Cancelled child remaining (40) excluded.
        // Projected = logged(20) + remaining(50) = 70.
        System.assertEquals(70, dto.projectedFinalHours,
            'Projected = logged(20) + active-child remaining(50); cancelled remaining excluded');

        // Forecast bars: spread the 50h ACTIVE remaining only (not 90 = 50+40).
        Decimal placed = totalForecast(dto);
        System.assert(placed >= 49.8 && placed <= 50.2,
            'Forecast bars spread ONLY the active child remaining (~50h), not the ' +
            'cancelled child (would be ~90h with the bug), got ' + placed);
        System.assertEquals(0, dto.unscheduledRemainingHours,
            'Both children are future-dated; cancelled remaining is excluded, not unscheduled');
    }

    @IsTest
    static void testTerminalRootSiblingExcludedFromForecastButLoggedKept() {
        // Belt-and-suspenders at the per-item-stage level: a terminal-stage item that
        // somehow enters the portfolio id set (here as a Done CHILD under an active root)
        // still has its logged kept and its remaining zeroed.
        WorkItem__c root = insertWi('DoneChildRoot', 0, null, null, null);
        WorkItem__c doneChild = insertWi('DoneChild', 80,
            Date.today().toStartOfMonth().addMonths(1),
            Date.today().toStartOfMonth().addMonths(3).addDays(-1), root.Id);
        insert buildLog(doneChild.Id, 15, Date.today());
        setStage(doneChild, 'Done');

        Test.startTest();
        DeliveryHoursAnalyticsController.PortfolioPacingDTO dto =
            DeliveryHoursAnalyticsController.getPortfolioPacing('Month', 6, 4);
        Test.stopTest();

        System.assertEquals(15, dto.totalLoggedHours, 'Done child 15h logged stays counted');
        System.assertEquals(0, totalForecast(dto),
            'Done child contributes no forecast bars (dead remaining)');
        System.assertEquals(0, dto.unscheduledRemainingHours,
            'Done child remaining is excluded, not pushed to unscheduled');
        // Projected = logged(15) + remaining(0) = 15. Root has 0 estimate.
        System.assertEquals(15, dto.projectedFinalHours,
            'Projected = logged only; no remaining from the Done child');
    }

    @IsTest
    static void testNoDrillDownItemHasZeroOrNegativeHours() {
        // Every items[] drill-down row across every bucket must carry hours > 0 — no
        // 0h noise rows (the second fix).
        Date nextMonthStart = Date.today().toStartOfMonth().addMonths(1);
        Date spanEnd = nextMonthStart.addMonths(3).addDays(-1);
        insertWi('DrillNonZero', 90, nextMonthStart, spanEnd, null);

        Test.startTest();
        String pacingJson = DeliveryHoursAnalyticsController.getPacing('Month', 6, 4);
        Test.stopTest();

        Integer rowsSeen = 0;
        for (Object o : bucketsOf(pacingJson)) {
            for (Object io : (List<Object>) ((Map<String, Object>) o).get('items')) {
                Decimal hrs = (Decimal) ((Map<String, Object>) io).get('hours');
                System.assert(hrs != null && hrs > 0,
                    'No drill-down item may have this-period hours <= 0, got ' + hrs);
                rowsSeen++;
            }
        }
        System.assert(rowsSeen > 0, 'Sanity: the scheduled item produced at least one drill row');
    }

    @IsTest
    static void testUnscheduledItemNeverAppearsInAnyBucketItems() {
        // A no-date item with remaining work is unscheduled — it must NOT show up in
        // any period's items[] (it is only counted in summary.unscheduledHours).
        insertWi('UnschedDrill', 45, null, null, null);

        Test.startTest();
        String pacingJson = DeliveryHoursAnalyticsController.getPacing('Month', 6, 3);
        Test.stopTest();

        Decimal totalItemHours = 0;
        for (Object o : bucketsOf(pacingJson)) {
            List<Object> items = (List<Object>) ((Map<String, Object>) o).get('items');
            System.assert(items.isEmpty(), 'Unscheduled item produces no bucket items[]');
            totalItemHours += sumBucketItemHours((Map<String, Object>) o);
        }
        System.assertEquals(0, totalItemHours, 'No placed item hours for an unscheduled item');
    }

    // ════════════════════════════════════════════════════════════════════
    // getForecastItems — flat leaf-only item feed for the capacity slider
    // ════════════════════════════════════════════════════════════════════

    /** @description Indexes a ForecastItemDTO list by WorkItem id. */
    private static Map<Id, DeliveryHoursAnalyticsController.ForecastItemDTO> byId(
        List<DeliveryHoursAnalyticsController.ForecastItemDTO> items
    ) {
        Map<Id, DeliveryHoursAnalyticsController.ForecastItemDTO> out =
            new Map<Id, DeliveryHoursAnalyticsController.ForecastItemDTO>();
        for (DeliveryHoursAnalyticsController.ForecastItemDTO d : items) {
            out.put(d.id, d);
        }
        return out;
    }

    @IsTest
    static void testForecastItemsLeafOnlyWithRemainingAndTier() {
        // Container parent (excluded by leaf-only) + leaf child, a greenlit leaf, and
        // a partially-logged leaf so remaining = estimate - logged.
        WorkItem__c parent = insertWi('FiParent', 200, Date.today(), Date.today().addMonths(2), null);
        WorkItem__c child = insertWi('FiChild', 60, Date.today(), Date.today().addMonths(1), parent.Id);
        WorkItem__c greenlit = TestDataFactory.createWorkItem(new Map<String, Object>{
            'BriefDescriptionTxt__c' => 'FiGreenlit',
            'EstimatedHoursNumber__c' => 40,
            'EstimatedStartDevDate__c' => Date.today(),
            'EstimatedEndDevDate__c' => Date.today().addMonths(1),
            'ClientPreApprovedHoursNumber__c' => 40
        });
        insert buildLog(child.Id, 25, Date.today()); // child remaining = 60 - 25 = 35

        Test.startTest();
        List<DeliveryHoursAnalyticsController.ForecastItemDTO> items =
            DeliveryHoursAnalyticsController.getForecastItems();
        Test.stopTest();

        Map<Id, DeliveryHoursAnalyticsController.ForecastItemDTO> m = byId(items);
        System.assert(!m.containsKey(parent.Id),
            'Leaf-only: the container parent must be excluded (its work is counted via the child)');
        System.assert(m.containsKey(child.Id), 'The leaf child is in scope');
        System.assert(m.containsKey(greenlit.Id), 'The greenlit leaf is in scope');

        System.assertEquals(35, m.get(child.Id).remaining,
            'remaining = estimate(60) - logged(25)');
        System.assertEquals(false, m.get(child.Id).isTerminal, 'Backlog stage is not terminal');
        System.assertEquals('greenlit', m.get(greenlit.Id).tier,
            'ClientPreApprovedHoursNumber__c > 0 → greenlit tier (drains first in the packer)');
        System.assertEquals(40, m.get(greenlit.Id).remaining,
            'remaining floors at estimate when nothing is logged');
    }

    @IsTest
    static void testForecastItemsRemainingFlooredAndTerminalFlagged() {
        // Over-logged item → remaining floored at 0. A terminal-stage item only stays
        // in scope as a non-root CHILD (queryActiveRootIds filters terminal ROOTS out),
        // so the Done item hangs under an active parent and is flagged terminal there.
        WorkItem__c overLogged = insertWi('FiOver', 10, Date.today(), Date.today().addMonths(1), null);
        WorkItem__c termParent = insertWi('FiTermParent', 100, Date.today(), Date.today().addMonths(2), null);
        WorkItem__c doneItem = TestDataFactory.createWorkItem(new Map<String, Object>{
            'BriefDescriptionTxt__c' => 'FiDone',
            'EstimatedHoursNumber__c' => 30,
            'StageNamePk__c' => 'Done',
            'ParentWorkItemLookup__c' => termParent.Id
        });
        insert buildLog(overLogged.Id, 18, Date.today()); // 10 - 18 → floored to 0

        Test.startTest();
        List<DeliveryHoursAnalyticsController.ForecastItemDTO> items =
            DeliveryHoursAnalyticsController.getForecastItems();
        Test.stopTest();

        Map<Id, DeliveryHoursAnalyticsController.ForecastItemDTO> m = byId(items);
        System.assertEquals(0, m.get(overLogged.Id).remaining,
            'remaining never goes negative — floored at 0');
        System.assertEquals(true, m.get(doneItem.Id).isTerminal,
            'Done is a terminal stage — the packer skips it so it never inflates the future');
    }

    @IsTest
    static void testForecastItemsEmptyScopeReturnsEmptyList() {
        Test.startTest();
        List<DeliveryHoursAnalyticsController.ForecastItemDTO> items =
            DeliveryHoursAnalyticsController.getForecastItems();
        Test.stopTest();

        System.assertNotEquals(null, items, 'Never null — empty list when no active items');
        System.assertEquals(0, items.size(), 'No active portfolio items → empty');
    }

    // ────────────────────────────────────────────────────────────────────
    // W5.3 (T6.1) — per-period segments on the LWC-facing DTO, so the ADMIN
    // pacing card renders the same stacked tiers the buyer surface gets.
    // ────────────────────────────────────────────────────────────────────

    @IsTest
    static void testDtoForecastPeriodsCarrySegmentsAndDefs() {
        Date nextMonthStart = Date.today().toStartOfMonth().addMonths(1);
        Date spanEnd = nextMonthStart.addMonths(2).addDays(-1);
        insertTieredWi('SegPredicted', 60, nextMonthStart, spanEnd, 'active');   // → predicted
        insertTieredWi('SegReady', 30, nextMonthStart, spanEnd, 'proposed');     // → ready

        Test.startTest();
        DeliveryHoursAnalyticsController.PortfolioPacingDTO dto =
            DeliveryHoursAnalyticsController.getPortfolioPacing('Month', 6, 4);
        Test.stopTest();

        Decimal seggedForecast = 0;
        Decimal totalForecast = 0;
        for (DeliveryHoursAnalyticsController.PacingPeriodDTO p : dto.periods) {
            if (!p.isForecast) {
                System.assertEquals(null, p.segments,
                    'History periods carry no segments — actuals are not tiered');
                continue;
            }
            totalForecast += p.forecastHours;
            if (p.segments != null) {
                for (String tier : p.segments.keySet()) {
                    seggedForecast += p.segments.get(tier);
                }
            }
        }
        System.assert(totalForecast > 0, 'Scheduled items must produce forecast bars');
        System.assert(Math.abs(seggedForecast - totalForecast) < 0.5,
            'Per-tier segment sums equal the flat forecast — the stacked bar is exactly '
            + 'as tall as the bar it replaces (got ' + seggedForecast + ' vs ' + totalForecast + ')');

        System.assertNotEquals(null, dto.segmentDefs, 'Tiers in play are advertised');
        Set<String> defIds = new Set<String>();
        for (DeliveryHoursAnalyticsController.PacingSegmentDefDTO d : dto.segmentDefs) {
            defIds.add(d.id);
            System.assert(String.isNotBlank(d.label) && String.isNotBlank(d.color),
                'Each segment def carries a label + color for the legend');
        }
        System.assert(defIds.contains('predicted') && defIds.contains('ready'),
            'Defs advertise exactly the tiers carrying hours, got ' + defIds);
        System.assert(!defIds.contains('greenlit'),
            'Tiers with no hours are not advertised');
    }

    @IsTest
    static void testDtoSegmentsIncludeRecurringTierWhenSettingSet() {
        DeliveryHubSettings__c settings = DeliveryHubSettings__c.getOrgDefaults();
        settings.RecurringHoursPerMonthNumber__c = 69;
        upsert settings;
        Date nextMonthStart = Date.today().toStartOfMonth().addMonths(1);
        insertTieredWi('SegRecBase', 40, nextMonthStart, nextMonthStart.addMonths(1).addDays(-1), 'active');

        Test.startTest();
        DeliveryHoursAnalyticsController.PortfolioPacingDTO dto =
            DeliveryHoursAnalyticsController.getPortfolioPacing('Month', 6, 3);
        Test.stopTest();

        Boolean sawRecurring = false;
        for (DeliveryHoursAnalyticsController.PacingPeriodDTO p : dto.periods) {
            if (p.isForecast && p.segments != null && p.segments.containsKey('recurring')) {
                sawRecurring = true;
                System.assertEquals(69, p.segments.get('recurring'),
                    'Monthly recurring rate rides on forecast periods unscaled at Month granularity');
            }
        }
        System.assert(sawRecurring, 'Recurring tier present on forecast periods when the org sets it');
    }

    @IsTest
    static void testDtoNoSegmentsWhenNothingScheduled() {
        // Logged history only — no remaining scheduled work → no segments, no defs.
        WorkItem__c root = insertWi('SegNone', 10, Date.today().addMonths(-2), Date.today().addDays(-10), null);
        insert buildLog(root.Id, 10, Date.today().addDays(-15));

        Test.startTest();
        DeliveryHoursAnalyticsController.PortfolioPacingDTO dto =
            DeliveryHoursAnalyticsController.getPortfolioPacing('Month', 6, 3);
        Test.stopTest();

        for (DeliveryHoursAnalyticsController.PacingPeriodDTO p : dto.periods) {
            System.assertEquals(null, p.segments, 'Nothing scheduled → no period segments');
        }
        System.assertEquals(null, dto.segmentDefs, 'Nothing scheduled → no segment defs');
    }

    // ────────────────────────────────────────────────────────────────────
    // W5.4 (F15) — "over budget" fires strictly ABOVE 100% at displayed
    // precision; 100% (and fractional overshoot that displays as 100%) is
    // AT budget.
    // ────────────────────────────────────────────────────────────────────

    @IsTest
    static void testPacingExactly100PercentIsNotOverBudget() {
        WorkItem__c root = insertWi('Boundary100', 100, Date.today().addMonths(-1), Date.today().addMonths(2), null);
        insert buildLog(root.Id, 100, Date.today()); // logged == estimate → projected == estimate

        Test.startTest();
        DeliveryHoursAnalyticsController.PortfolioPacingDTO dto =
            DeliveryHoursAnalyticsController.getPortfolioPacing('Month', 6, 3);
        Test.stopTest();

        System.assertEquals(100, dto.projectedFinalHours, 'Projected == estimate at the boundary');
        System.assertEquals(false, dto.isOverBudgetTrajectory,
            'Exactly 100% is AT budget, not over (F15)');
    }

    @IsTest
    static void testPacingFractionallyOver100StillReadsAtBudget() {
        // 251/250 = 100.4% — displays as "100%", so the flag must stay false: the
        // label and the displayed number can never disagree.
        WorkItem__c root = insertWi('Boundary100p4', 250, Date.today().addMonths(-1), Date.today().addMonths(2), null);
        insert buildLog(root.Id, 251, Date.today());

        Test.startTest();
        DeliveryHoursAnalyticsController.PortfolioPacingDTO dto =
            DeliveryHoursAnalyticsController.getPortfolioPacing('Month', 6, 3);
        Test.stopTest();

        System.assertEquals(251, dto.projectedFinalHours, 'Projected = logged (remaining floored)');
        System.assertEquals(false, dto.isOverBudgetTrajectory,
            '100.4% rounds to the displayed 100% → at budget, not over');
    }

    @IsTest
    static void testPacingAbove100PercentIsOverBudget() {
        WorkItem__c root = insertWi('Boundary102', 100, Date.today().addMonths(-1), Date.today().addMonths(2), null);
        insert buildLog(root.Id, 102, Date.today());

        Test.startTest();
        DeliveryHoursAnalyticsController.PortfolioPacingDTO dto =
            DeliveryHoursAnalyticsController.getPortfolioPacing('Month', 6, 3);
        Test.stopTest();

        System.assertEquals(true, dto.isOverBudgetTrajectory,
            '102% is strictly over 100 → over-budget trajectory fires');
    }
}

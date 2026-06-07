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
}

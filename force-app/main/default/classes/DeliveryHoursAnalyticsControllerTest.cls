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
        String json = DeliveryHoursAnalyticsController.getPacing('Week', 6, 6);
        Test.stopTest();

        System.assertNotEquals(null, json, 'getPacing returns a JSON string');
        Map<String, Object> data = (Map<String, Object>) JSON.deserializeUntyped(json);
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
        System.assert(b0.containsKey('items'), 'bucket has items[] (empty — NG hybrid fills)');

        Map<String, Object> summary = (Map<String, Object>) data.get('summary');
        System.assertNotEquals(null, summary, 'summary present');
        System.assertEquals(80, ((Decimal) summary.get('estimatedHours')), 'estimate summed');
        System.assertEquals(10, ((Decimal) summary.get('loggedHours')), 'logged summed (6 + 4)');
        System.assertEquals(1, ((Integer) summary.get('activeItems')), 'one active root');
    }

    @IsTest
    static void testGetPacingEmptyOrgStillReturnsJson() {
        Test.startTest();
        String json = DeliveryHoursAnalyticsController.getPacing('Month', 6, 3);
        Test.stopTest();

        System.assertNotEquals(null, json, 'JSON returned even with no data');
        Map<String, Object> data = (Map<String, Object>) JSON.deserializeUntyped(json);
        System.assertEquals('month', (String) data.get('bucket'), 'default-ish month bucket');
        Map<String, Object> summary = (Map<String, Object>) data.get('summary');
        System.assertEquals(0, ((Integer) summary.get('activeItems')), 'no active roots');
    }
}

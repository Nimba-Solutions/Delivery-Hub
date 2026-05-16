/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Tests for DeliveryForecastAlertService. Covers gating
 *              (disabled feature, no candidates, no estimate), threshold
 *              firing, cooldown, material-worsening re-fire, recipient
 *              routing, queueable wiring.
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.ApexDoc,PMD.ExcessiveParameterList')
@IsTest
private class DeliveryForecastAlertServiceTest {

    /**
     * @description Thin wrapper around TestDataFactory.createWorkItem.
     *              Factory bypasses triggers by default so this test focuses
     *              on alert math, not auto-WR / sync side effects.
     */
    private static WorkItem__c insertActiveRoot(String briefDesc, Decimal estimate, Date startDate, Date endDate) {
        return TestDataFactory.createWorkItem(new Map<String, Object>{
            'BriefDescriptionTxt__c' => briefDesc,
            'EstimatedHoursNumber__c' => estimate,
            'EstimatedStartDevDate__c' => startDate,
            'EstimatedEndDevDate__c' => endDate,
            'StageNamePk__c' => 'In Development'
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
            new Map<String, Object>{ 'WorkDescriptionTxt__c' => 'forecast alert test' });
    }

    private static void enableFeature(Decimal thresholdPct) {
        DeliveryHubSettings__c s = DeliveryHubSettings__c.getOrgDefaults();
        s.EnableForecastAlertsDateTime__c = Datetime.now();
        s.ForecastAlertThresholdPercentNumber__c = thresholdPct;
        upsert s;
    }

    private static void seedOverBudgetWi() {
        // 5h estimate, 4 weeks of 10h logs anchored on today → projected hugely over.
        WorkItem__c wi = insertActiveRoot('Over-budget root', 5, Date.today().addDays(-21), Date.today().addDays(-1));
        insert new List<WorkLog__c>{
            buildLog(wi.Id, 10, Date.today().addDays(-21)),
            buildLog(wi.Id, 10, Date.today().addDays(-14)),
            buildLog(wi.Id, 10, Date.today().addDays(-7)),
            buildLog(wi.Id, 10, Date.today())
        };
    }

    @IsTest
    static void testDisabledFeatureReturnsZero() {
        seedOverBudgetWi();
        // EnableForecastAlertsDateTime is null by default.

        Test.startTest();
        Integer fired = DeliveryForecastAlertService.runSweep();
        Test.stopTest();

        System.assertEquals(0, fired, 'Disabled feature must not dispatch');
    }

    @IsTest
    static void testThresholdFiresOnOverBudgetWi() {
        seedOverBudgetWi();
        enableFeature(110);

        Test.startTest();
        Integer fired = DeliveryForecastAlertService.runSweep();
        Test.stopTest();

        System.assertEquals(1, fired, 'Single over-budget WI should fire one alert');

        // Verify cooldown stamp landed
        WorkItem__c wi = [SELECT LastForecastAlertDateTime__c, LastForecastAlertProjectedHoursNumber__c
                         FROM WorkItem__c WHERE BriefDescriptionTxt__c = 'Over-budget root' LIMIT 1];
        System.assertNotEquals(null, wi.LastForecastAlertDateTime__c, 'LastForecastAlertDateTime stamped');
        System.assertNotEquals(null, wi.LastForecastAlertProjectedHoursNumber__c, 'Projected hours captured');
    }

    @IsTest
    static void testCooldownSuppressesRefire() {
        seedOverBudgetWi();
        enableFeature(110);

        DeliveryForecastAlertService.runSweep();

        Test.startTest();
        Integer secondFire = DeliveryForecastAlertService.runSweep();
        Test.stopTest();

        System.assertEquals(0, secondFire,
            'Within cooldown (default 7d) without material worsening, no re-fire');
    }

    @IsTest
    static void testUnderThresholdSilent() {
        // 50h estimate, 4 weeks of 10h = 40h logged at velocity 10h/wk.
        // Projected final = 50h exactly = 100% of estimate → under 110% threshold.
        WorkItem__c wi = insertActiveRoot('At-budget', 50, Date.today().addDays(-21), Date.today().addDays(28));
        insert new List<WorkLog__c>{
            buildLog(wi.Id, 10, Date.today().addDays(-21)),
            buildLog(wi.Id, 10, Date.today().addDays(-14)),
            buildLog(wi.Id, 10, Date.today().addDays(-7)),
            buildLog(wi.Id, 10, Date.today())
        };
        enableFeature(110);

        Test.startTest();
        Integer fired = DeliveryForecastAlertService.runSweep();
        Test.stopTest();

        System.assertEquals(0, fired, 'WI projected at exactly 100% must not fire 110% threshold');
    }

    @IsTest
    static void testNoEstimateSkipped() {
        WorkItem__c wi = insertActiveRoot('No estimate', null, null, null);
        insert new List<WorkLog__c>{
            buildLog(wi.Id, 10, Date.today())
        };
        enableFeature(110);

        Test.startTest();
        Integer fired = DeliveryForecastAlertService.runSweep();
        Test.stopTest();

        System.assertEquals(0, fired, 'WIs without an estimate cannot be alerted on');
    }

    @IsTest
    static void testChildWiIgnored() {
        // Only root-level WIs (ParentWorkItemLookup__c = null) enter the sweep.
        // Tree-rollup combines parent + child estimates and logs, so the parent
        // fires only when the COMBINED rollup crosses threshold. With parent=2h
        // est and child=3h est, total estimate = 5h. Child logs 40h. Rollup
        // projected = 40h logged at velocity 10h/wk against 5h scope → trivially
        // > 110%. Parent fires; child never enters the candidate list.
        WorkItem__c parent = insertActiveRoot('Parent', 2, null, null);
        WorkItem__c child = TestDataFactory.createWorkItem(new Map<String, Object>{
            'BriefDescriptionTxt__c' => 'child',
            'EstimatedHoursNumber__c' => 3,
            'ParentWorkItemLookup__c' => parent.Id,
            'StageNamePk__c' => 'In Development'
        });
        insert new List<WorkLog__c>{
            buildLog(child.Id, 10, Date.today().addDays(-21)),
            buildLog(child.Id, 10, Date.today().addDays(-14)),
            buildLog(child.Id, 10, Date.today().addDays(-7)),
            buildLog(child.Id, 10, Date.today())
        };
        enableFeature(110);

        Test.startTest();
        Integer fired = DeliveryForecastAlertService.runSweep();
        Test.stopTest();

        System.assertEquals(1, fired,
            'Parent rolls up child logs over the combined estimate → exactly one alert (root only)');

        WorkItem__c childAfter = [SELECT LastForecastAlertDateTime__c
                                 FROM WorkItem__c WHERE Id = :child.Id LIMIT 1];
        System.assertEquals(null, childAfter.LastForecastAlertDateTime__c,
            'Child WI must NOT be alerted directly — it was never a sweep candidate');
    }

    @IsTest
    static void testTerminalStageSkipped() {
        WorkItem__c wi = insertActiveRoot('Done one', 5, Date.today().addDays(-21), Date.today().addDays(-1));
        wi.StageNamePk__c = 'Done';
        DeliveryWorkItemTriggerHandler.triggerDisabled = true;
        try {
            update wi;
        } finally {
            DeliveryWorkItemTriggerHandler.triggerDisabled = false;
        }
        insert new List<WorkLog__c>{
            buildLog(wi.Id, 10, Date.today().addDays(-21)),
            buildLog(wi.Id, 10, Date.today().addDays(-14)),
            buildLog(wi.Id, 10, Date.today().addDays(-7)),
            buildLog(wi.Id, 10, Date.today())
        };
        enableFeature(110);

        Test.startTest();
        Integer fired = DeliveryForecastAlertService.runSweep();
        Test.stopTest();

        System.assertEquals(0, fired, 'Terminal-stage WIs excluded from sweep');
    }

    @IsTest
    static void testQueueableDelegates() {
        seedOverBudgetWi();
        enableFeature(110);

        Test.startTest();
        System.enqueueJob(new DeliveryForecastAlertQueueable());
        Test.stopTest();

        WorkItem__c wi = [SELECT LastForecastAlertDateTime__c
                         FROM WorkItem__c WHERE BriefDescriptionTxt__c = 'Over-budget root' LIMIT 1];
        System.assertNotEquals(null, wi.LastForecastAlertDateTime__c,
            'Queueable wraps runSweep correctly — alert should fire end-to-end');
    }

    @IsTest
    static void testScanDateStampedEvenWhenNoneFired() {
        // No data → 0 fired, but the scan-date stamp should still land so the
        // scheduler's once-per-day guard works correctly.
        enableFeature(110);

        Test.startTest();
        DeliveryForecastAlertService.runSweep();
        Test.stopTest();

        // PR #778 fixed a TZ slip: stampScanComplete now stamps with GMT date
        // (matching DeliveryHubScheduler.enqueueForecastAlertsIfDue which gates
        // on hourGmt()=8). The test must compare against GMT too, otherwise a
        // packaging-org run between ~04:00–08:00 ET (GMT day +1 vs user day)
        // fails the assertion even though the stamp is correct.
        DateTime nowDt = DateTime.now();
        Date expectedGmt = Date.newInstance(nowDt.yearGmt(), nowDt.monthGmt(), nowDt.dayGmt());
        DeliveryHubSettings__c s = DeliveryHubSettings__c.getOrgDefaults();
        System.assertEquals(expectedGmt, s.LastForecastAlertScanDate__c,
            'Scan-date stamps each successful sweep regardless of fire count');
    }
}

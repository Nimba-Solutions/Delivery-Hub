/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Tests for DeliveryAutoDiagnoseService (self-heal Move 1). Covers
 *               the two gates (master flag + active rule), the threshold
 *               crossing that auto-drafts a quoted request into the queue, the
 *               anomaly-value filter, the cooldown dedup, and the once-per-day
 *               guard. DiagnoseRule__mdt records can't be DML'd, so rules are
 *               injected via the @TestVisible override; ActivityLog rows (the
 *               SEE stream) are inserted directly in the shape the capture
 *               engine writes.
 * @author Cloud Nimbus LLC
 */
@IsTest
private class DeliveryAutoDiagnoseServiceTest {

    private static final String OBJ = 'AcmeTxn__c';
    private static final String FIELD = 'StatusField__c';
    private static final String BAD = 'Error';

    private static void enable(Boolean on) {
        DeliveryHubSettings__c s = DeliveryHubSettings__c.getOrgDefaults();
        s.EnableAutoDiagnoseDateTime__c = on ? Datetime.now() : null;
        s.LastAutoDiagnoseScanDateTime__c = null;
        // Threshold low so an 8h auto-draft lands Offer-Sent, not auto-accepted.
        s.DiscretionaryThresholdHoursNumber__c = 1;
        upsert s;
    }

    private static DiagnoseRule__mdt rule(Integer threshold, Integer cooldownHours, String anomalyValue) {
        return new DiagnoseRule__mdt(
            DeveloperName              = 'Test_Rule',
            WatchedObjectApiNameTxt__c = OBJ,
            WatchedFieldApiNameTxt__c  = FIELD,
            AnomalyValueTxt__c         = anomalyValue,
            WindowHoursNumber__c       = 24,
            CountThresholdNumber__c    = threshold,
            QuotedHoursNumber__c       = 8,
            WorkItemTitleTxt__c        = '{count} anomalies on {object}',
            CooldownHoursNumber__c     = cooldownHours
        );
    }

    /** Inserts n ActivityLog rows shaped like the field-change capture engine. */
    private static void seedAnomalies(String newValue, Integer n) {
        List<ActivityLog__c> logs = new List<ActivityLog__c>();
        for (Integer i = 0; i < n; i++) {
            Map<String, Object> ctx = new Map<String, Object>{
                'objectName' => OBJ, 'fieldName' => FIELD, 'newValue' => newValue
            };
            logs.add(new ActivityLog__c(
                ActionTypePk__c     = 'Field_Change',
                ComponentNameTxt__c = FIELD,
                RecordIdTxt__c      = 'REC-' + i,
                ContextDataTxt__c   = JSON.serialize(ctx)
            ));
        }
        insert logs;
    }

    private static Integer draftedCount() {
        return [
            SELECT COUNT()
            FROM WorkItem__c
            WHERE BriefDescriptionTxt__c LIKE '[auto-diagnose:%'
        ];
    }

    @IsTest
    static void testMasterFlagOffNoOp() {
        enable(false);
        seedAnomalies(BAD, 5);
        DeliveryAutoDiagnoseService.testRuleOverride = new List<DiagnoseRule__mdt>{ rule(3, 48, BAD) };

        Test.startTest();
        Integer drafted = DeliveryAutoDiagnoseService.runSweep();
        Test.stopTest();

        System.assertEquals(0, drafted, 'master flag OFF must no-op');
        System.assertEquals(0, draftedCount(), 'no work item drafted when disabled');
    }

    @IsTest
    static void testNoActiveRulesNoOp() {
        enable(true);
        seedAnomalies(BAD, 5);
        DeliveryAutoDiagnoseService.testRuleOverride = new List<DiagnoseRule__mdt>();

        Test.startTest();
        Integer drafted = DeliveryAutoDiagnoseService.runSweep();
        Test.stopTest();

        System.assertEquals(0, drafted, 'no rules → nothing drafted');
    }

    @IsTest
    static void testThresholdCrossedDraftsQueuedRequest() {
        enable(true);
        seedAnomalies(BAD, 4); // 4 distinct records >= threshold 3
        DeliveryAutoDiagnoseService.testRuleOverride = new List<DiagnoseRule__mdt>{ rule(3, 48, BAD) };

        Test.startTest();
        Integer drafted = DeliveryAutoDiagnoseService.runSweep();
        Test.stopTest();

        System.assertEquals(1, drafted, 'threshold crossed → one rule drafts');
        List<WorkItem__c> items = [
            SELECT Id, BriefDescriptionTxt__c FROM WorkItem__c
            WHERE BriefDescriptionTxt__c LIKE '[auto-diagnose:%'
        ];
        System.assertEquals(1, items.size(), 'exactly one auto-drafted work item');
        System.assert(items[0].BriefDescriptionTxt__c.contains('4 anomalies on ' + OBJ),
            'title resolves {count}/{object} tokens: ' + items[0].BriefDescriptionTxt__c);

        // It must land in the approval queue as Offer Sent (quote 8 > threshold 1).
        List<WorkRequest__c> reqs = [
            SELECT StatusPk__c, QuotedHoursNumber__c FROM WorkRequest__c
            WHERE WorkItemId__c = :items[0].Id
        ];
        System.assertEquals(1, reqs.size(), 'a work request was created for the drafted item');
        System.assertEquals('Offer Sent', reqs[0].StatusPk__c, 'drafted request waits in the queue');
        System.assertEquals(8, reqs[0].QuotedHoursNumber__c, 'rule quote stamped on the request');
    }

    @IsTest
    static void testBelowThresholdNoDraft() {
        enable(true);
        seedAnomalies(BAD, 2); // 2 < threshold 3
        DeliveryAutoDiagnoseService.testRuleOverride = new List<DiagnoseRule__mdt>{ rule(3, 48, BAD) };

        Test.startTest();
        Integer drafted = DeliveryAutoDiagnoseService.runSweep();
        Test.stopTest();

        System.assertEquals(0, drafted, 'below threshold → no draft');
        System.assertEquals(0, draftedCount(), 'no work item drafted below threshold');
    }

    @IsTest
    static void testAnomalyValueFilterExcludesNonMatches() {
        enable(true);
        seedAnomalies('Ok', 5);   // 5 changes, but to a non-anomalous value
        seedAnomalies(BAD, 1);    // only 1 to the anomalous value
        DeliveryAutoDiagnoseService.testRuleOverride = new List<DiagnoseRule__mdt>{ rule(3, 48, BAD) };

        Test.startTest();
        Integer drafted = DeliveryAutoDiagnoseService.runSweep();
        Test.stopTest();

        System.assertEquals(0, drafted,
            'only newValue=Error counts; 1 match < threshold 3, so no draft');
    }

    @IsTest
    static void testCooldownPreventsRedraft() {
        enable(true);
        seedAnomalies(BAD, 4);
        DeliveryAutoDiagnoseService.testRuleOverride = new List<DiagnoseRule__mdt>{ rule(3, 48, BAD) };

        Test.startTest();
        DeliveryAutoDiagnoseService.runSweep();           // first pass drafts
        // Clear the once-per-day guard so the second pass actually evaluates;
        // the COOLDOWN (not the daily guard) is what must now suppress it.
        DeliveryHubSettings__c s = DeliveryHubSettings__c.getOrgDefaults();
        s.LastAutoDiagnoseScanDateTime__c = null;
        upsert s;
        Integer second = DeliveryAutoDiagnoseService.runSweep();
        Test.stopTest();

        System.assertEquals(0, second, 'cooldown suppresses a re-draft for the same rule');
        System.assertEquals(1, draftedCount(), 'still exactly one drafted item after the second pass');
    }

    @IsTest
    static void testOncePerDayGuard() {
        enable(true);
        seedAnomalies(BAD, 4);
        DeliveryAutoDiagnoseService.testRuleOverride = new List<DiagnoseRule__mdt>{ rule(3, 48, BAD) };

        Test.startTest();
        DeliveryAutoDiagnoseService.runSweep();   // stamps LastAutoDiagnoseScan = today
        Integer second = DeliveryAutoDiagnoseService.runSweep(); // same day → guarded
        Test.stopTest();

        System.assertEquals(0, second, 'second pass the same day is skipped by the daily guard');
    }
}

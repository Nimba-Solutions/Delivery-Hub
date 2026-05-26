/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Unit tests for WatcherStuckStageQueryService.
 *
 *              WorkflowEscalationRule__mdt rows cannot be inserted in
 *              @IsTest context (CMT records require deployment). The tests
 *              therefore drive the signal via the @TestVisible
 *              `testClusterOverride` seam — injecting a deterministic
 *              stage → (threshold,critical) cluster map — and then
 *              assert against seeded WorkItem__c rows whose
 *              StageEnteredDateTime__c is backdated past the threshold.
 *
 *              Note: WorkItem__c.StageEnteredDateTime__c is auto-stamped by
 *              DeliveryWorkItemTriggerHandler on stage transitions. The
 *              TestDataFactory bypasses that trigger by default so we can
 *              set the field directly via the overrides map.
 * @author Cloud Nimbus LLC
 */
@IsTest
private class WatcherStuckStageQueryServiceTest {

    /**
     * @description Happy path: 3 WIs in a stage with a 5-day rule, all
     *              stamped 6 days ago → primaryCount=3 (no Critical
     *              weighting), secondaryCount=3, 3 entries surfaced.
     */
    @IsTest
    static void testHappyPathReturnsCountsAndEntries() {
        WatcherStuckStageQueryService.testClusterOverride = clusterMap(
            'In Development', 5, false
        );
        seedStuckWorkItems('In Development', 3, Datetime.now().addDays(-6));

        Test.startTest();
        SignalResultDTO result = WatcherStuckStageQueryService.query();
        Test.stopTest();

        System.assertEquals('StuckStage', result.signalName, 'signalName should be StuckStage');
        System.assertEquals(3, result.primaryCount,
            'Three 6-day-old WIs past a 5-day Warning rule → weighted count 3');
        System.assertEquals(3, result.secondaryCount,
            'Raw count should match the seeded number');
        System.assertEquals(3, result.topEntries.size(), 'Three entries should land in topEntries');
        SignalEntryDTO first = result.topEntries.get(0);
        System.assertNotEquals(null, first.recordId, 'Entry should carry the WI Id');
        System.assert(String.isNotBlank(first.detailLine), 'Entry should carry a detail line');
    }

    /**
     * @description Critical-weighting: a single WI past a Critical rule
     *              should contribute 2 to primaryCount + 1 to secondaryCount.
     */
    @IsTest
    static void testCriticalSeverityDoublesPrimaryCount() {
        WatcherStuckStageQueryService.testClusterOverride = clusterMap(
            'Code Review', 3, true
        );
        seedStuckWorkItems('Code Review', 1, Datetime.now().addDays(-4));

        Test.startTest();
        SignalResultDTO result = WatcherStuckStageQueryService.query();
        Test.stopTest();

        System.assertEquals(2, result.primaryCount,
            'Critical rule weighting should double the entry count → 2');
        System.assertEquals(1, result.secondaryCount,
            'Raw count is unaffected by severity weighting');
        System.assertEquals(1, result.topEntries.size(), 'Single WI surfaces once in topEntries');
        System.assert(result.topEntries.get(0).detailLine.contains('Critical'),
            'Critical-stage entry detail should flag severity — got: '
                + result.topEntries.get(0).detailLine);
    }

    /**
     * @description Exclusion path: SLA-paused / archived / template /
     *              deactivated / terminal-stage WIs must NOT surface even
     *              when their StageEnteredDateTime__c is past the threshold.
     */
    @IsTest
    static void testExcludedRecordsAreFiltered() {
        WatcherStuckStageQueryService.testClusterOverride = clusterMap(
            'Testing', 3, false
        );
        Datetime oldStamp = Datetime.now().addDays(-10);
        // SLA Paused — excluded by SLAPausedDateTime__c filter.
        TestDataFactory.createWorkItem(new Map<String, Object>{
            'BriefDescriptionTxt__c' => 'Paused WI',
            'StageNamePk__c' => 'Testing',
            'StageEnteredDateTime__c' => oldStamp,
            'SLAPausedDateTime__c' => Datetime.now()
        });
        // Archived — excluded.
        TestDataFactory.createWorkItem(new Map<String, Object>{
            'BriefDescriptionTxt__c' => 'Archived WI',
            'StageNamePk__c' => 'Testing',
            'StageEnteredDateTime__c' => oldStamp,
            'ArchivedDateTime__c' => Datetime.now()
        });
        // Template — excluded.
        TestDataFactory.createWorkItem(new Map<String, Object>{
            'BriefDescriptionTxt__c' => 'Template WI',
            'StageNamePk__c' => 'Testing',
            'StageEnteredDateTime__c' => oldStamp,
            'TemplateMarkedDateTime__c' => Datetime.now()
        });
        // Deactivated — excluded.
        TestDataFactory.createWorkItem(new Map<String, Object>{
            'BriefDescriptionTxt__c' => 'Deactivated WI',
            'StageNamePk__c' => 'Testing',
            'StageEnteredDateTime__c' => oldStamp,
            'ActivatedDateTime__c' => null
        });

        Test.startTest();
        SignalResultDTO result = WatcherStuckStageQueryService.query();
        Test.stopTest();

        System.assertEquals(0, result.primaryCount,
            'All exclusions should land at zero — got ' + result.primaryCount);
        System.assertEquals(0, result.secondaryCount,
            'Raw count should also be zero with all exclusions in effect');
    }

    /**
     * @description Terminal stages must be discarded during cluster
     *              construction even when a rule somehow names one of them.
     *              Validates the EXCLUDED_STAGES guard in buildClustersByStage.
     */
    @IsTest
    static void testTerminalStageClusterIsDropped() {
        // 'Done' is in EXCLUDED_STAGES — should be filtered out at cluster build.
        WatcherStuckStageQueryService.testClusterOverride = clusterMap(
            'In Development', 5, false
        );
        // Seed a WI in 'Done' that's 30 days old — should NOT surface.
        TestDataFactory.createWorkItem(new Map<String, Object>{
            'BriefDescriptionTxt__c' => 'Closed WI',
            'StageNamePk__c' => 'Done',
            'StageEnteredDateTime__c' => Datetime.now().addDays(-30)
        });
        // Seed one valid candidate to confirm the rest of the pipeline runs.
        TestDataFactory.createWorkItem(new Map<String, Object>{
            'BriefDescriptionTxt__c' => 'Stuck WI',
            'StageNamePk__c' => 'In Development',
            'StageEnteredDateTime__c' => Datetime.now().addDays(-6)
        });

        Test.startTest();
        SignalResultDTO result = WatcherStuckStageQueryService.query();
        Test.stopTest();

        System.assertEquals(1, result.secondaryCount,
            'Only the In-Development WI should surface — Done WI must be filtered');
    }

    /**
     * @description Empty path: cluster override set but no matching WIs in
     *              the org. primaryCount=0, secondaryCount=0, no entries.
     */
    @IsTest
    static void testEmptyResultZeroCounts() {
        WatcherStuckStageQueryService.testClusterOverride = clusterMap(
            'In Development', 5, false
        );
        // Seed a fresh WI that's NOT past the threshold (1 day old).
        TestDataFactory.createWorkItem(new Map<String, Object>{
            'BriefDescriptionTxt__c' => 'Fresh WI',
            'StageNamePk__c' => 'In Development',
            'StageEnteredDateTime__c' => Datetime.now().addDays(-1)
        });

        Test.startTest();
        SignalResultDTO result = WatcherStuckStageQueryService.query();
        Test.stopTest();

        System.assertEquals(0, result.primaryCount, 'Fresh WI should not surface');
        System.assertEquals(0, result.secondaryCount, 'Raw count should be zero');
        System.assertEquals(0, result.topEntries.size(), 'No entries on empty result');
    }

    /**
     * @description Empty-cluster path: when no MDT rules return + no test
     *              override is configured the signal returns a zero result
     *              without making any WorkItem SOQL calls. Exercises the
     *              `clusters.isEmpty()` short-circuit.
     */
    @IsTest
    static void testNoRulesNoOverrideReturnsEmpty() {
        // No override set; CMT rows lack ActiveDateTime__c in this env so
        // queryActiveRules() returns empty.
        WatcherStuckStageQueryService.testClusterOverride = null;

        Test.startTest();
        SignalResultDTO result = WatcherStuckStageQueryService.query();
        Test.stopTest();

        System.assertEquals(0, result.primaryCount,
            'No clusters → zero primary count');
        System.assertEquals(0, result.secondaryCount,
            'No clusters → zero secondary count');
    }

    /**
     * @description Bulk path: 60 candidates in a single stage cluster →
     *              SOQL LIMIT 50 caps the deduped map at 50, topEntries
     *              capped at 5.
     */
    @IsTest
    static void testBulkRespectsLimit() {
        WatcherStuckStageQueryService.testClusterOverride = clusterMap(
            'In Development', 3, false
        );
        seedStuckWorkItems('In Development', 60, Datetime.now().addDays(-5));

        Test.startTest();
        SignalResultDTO result = WatcherStuckStageQueryService.query();
        Test.stopTest();

        System.assert(result.secondaryCount <= 50,
            'SOQL LIMIT 50 should cap raw count, got ' + result.secondaryCount);
        System.assert(result.secondaryCount >= 49,
            'Bulk seed should fill near the cap, got ' + result.secondaryCount);
        System.assertEquals(5, result.topEntries.size(),
            'topEntries should be capped at TOP_ENTRY_CAP (5)');
    }

    // ── Helpers ──────────────────────────────────────────────────────────────

    /**
     * @description Builds a single-entry cluster map for the override seam.
     * @param stage      Stage name.
     * @param daysIdle   Days-idle threshold.
     * @param isCritical Severity flag.
     * @return Stage -> RuleCluster map ready for testClusterOverride.
     */
    private static Map<String, WatcherStuckStageQueryService.RuleCluster> clusterMap(
        String stage, Integer daysIdle, Boolean isCritical
    ) {
        return new Map<String, WatcherStuckStageQueryService.RuleCluster>{
            stage => new WatcherStuckStageQueryService.RuleCluster(daysIdle, isCritical)
        };
    }

    /**
     * @description Seeds N WorkItems stuck in `stage` with the given
     *              StageEnteredDateTime__c value. Uses TestDataFactory so
     *              required Master-Detail parents are auto-populated.
     * @param stage         Stage name.
     * @param count         Number of WIs to insert.
     * @param stageEnteredTs Backdated StageEnteredDateTime__c value.
     */
    private static void seedStuckWorkItems(String stage, Integer count, Datetime stageEnteredTs) {
        for (Integer i = 0; i < count; i++) {
            TestDataFactory.createWorkItem(new Map<String, Object>{
                'BriefDescriptionTxt__c' => 'Stuck WI ' + i,
                'StageNamePk__c' => stage,
                'StageEnteredDateTime__c' => stageEnteredTs
            });
        }
    }
}

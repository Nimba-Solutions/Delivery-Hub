/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Unit tests for WatcherSLABreachQueryService. SLAStatusTxt__c
 *              is a formula derived from SLATargetDate__c + StageNamePk__c,
 *              so tests seed WIs with explicit SLATargetDate__c values that
 *              place them in the Breached or At Risk buckets per the
 *              formula in objects/WorkItem__c/fields/SLAStatusTxt__c.
 *
 *              Formula recap:
 *                target blank          → ''
 *                stage terminal        → 'Met'
 *                target < TODAY        → 'Breached'
 *                target - TODAY ≤ 2    → 'At Risk'
 *                otherwise             → 'On Track'
 * @author Cloud Nimbus LLC
 */
@IsTest
private class WatcherSLABreachQueryServiceTest {

    /**
     * @description Happy path: 2 Breached + 1 At Risk → counts 2/1, 3 entries.
     */
    @IsTest
    static void testHappyPathReturnsCountsAndEntries() {
        seedAlertableWorkItems(2, 1);

        Test.startTest();
        SignalResultDTO result = WatcherSLABreachQueryService.query();
        Test.stopTest();

        System.assertNotEquals(null, result, 'Query should never return null on the happy path');
        System.assertEquals('SLABreach', result.signalName, 'signalName should be SLABreach');
        System.assertEquals(2, result.primaryCount,
            'primaryCount should reflect the seeded Breached count');
        System.assertEquals(1, result.secondaryCount,
            'secondaryCount should reflect the seeded At Risk count');
        System.assertEquals(3, result.topEntries.size(),
            'topEntries should surface all 3 seeded alertable WIs');
        // Spot-check entry shape.
        SignalEntryDTO first = result.topEntries.get(0);
        System.assertNotEquals(null, first.recordId, 'Entry should carry the WI Id');
        System.assertNotEquals(null, first.label, 'Entry should carry a label');
        System.assertNotEquals(null, first.detailLine, 'Entry should carry a detail line');
    }

    /**
     * @description Empty path: no alertable WIs → counts zero, no entries,
     *              no error.
     */
    @IsTest
    static void testEmptyReturnsZeroCounts() {
        // Seed nothing alertable. Insert one On-Track WI to prove the
        // filter excludes it.
        WorkItem__c onTrack = TestDataFactory.createWorkItem(new Map<String, Object>{
            'BriefDescriptionTxt__c' => 'On track WI',
            'StageNamePk__c' => 'In Development',
            'SLATargetDate__c' => Date.today().addDays(30)
        });
        System.assertNotEquals(null, onTrack.Id, 'Seed insert should have succeeded');

        Test.startTest();
        SignalResultDTO result = WatcherSLABreachQueryService.query();
        Test.stopTest();

        System.assertEquals(0, result.primaryCount, 'No alertable WIs → primaryCount=0');
        System.assertEquals(0, result.secondaryCount, 'No alertable WIs → secondaryCount=0');
        System.assertEquals(0, result.topEntries.size(), 'No alertable WIs → empty entries');
    }

    /**
     * @description Bulk: 60 alertable WIs → respects LIMIT 50 + caps
     *              topEntries at 5.
     */
    @IsTest
    static void testBulkRespectsLimit() {
        seedAlertableWorkItems(60, 0);

        Test.startTest();
        SignalResultDTO result = WatcherSLABreachQueryService.query();
        Test.stopTest();

        // The SOQL is LIMIT 50; primaryCount is computed from query rows so it
        // reflects up to 50, not the seeded 60.
        System.assert(result.primaryCount <= 50,
            'primaryCount should be capped at LIMIT 50, got ' + result.primaryCount);
        System.assert(result.primaryCount >= 49,
            'primaryCount should pull at or near the LIMIT, got ' + result.primaryCount);
        System.assertEquals(5, result.topEntries.size(),
            'topEntries should be capped at TOP_ENTRY_CAP (5)');
    }

    /**
     * @description Templates, archived, terminal-stage, and child WIs must
     *              be excluded from the result set even when their SLA dates
     *              would otherwise alert.
     */
    @IsTest
    static void testExcludedRecordsNotSurfaced() {
        Date breachedDate = Date.today().addDays(-3);
        // Template — should be excluded by TemplateMarkedDateTime__c filter.
        TestDataFactory.createWorkItem(new Map<String, Object>{
            'BriefDescriptionTxt__c' => 'Template WI',
            'StageNamePk__c' => 'In Development',
            'SLATargetDate__c' => breachedDate,
            'TemplateMarkedDateTime__c' => Datetime.now()
        });
        // Archived — should be excluded by ArchivedDateTime__c filter.
        TestDataFactory.createWorkItem(new Map<String, Object>{
            'BriefDescriptionTxt__c' => 'Archived WI',
            'StageNamePk__c' => 'In Development',
            'SLATargetDate__c' => breachedDate,
            'ArchivedDateTime__c' => Datetime.now()
        });
        // Terminal stage 'Done' → SLA formula returns Met, excluded by IN clause too.
        TestDataFactory.createWorkItem(new Map<String, Object>{
            'BriefDescriptionTxt__c' => 'Done WI',
            'StageNamePk__c' => 'Done',
            'SLATargetDate__c' => breachedDate
        });
        // Deactivated WI — should be excluded by ActivatedDateTime__c filter.
        TestDataFactory.createWorkItem(new Map<String, Object>{
            'BriefDescriptionTxt__c' => 'Deactivated WI',
            'StageNamePk__c' => 'In Development',
            'SLATargetDate__c' => breachedDate,
            'ActivatedDateTime__c' => null
        });
        // Child WI — should be excluded by ParentWorkItemLookup__c filter.
        WorkItem__c parent = TestDataFactory.createWorkItem(new Map<String, Object>{
            'BriefDescriptionTxt__c' => 'Parent WI for child exclusion test',
            'StageNamePk__c' => 'In Development',
            'SLATargetDate__c' => Date.today().addDays(30)
        });
        TestDataFactory.createWorkItem(new Map<String, Object>{
            'BriefDescriptionTxt__c' => 'Child WI',
            'StageNamePk__c' => 'In Development',
            'SLATargetDate__c' => breachedDate,
            'ParentWorkItemLookup__c' => parent.Id
        });

        Test.startTest();
        SignalResultDTO result = WatcherSLABreachQueryService.query();
        Test.stopTest();

        System.assertEquals(0, result.primaryCount,
            'All excluded records should not be surfaced — got ' + result.primaryCount + ' breached');
        System.assertEquals(0, result.secondaryCount,
            'No at-risk records should surface — got ' + result.secondaryCount);
    }

    /**
     * @description Seeds N Breached + M At-Risk WIs using TestDataFactory.
     *              Breached WIs have SLATargetDate__c in the past (the
     *              formula returns 'Breached' when target < TODAY).
     *              At-Risk WIs have SLATargetDate__c within 2 days of today.
     * @param breachedCount Number of breached WIs to insert.
     * @param atRiskCount   Number of at-risk WIs to insert.
     */
    private static void seedAlertableWorkItems(Integer breachedCount, Integer atRiskCount) {
        Date breachedDate = Date.today().addDays(-3);
        Date atRiskDate = Date.today().addDays(1);
        for (Integer i = 0; i < breachedCount; i++) {
            TestDataFactory.createWorkItem(new Map<String, Object>{
                'BriefDescriptionTxt__c' => 'Breached WI ' + i,
                'StageNamePk__c' => 'In Development',
                'SLATargetDate__c' => breachedDate
            });
        }
        for (Integer i = 0; i < atRiskCount; i++) {
            TestDataFactory.createWorkItem(new Map<String, Object>{
                'BriefDescriptionTxt__c' => 'At Risk WI ' + i,
                'StageNamePk__c' => 'In Development',
                'SLATargetDate__c' => atRiskDate
            });
        }
    }
}

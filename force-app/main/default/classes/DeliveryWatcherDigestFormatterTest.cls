/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Tests for DeliveryWatcherDigestFormatter. Asserts Block Kit
 *              shape on non-quiet runs, plaintext shape always, and null
 *              Block Kit return on quiet days.
 * @author Cloud Nimbus LLC
 */
@IsTest
private class DeliveryWatcherDigestFormatterTest {

    /**
     * @description Builds a non-quiet WatcherRunResultDTO with one Breached
     *              + one At Risk entry, runs both formatters, and asserts
     *              the expected shapes.
     */
    @IsTest
    static void testNonQuietProducesBlockKitAndMarkdown() {
        DeliveryWatcherService.WatcherRunResultDTO result =
            new DeliveryWatcherService.WatcherRunResultDTO();
        SignalResultDTO sla = SignalResultDTO.emptyResult('SLABreach');
        sla.primaryCount = 1;
        sla.secondaryCount = 1;
        sla.topEntries = new List<SignalEntryDTO>{
            new SignalEntryDTO(null, 'T-0142 — Compliance gate',
                '3 days breached · stage: In Review',
                'https://example.test/lightning/r/WorkItem__c/x/view'),
            new SignalEntryDTO(null, 'T-0167 — Cashflow report',
                '1 day to deadline · stage: Testing', null)
        };
        result.slaSignal = sla;
        result.slaBreachCount = 1;
        result.slaAtRiskCount = 1;
        result.runDurationMs = 847L;
        result.status = 'Success';

        Test.startTest();
        Map<String, Object> blockKit = DeliveryWatcherDigestFormatter.buildBlockKit(result, '2026-05-19 08:00 ET');
        String md = DeliveryWatcherDigestFormatter.buildMarkdown(result, '2026-05-19 08:00 ET');
        Test.stopTest();

        System.assertNotEquals(null, blockKit, 'Non-quiet day should return a Block Kit payload');
        System.assert(blockKit.containsKey('blocks'),
            'Block Kit payload should contain a "blocks" key');
        List<Object> blocks = (List<Object>) blockKit.get('blocks');
        System.assert(blocks.size() >= 2,
            'Block Kit should include header + at least one signal section + context');
        // Serialize round-trip to prove it's valid JSON.
        String serialized = JSON.serialize(blockKit);
        System.assertNotEquals(null, serialized, 'Block Kit must serialize cleanly');
        System.assert(serialized.contains('Watcher Digest'),
            'Header text should mention "Watcher Digest"');

        System.assertNotEquals(null, md, 'Markdown should never be null on non-quiet runs');
        System.assert(md.contains('Watcher Digest'),
            'Markdown should include header text');
        System.assert(md.contains('SLA Breach (1)'),
            'Markdown should include Breached header — got: ' + md);
        System.assert(md.contains('At Risk in <48h (1)'),
            'Markdown should include At Risk header');
        System.assert(md.contains('Counts: SLA=2'),
            'Markdown footer should sum primary+secondary SLA counts');
    }

    /**
     * @description Quiet-day path: all signals returned zero entries →
     *              buildBlockKit returns null; buildMarkdown returns a
     *              short "all clear" string.
     */
    @IsTest
    static void testQuietDayReturnsNullBlockKitAndStillRendersMarkdown() {
        DeliveryWatcherService.WatcherRunResultDTO result =
            new DeliveryWatcherService.WatcherRunResultDTO();
        result.slaSignal = SignalResultDTO.emptyResult('SLABreach');
        result.runDurationMs = 200L;
        result.status = 'Success';

        Test.startTest();
        Map<String, Object> blockKit = DeliveryWatcherDigestFormatter.buildBlockKit(result, '2026-05-19 08:00 ET');
        String md = DeliveryWatcherDigestFormatter.buildMarkdown(result, '2026-05-19 08:00 ET');
        Test.stopTest();

        System.assertEquals(null, blockKit, 'Quiet day should suppress the Slack payload');
        System.assertNotEquals(null, md, 'Markdown should still be produced for the audit row');
        System.assert(md.contains('All clear'),
            'Quiet-day markdown should reassure with "All clear" — got: ' + md);
    }

    /**
     * @description Null DTO path: defensive return rather than NPE.
     */
    @IsTest
    static void testNullResultProducesPlaceholderMarkdown() {
        Test.startTest();
        String md = DeliveryWatcherDigestFormatter.buildMarkdown(null, null);
        Test.stopTest();
        System.assertNotEquals(null, md, 'Markdown should never be null even for null input');
        System.assert(md.contains('All clear'),
            'Null-input markdown should still reassure — got: ' + md);
    }

    /**
     * @description All-three-signals populated: SLA + Stuck Stage + A/R
     *              Aging entries → markdown should contain headings for
     *              every section, footer should include the AR dollar
     *              amount in parens.
     */
    @IsTest
    static void testAllThreeSignalsRenderEverySection() {
        DeliveryWatcherService.WatcherRunResultDTO result =
            new DeliveryWatcherService.WatcherRunResultDTO();
        // SLA — 1 Breached + 1 At Risk.
        SignalResultDTO sla = SignalResultDTO.emptyResult('SLABreach');
        sla.primaryCount = 1;
        sla.secondaryCount = 1;
        sla.topEntries = new List<SignalEntryDTO>{
            new SignalEntryDTO(null, 'T-0142 — Compliance gate',
                '3 days breached · stage: In Review', null),
            new SignalEntryDTO(null, 'T-0167 — Cashflow report',
                '1 day to deadline · stage: Testing', null)
        };
        result.slaSignal = sla;
        result.slaBreachCount = 1;
        result.slaAtRiskCount = 1;
        // Stuck Stage — 1 entry.
        SignalResultDTO stuck = SignalResultDTO.emptyResult('StuckStage');
        stuck.primaryCount = 1;
        stuck.secondaryCount = 1;
        stuck.topEntries = new List<SignalEntryDTO>{
            new SignalEntryDTO(null, 'T-0151 — Slack inbound refactor',
                '6 days in Code Review (Critical)', null)
        };
        result.stuckSignal = stuck;
        result.stuckStageCount = 1;
        // A/R Aging — 2 entries.
        SignalResultDTO ar = SignalResultDTO.emptyResult('ARAging');
        ar.primaryCount = 2;
        ar.secondaryCount = 4300;
        ar.topEntries = new List<SignalEntryDTO>{
            new SignalEntryDTO(null, 'INV-0042 — ACME Inc',
                '$2,800 · 45 days overdue (30+)', null),
            new SignalEntryDTO(null, 'INV-0043 — Globex Corp',
                '$1,500 · 20 days overdue (15-30)', null)
        };
        result.arSignal = ar;
        result.arOverdueCount = 2;
        result.arOverdueAmount = 4300;
        result.runDurationMs = 847L;
        result.status = 'Success';

        Test.startTest();
        Map<String, Object> blockKit = DeliveryWatcherDigestFormatter.buildBlockKit(result, '2026-05-21 08:00 ET');
        String md = DeliveryWatcherDigestFormatter.buildMarkdown(result, '2026-05-21 08:00 ET');
        Test.stopTest();

        System.assertNotEquals(null, blockKit, 'Non-quiet day should return a Block Kit payload');
        List<Object> blocks = (List<Object>) blockKit.get('blocks');
        // header + SLA breach + SLA at-risk + stuck + AR + context = at least 6 blocks.
        System.assert(blocks.size() >= 6,
            'All-three-signal payload should include header + 4 signal sections + context — got ' + blocks.size());
        System.assert(md.contains('SLA Breach (1)'),
            'Markdown should include SLA Breach heading — got: ' + md);
        System.assert(md.contains('At Risk in <48h (1)'),
            'Markdown should include At Risk heading');
        System.assert(md.contains('Stuck Stage (1)'),
            'Markdown should include Stuck Stage heading — got: ' + md);
        System.assert(md.contains('A/R Aging (2)'),
            'Markdown should include A/R Aging heading — got: ' + md);
        System.assert(md.contains('$4300 overdue'),
            'A/R header should embed total amount — got: ' + md);
        System.assert(md.contains('AR=2 ($4300)'),
            'Footer should include AR count + dollar suffix — got: ' + md);
    }

    /**
     * @description Signals 2 + 3 populated but SLA empty: output should
     *              skip the SLA section entirely, leading with Stuck Stage.
     */
    @IsTest
    static void testStuckAndArOnlySkipsSlaSection() {
        DeliveryWatcherService.WatcherRunResultDTO result =
            new DeliveryWatcherService.WatcherRunResultDTO();
        result.slaSignal = SignalResultDTO.emptyResult('SLABreach');
        result.slaBreachCount = 0;
        result.slaAtRiskCount = 0;
        SignalResultDTO stuck = SignalResultDTO.emptyResult('StuckStage');
        stuck.primaryCount = 2;
        stuck.secondaryCount = 2;
        stuck.topEntries = new List<SignalEntryDTO>{
            new SignalEntryDTO(null, 'T-0151 — Slack refactor', '6 days in Code Review', null),
            new SignalEntryDTO(null, 'T-0152 — Login UI', '5 days in Code Review', null)
        };
        result.stuckSignal = stuck;
        result.stuckStageCount = 2;
        SignalResultDTO ar = SignalResultDTO.emptyResult('ARAging');
        ar.primaryCount = 1;
        ar.secondaryCount = 800;
        ar.topEntries = new List<SignalEntryDTO>{
            new SignalEntryDTO(null, 'INV-0050 — Initech', '$800 · 12 days overdue (8-14)', null)
        };
        result.arSignal = ar;
        result.arOverdueCount = 1;
        result.arOverdueAmount = 800;
        result.runDurationMs = 410L;
        result.status = 'Success';

        Test.startTest();
        String md = DeliveryWatcherDigestFormatter.buildMarkdown(result, '2026-05-21 08:00 ET');
        Test.stopTest();

        System.assert(!md.contains('SLA Breach'),
            'No SLA section should render when both breached + at-risk counts are zero');
        System.assert(!md.contains('At Risk in <48h'),
            'No At Risk section should render when atRiskCount is zero');
        System.assert(md.contains('Stuck Stage (2)'),
            'Stuck Stage section should render — got: ' + md);
        System.assert(md.contains('A/R Aging (1)'),
            'A/R Aging section should render — got: ' + md);
    }
}

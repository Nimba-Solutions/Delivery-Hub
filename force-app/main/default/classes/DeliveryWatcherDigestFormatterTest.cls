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
}

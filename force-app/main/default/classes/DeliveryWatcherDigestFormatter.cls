/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Builds the two output formats for a Watcher run:
 *
 *                1. Slack Block Kit payload (Map&lt;String,Object&gt;) for
 *                   posting via DeliverySlackService.postWatcherDigest.
 *                   Returns null when there's nothing to say (quiet day) so
 *                   the orchestrator can skip Slack while still writing the
 *                   audit row.
 *
 *                2. Plaintext markdown fallback persisted to
 *                   WatcherDigest__c.DigestBodyTxt__c. Always populated
 *                   (even on quiet days a short "0 items" string is stored).
 *
 *              Mirror of DeliverySlackService.buildCommentBatchPayload —
 *              same Block Kit section/context shape.
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.CyclomaticComplexity,PMD.StdCyclomaticComplexity,PMD.NcssMethodCount,PMD.NcssTypeCount')
public with sharing class DeliveryWatcherDigestFormatter {

    /** @description Newline used when concatenating plaintext body lines. */
    private static final String NL = '\n';

    /**
     * @description Builds the Slack Block Kit payload for the run. Returns
     *              null on a quiet day (no signal reported any entries) so
     *              the orchestrator can skip posting.
     * @param result     Aggregated run result from DeliveryWatcherService.
     * @param runDateLabel Human-friendly date label (e.g. `2026-05-19 08:00 ET`).
     * @return Block Kit map ready for JSON.serialize, or null on quiet days.
     */
    public static Map<String, Object> buildBlockKit(
        DeliveryWatcherService.WatcherRunResultDTO result,
        String runDateLabel
    ) {
        if (isQuietDay(result)) {
            return null;
        }
        Integer totalItems = totalSurfacedCount(result);
        List<Object> blocks = new List<Object>();
        blocks.add(buildHeaderBlock(runDateLabel, totalItems));
        appendSlaBreachSection(blocks, result);
        appendStuckStageSection(blocks, result);
        appendArAgingSection(blocks, result);
        blocks.add(buildContextBlock(result));
        return new Map<String, Object>{ 'blocks' => blocks };
    }

    /**
     * @description Builds the plaintext markdown body — both the audit
     *              record's body field and a human-readable replay surface.
     *              Always populated, even on quiet days.
     * @param result     Aggregated run result from DeliveryWatcherService.
     * @param runDateLabel Human-friendly date label.
     * @return Plaintext / markdown string.
     */
    public static String buildMarkdown(
        DeliveryWatcherService.WatcherRunResultDTO result,
        String runDateLabel
    ) {
        if (result == null) {
            return ':eyes: Watcher Digest — ' + safeLabel(runDateLabel)
                + NL + '0 items today. All clear.';
        }
        if (isQuietDay(result)) {
            return ':eyes: Watcher Digest — ' + safeLabel(runDateLabel)
                + NL + '0 items today. All clear.'
                + NL + buildCountsLine(result);
        }
        Integer totalItems = totalSurfacedCount(result);
        List<String> lines = new List<String>();
        lines.add(':eyes: Watcher Digest — ' + safeLabel(runDateLabel));
        lines.add(totalItems + ' item' + (totalItems == 1 ? '' : 's')
            + ' need' + (totalItems == 1 ? 's' : '') + ' your eyes today.');
        appendSlaMarkdownLines(lines, result);
        appendStuckStageMarkdownLines(lines, result);
        appendArAgingMarkdownLines(lines, result);
        lines.add('');
        lines.add(buildCountsLine(result));
        return String.join(lines, NL);
    }

    /**
     * @description Detects the quiet-day condition — all signals reported 0
     *              entries (regardless of whether they ran or were
     *              flag-gated off).
     * @param result Aggregated run result.
     * @return true when nothing should be posted to Slack.
     */
    private static Boolean isQuietDay(DeliveryWatcherService.WatcherRunResultDTO result) {
        if (result == null) {
            return true;
        }
        return totalSurfacedCount(result) == 0;
    }

    /**
     * @description Sums all per-signal counts to determine whether anything
     *              needs to be surfaced.
     * @param result Aggregated run result.
     * @return Total count across all signals (including At Risk under SLA).
     */
    private static Integer totalSurfacedCount(DeliveryWatcherService.WatcherRunResultDTO result) {
        Integer total = 0;
        total += safeInt(result.slaBreachCount);
        total += safeInt(result.slaAtRiskCount);
        total += safeInt(result.stuckStageCount);
        total += safeInt(result.arOverdueCount);
        return total;
    }

    /**
     * @description Builds the Block Kit header block.
     * @param runDateLabel Date label (e.g. `2026-05-19 08:00 ET`).
     * @param totalItems   Sum of all per-signal counts.
     * @return Header block map.
     */
    private static Map<String, Object> buildHeaderBlock(String runDateLabel, Integer totalItems) {
        String header = ':eyes: *Watcher Digest — ' + safeLabel(runDateLabel) + '*'
            + NL + totalItems + ' item' + (totalItems == 1 ? '' : 's')
            + ' need' + (totalItems == 1 ? 's' : '') + ' your eyes today.';
        return new Map<String, Object>{
            'type' => 'section',
            'text' => new Map<String, Object>{
                'type' => 'mrkdwn',
                'text' => header
            }
        };
    }

    /**
     * @description Appends the SLA Breach + At Risk block(s) when the
     *              signal returned entries. Splits the entries into two
     *              sections: breached (first slaBreachCount entries) and
     *              at-risk (the remaining entries from the topEntries list).
     * @param blocks Block Kit accumulator.
     * @param result Aggregated run result.
     */
    private static void appendSlaBreachSection(
        List<Object> blocks,
        DeliveryWatcherService.WatcherRunResultDTO result
    ) {
        if (result.slaSignal == null || result.slaSignal.topEntries == null
            || result.slaSignal.topEntries.isEmpty()) {
            return;
        }
        Integer breachCount = safeInt(result.slaBreachCount);
        Integer atRiskCount = safeInt(result.slaAtRiskCount);
        if (breachCount > 0) {
            blocks.add(buildEntryBlock(
                '*SLA Breach (' + breachCount + ')*',
                sliceEntries(result.slaSignal.topEntries, 0, breachCount)
            ));
        }
        if (atRiskCount > 0) {
            blocks.add(buildEntryBlock(
                '*At Risk in <48h (' + atRiskCount + ')*',
                sliceEntries(result.slaSignal.topEntries, breachCount, result.slaSignal.topEntries.size())
            ));
        }
    }

    /**
     * @description Appends SLA-Breach markdown lines into the plaintext body.
     * @param lines  Accumulator for the markdown body.
     * @param result Aggregated run result.
     */
    private static void appendSlaMarkdownLines(
        List<String> lines,
        DeliveryWatcherService.WatcherRunResultDTO result
    ) {
        if (result.slaSignal == null || result.slaSignal.topEntries == null
            || result.slaSignal.topEntries.isEmpty()) {
            return;
        }
        Integer breachCount = safeInt(result.slaBreachCount);
        Integer atRiskCount = safeInt(result.slaAtRiskCount);
        Integer cursor = 0;
        if (breachCount > 0) {
            lines.add('');
            lines.add('*SLA Breach (' + breachCount + ')*');
            cursor = appendEntryLines(lines, result.slaSignal.topEntries, 0, breachCount);
        }
        if (atRiskCount > 0 && cursor < result.slaSignal.topEntries.size()) {
            lines.add('');
            lines.add('*At Risk in <48h (' + atRiskCount + ')*');
            appendEntryLines(lines, result.slaSignal.topEntries, cursor, result.slaSignal.topEntries.size());
        }
    }

    /**
     * @description Appends the Stuck Stage Block Kit section when the
     *              signal returned entries. Mirrors the SLA section shape.
     * @param blocks Block Kit accumulator.
     * @param result Aggregated run result.
     */
    private static void appendStuckStageSection(
        List<Object> blocks,
        DeliveryWatcherService.WatcherRunResultDTO result
    ) {
        if (result.stuckSignal == null || result.stuckSignal.topEntries == null
            || result.stuckSignal.topEntries.isEmpty()) {
            return;
        }
        Integer count = safeInt(result.stuckStageCount);
        if (count <= 0) {
            return;
        }
        blocks.add(buildEntryBlock(
            '*Stuck Stage (' + count + ')*',
            result.stuckSignal.topEntries
        ));
    }

    /**
     * @description Appends Stuck Stage markdown lines into the plaintext
     *              body when the signal surfaced entries.
     * @param lines  Accumulator for the markdown body.
     * @param result Aggregated run result.
     */
    private static void appendStuckStageMarkdownLines(
        List<String> lines,
        DeliveryWatcherService.WatcherRunResultDTO result
    ) {
        if (result.stuckSignal == null || result.stuckSignal.topEntries == null
            || result.stuckSignal.topEntries.isEmpty()) {
            return;
        }
        Integer count = safeInt(result.stuckStageCount);
        if (count <= 0) {
            return;
        }
        lines.add('');
        lines.add('*Stuck Stage (' + count + ')*');
        for (SignalEntryDTO e : result.stuckSignal.topEntries) {
            lines.add(renderEntry(e));
        }
    }

    /**
     * @description Appends the A/R Aging Block Kit section when the signal
     *              returned entries. Includes the total-amount summary in
     *              the section header for an at-a-glance view of exposure.
     * @param blocks Block Kit accumulator.
     * @param result Aggregated run result.
     */
    private static void appendArAgingSection(
        List<Object> blocks,
        DeliveryWatcherService.WatcherRunResultDTO result
    ) {
        if (result.arSignal == null || result.arSignal.topEntries == null
            || result.arSignal.topEntries.isEmpty()) {
            return;
        }
        Integer count = safeInt(result.arOverdueCount);
        if (count <= 0) {
            return;
        }
        blocks.add(buildEntryBlock(
            buildArHeader(count, safeInt(result.arOverdueAmount)),
            result.arSignal.topEntries
        ));
    }

    /**
     * @description Appends A/R Aging markdown lines into the plaintext body.
     * @param lines  Accumulator for the markdown body.
     * @param result Aggregated run result.
     */
    private static void appendArAgingMarkdownLines(
        List<String> lines,
        DeliveryWatcherService.WatcherRunResultDTO result
    ) {
        if (result.arSignal == null || result.arSignal.topEntries == null
            || result.arSignal.topEntries.isEmpty()) {
            return;
        }
        Integer count = safeInt(result.arOverdueCount);
        if (count <= 0) {
            return;
        }
        lines.add('');
        lines.add(buildArHeader(count, safeInt(result.arOverdueAmount)));
        for (SignalEntryDTO e : result.arSignal.topEntries) {
            lines.add(renderEntry(e));
        }
    }

    /**
     * @description Builds the A/R section header — e.g.
     *              `*A/R Aging (3) · $4,300 overdue*`.
     * @param count        Number of overdue invoices.
     * @param totalAmount  Sum of TotalCurrency__c across the result set
     *                     (major units, cents truncated).
     * @return Header string for the section.
     */
    private static String buildArHeader(Integer count, Integer totalAmount) {
        if (totalAmount <= 0) {
            return '*A/R Aging (' + count + ')*';
        }
        return '*A/R Aging (' + count + ') · $' + totalAmount + ' overdue*';
    }

    /**
     * @description Builds a Block Kit section block bundling a header line +
     *              a bulleted list of entries.
     * @param headerLine Bold header for the section.
     * @param entries    Entries to render under the header.
     * @return Block Kit section map.
     */
    private static Map<String, Object> buildEntryBlock(String headerLine, List<SignalEntryDTO> entries) {
        List<String> bodyLines = new List<String>();
        bodyLines.add(headerLine);
        for (SignalEntryDTO e : entries) {
            bodyLines.add(renderEntry(e));
        }
        return new Map<String, Object>{
            'type' => 'section',
            'text' => new Map<String, Object>{
                'type' => 'mrkdwn',
                'text' => String.join(bodyLines, NL)
            }
        };
    }

    /**
     * @description Builds the trailing context block — small grey footer with
     *              compact counts + duration.
     * @param result Aggregated run result.
     * @return Context block map.
     */
    private static Map<String, Object> buildContextBlock(DeliveryWatcherService.WatcherRunResultDTO result) {
        return new Map<String, Object>{
            'type' => 'context',
            'elements' => new List<Object>{
                new Map<String, Object>{
                    'type' => 'mrkdwn',
                    'text' => buildCountsLine(result)
                }
            }
        };
    }

    /**
     * @description Builds the one-line `Counts: SLA=3, Stuck=1, AR=2 ($4300) | 847ms`
     *              footer used in both Slack context block and plaintext body.
     * @param result Aggregated run result.
     * @return Counts line string.
     */
    private static String buildCountsLine(DeliveryWatcherService.WatcherRunResultDTO result) {
        Integer slaTotal = safeInt(result.slaBreachCount) + safeInt(result.slaAtRiskCount);
        Integer arAmount = safeInt(result.arOverdueAmount);
        String arSuffix = arAmount > 0 ? (' ($' + arAmount + ')') : '';
        String durationPart = result.runDurationMs == null
            ? ''
            : (' | ' + result.runDurationMs + 'ms');
        return 'Counts: SLA=' + slaTotal
            + ', Stuck=' + safeInt(result.stuckStageCount)
            + ', AR=' + safeInt(result.arOverdueCount) + arSuffix
            + durationPart;
    }

    /**
     * @description Renders one digest entry as a markdown bullet line.
     * @param e Entry to render.
     * @return Markdown line, prefixed with bullet glyph.
     */
    private static String renderEntry(SignalEntryDTO e) {
        if (e == null) {
            return '• (empty entry)';
        }
        String labelPart;
        if (String.isNotBlank(e.url) && String.isNotBlank(e.label)) {
            labelPart = '<' + e.url + '|' + e.label + '>';
        } else if (String.isNotBlank(e.label)) {
            labelPart = e.label;
        } else {
            labelPart = '(unnamed)';
        }
        String detailPart = String.isBlank(e.detailLine) ? '' : (' · ' + e.detailLine);
        return '• ' + labelPart + detailPart;
    }

    /**
     * @description Returns the sublist of `entries` from `fromIndex`
     *              (inclusive) to `toIndex` (exclusive). Apex List has no
     *              sublist — manual copy.
     * @param entries  Full list of entries.
     * @param fromIndex Start index (inclusive).
     * @param toIndex   End index (exclusive).
     * @return New list containing the selected entries; never null.
     */
    private static List<SignalEntryDTO> sliceEntries(List<SignalEntryDTO> entries, Integer fromIndex, Integer toIndex) {
        List<SignalEntryDTO> out = new List<SignalEntryDTO>();
        if (entries == null) {
            return out;
        }
        Integer start = Math.max(0, fromIndex);
        Integer endIndex = Math.min(entries.size(), toIndex);
        for (Integer i = start; i < endIndex; i++) {
            out.add(entries.get(i));
        }
        return out;
    }

    /**
     * @description Appends renderEntry output for the given slice into
     *              the line accumulator.
     * @param lines   Accumulator for the markdown body.
     * @param entries Full entry list.
     * @param fromIndex Start index (inclusive).
     * @param toIndex   End index (exclusive).
     * @return Index immediately after the last appended entry.
     */
    private static Integer appendEntryLines(List<String> lines, List<SignalEntryDTO> entries, Integer fromIndex, Integer toIndex) {
        if (entries == null) {
            return fromIndex;
        }
        Integer start = Math.max(0, fromIndex);
        Integer endIndex = Math.min(entries.size(), toIndex);
        for (Integer i = start; i < endIndex; i++) {
            lines.add(renderEntry(entries.get(i)));
        }
        return endIndex;
    }

    /**
     * @description Null-tolerant Integer accessor.
     * @param v Possibly null Integer.
     * @return v when non-null, else 0.
     */
    private static Integer safeInt(Integer v) {
        return v == null ? 0 : v;
    }

    /**
     * @description Null/blank-tolerant label.
     * @param label Possibly null/blank label.
     * @return label when non-blank, else current Datetime.
     */
    private static String safeLabel(String label) {
        return String.isBlank(label) ? Datetime.now().format('yyyy-MM-dd HH:mm') : label;
    }
}

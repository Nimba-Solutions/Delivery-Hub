/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Signal 3 — surfaces DeliveryDocument__c invoices that have
 *              been Overdue past the configured minimum-days-overdue
 *              threshold. Reads
 *              DeliveryHubSettings__c.WatcherARAgingMinDaysOverdueNumber__c
 *              (default 7) so the signal doesn't overlap with the first-pass
 *              reminder window covered by DeliveryOverdueReminderService.
 *
 *              Detection mechanism:
 *                - Query DeliveryDocument__c WHERE TemplatePk__c='Invoice'
 *                  AND StatusPk__c='Overdue' AND DueDateDate__c is non-null
 *                  AND DueDateDate__c &lt; (TODAY - minDaysOverdue).
 *                - Exclude disputed invoices (StatusPk__c='Disputed' is
 *                  mutually exclusive with 'Overdue' on the picklist —
 *                  disputed docs never reach this signal). LongTextArea
 *                  fields like DisputeReasonTxt__c cannot be filtered in
 *                  SOQL, so no belt-and-suspenders predicate.
 *                - Exclude superseded versions — StatusPk__c='Superseded' is
 *                  not 'Overdue' so already excluded; PreviousVersionLookup__c
 *                  is purely informational and not a filter (the superseded
 *                  row keeps Superseded status by convention).
 *                - Single SOQL, ordered TotalCurrency__c DESC for the
 *                  top-5 high-value bucket.
 *
 *              Result shape:
 *                primaryCount   = total count of overdue invoices past threshold
 *                secondaryCount = total $ amount across the result set
 *                                 (Integer/Long cast — major-units only;
 *                                  cents truncated for compact reporting)
 *                topEntries     = top 5 by TotalCurrency__c descending
 *
 *              Aging-band tally is recorded into each entry's detailLine
 *              so the Slack body can surface "1 in 30+ band, 2 in 15-30
 *              band" without re-computation downstream.
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.ApexCRUDViolation,PMD.CyclomaticComplexity,PMD.StdCyclomaticComplexity')
public with sharing class WatcherARAgingQueryService {

    /** @description Stable signal identifier surfaced into WatcherDigest__c.SignalCountsTxt__c + the digest body. */
    public static final String SIGNAL_NAME = 'ARAging';

    /** @description Default min-days-overdue floor when settings field is null. */
    @TestVisible
    private static final Integer DEFAULT_MIN_DAYS = 7;

    /** @description Max rows pulled from the AR sweep. Single SOQL, no fan-out. */
    @TestVisible
    private static final Integer ROW_CAP = 50;

    /** @description Max body entries surfaced into the digest message. */
    @TestVisible
    private static final Integer TOP_ENTRY_CAP = 5;

    /**
     * @description Run the signal. Single SOQL against DeliveryDocument__c
     *              filtered to Overdue invoices past the configured min-
     *              days-overdue threshold. Returns counts + top 5 by amount.
     * @return SignalResultDTO with counts + up to 5 entries.
     */
    public static SignalResultDTO query() {
        Integer minDaysOverdue = resolveMinDaysOverdue();
        Date cutoff = Date.today().addDays(-minDaysOverdue);
        List<DeliveryDocument__c> rows = fetchOverdueInvoices(cutoff);
        return assembleResult(rows);
    }

    /**
     * @description Reads the org-default min-days-overdue threshold from
     *              DeliveryHubSettings__c. Falls back to DEFAULT_MIN_DAYS
     *              when null / not configured / out of sane bounds.
     * @return Min days overdue threshold (>= 1).
     */
    private static Integer resolveMinDaysOverdue() {
        DeliveryHubSettings__c settings = DeliveryHubSettings__c.getOrgDefaults();
        if (settings == null || settings.WatcherARAgingMinDaysOverdueNumber__c == null) {
            return DEFAULT_MIN_DAYS;
        }
        Integer configured = settings.WatcherARAgingMinDaysOverdueNumber__c.intValue();
        return configured < 1 ? DEFAULT_MIN_DAYS : configured;
    }

    /**
     * @description Pulls overdue invoices past the cutoff in a single bulk
     *              SOQL. Ordered by TotalCurrency__c DESC so topEntries
     *              naturally renders highest-dollar first.
     * @param cutoff DueDateDate__c must be strictly before this date.
     * @return List of DeliveryDocument__c rows, capped at ROW_CAP.
     */
    private static List<DeliveryDocument__c> fetchOverdueInvoices(Date cutoff) {
        // DisputeReasonTxt__c is LongTextArea — not filterable in SOQL
        // (platform rejection: "field can not be filtered in a query call").
        // StatusPk__c = 'Overdue' is mutually exclusive with 'Disputed' on the
        // picklist, so the prior dispute-reason predicate was redundant. Disputed
        // docs (StatusPk__c='Disputed') never reach this branch.
        return [
            SELECT Id, Name, DueDateDate__c, TotalCurrency__c,
                   StatusPk__c, TemplatePk__c, NetworkEntityId__c,
                   NetworkEntityId__r.Name
            FROM DeliveryDocument__c
            WHERE TemplatePk__c = 'Invoice'
              AND StatusPk__c = 'Overdue'
              AND DueDateDate__c != NULL
              AND DueDateDate__c < :cutoff
            WITH SYSTEM_MODE
            ORDER BY TotalCurrency__c DESC NULLS LAST, DueDateDate__c ASC NULLS LAST
            LIMIT :ROW_CAP
        ];
    }

    /**
     * @description Walks the queried invoices, sums totals into the
     *              secondary count, and builds the top-5 digest entries.
     * @param rows Result rows from fetchOverdueInvoices.
     * @return Fully-populated SignalResultDTO.
     */
    private static SignalResultDTO assembleResult(List<DeliveryDocument__c> rows) {
        SignalResultDTO result = SignalResultDTO.emptyResult(SIGNAL_NAME);
        if (rows == null || rows.isEmpty()) {
            return result;
        }
        Decimal totalAmount = 0;
        String orgUrl = safeOrgUrl();
        Date today = Date.today();
        for (DeliveryDocument__c doc : rows) {
            if (doc.TotalCurrency__c != null) {
                totalAmount += doc.TotalCurrency__c;
            }
            if (result.topEntries.size() < TOP_ENTRY_CAP) {
                result.topEntries.add(buildEntry(doc, orgUrl, today));
            }
        }
        result.primaryCount = rows.size();
        // secondaryCount = total dollar amount, major units (Integer cast).
        // We intentionally lose cents — the digest is a glance-summary.
        result.secondaryCount = totalAmount.intValue();
        return result;
    }

    /**
     * @description Builds one digest entry from a DeliveryDocument row.
     * @param doc    The invoice to render.
     * @param orgUrl Cached org URL.
     * @param today  Today's date for aging-band classification.
     * @return SignalEntryDTO with label + detail + record-page URL.
     */
    private static SignalEntryDTO buildEntry(DeliveryDocument__c doc, String orgUrl, Date today) {
        String partyName = (doc.NetworkEntityId__r != null
            && String.isNotBlank(doc.NetworkEntityId__r.Name))
            ? doc.NetworkEntityId__r.Name : 'Unknown party';
        String label = (String.isBlank(doc.Name) ? 'INV' : doc.Name) + ' — ' + partyName;
        String detail = buildDetailLine(doc, today);
        String recordUrl = String.isBlank(orgUrl)
            ? null
            : (orgUrl + '/lightning/r/DeliveryDocument__c/' + doc.Id + '/view');
        return new SignalEntryDTO(doc.Id, label, detail, recordUrl);
    }

    /**
     * @description Builds the per-entry detail string. Emits the total
     *              amount, days overdue, and an aging-band label
     *              (8-14 / 15-30 / 30+).
     * @param doc   Invoice row.
     * @param today Today's date.
     * @return Detail string for the digest body.
     */
    private static String buildDetailLine(DeliveryDocument__c doc, Date today) {
        Integer daysOverdue = (doc.DueDateDate__c == null)
            ? 0 : doc.DueDateDate__c.daysBetween(today);
        if (daysOverdue < 0) {
            daysOverdue = 0;
        }
        String amountPart = (doc.TotalCurrency__c == null)
            ? '' : ('$' + doc.TotalCurrency__c.setScale(0).format() + ' · ');
        String bandLabel = classifyAgingBand(daysOverdue);
        String unit = daysOverdue == 1 ? 'day' : 'days';
        return amountPart + daysOverdue + ' ' + unit + ' overdue (' + bandLabel + ')';
    }

    /**
     * @description Bucket helper for the aging-band labels surfaced into
     *              the per-entry detail line.
     * @param daysOverdue Days past due (>= 0).
     * @return Band label string (e.g. `8-14`, `15-30`, `30+`).
     */
    @TestVisible
    private static String classifyAgingBand(Integer daysOverdue) {
        if (daysOverdue >= 30) {
            return '30+';
        }
        if (daysOverdue >= 15) {
            return '15-30';
        }
        if (daysOverdue >= 8) {
            return '8-14';
        }
        return '1-7';
    }

    /**
     * @description Returns the org domain URL or empty string when
     *              unavailable. Mirrors WatcherSLABreachQueryService.
     * @return Org domain URL or empty string.
     */
    private static String safeOrgUrl() {
        try {
            Url u = Url.getOrgDomainUrl();
            return (u == null) ? '' : u.toExternalForm();
        } catch (Exception e) {
            return '';
        }
    }
}

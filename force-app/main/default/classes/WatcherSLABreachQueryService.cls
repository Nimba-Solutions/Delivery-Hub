/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Signal 1 — surfaces root-level WorkItems whose SLA formula
 *              field has tipped past `Breached` or `At Risk`. Reuses the
 *              existing WorkItem__c.SLAStatusTxt__c formula — no
 *              re-derivation. Single bulk SOQL, capped at 50, excludes
 *              templates / archived / terminal-stage / parent-WI rows.
 *
 *              Returns a SignalResultDTO with:
 *                primaryCount   = count of `Breached` WIs in the result set
 *                secondaryCount = count of `At Risk` WIs in the result set
 *                topEntries     = up to 5 by (breached first, then at-risk),
 *                                 ordered by SLATargetDate__c ASC (most
 *                                 overdue first).
 *
 *              Errors thrown by query() bubble up to the orchestrator's
 *              try/catch — this class deliberately does NOT catch internally.
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.ApexCRUDViolation')
public with sharing class WatcherSLABreachQueryService {

    /** @description Stable signal identifier surfaced into WatcherDigest__c.SignalCountsTxt__c + the digest body. */
    public static final String SIGNAL_NAME = 'SLABreach';

    /** @description Max rows pulled in a single sweep. Single SOQL, no fan-out per row. */
    @TestVisible
    private static final Integer ROW_CAP = 50;

    /** @description Max body entries surfaced into the digest message. */
    @TestVisible
    private static final Integer TOP_ENTRY_CAP = 5;

    /** @description Terminal stages excluded from sweep (matches the SLA formula's `Met` carve-out + adds a couple more). */
    private static final Set<String> EXCLUDED_STAGES = new Set<String>{
        'Done', 'Cancelled', 'Closed', 'Rejected', 'Deployed to Prod'
    };

    /**
     * @description Run the signal. Single SOQL over WorkItem__c, filtered by
     *              SLAStatusTxt__c IN ('Breached','At Risk'), root WIs only,
     *              non-template / non-archived / non-terminal.
     * @return SignalResultDTO with counts + up to 5 entries.
     */
    public static SignalResultDTO query() {
        List<WorkItem__c> rows = fetchAlertableWorkItems();
        return assembleResult(rows);
    }

    /**
     * @description Pulls the SLA-alertable WorkItems in a single bulk SOQL.
     *              Ordered breached-first, then At Risk; within each bucket
     *              the most overdue (smallest SLATargetDate__c) lands first.
     * @return List of WorkItem__c rows, max ROW_CAP entries.
     */
    private static List<WorkItem__c> fetchAlertableWorkItems() {
        return [
            SELECT Id, Name, BriefDescriptionTxt__c, StageNamePk__c,
                   SLAStatusTxt__c, SLATargetDate__c, OwnerId
            FROM WorkItem__c
            WHERE SLAStatusTxt__c IN ('Breached', 'At Risk')
              AND ParentWorkItemLookup__c = NULL
              AND ActivatedDateTime__c != NULL
              AND ArchivedDateTime__c = NULL
              AND TemplateMarkedDateTime__c = NULL
              AND StageNamePk__c NOT IN :EXCLUDED_STAGES
            WITH SYSTEM_MODE
            ORDER BY SLAStatusTxt__c ASC, SLATargetDate__c ASC NULLS LAST
            LIMIT :ROW_CAP
        ];
    }

    /**
     * @description Walks the queried rows, tallies counts per bucket, and
     *              builds up to TOP_ENTRY_CAP entries for the digest body.
     * @param rows Result rows from fetchAlertableWorkItems.
     * @return Fully-populated SignalResultDTO ready for orchestrator merge.
     */
    private static SignalResultDTO assembleResult(List<WorkItem__c> rows) {
        SignalResultDTO result = SignalResultDTO.emptyResult(SIGNAL_NAME);
        if (rows == null || rows.isEmpty()) {
            return result;
        }
        Integer breachedCount = 0;
        Integer atRiskCount = 0;
        String orgUrl = safeOrgUrl();
        for (WorkItem__c wi : rows) {
            if (wi.SLAStatusTxt__c == 'Breached') {
                breachedCount++;
            } else if (wi.SLAStatusTxt__c == 'At Risk') {
                atRiskCount++;
            }
            if (result.topEntries.size() < TOP_ENTRY_CAP) {
                result.topEntries.add(buildEntry(wi, orgUrl));
            }
        }
        result.primaryCount = breachedCount;
        result.secondaryCount = atRiskCount;
        return result;
    }

    /**
     * @description Builds one digest entry from a WorkItem row.
     * @param wi     The WorkItem to render.
     * @param orgUrl Cached org URL (or empty string if unavailable).
     * @return SignalEntryDTO with label + detail + record-page URL.
     */
    private static SignalEntryDTO buildEntry(WorkItem__c wi, String orgUrl) {
        String briefDesc = String.isBlank(wi.BriefDescriptionTxt__c)
            ? 'Untitled' : wi.BriefDescriptionTxt__c;
        String label = wi.Name + ' — ' + briefDesc;
        String detail = buildDetailLine(wi);
        String recordUrl = String.isBlank(orgUrl)
            ? null
            : (orgUrl + '/lightning/r/WorkItem__c/' + wi.Id + '/view');
        return new SignalEntryDTO(wi.Id, label, detail, recordUrl);
    }

    /**
     * @description Builds the one-line detail string for a digest entry —
     *              e.g. `3 days breached · stage: In Review` or
     *              `2 days to deadline · stage: Awaiting Signoff`.
     * @param wi The WorkItem to summarise.
     * @return Detail string for the digest body.
     */
    private static String buildDetailLine(WorkItem__c wi) {
        String stagePart = String.isBlank(wi.StageNamePk__c)
            ? '' : (' · stage: ' + wi.StageNamePk__c);
        if (wi.SLATargetDate__c == null) {
            return wi.SLAStatusTxt__c + stagePart;
        }
        Integer daysDelta = wi.SLATargetDate__c.daysBetween(Date.today());
        if (wi.SLAStatusTxt__c == 'Breached') {
            Integer absDays = Math.abs(daysDelta);
            String unit = absDays == 1 ? 'day' : 'days';
            return absDays + ' ' + unit + ' breached' + stagePart;
        }
        Integer daysToTarget = -daysDelta;
        String unit2 = daysToTarget == 1 ? 'day' : 'days';
        return daysToTarget + ' ' + unit2 + ' to deadline' + stagePart;
    }

    /**
     * @description Returns the org domain URL or empty string when unavailable
     *              (e.g. some scratch contexts return null). We never want to
     *              produce a URL like `null/lightning/...`.
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

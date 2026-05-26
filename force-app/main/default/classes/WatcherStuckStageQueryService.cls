/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Signal 2 — surfaces WorkItems that have been idle in their
 *              current stage longer than the threshold defined by their
 *              matching WorkflowEscalationRule__mdt row. When no rule covers
 *              a stage we fall back to the
 *              DeliveryHubSettings__c.WatcherStuckStageDefaultDaysNumber__c
 *              floor (default 5 days), so the signal still surfaces stuck
 *              items in stages without an explicit rule.
 *
 *              Detection mechanism:
 *                - Read active WorkflowEscalationRule__mdt rows (already
 *                  filtered to ActiveDateTime__c != null).
 *                - Group by trigger stage; per-stage minimum threshold wins
 *                  (a stage covered by both a 3-day Warning + a 5-day
 *                  Critical surfaces at the 3-day mark).
 *                - One SOQL per (stage, threshold) cluster, hard cap LIMIT
 *                  ROW_CAP per query. At 5 deployed rules → max 5 SOQL.
 *                - Dedup by WorkItem Id (a WI matching multiple stage rules
 *                  is counted once).
 *
 *              Severity weighting: WIs covered by a Critical rule count
 *              double in primaryCount for display weight (per design memo
 *              §"Signal 2"); we still surface them once in topEntries.
 *
 *              Excluded from the sweep:
 *                - Terminal stages (Done / Cancelled / Closed / Rejected /
 *                  Deployed to Prod) — never surfaced even if a rule
 *                  somehow names them.
 *                - SLAPausedDateTime__c != null — deliberately paused.
 *                - ActivatedDateTime__c = null — not yet active.
 *                - ArchivedDateTime__c != null — archived.
 *                - TemplateMarkedDateTime__c != null — templates.
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.ApexCRUDViolation,PMD.CyclomaticComplexity,PMD.StdCyclomaticComplexity,PMD.NcssMethodCount')
public with sharing class WatcherStuckStageQueryService {

    /** @description Stable signal identifier surfaced into WatcherDigest__c.SignalCountsTxt__c + the digest body. */
    public static final String SIGNAL_NAME = 'StuckStage';

    /** @description Max rows pulled per (stage,threshold) cluster. */
    @TestVisible
    private static final Integer ROW_CAP = 50;

    /** @description Max body entries surfaced into the digest message. */
    @TestVisible
    private static final Integer TOP_ENTRY_CAP = 5;

    /** @description Fallback days-idle threshold when no MDT rule + no settings override. */
    @TestVisible
    private static final Integer FALLBACK_DAYS = 5;

    /** @description Terminal stages excluded from the sweep regardless of rule definitions. */
    private static final Set<String> EXCLUDED_STAGES = new Set<String>{
        'Done', 'Cancelled', 'Closed', 'Rejected', 'Deployed to Prod'
    };

    /**
     * @description Test-only cluster override. When set, query() uses this
     *              map instead of reading WorkflowEscalationRule__mdt. CMT
     *              rows cannot be inserted in @IsTest context, so this seam
     *              lets tests exercise the SOQL + assembly paths against
     *              seeded WI data with deterministic thresholds.
     */
    @TestVisible
    private static Map<String, RuleCluster> testClusterOverride;

    /**
     * @description Run the signal. Reads active escalation rules, groups by
     *              stage, queries WorkItems past each (stage, threshold)
     *              cluster, dedups, builds counts + top-5 entries.
     * @return SignalResultDTO with counts + up to 5 entries.
     */
    public static SignalResultDTO query() {
        Map<String, RuleCluster> clusters = (testClusterOverride != null)
            ? testClusterOverride
            : buildClustersByStage();
        if (clusters.isEmpty()) {
            return SignalResultDTO.emptyResult(SIGNAL_NAME);
        }
        Map<Id, WorkItem__c> deduped = fetchStuckWorkItems(clusters);
        return assembleResult(deduped, clusters);
    }

    // ── Cluster building ─────────────────────────────────────────────────────

    /**
     * @description Reads active WorkflowEscalationRule__mdt rows and groups
     *              them by trigger stage. Per stage we keep the minimum days
     *              threshold (most aggressive rule wins for stuck-stage
     *              surfacing). Tracks whether any Critical rule applied so
     *              the severity-weighted display count is accurate.
     * @return Map of stage -> RuleCluster (threshold + critical flag).
     */
    private static Map<String, RuleCluster> buildClustersByStage() {
        Map<String, RuleCluster> result = new Map<String, RuleCluster>();
        List<WorkflowEscalationRule__mdt> rules = queryActiveRules();
        for (WorkflowEscalationRule__mdt rule : rules) {
            if (String.isBlank(rule.TriggerStageTxt__c)
                || EXCLUDED_STAGES.contains(rule.TriggerStageTxt__c)) {
                continue;
            }
            Integer days = (rule.DaysThresholdNumber__c == null)
                ? FALLBACK_DAYS : rule.DaysThresholdNumber__c.intValue();
            if (days < 1) {
                days = FALLBACK_DAYS;
            }
            Boolean isCritical = rule.SeverityLevelPk__c == 'Critical';
            RuleCluster existing = result.get(rule.TriggerStageTxt__c);
            if (existing == null) {
                result.put(rule.TriggerStageTxt__c, new RuleCluster(days, isCritical));
            } else {
                existing.mergeRule(days, isCritical);
            }
        }
        return result;
    }

    /**
     * @description Reads all active escalation rules. Wrapped so tests can
     *              evaluate cluster shape independently of the SOQL.
     * @return Active WorkflowEscalationRule__mdt rows.
     */
    @TestVisible
    private static List<WorkflowEscalationRule__mdt> queryActiveRules() {
        return [
            SELECT MasterLabel, TriggerStageTxt__c, DaysThresholdNumber__c,
                   SeverityLevelPk__c, ActiveDateTime__c, SortOrderNumber__c
            FROM WorkflowEscalationRule__mdt
            WHERE ActiveDateTime__c != NULL
            WITH SYSTEM_MODE
            ORDER BY SortOrderNumber__c ASC NULLS LAST
        ];
    }

    // ── SOQL ─────────────────────────────────────────────────────────────────

    /**
     * @description Runs one SOQL per (stage, threshold) cluster and
     *              dedupes results by WorkItem Id. Each query is capped at
     *              ROW_CAP, so worst-case row volume is clusterCount × ROW_CAP.
     *              Per design memo the deployed rule count is bounded to 5,
     *              so this is safely under SOQL governors.
     * @param clusters Stage -> RuleCluster mapping built earlier.
     * @return Deduped map of WorkItem Id -> WorkItem__c.
     */
    @SuppressWarnings('PMD.OperationWithLimitsInLoop')
    private static Map<Id, WorkItem__c> fetchStuckWorkItems(Map<String, RuleCluster> clusters) {
        Map<Id, WorkItem__c> deduped = new Map<Id, WorkItem__c>();
        Datetime nowTs = Datetime.now();
        for (String stage : clusters.keySet()) {
            RuleCluster cluster = clusters.get(stage);
            Datetime cutoff = nowTs.addDays(-cluster.daysIdleThreshold);
            String stageFilter = stage;
            for (WorkItem__c wi : [
                SELECT Id, Name, BriefDescriptionTxt__c, StageNamePk__c,
                       StageEnteredDateTime__c, OwnerId
                FROM WorkItem__c
                WHERE StageEnteredDateTime__c <= :cutoff
                  AND StageNamePk__c = :stageFilter
                  AND StageNamePk__c NOT IN :EXCLUDED_STAGES
                  AND SLAPausedDateTime__c = NULL
                  AND ActivatedDateTime__c != NULL
                  AND ArchivedDateTime__c = NULL
                  AND TemplateMarkedDateTime__c = NULL
                WITH SYSTEM_MODE
                ORDER BY StageEnteredDateTime__c ASC NULLS LAST
                LIMIT :ROW_CAP
            ]) {
                if (!deduped.containsKey(wi.Id)) {
                    deduped.put(wi.Id, wi);
                }
            }
        }
        return deduped;
    }

    // ── Result assembly ──────────────────────────────────────────────────────

    /**
     * @description Walks the deduped result set, weights Critical-stage WIs
     *              double in primaryCount, and builds up to TOP_ENTRY_CAP
     *              digest entries.
     * @param deduped  Deduped Id -> WorkItem__c map.
     * @param clusters Stage -> RuleCluster mapping for severity weighting.
     * @return Fully-populated SignalResultDTO.
     */
    private static SignalResultDTO assembleResult(Map<Id, WorkItem__c> deduped, Map<String, RuleCluster> clusters) {
        SignalResultDTO result = SignalResultDTO.emptyResult(SIGNAL_NAME);
        if (deduped.isEmpty()) {
            return result;
        }
        Integer weightedCount = 0;
        String orgUrl = safeOrgUrl();
        Date today = Date.today();
        for (WorkItem__c wi : deduped.values()) {
            RuleCluster cluster = clusters.get(wi.StageNamePk__c);
            Boolean critical = cluster != null && cluster.hasCritical;
            weightedCount += critical ? 2 : 1;
            if (result.topEntries.size() < TOP_ENTRY_CAP) {
                result.topEntries.add(buildEntry(wi, orgUrl, cluster, today));
            }
        }
        result.primaryCount = weightedCount;
        // secondaryCount = raw WI count (so callers/UI can distinguish weighted vs unweighted).
        result.secondaryCount = deduped.size();
        return result;
    }

    /**
     * @description Builds one digest entry from a WorkItem row.
     * @param wi      The WorkItem to render.
     * @param orgUrl  Cached org URL.
     * @param cluster Matching rule cluster (may be null).
     * @param today   Today's date for the days-idle calculation.
     * @return SignalEntryDTO with label + detail + record-page URL.
     */
    private static SignalEntryDTO buildEntry(WorkItem__c wi, String orgUrl, RuleCluster cluster, Date today) {
        String briefDesc = String.isBlank(wi.BriefDescriptionTxt__c)
            ? 'Untitled' : wi.BriefDescriptionTxt__c;
        String label = wi.Name + ' — ' + briefDesc;
        String detail = buildDetailLine(wi, cluster, today);
        String recordUrl = String.isBlank(orgUrl)
            ? null
            : (orgUrl + '/lightning/r/WorkItem__c/' + wi.Id + '/view');
        return new SignalEntryDTO(wi.Id, label, detail, recordUrl);
    }

    /**
     * @description Builds the per-entry detail string, e.g.
     *              `6 days in Code Review (Critical)`.
     * @param wi      The WorkItem to summarise.
     * @param cluster Matching rule cluster (may be null).
     * @param today   Today's date for days-idle calculation.
     * @return Detail string for the digest body.
     */
    private static String buildDetailLine(WorkItem__c wi, RuleCluster cluster, Date today) {
        String stagePart = String.isBlank(wi.StageNamePk__c)
            ? '' : wi.StageNamePk__c;
        Integer daysIdle = 0;
        if (wi.StageEnteredDateTime__c != null) {
            daysIdle = wi.StageEnteredDateTime__c.date().daysBetween(today);
        }
        if (daysIdle < 0) {
            daysIdle = 0;
        }
        String unit = daysIdle == 1 ? 'day' : 'days';
        String severityPart = (cluster != null && cluster.hasCritical) ? ' (Critical)' : '';
        return daysIdle + ' ' + unit + ' in ' + stagePart + severityPart;
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

    // ── Inner types ──────────────────────────────────────────────────────────

    /**
     * @description Per-stage cluster of escalation rules. Holds the minimum
     *              days-idle threshold (most aggressive across overlapping
     *              rules) plus a flag indicating whether any rule for the
     *              stage is Critical (drives severity-weighted display).
     *              Exposed `public` (not `@TestVisible private`) so tests
     *              can instantiate the type directly when seeding the
     *              testClusterOverride seam.
     */
    public class RuleCluster {

        /** @description Minimum days-idle threshold across all rules touching this stage. */
        public Integer daysIdleThreshold;

        /** @description True when at least one rule touching this stage has SeverityLevelPk__c='Critical'. */
        public Boolean hasCritical;

        /**
         * @description Constructor.
         * @param days       Days-idle threshold.
         * @param isCritical Critical flag.
         */
        public RuleCluster(Integer days, Boolean isCritical) {
            this.daysIdleThreshold = (days == null || days < 1) ? FALLBACK_DAYS : days;
            this.hasCritical = (isCritical == true);
        }

        /**
         * @description Merges another rule's threshold into this cluster —
         *              keeps the smaller threshold (most aggressive surfacing)
         *              and OR's the Critical flag.
         * @param otherDays       Other rule's days threshold.
         * @param otherIsCritical Other rule's Critical flag.
         */
        public void mergeRule(Integer otherDays, Boolean otherIsCritical) {
            if (otherDays != null && otherDays < this.daysIdleThreshold) {
                this.daysIdleThreshold = otherDays;
            }
            if (otherIsCritical == true) {
                this.hasCritical = true;
            }
        }
    }
}

/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Move 1 of the self-heal loop — the first unattended segment.
 *               Reads the captured field-change stream (ActivityLog__c, the
 *               "SEE" layer) and, for each configured DiagnoseRule__mdt, counts
 *               anomalous events in a rolling window. When a rule's threshold is
 *               crossed it AUTO-DRAFTS a quoted work request straight into the
 *               existing approval queue (DeliveryWorkApprovalService) — no new
 *               pipeline, it reuses the storefront that already ships.
 *
 *               This is the bridge from "the eyes captured a problem" to "a
 *               human-approvable fix is waiting in the queue," with NO human in
 *               between. It is the literal subtract-Glen payload.
 *
 *               GATED OFF BY DEFAULT. Two gates, both must be satisfied:
 *                 1. DeliveryHubSettings__c.EnableAutoDiagnoseDateTime__c set
 *                    (the master flag — null = the safe shipping default).
 *                 2. At least one DiagnoseRule__mdt with ActiveDateTime__c set.
 *               Until the SEE Flow is actually feeding business-object events
 *               and an admin authors a rule, this no-ops every tick.
 *
 *               GENERIC by design — nothing here names a tenant's objects. A
 *               rule points at any watched object/field via config; the package
 *               ships the engine, not the rule.
 *
 *               Idempotent: a per-rule cooldown (queried off the marker-prefixed
 *               work-item title) prevents the same anomaly from re-drafting on
 *               every run. A once-per-day guard caps the sweep to one pass/day
 *               even though the scheduler calls it every tick.
 *
 *               SOQL is WITH SYSTEM_MODE per CLAUDE.md (WITH USER_MODE breaks in
 *               namespaced package test context).
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.ApexCRUDViolation,PMD.CyclomaticComplexity,PMD.StdCyclomaticComplexity,PMD.AvoidGlobalModifier,PMD.CognitiveComplexity')
global without sharing class DeliveryAutoDiagnoseService {

    /** ActivityLog ActionType written by the field-change capture engine. */
    private static final String ACTION_FIELD_CHANGE = 'Field_Change';

    /** Cap on ActivityLog rows scanned per rule per sweep. */
    private static final Integer MAX_LOG_ROWS = 5000;

    /** Marker that prefixes every auto-drafted work-item title — also the
     *  dedup key (one stable token per rule). Keep stable: changing it orphans
     *  the cooldown lookup against already-drafted items. */
    @TestVisible
    private static final String MARKER = '[auto-diagnose:';

    /** Test seam: DiagnoseRule__mdt records cannot be DML'd, so tests inject
     *  in-memory rules here instead of relying on shipped CMT (none ships). */
    @TestVisible
    private static List<DiagnoseRule__mdt> testRuleOverride;

    /**
     * @description Runs the diagnose sweep. Called every scheduler tick; gated
     *              off by default and self-rate-limited to one pass per day.
     * @return Number of rules that drafted a work request this pass.
     */
    global static Integer runSweep() {
        DeliveryHubSettings__c settings = DeliveryHubSettings__c.getOrgDefaults();
        if (settings == null || settings.EnableAutoDiagnoseDateTime__c == null) {
            return 0; // master flag off — the safe default
        }
        // Once-per-day guard: skip if we already swept today (GMT).
        if (settings.LastAutoDiagnoseScanDateTime__c != null
                && settings.LastAutoDiagnoseScanDateTime__c.dateGmt() == Date.today()) {
            return 0;
        }

        List<DiagnoseRule__mdt> rules = testRuleOverride != null
            ? testRuleOverride
            : [
                SELECT DeveloperName, WatchedObjectApiNameTxt__c, WatchedFieldApiNameTxt__c,
                       AnomalyValueTxt__c, WindowHoursNumber__c, CountThresholdNumber__c,
                       QuotedHoursNumber__c, WorkItemTitleTxt__c, CooldownHoursNumber__c
                FROM DiagnoseRule__mdt
                WHERE ActiveDateTime__c != null
                WITH SYSTEM_MODE
                ORDER BY SortOrderNumber__c ASC NULLS LAST
            ];

        Integer drafted = 0;
        for (DiagnoseRule__mdt rule : rules) {
            if (!isRuleUsable(rule)) {
                continue;
            }
            if (alreadyDraftedWithinCooldown(rule)) {
                continue;
            }
            Integer hits = countAnomalies(rule);
            if (hits >= rule.CountThresholdNumber__c) {
                draftRequest(rule, hits);
                drafted++;
            }
        }

        stampScanComplete(settings);
        return drafted;
    }

    // ── Evaluation ───────────────────────────────────────────────────────

    /** A rule must name an object + field and carry a positive threshold. */
    private static Boolean isRuleUsable(DiagnoseRule__mdt rule) {
        return String.isNotBlank(rule.WatchedObjectApiNameTxt__c)
            && String.isNotBlank(rule.WatchedFieldApiNameTxt__c)
            && rule.CountThresholdNumber__c != null && rule.CountThresholdNumber__c > 0
            && rule.WindowHoursNumber__c != null && rule.WindowHoursNumber__c > 0;
    }

    /**
     * @description Counts DISTINCT records whose watched field changed (to the
     *              anomaly value, when one is configured) within the rule's
     *              window. The capture engine stores object name + values inside
     *              ActivityLog ContextDataTxt JSON, so we filter on the queryable
     *              top-level columns (action + field name + window) and confirm
     *              object/value in Apex.
     */
    private static Integer countAnomalies(DiagnoseRule__mdt rule) {
        Datetime windowStart = Datetime.now().addHours(-(Integer) rule.WindowHoursNumber__c);
        List<ActivityLog__c> logs = [
            SELECT RecordIdTxt__c, ContextDataTxt__c
            FROM ActivityLog__c
            WHERE ActionTypePk__c = :ACTION_FIELD_CHANGE
            AND ComponentNameTxt__c = :rule.WatchedFieldApiNameTxt__c
            AND CreatedDate >= :windowStart
            WITH SYSTEM_MODE
            ORDER BY CreatedDate DESC
            LIMIT :MAX_LOG_ROWS
        ];

        Boolean filterValue = String.isNotBlank(rule.AnomalyValueTxt__c);
        Set<String> matchedRecordIds = new Set<String>();
        for (ActivityLog__c log : logs) {
            if (String.isBlank(log.ContextDataTxt__c)) {
                continue;
            }
            Map<String, Object> ctx;
            try {
                ctx = (Map<String, Object>) JSON.deserializeUntyped(log.ContextDataTxt__c);
            } catch (Exception ignored) {
                continue;
            }
            if (String.valueOf(ctx.get('objectName')) != rule.WatchedObjectApiNameTxt__c) {
                continue;
            }
            if (filterValue && String.valueOf(ctx.get('newValue')) != rule.AnomalyValueTxt__c) {
                continue;
            }
            if (String.isNotBlank(log.RecordIdTxt__c)) {
                matchedRecordIds.add(log.RecordIdTxt__c);
            }
        }
        return matchedRecordIds.size();
    }

    /** True when this rule already drafted an item inside its cooldown window. */
    private static Boolean alreadyDraftedWithinCooldown(DiagnoseRule__mdt rule) {
        Integer cooldown = rule.CooldownHoursNumber__c == null
            ? (Integer) rule.WindowHoursNumber__c
            : (Integer) rule.CooldownHoursNumber__c;
        if (cooldown <= 0) {
            return false;
        }
        Datetime since = Datetime.now().addHours(-cooldown);
        String prefix = markerFor(rule);
        Integer existing = [
            SELECT COUNT()
            FROM WorkItem__c
            WHERE BriefDescriptionTxt__c LIKE :(prefix + '%')
            AND CreatedDate >= :since
            WITH SYSTEM_MODE
        ];
        return existing > 0;
    }

    // ── Drafting ─────────────────────────────────────────────────────────

    /**
     * @description Creates an intake work item describing the anomaly and submits
     *              it for approval at the rule's quoted hours — landing it as an
     *              Offer-Sent request in the existing queue (or auto-accepted if
     *              the quote is under the org's discretionary threshold, exactly
     *              as a human-submitted request would be).
     */
    private static void draftRequest(DiagnoseRule__mdt rule, Integer hits) {
        WorkItem__c wi = new WorkItem__c(
            BriefDescriptionTxt__c = buildTitle(rule, hits),
            StageNamePk__c         = 'Backlog',
            StatusPk__c            = 'New',
            PriorityPk__c          = 'High',
            ActivatedDateTime__c   = Datetime.now()
        );
        insert wi;

        Decimal quote = rule.QuotedHoursNumber__c == null ? 0 : rule.QuotedHoursNumber__c;
        DeliveryWorkApprovalService.submitForApproval(
            new Set<Id>{ wi.Id },
            new Map<Id, Decimal>{ wi.Id => quote }
        );
    }

    /** Marker prefix unique to a rule (the dedup/cooldown key). */
    private static String markerFor(DiagnoseRule__mdt rule) {
        return MARKER + rule.DeveloperName + ']';
    }

    /** Title = the stable marker + the rule template with {count}/{object}
     *  tokens resolved, capped at the BriefDescription length. */
    private static String buildTitle(DiagnoseRule__mdt rule, Integer hits) {
        String template = String.isNotBlank(rule.WorkItemTitleTxt__c)
            ? rule.WorkItemTitleTxt__c
            : '{count} anomalies detected on {object}';
        String body = template
            .replace('{count}', String.valueOf(hits))
            .replace('{object}', rule.WatchedObjectApiNameTxt__c);
        String full = markerFor(rule) + ' ' + body;
        return full.length() > 255 ? full.substring(0, 255) : full;
    }

    // ── Bookkeeping ──────────────────────────────────────────────────────

    private static void stampScanComplete(DeliveryHubSettings__c settings) {
        try {
            settings.LastAutoDiagnoseScanDateTime__c = Datetime.now();
            upsert settings;
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN,
                '[DeliveryAutoDiagnoseService.stampScanComplete] failed: ' + e.getMessage());
        }
    }
}

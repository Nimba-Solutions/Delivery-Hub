/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Read-only viewer controller for WatcherDigest__c — one row
 *               per scheduled (or manual) Watcher run, written by
 *               DeliveryWatcherService. Returns the latest N runs newest-first.
 *
 *               Closes the cross-flow audit-trail gap documented in the
 *               e2e walkthrough audit (docs/audits/e2e-walkthrough-
 *               2026-05-21.md). Companion to DeliveryActivityLogController
 *               and DeliveryOnboardingHistoryController.
 *
 *               The viewer presents Run Date Time, Status, Signal Counts,
 *               Recipient User Ids, Slack delivery (derived from
 *               StatusPk__c — `Slack_Failed` indicates the post 4xx/5xx'd or
 *               threw; see fix/watcher-slack-delivery-status-2026-05-26),
 *               Run Mode, and the body notes.
 * @author       Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.ApexCRUDViolation')
public with sharing class DeliveryWatcherDigestHistoryController {

    private static final Integer DEFAULT_LIMIT = 50;
    private static final Integer MAX_LIMIT = 200;
    private static final Integer BODY_TRUNCATE = 500;

    /**
     * @description Flat row shape for lightning-datatable. Slack delivery is
     *              now derived from StatusPk__c: a recipient list was
     *              configured AND the StatusPk__c is NOT `Slack_Failed`.
     *              `slackResponse` exposes the captured response text on
     *              failure rows (empty otherwise) for debugging.
     */
    public class DigestRow {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public Datetime runDateTime;
        @AuraEnabled public String status;
        @AuraEnabled public String runMode;
        @AuraEnabled public String signalCounts;
        @AuraEnabled public Decimal runDurationMs;
        @AuraEnabled public String recipientUserIds;
        @AuraEnabled public Boolean slackDelivered;
        @AuraEnabled public String slackResponse;
        @AuraEnabled public String notes;
        @AuraEnabled public String errorMessage;
    }

    /**
     * @description Returns the most recent WatcherDigest__c rows, bounded
     *              by recordLimit (1..200, default 50). contextId is
     *              accepted for shape-parity with the other audit-trail
     *              controllers but is currently ignored — WatcherDigest__c
     *              has no lookup to filter against.
     * @param  recordLimit Max rows to return. Null / <1 falls back to 50.
     *                     Capped at 200.
     * @param  contextId   Reserved for future per-feature scoping.
     * @return List<DigestRow> ordered by RunDateTime DESC.
     */
    @AuraEnabled(cacheable=true)
    public static List<DigestRow> recent(Integer recordLimit, Id contextId) {
        Integer bound = resolveLimit(recordLimit);
        // contextId is currently unused — WatcherDigest__c has no per-record
        // foreign key. Kept in the signature so the three audit-trail
        // controllers share one method shape on the LWC side.
        if (contextId != null) {
            System.debug(LoggingLevel.FINE, 'WatcherDigest viewer ignores contextId — no foreign key on the object.');
        }

        List<WatcherDigest__c> rows = [
            SELECT Id, Name, RunDateTime__c, StatusPk__c, RunModePk__c,
                   SignalCountsTxt__c, RunDurationMsNumber__c,
                   RecipientUserIdsTxt__c, DigestBodyTxt__c, ErrorMessageTxt__c,
                   SlackResponseTxt__c
            FROM WatcherDigest__c
            WITH SYSTEM_MODE
            ORDER BY RunDateTime__c DESC NULLS LAST
            LIMIT :bound
        ];

        List<DigestRow> out = new List<DigestRow>();
        for (WatcherDigest__c w : rows) {
            DigestRow r = new DigestRow();
            r.id = w.Id;
            r.name = w.Name;
            r.runDateTime = w.RunDateTime__c;
            r.status = w.StatusPk__c;
            r.runMode = w.RunModePk__c;
            r.signalCounts = w.SignalCountsTxt__c;
            r.runDurationMs = w.RunDurationMsNumber__c;
            r.recipientUserIds = w.RecipientUserIdsTxt__c;
            r.slackDelivered = String.isNotBlank(w.RecipientUserIdsTxt__c)
                && w.StatusPk__c != 'Slack_Failed';
            r.slackResponse = w.SlackResponseTxt__c;
            r.notes = truncate(w.DigestBodyTxt__c, BODY_TRUNCATE);
            r.errorMessage = w.ErrorMessageTxt__c;
            out.add(r);
        }
        return out;
    }

    private static Integer resolveLimit(Integer requested) {
        if (requested == null || requested < 1) {
            return DEFAULT_LIMIT;
        }
        return requested > MAX_LIMIT ? MAX_LIMIT : requested;
    }

    private static String truncate(String raw, Integer max) {
        if (String.isBlank(raw)) {
            return '';
        }
        if (raw.length() <= max) {
            return raw;
        }
        return raw.substring(0, max) + '…';
    }
}

/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  WorkLog deferral service. Supports the "defer disputed hours to a
 *               future milestone date" accounting pattern: flip Approved -> Draft
 *               so they drop out of the current invoice, prepend a
 *               [DEFERRED to YYYY-MM-DD] tag in the description, and later
 *               release them back to Approved with WorkDateDate__c shifted to
 *               the milestone date so they land in that period's invoice.
 *
 *               Revenue recognition occurs at acceptance — preserves billable
 *               dollars without issuing credit notes. Audit trail via
 *               field-tracking on StatusPk__c, WorkDateDate__c, and
 *               WorkDescriptionTxt__c.
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.ApexCRUDViolation')
public with sharing class DeliveryDocDeferralService {

    /**
     * @description Wire-backing query used by deliveryInvoicePreviewDeferPanel.
     *              Returns every Approved WorkLog belonging to work items whose
     *              ClientNetworkEntityLookup__c matches the supplied entity and
     *              whose WorkDateDate__c falls inside the inclusive period.
     *              Used to populate the deferral table; cacheable.
     * @param networkEntityId The client NetworkEntity__c.
     * @param periodStart     Inclusive period start (YYYY-MM-DD string or Date).
     * @param periodEnd       Inclusive period end.
     * @return The matching WorkLogs ordered by WorkDateDate__c.
     */
    @AuraEnabled(cacheable=true)
    public static List<WorkLog__c> getWorkLogsForEntityPeriod(
        Id networkEntityId, Date periodStart, Date periodEnd
    ) {
        if (networkEntityId == null || periodStart == null || periodEnd == null) {
            return new List<WorkLog__c>();
        }
        return [
            SELECT Id, WorkDateDate__c, HoursLoggedNumber__c,
                   WorkDescriptionTxt__c, StatusPk__c
            FROM WorkLog__c
            WHERE WorkItemLookup__r.ClientNetworkEntityLookup__c = :networkEntityId
            AND WorkDateDate__c >= :periodStart
            AND WorkDateDate__c <= :periodEnd
            AND StatusPk__c = 'Approved'
            WITH SYSTEM_MODE
            ORDER BY WorkDateDate__c ASC
        ];
    }

    @TestVisible
    private static final String TAG_PREFIX_OPEN  = '[DEFERRED to ';
    @TestVisible
    private static final String TAG_SUFFIX_CLOSE = ']';
    private static final Integer DESC_FIELD_LIMIT = 255;

    /**
     * @description Flips the given WorkLog__c records from Approved to Draft and
     *              prepends a [DEFERRED to YYYY-MM-DD] tag to WorkDescriptionTxt__c
     *              capturing the milestone (acceptance) date. The original
     *              description is preserved after the tag, so a subsequent release
     *              can recover it. Logs an ActivityLog__c entry per call carrying
     *              the human-readable reason.
     * @param workLogIds   The WorkLog__c records to defer (must be non-empty).
     * @param milestoneDate The future date the deferred hours should bill on.
     * @param reason       Human-readable rationale stored in the ActivityLog note.
     * @return Count of WorkLog__c records updated.
     */
    @AuraEnabled
    public static Integer deferWorkLogs(List<Id> workLogIds, Date milestoneDate, String reason) {
        if (workLogIds == null || workLogIds.isEmpty()) {
            throw new AuraHandledException('At least one Work Log must be selected.');
        }
        if (milestoneDate == null) {
            throw new AuraHandledException('A milestone date is required.');
        }

        List<WorkLog__c> logs = [
            SELECT Id, StatusPk__c, WorkDescriptionTxt__c, WorkDateDate__c
            FROM WorkLog__c
            WHERE Id IN :workLogIds
            WITH SYSTEM_MODE
        ];
        if (logs.isEmpty()) {
            return 0;
        }

        String tag = buildTag(milestoneDate);
        for (WorkLog__c wl : logs) {
            wl.StatusPk__c = 'Draft';
            wl.WorkDescriptionTxt__c = applyTag(wl.WorkDescriptionTxt__c, tag);
        }
        Database.update(logs, AccessLevel.SYSTEM_MODE);

        logActivity('defer', workLogIds.size(), milestoneDate, reason);
        return logs.size();
    }

    /**
     * @description Releases previously-deferred WorkLogs back to Approved status
     *              when their tagged milestone date falls inside the supplied
     *              invoice period. Also shifts WorkDateDate__c to the milestone
     *              date so the released hours roll into the period's invoice.
     *              Strips the [DEFERRED to YYYY-MM-DD] tag, restoring the
     *              original description.
     * @param networkEntityId The client NetworkEntity__c being invoiced.
     * @param periodStart     Inclusive period start.
     * @param periodEnd       Inclusive period end.
     * @return Count of WorkLog__c records released.
     */
    @AuraEnabled
    public static Integer releaseDeferredForPeriod(Id networkEntityId, Date periodStart, Date periodEnd) {
        if (networkEntityId == null || periodStart == null || periodEnd == null) {
            throw new AuraHandledException('Network Entity Id and a period range are required.');
        }

        String tagSearch = TAG_PREFIX_OPEN + '%';
        List<WorkLog__c> candidates = [
            SELECT Id, StatusPk__c, WorkDescriptionTxt__c, WorkDateDate__c
            FROM WorkLog__c
            WHERE StatusPk__c = 'Draft'
            AND WorkDescriptionTxt__c LIKE :tagSearch
            AND WorkItemLookup__r.ClientNetworkEntityLookup__c = :networkEntityId
            WITH SYSTEM_MODE
        ];
        if (candidates.isEmpty()) {
            return 0;
        }

        List<WorkLog__c> toUpdate = new List<WorkLog__c>();
        for (WorkLog__c wl : candidates) {
            Date milestone = parseTaggedDate(wl.WorkDescriptionTxt__c);
            if (milestone == null) {
                continue;
            }
            if (milestone < periodStart || milestone > periodEnd) {
                continue;
            }
            wl.StatusPk__c = 'Approved';
            wl.WorkDateDate__c = milestone;
            wl.WorkDescriptionTxt__c = stripTag(wl.WorkDescriptionTxt__c);
            toUpdate.add(wl);
        }

        if (toUpdate.isEmpty()) {
            return 0;
        }
        Database.update(toUpdate, AccessLevel.SYSTEM_MODE);

        logActivity('release', toUpdate.size(), periodStart, 'Released for period '
            + String.valueOf(periodStart) + ' .. ' + String.valueOf(periodEnd));
        return toUpdate.size();
    }

    // ── Tag helpers ─────────────────────────────────────────────────────

    /**
     * @description Builds the [DEFERRED to YYYY-MM-DD] tag for a milestone date.
     * @param milestoneDate The date to encode into the tag.
     * @return The fully-formed tag string.
     */
    @TestVisible
    private static String buildTag(Date milestoneDate) {
        String iso = String.valueOf(milestoneDate); // ISO YYYY-MM-DD for Date.valueOf round-trip
        return TAG_PREFIX_OPEN + iso + TAG_SUFFIX_CLOSE;
    }

    /**
     * @description Prepends the tag to the description, preserving the original.
     *              If the description already begins with a deferred tag, the
     *              existing tag is replaced (re-defer to a new milestone). Result
     *              is truncated to the field length to avoid storage failure.
     * @param current The existing WorkDescriptionTxt__c value (may be null/blank).
     * @param tag     The pre-formed tag to prepend.
     * @return The new description value.
     */
    @TestVisible
    private static String applyTag(String current, String tag) {
        String body = current == null ? '' : stripTag(current);
        String combined = (body.length() == 0) ? tag : (tag + ' ' + body);
        if (combined.length() > DESC_FIELD_LIMIT) {
            combined = combined.substring(0, DESC_FIELD_LIMIT);
        }
        return combined;
    }

    /**
     * @description Removes a leading [DEFERRED to YYYY-MM-DD] tag (and the single
     *              following space) from the description. Returns the input
     *              unchanged when no tag is present.
     * @param current The existing WorkDescriptionTxt__c value.
     * @return The description with the tag removed.
     */
    @TestVisible
    private static String stripTag(String current) {
        if (String.isBlank(current)) {
            return '';
        }
        if (!current.startsWith(TAG_PREFIX_OPEN)) {
            return current;
        }
        Integer closeIdx = current.indexOf(TAG_SUFFIX_CLOSE);
        if (closeIdx < 0) {
            return current;
        }
        Integer cut = closeIdx + 1;
        if (cut < current.length() && current.substring(cut, cut + 1) == ' ') {
            cut += 1;
        }
        return current.substring(cut);
    }

    /**
     * @description Parses the milestone date from a tagged description. Returns
     *              null when the tag is missing or malformed.
     * @param current The description value.
     * @return The Date encoded in the tag, or null.
     */
    @TestVisible
    private static Date parseTaggedDate(String current) {
        if (String.isBlank(current) || !current.startsWith(TAG_PREFIX_OPEN)) {
            return null;
        }
        Integer closeIdx = current.indexOf(TAG_SUFFIX_CLOSE);
        if (closeIdx < 0) {
            return null;
        }
        String iso = current.substring(TAG_PREFIX_OPEN.length(), closeIdx);
        try {
            return Date.valueOf(iso);
        } catch (Exception ex) {
            return null;
        }
    }

    /**
     * @description Records an activity log entry capturing the deferral / release
     *              event for downstream audit. Failures are swallowed: the
     *              business operation must succeed even if telemetry insert
     *              cannot.
     * @param action       'defer' or 'release'.
     * @param recordCount  Number of WorkLogs affected.
     * @param targetDate   Milestone date or period start.
     * @param reason       Human-readable reason text.
     */
    private static void logActivity(String action, Integer recordCount, Date targetDate, String reason) {
        Map<String, Object> ctx = new Map<String, Object>{
            'action'       => action,
            'recordCount'  => recordCount,
            'targetDate'   => String.valueOf(targetDate)
        };
        if (String.isNotBlank(reason)) {
            ctx.put('reason', reason.left(500));
        }
        try {
            ActivityLog__c log = new ActivityLog__c(
                ActionTypePk__c   = 'WorkLog_Deferral',
                ContextDataTxt__c = JSON.serialize(ctx)
            );
            Database.insert(log, AccessLevel.SYSTEM_MODE);
        } catch (Exception ex) {
            // Telemetry must not break the user's deferral action.
        }
    }
}

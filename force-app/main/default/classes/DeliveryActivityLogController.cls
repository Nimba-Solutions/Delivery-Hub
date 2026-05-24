/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Read-only audit-trail viewer for ActivityLog__c rows.
 *               Surfaces the full org-wide audit trail (feature toggles,
 *               approval grants, document actions, navigation, etc.) — a
 *               superset of what deliveryActivityFeed shows (which is
 *               scoped to Stage_Change / Field_Change on WorkItem records).
 *
 *               Closes the cross-flow audit-trail gap documented in the
 *               e2e walkthrough audit (docs/audits/e2e-walkthrough-
 *               2026-05-21.md). Companion to deliveryWatcherDigestHistory-
 *               Controller and deliveryOnboardingHistoryController.
 * @author       Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.ApexCRUDViolation')
public with sharing class DeliveryActivityLogController {

    private static final Integer DEFAULT_LIMIT = 50;
    private static final Integer MAX_LIMIT = 200;
    private static final Integer DETAILS_TRUNCATE = 240;

    /**
     * @description Wire-friendly row shape returned to the viewer LWC.
     *              Flat so lightning-datatable can render without nested
     *              expressions. UserName is pre-resolved from UserIdTxt__c
     *              so the LWC never has to round-trip for User names.
     */
    public class LogRow {
        @AuraEnabled public Id id;
        @AuraEnabled public Datetime activityDateTime;
        @AuraEnabled public String userId;
        @AuraEnabled public String userName;
        @AuraEnabled public String actionType;
        @AuraEnabled public String componentName;
        @AuraEnabled public String recordId;
        @AuraEnabled public String pageUrl;
        @AuraEnabled public String detailsTxt;
    }

    /**
     * @description Returns the most recent ActivityLog__c rows, optionally
     *              filtered by a context record Id (e.g., a WorkItem__c or
     *              Feature__c). Bounded by recordLimit (1..200, default 50).
     *
     *              Uses WITH SYSTEM_MODE per CLAUDE.md — namespaced package
     *              context breaks USER_MODE in test runs. UserIdTxt__c stays
     *              the canonical actor source; we resolve names in a bulk
     *              follow-up query so the wire response is a clean flat row.
     * @param  recordLimit Max rows to return. Null / <1 falls back to 50.
     *                     Capped at 200.
     * @param  contextId   Optional record Id used to filter on RecordIdTxt__c.
     *                     When null, the viewer shows org-wide activity.
     * @return List<LogRow> ordered by CreatedDate DESC.
     */
    @AuraEnabled(cacheable=true)
    public static List<LogRow> recent(Integer recordLimit, Id contextId) {
        Integer bound = resolveLimit(recordLimit);
        String contextFilter = (contextId == null) ? null : String.valueOf(contextId);

        List<ActivityLog__c> logs;
        if (contextFilter == null) {
            logs = [
                SELECT Id, CreatedDate, UserIdTxt__c, ActionTypePk__c,
                       ComponentNameTxt__c, RecordIdTxt__c, PageUrlTxt__c,
                       ContextDataTxt__c
                FROM ActivityLog__c
                WITH SYSTEM_MODE
                ORDER BY CreatedDate DESC
                LIMIT :bound
            ];
        } else {
            logs = [
                SELECT Id, CreatedDate, UserIdTxt__c, ActionTypePk__c,
                       ComponentNameTxt__c, RecordIdTxt__c, PageUrlTxt__c,
                       ContextDataTxt__c
                FROM ActivityLog__c
                WHERE RecordIdTxt__c = :contextFilter
                WITH SYSTEM_MODE
                ORDER BY CreatedDate DESC
                LIMIT :bound
            ];
        }

        Map<Id, String> nameByUserId = resolveUserNames(logs);

        List<LogRow> out = new List<LogRow>();
        for (ActivityLog__c al : logs) {
            LogRow row = new LogRow();
            row.id = al.Id;
            row.activityDateTime = al.CreatedDate;
            row.userId = al.UserIdTxt__c;
            row.userName = resolveUserName(al.UserIdTxt__c, nameByUserId);
            row.actionType = al.ActionTypePk__c;
            row.componentName = al.ComponentNameTxt__c;
            row.recordId = al.RecordIdTxt__c;
            row.pageUrl = al.PageUrlTxt__c;
            row.detailsTxt = truncate(al.ContextDataTxt__c, DETAILS_TRUNCATE);
            out.add(row);
        }
        return out;
    }

    private static Integer resolveLimit(Integer requested) {
        if (requested == null || requested < 1) {
            return DEFAULT_LIMIT;
        }
        return requested > MAX_LIMIT ? MAX_LIMIT : requested;
    }

    private static Map<Id, String> resolveUserNames(List<ActivityLog__c> logs) {
        Set<Id> userIds = new Set<Id>();
        for (ActivityLog__c al : logs) {
            Id uid = safeToId(al.UserIdTxt__c);
            if (uid != null) {
                userIds.add(uid);
            }
        }
        Map<Id, String> out = new Map<Id, String>();
        if (!userIds.isEmpty()) {
            for (User u : [SELECT Id, Name FROM User WHERE Id IN :userIds WITH SYSTEM_MODE]) {
                out.put(u.Id, u.Name);
            }
        }
        return out;
    }

    private static String resolveUserName(String userIdTxt, Map<Id, String> nameByUserId) {
        Id uid = safeToId(userIdTxt);
        if (uid != null && nameByUserId.containsKey(uid)) {
            return nameByUserId.get(uid);
        }
        return String.isBlank(userIdTxt) ? 'System' : userIdTxt;
    }

    private static Id safeToId(String raw) {
        if (String.isBlank(raw)) {
            return null;
        }
        try {
            return (Id) raw;
        } catch (StringException ex) {
            return null;
        }
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

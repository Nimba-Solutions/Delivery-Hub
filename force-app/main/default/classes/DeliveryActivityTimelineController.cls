/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Controller for the Activity Timeline LWC.
 * Queries WorkItemComment__c, WorkLog__c, and ActivityLog__c to build a
 * unified, chronological event feed for a given Work Item.
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.CyclomaticComplexity,PMD.AvoidDebugStatements')
public with sharing class DeliveryActivityTimelineController {

    private static final Integer PAGE_SIZE = 20;

    /**
     * @description Returns a unified list of timeline events for a Work Item.
     * Merges comments, work logs, and activity logs (stage changes) into a
     * single chronologically-sorted collection.
     * @param workItemId The Id of the parent WorkItem__c record.
     * @param filterType One of: 'all', 'comments', 'stage_changes', 'time_logs'.
     * @param pageOffset Zero-based page offset for pagination (0 = first page).
     * @return List of Maps, each representing one timeline event.
     */
    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getTimelineEvents(
        Id workItemId,
        String filterType,
        Integer pageOffset
    ) {
        if (workItemId == null) {
            return new List<Map<String, Object>>();
        }
        filterType = sanitizeFilterType(filterType);
        pageOffset = sanitizePageOffset(pageOffset);

        List<Map<String, Object>> events = collectFilteredEvents(workItemId, filterType);
        events.sort(new TimelineEventComparator());
        return paginateEvents(events, pageOffset);
    }

    // ── Input sanitization helpers ───────────────────────────────────────

    private static String sanitizeFilterType(String filterType) {
        return String.isBlank(filterType) ? 'all' : filterType;
    }

    private static Integer sanitizePageOffset(Integer pageOffset) {
        return (pageOffset == null || pageOffset < 0) ? 0 : pageOffset;
    }

    // ── Event collection by filter ───────────────────────────────────────

    private static List<Map<String, Object>> collectFilteredEvents(Id workItemId, String filterType) {
        List<Map<String, Object>> events = new List<Map<String, Object>>();

        if (filterType == 'all' || filterType == 'comments') {
            events.addAll(queryComments(workItemId));
        }
        if (filterType == 'all' || filterType == 'time_logs') {
            events.addAll(queryWorkLogs(workItemId));
        }
        if (filterType == 'all' || filterType == 'stage_changes') {
            events.addAll(queryActivityLogs(workItemId));
        }
        return events;
    }

    // ── Pagination helper ────────────────────────────────────────────────

    private static List<Map<String, Object>> paginateEvents(
        List<Map<String, Object>> events, Integer pageOffset
    ) {
        Integer startIndex = pageOffset * PAGE_SIZE;
        if (startIndex >= events.size()) {
            return new List<Map<String, Object>>();
        }
        Integer endIndex = Math.min(startIndex + PAGE_SIZE, events.size());
        List<Map<String, Object>> page = new List<Map<String, Object>>();
        for (Integer i = startIndex; i < endIndex; i++) {
            page.add(events[i]);
        }
        return page;
    }

    // ── Comment events ──────────────────────────────────────────────────

    private static List<Map<String, Object>> queryComments(Id workItemId) {
        List<Map<String, Object>> results = new List<Map<String, Object>>();

        List<WorkItemComment__c> comments = [
            SELECT Id, CreatedDate, AuthorTxt__c, BodyTxt__c, SourcePk__c, CreatedBy.Name
            FROM WorkItemComment__c
            WHERE WorkItemId__c = :workItemId
            WITH SYSTEM_MODE
            ORDER BY CreatedDate DESC
            LIMIT 200
        ];

        for (WorkItemComment__c c : comments) {
            String authorName = String.isNotBlank(c.AuthorTxt__c)
                ? c.AuthorTxt__c
                : c.CreatedBy.Name;

            // Strip HTML tags from body for plain-text preview
            String bodyPreview = c.BodyTxt__c;
            if (String.isNotBlank(bodyPreview)) {
                bodyPreview = bodyPreview.stripHtmlTags();
                if (bodyPreview.length() > 300) {
                    bodyPreview = bodyPreview.substring(0, 300) + '...';
                }
            }

            String sourceLabel = String.isNotBlank(c.SourcePk__c)
                ? c.SourcePk__c
                : 'Salesforce';

            results.add(new Map<String, Object>{
                'id'          => c.Id,
                'type'        => 'comment',
                'timestamp'   => c.CreatedDate,
                'userName'    => authorName,
                'title'       => 'Comment from ' + authorName + ' (' + sourceLabel + ')',
                'detail'      => bodyPreview,
                'icon'        => 'standard:feedback',
                'iconVariant' => 'success'
            });
        }
        return results;
    }

    // ── Work Log events ─────────────────────────────────────────────────

    private static List<Map<String, Object>> queryWorkLogs(Id workItemId) {
        List<Map<String, Object>> results = new List<Map<String, Object>>();

        List<WorkLog__c> logs = [
            SELECT Id, CreatedDate, CreatedBy.Name, HoursLoggedNumber__c,
                   WorkDescriptionTxt__c, WorkDateDate__c
            FROM WorkLog__c
            WHERE WorkItemId__c = :workItemId
            WITH SYSTEM_MODE
            ORDER BY CreatedDate DESC
            LIMIT 200
        ];

        for (WorkLog__c wl : logs) {
            Decimal hours = wl.HoursLoggedNumber__c != null
                ? wl.HoursLoggedNumber__c
                : 0;
            String hoursLabel = hours + 'h logged';

            String detail = String.isNotBlank(wl.WorkDescriptionTxt__c)
                ? wl.WorkDescriptionTxt__c
                : '';
            if (wl.WorkDateDate__c != null) {
                String dateStr = String.valueOf(wl.WorkDateDate__c);
                detail = (String.isNotBlank(detail))
                    ? detail + ' (Work date: ' + dateStr + ')'
                    : 'Work date: ' + dateStr;
            }

            results.add(new Map<String, Object>{
                'id'          => wl.Id,
                'type'        => 'worklog',
                'timestamp'   => wl.CreatedDate,
                'userName'    => wl.CreatedBy.Name,
                'title'       => hoursLabel + ' by ' + wl.CreatedBy.Name,
                'detail'      => detail,
                'icon'        => 'standard:timesheet',
                'iconVariant' => ''
            });
        }
        return results;
    }

    // ── Activity Log events (stage changes) ─────────────────────────────

    private static List<Map<String, Object>> queryActivityLogs(Id workItemId) {
        List<ActivityLog__c> logs = queryStageChangeLogs(workItemId);
        Set<Id> userIds = collectUserIds(logs);
        Map<Id, String> userNameMap = resolveUserNames(userIds);

        List<Map<String, Object>> results = new List<Map<String, Object>>();
        for (ActivityLog__c al : logs) {
            String userName = resolveUserName(al.UserIdTxt__c, userNameMap);
            Map<String, String> stageInfo = parseStageChangeContext(al.ContextDataTxt__c);
            results.add(buildStageChangeEvent(al, userName, stageInfo));
        }
        return results;
    }

    private static List<ActivityLog__c> queryStageChangeLogs(Id workItemId) {
        // ActivityLog__c has no direct WorkItem lookup. Stage_Change entries
        // store the record Id inside the ContextDataTxt__c JSON blob.
        // ContextDataTxt__c is a Long Text Area — not filterable in SOQL.
        // We query all Stage_Change logs and post-filter in Apex.
        String workItemIdStr = String.valueOf(workItemId);

        List<ActivityLog__c> allLogs = [
            SELECT Id, CreatedDate, UserIdTxt__c, ActionTypePk__c,
                   ComponentNameTxt__c, ContextDataTxt__c
            FROM ActivityLog__c
            WHERE ActionTypePk__c = 'Stage_Change'
            WITH SYSTEM_MODE
            ORDER BY CreatedDate DESC
            LIMIT 1000
        ];

        List<ActivityLog__c> filtered = new List<ActivityLog__c>();
        for (ActivityLog__c log : allLogs) {
            if (String.isNotBlank(log.ContextDataTxt__c)
                && log.ContextDataTxt__c.contains(workItemIdStr)
                && filtered.size() < 200) {
                filtered.add(log);
            }
        }
        return filtered;
    }

    // ── User resolution helpers ──────────────────────────────────────────

    private static Set<Id> collectUserIds(List<ActivityLog__c> logs) {
        Set<Id> userIds = new Set<Id>();
        for (ActivityLog__c al : logs) {
            if (String.isNotBlank(al.UserIdTxt__c)) {
                try {
                    userIds.add((Id) al.UserIdTxt__c);
                } catch (Exception ex) {
                    System.debug(LoggingLevel.FINE,
                        'Activity Timeline: Skipping invalid User Id "' +
                        al.UserIdTxt__c + '": ' + ex.getMessage());
                }
            }
        }
        return userIds;
    }

    private static Map<Id, String> resolveUserNames(Set<Id> userIds) {
        Map<Id, String> userNameMap = new Map<Id, String>();
        if (!userIds.isEmpty()) {
            for (User u : [SELECT Id, Name FROM User WHERE Id IN :userIds WITH SYSTEM_MODE]) {
                userNameMap.put(u.Id, u.Name);
            }
        }
        return userNameMap;
    }

    private static String resolveUserName(String userIdTxt, Map<Id, String> userNameMap) {
        if (String.isNotBlank(userIdTxt) && userNameMap.containsKey(userIdTxt)) {
            return userNameMap.get(userIdTxt);
        }
        return 'System';
    }

    // ── Stage change context parsing ─────────────────────────────────────

    private static Map<String, String> parseStageChangeContext(String contextDataJson) {
        Map<String, String> stageInfo = new Map<String, String>{
            'title'  => 'Stage changed',
            'detail' => ''
        };
        if (String.isBlank(contextDataJson)) {
            return stageInfo;
        }
        try {
            Map<String, Object> ctx = (Map<String, Object>) JSON.deserializeUntyped(contextDataJson);
            String newStage = (String) ctx.get('newStage');
            String oldStage = (String) ctx.get('oldStage');
            if (String.isNotBlank(newStage)) {
                stageInfo.put('title', 'Stage changed to ' + newStage);
            }
            if (String.isNotBlank(oldStage) && String.isNotBlank(newStage)) {
                stageInfo.put('detail', oldStage + ' → ' + newStage);
            }
        } catch (Exception ex) {
            System.debug(LoggingLevel.FINE,
                'Activity Timeline: Could not parse stage change context: ' +
                ex.getMessage());
        }
        return stageInfo;
    }

    private static Map<String, Object> buildStageChangeEvent(
        ActivityLog__c al, String userName, Map<String, String> stageInfo
    ) {
        return new Map<String, Object>{
            'id'          => al.Id,
            'type'        => 'stage_change',
            'timestamp'   => al.CreatedDate,
            'userName'    => userName,
            'title'       => stageInfo.get('title'),
            'detail'      => stageInfo.get('detail'),
            'icon'        => 'standard:record',
            'iconVariant' => ''
        };
    }

    // ── Comparator: sort events by timestamp descending ─────────────────

    /** @description Comparator that sorts timeline events by timestamp in descending order (newest first). */
    private class TimelineEventComparator implements Comparator<Map<String, Object>> {
        /**
         * @description Compares two timeline event maps by their timestamp field for descending sort order.
         * @param a First timeline event map
         * @param b Second timeline event map
         * @return Negative if a is newer, positive if b is newer, zero if equal
         */
        public Integer compare(Map<String, Object> a, Map<String, Object> b) {
            Datetime tsA = (Datetime) a.get('timestamp');
            Datetime tsB = (Datetime) b.get('timestamp');
            if (tsA == null && tsB == null) {
                return 0;
            }
            if (tsA == null) {
                return 1;
            }
            if (tsB == null) {
                return -1;
            }
            // Descending: newer first
            if (tsB > tsA) {
                return 1;
            }
            if (tsB < tsA) {
                return -1;
            }
            return 0;
        }
    }
}

/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Controller for the Activity Feed LWC. Provides a cross-item
 *               unified activity view combining comments, work logs, and
 *               activity logs (stage/field changes). Supports filtering by
 *               NetworkEntity for multi-tenant scoping, pagination, and
 *               WorkLog approval workflows.
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.ApexCRUDViolation,PMD.AvoidDebugStatements,PMD.ExcessiveParameterList')
public with sharing class DeliveryActivityFeedController {

    private static final Integer PAGE_SIZE = 25;

    // ── Unified Activity Feed ──────────────────────────────────────────

    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getActivityFeed(
        String filterType,
        Integer pageOffset,
        Id networkEntityId,
        Id workItemId,
        Date startDate,
        Date endDate
    ) {
        filterType = String.isBlank(filterType) ? 'all' : filterType;
        pageOffset = sanitizeOffset(pageOffset);

        Set<Id> scopedWorkItemIds = resolveWorkItemScope(networkEntityId, workItemId);
        List<Map<String, Object>> events = collectEvents(filterType, scopedWorkItemIds, startDate, endDate);

        Set<Id> allWorkItemIds = collectWorkItemIds(events);
        Map<Id, WorkItem__c> workItemMap = resolveWorkItemNames(allWorkItemIds);
        decorateWithWorkItemInfo(events, workItemMap);

        events.sort(new EventComparator());
        Integer totalCount = events.size();
        List<Map<String, Object>> page = paginateEvents(events, pageOffset);

        return new Map<String, Object>{
            'events' => page,
            'totalCount' => totalCount,
            'hasMore' => (pageOffset + 1) * PAGE_SIZE < totalCount
        };
    }

    private static List<Map<String, Object>> collectEvents(
        String filterType, Set<Id> scopedWorkItemIds, Date startDate, Date endDate
    ) {
        List<Map<String, Object>> events = new List<Map<String, Object>>();
        if (filterType == 'all' || filterType == 'comments') {
            events.addAll(queryFeedComments(scopedWorkItemIds, startDate, endDate));
        }
        if (filterType == 'all' || filterType == 'hours') {
            events.addAll(queryFeedWorkLogs(scopedWorkItemIds, startDate, endDate));
        }
        if (filterType == 'all' || filterType == 'changes') {
            events.addAll(queryFeedActivityLogs(scopedWorkItemIds, startDate, endDate));
        }
        return events;
    }

    // ── Conversations (grouped by WorkItem) ────────────────────────────

    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getConversations(
        Integer pageOffset,
        Id networkEntityId
    ) {
        pageOffset = sanitizeOffset(pageOffset);
        Set<Id> scopedWorkItemIds = resolveWorkItemScope(networkEntityId, null);

        String query = 'SELECT Id, CreatedDate, AuthorTxt__c, BodyTxt__c, SourcePk__c, '
            + 'WorkItemId__c, CreatedBy.Name '
            + 'FROM WorkItemComment__c ';
        if (scopedWorkItemIds != null) {
            query += 'WHERE WorkItemId__c IN :scopedWorkItemIds ';
        }
        query += 'ORDER BY CreatedDate DESC LIMIT 500';

        List<WorkItemComment__c> comments = Database.query(query);
        Map<Id, List<WorkItemComment__c>> grouped = groupCommentsByWorkItem(comments);
        Map<Id, WorkItem__c> workItemMap = resolveWorkItemNames(grouped.keySet());
        List<Map<String, Object>> threads = buildThreads(grouped, workItemMap);

        threads.sort(new EventComparator());
        return paginateEvents(threads, pageOffset);
    }

    private static Map<Id, List<WorkItemComment__c>> groupCommentsByWorkItem(List<WorkItemComment__c> comments) {
        Map<Id, List<WorkItemComment__c>> grouped = new Map<Id, List<WorkItemComment__c>>();
        for (WorkItemComment__c c : comments) {
            if (!grouped.containsKey(c.WorkItemId__c)) {
                grouped.put(c.WorkItemId__c, new List<WorkItemComment__c>());
            }
            grouped.get(c.WorkItemId__c).add(c);
        }
        return grouped;
    }

    private static List<Map<String, Object>> buildThreads(
        Map<Id, List<WorkItemComment__c>> grouped,
        Map<Id, WorkItem__c> workItemMap
    ) {
        List<Map<String, Object>> threads = new List<Map<String, Object>>();
        for (Id wiId : grouped.keySet()) {
            List<WorkItemComment__c> threadComments = grouped.get(wiId);
            WorkItem__c wi = workItemMap.get(wiId);
            List<Map<String, Object>> commentMaps = buildCommentMaps(threadComments);

            threads.add(new Map<String, Object>{
                'workItemId' => wiId,
                'workItemName' => wi != null ? wi.Name : '',
                'workItemDescription' => wi != null ? wi.BriefDescriptionTxt__c : '',
                'commentCount' => threadComments.size(),
                'latestTimestamp' => threadComments[0].CreatedDate,
                'latestPreview' => commentMaps[0].get('body'),
                'latestAuthor' => commentMaps[0].get('author'),
                'comments' => commentMaps
            });
        }
        return threads;
    }

    private static List<Map<String, Object>> buildCommentMaps(List<WorkItemComment__c> comments) {
        List<Map<String, Object>> maps = new List<Map<String, Object>>();
        for (WorkItemComment__c c : comments) {
            String author = String.isNotBlank(c.AuthorTxt__c) ? c.AuthorTxt__c : c.CreatedBy.Name;
            String body = c.BodyTxt__c;
            if (String.isNotBlank(body)) {
                body = body.stripHtmlTags();
            }
            maps.add(new Map<String, Object>{
                'id' => c.Id,
                'author' => author,
                'body' => body,
                'source' => String.isNotBlank(c.SourcePk__c) ? c.SourcePk__c : 'Salesforce',
                'timestamp' => c.CreatedDate
            });
        }
        return maps;
    }

    // ── Pending Approvals ──────────────────────────────────────────────

    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getPendingApprovals(
        Integer pageOffset,
        Id networkEntityId
    ) {
        pageOffset = sanitizeOffset(pageOffset);
        Set<Id> scopedWorkItemIds = resolveWorkItemScope(networkEntityId, null);

        String query = 'SELECT Id, CreatedDate, CreatedBy.Name, HoursLoggedNumber__c, '
            + 'WorkDateDate__c, WorkDescriptionTxt__c, WorkItemId__c, StatusPk__c '
            + 'FROM WorkLog__c '
            + 'WHERE StatusPk__c = \'Draft\' ';
        if (scopedWorkItemIds != null) {
            query += 'AND WorkItemId__c IN :scopedWorkItemIds ';
        }
        query += 'ORDER BY CreatedDate DESC LIMIT 200';

        List<WorkLog__c> logs = Database.query(query);

        Set<Id> wiIds = new Set<Id>();
        for (WorkLog__c wl : logs) {
            wiIds.add(wl.WorkItemId__c);
        }
        Map<Id, WorkItem__c> workItemMap = resolveWorkItemNames(wiIds);

        List<Map<String, Object>> results = new List<Map<String, Object>>();
        for (WorkLog__c wl : logs) {
            results.add(buildApprovalMap(wl, workItemMap));
        }

        return new Map<String, Object>{
            'approvals' => results,
            'totalCount' => results.size()
        };
    }

    private static Map<String, Object> buildApprovalMap(WorkLog__c wl, Map<Id, WorkItem__c> workItemMap) {
        WorkItem__c wi = workItemMap.get(wl.WorkItemId__c);
        return new Map<String, Object>{
            'id' => wl.Id,
            'workItemId' => wl.WorkItemId__c,
            'workItemName' => wi != null ? wi.Name : '',
            'workItemDescription' => wi != null ? wi.BriefDescriptionTxt__c : '',
            'hours' => wl.HoursLoggedNumber__c,
            'workDate' => wl.WorkDateDate__c,
            'description' => wl.WorkDescriptionTxt__c,
            'userName' => wl.CreatedBy.Name,
            'timestamp' => wl.CreatedDate,
            'status' => wl.StatusPk__c
        };
    }

    // ── Approval Actions ───────────────────────────────────────────────

    @AuraEnabled
    public static void approveWorkLogs(List<Id> workLogIds) {
        DeliveryTimeLoggerController.approveWorkLogs(workLogIds);
    }

    @AuraEnabled
    public static void rejectWorkLogs(List<Id> workLogIds) {
        DeliveryTimeLoggerController.rejectWorkLogs(workLogIds);
    }

    // ── Post Comment from Feed ─────────────────────────────────────────

    @AuraEnabled
    public static void postCommentFromFeed(Id workItemId, String body) {
        if (workItemId == null || String.isBlank(body)) {
            throw new AuraHandledException('Work item and comment body are required.');
        }
        WorkItemComment__c comment = new WorkItemComment__c(
            WorkItemId__c = workItemId,
            BodyTxt__c = body,
            SourcePk__c = 'Client',
            AuthorTxt__c = UserInfo.getName()
        );
        Database.insert(comment, AccessLevel.SYSTEM_MODE);
    }

    // ── Query Helpers ──────────────────────────────────────────────────

    private static String buildWhereClause(List<String> conditions) {
        if (conditions.isEmpty()) {
            return '';
        }
        return 'WHERE ' + String.join(conditions, ' AND ') + ' ';
    }

    private static void addDateConditions(List<String> conditions, Date startDate, Date endDate) {
        if (startDate != null) {
            conditions.add('CreatedDate >= :startDate');
        }
        if (endDate != null) {
            conditions.add('CreatedDate < :endDate');
        }
    }

    private static List<Map<String, Object>> queryFeedComments(
        Set<Id> scopedWorkItemIds, Date startDate, Date endDate
    ) {
        List<String> conditions = new List<String>();
        if (scopedWorkItemIds != null) {
            conditions.add('WorkItemId__c IN :scopedWorkItemIds');
        }
        addDateConditions(conditions, startDate, endDate);

        String query = 'SELECT Id, CreatedDate, AuthorTxt__c, BodyTxt__c, SourcePk__c, '
            + 'WorkItemId__c, CreatedBy.Name '
            + 'FROM WorkItemComment__c '
            + buildWhereClause(conditions)
            + 'ORDER BY CreatedDate DESC LIMIT 200';

        List<Map<String, Object>> results = new List<Map<String, Object>>();
        for (WorkItemComment__c c : Database.query(query)) {
            results.add(buildCommentEvent(c));
        }
        return results;
    }

    private static Map<String, Object> buildCommentEvent(WorkItemComment__c c) {
        String author = String.isNotBlank(c.AuthorTxt__c) ? c.AuthorTxt__c : c.CreatedBy.Name;
        String bodyPreview = c.BodyTxt__c;
        if (String.isNotBlank(bodyPreview)) {
            bodyPreview = bodyPreview.stripHtmlTags();
            if (bodyPreview.length() > 200) {
                bodyPreview = bodyPreview.substring(0, 200) + '...';
            }
        }
        return new Map<String, Object>{
            'id' => c.Id,
            'type' => 'comment',
            'timestamp' => c.CreatedDate,
            'userName' => author,
            'title' => 'Comment by ' + author,
            'detail' => bodyPreview,
            'icon' => 'standard:feedback',
            'workItemId' => c.WorkItemId__c,
            'source' => String.isNotBlank(c.SourcePk__c) ? c.SourcePk__c : 'Salesforce'
        };
    }

    private static List<Map<String, Object>> queryFeedWorkLogs(
        Set<Id> scopedWorkItemIds, Date startDate, Date endDate
    ) {
        List<String> conditions = new List<String>();
        if (scopedWorkItemIds != null) {
            conditions.add('WorkItemId__c IN :scopedWorkItemIds');
        }
        addDateConditions(conditions, startDate, endDate);

        String query = 'SELECT Id, CreatedDate, CreatedBy.Name, HoursLoggedNumber__c, '
            + 'WorkDateDate__c, WorkDescriptionTxt__c, WorkItemId__c, StatusPk__c '
            + 'FROM WorkLog__c '
            + buildWhereClause(conditions)
            + 'ORDER BY CreatedDate DESC LIMIT 200';

        List<Map<String, Object>> results = new List<Map<String, Object>>();
        for (WorkLog__c wl : Database.query(query)) {
            results.add(buildWorkLogEvent(wl));
        }
        return results;
    }

    private static Map<String, Object> buildWorkLogEvent(WorkLog__c wl) {
        Decimal hours = wl.HoursLoggedNumber__c != null ? wl.HoursLoggedNumber__c : 0;
        String statusLabel = String.isNotBlank(wl.StatusPk__c) ? wl.StatusPk__c : 'Approved';
        String detail = buildWorkLogDetail(wl);

        return new Map<String, Object>{
            'id' => wl.Id,
            'type' => 'worklog',
            'timestamp' => wl.CreatedDate,
            'userName' => wl.CreatedBy.Name,
            'title' => hours + 'h logged by ' + wl.CreatedBy.Name,
            'detail' => detail,
            'icon' => 'standard:timesheet',
            'workItemId' => wl.WorkItemId__c,
            'hours' => hours,
            'status' => statusLabel
        };
    }

    private static String buildWorkLogDetail(WorkLog__c wl) {
        String detail = String.isNotBlank(wl.WorkDescriptionTxt__c) ? wl.WorkDescriptionTxt__c : '';
        if (wl.WorkDateDate__c == null) {
            return detail;
        }
        String dateStr = String.valueOf(wl.WorkDateDate__c);
        return String.isNotBlank(detail)
            ? detail + ' (Work date: ' + dateStr + ')'
            : 'Work date: ' + dateStr;
    }

    private static List<Map<String, Object>> queryFeedActivityLogs(
        Set<Id> scopedWorkItemIds, Date startDate, Date endDate
    ) {
        List<String> conditions = new List<String>();
        conditions.add('ActionTypePk__c IN (\'Stage_Change\', \'Field_Change\')');
        Set<String> idStrings = toStringSet(scopedWorkItemIds);
        if (idStrings != null) {
            conditions.add('RecordIdTxt__c IN :idStrings');
        }
        addDateConditions(conditions, startDate, endDate);

        String query = 'SELECT Id, CreatedDate, UserIdTxt__c, ActionTypePk__c, '
            + 'ContextDataTxt__c, RecordIdTxt__c '
            + 'FROM ActivityLog__c '
            + buildWhereClause(conditions)
            + 'ORDER BY CreatedDate DESC LIMIT 200';

        List<ActivityLog__c> logs = Database.query(query);
        Map<Id, String> userNameMap = resolveUserNames(logs);

        List<Map<String, Object>> results = new List<Map<String, Object>>();
        for (ActivityLog__c al : logs) {
            results.add(buildActivityLogEvent(al, userNameMap));
        }
        return results;
    }

    private static Set<String> toStringSet(Set<Id> ids) {
        if (ids == null) {
            return null;
        }
        Set<String> strings = new Set<String>();
        for (Id i : ids) {
            strings.add(String.valueOf(i));
        }
        return strings;
    }

    private static Map<Id, String> resolveUserNames(List<ActivityLog__c> logs) {
        Set<Id> userIds = new Set<Id>();
        for (ActivityLog__c al : logs) {
            if (String.isNotBlank(al.UserIdTxt__c)) {
                try {
                    userIds.add((Id) al.UserIdTxt__c);
                } catch (Exception ex) { /* skip invalid */ }
            }
        }
        Map<Id, String> userNameMap = new Map<Id, String>();
        if (!userIds.isEmpty()) {
            for (User u : [SELECT Id, Name FROM User WHERE Id IN :userIds WITH SYSTEM_MODE]) {
                userNameMap.put(u.Id, u.Name);
            }
        }
        return userNameMap;
    }

    private static Map<String, Object> buildActivityLogEvent(ActivityLog__c al, Map<Id, String> userNameMap) {
        String userName = resolveUserName(al.UserIdTxt__c, userNameMap);
        Map<String, String> changeInfo = parseChangeContext(al.ContextDataTxt__c, al.ActionTypePk__c);
        Id recordId = safeToId(al.RecordIdTxt__c);

        return new Map<String, Object>{
            'id' => al.Id,
            'type' => al.ActionTypePk__c == 'Stage_Change' ? 'stage_change' : 'field_change',
            'timestamp' => al.CreatedDate,
            'userName' => userName,
            'title' => changeInfo.get('title'),
            'detail' => changeInfo.get('detail'),
            'icon' => al.ActionTypePk__c == 'Stage_Change' ? 'standard:record' : 'standard:custom_notification',
            'workItemId' => recordId
        };
    }

    private static String resolveUserName(String userIdTxt, Map<Id, String> userNameMap) {
        if (String.isNotBlank(userIdTxt) && userIdTxt instanceof Id && userNameMap.containsKey(userIdTxt)) {
            return userNameMap.get(userIdTxt);
        }
        return 'System';
    }

    private static Id safeToId(String idString) {
        if (String.isBlank(idString)) {
            return null;
        }
        try {
            return (Id) idString;
        } catch (Exception ex) {
            return null;
        }
    }

    private static Map<String, String> parseChangeContext(String contextDataJson, String actionType) {
        Map<String, String> info = new Map<String, String>{
            'title' => actionType == 'Stage_Change' ? 'Stage changed' : 'Field changed',
            'detail' => ''
        };
        if (String.isBlank(contextDataJson)) {
            return info;
        }
        try {
            Map<String, Object> ctx = (Map<String, Object>) JSON.deserializeUntyped(contextDataJson);
            if (actionType == 'Stage_Change') {
                parseStageChange(ctx, info);
            } else {
                parseFieldChange(ctx, info);
            }
        } catch (Exception ex) {
            System.debug(LoggingLevel.FINE, 'Activity Feed: Could not parse context: ' + ex.getMessage());
        }
        return info;
    }

    private static void parseStageChange(Map<String, Object> ctx, Map<String, String> info) {
        String newStage = (String) ctx.get('newStage');
        String oldStage = (String) ctx.get('oldStage');
        if (String.isNotBlank(newStage)) {
            info.put('title', 'Stage changed to ' + newStage);
        }
        if (String.isNotBlank(oldStage) && String.isNotBlank(newStage)) {
            info.put('detail', oldStage + ' \u2192 ' + newStage);
        }
    }

    private static void parseFieldChange(Map<String, Object> ctx, Map<String, String> info) {
        String fieldLabel = (String) ctx.get('fieldLabel');
        String oldValue = String.valueOf(ctx.get('oldValue'));
        String newValue = String.valueOf(ctx.get('newValue'));
        if (String.isNotBlank(fieldLabel)) {
            info.put('title', fieldLabel + ' changed');
        }
        if (oldValue != null && newValue != null) {
            info.put('detail', oldValue + ' \u2192 ' + newValue);
        }
    }

    // ── Shared Helpers ─────────────────────────────────────────────────

    private static Integer sanitizeOffset(Integer pageOffset) {
        return (pageOffset == null || pageOffset < 0) ? 0 : pageOffset;
    }

    private static Set<Id> resolveWorkItemScope(Id networkEntityId, Id workItemId) {
        if (workItemId != null) {
            return new Set<Id>{ workItemId };
        }
        if (networkEntityId != null) {
            Set<Id> ids = new Set<Id>();
            for (WorkItem__c wi : [
                SELECT Id FROM WorkItem__c
                WHERE ClientNetworkEntityId__c = :networkEntityId
                WITH SYSTEM_MODE
                LIMIT 2000
            ]) {
                ids.add(wi.Id);
            }
            return ids;
        }
        return null;
    }

    private static Set<Id> collectWorkItemIds(List<Map<String, Object>> events) {
        Set<Id> ids = new Set<Id>();
        for (Map<String, Object> ev : events) {
            Object wiId = ev.get('workItemId');
            if (wiId != null && wiId instanceof Id) {
                ids.add((Id) wiId);
            }
        }
        return ids;
    }

    private static Map<Id, WorkItem__c> resolveWorkItemNames(Set<Id> workItemIds) {
        if (workItemIds == null || workItemIds.isEmpty()) {
            return new Map<Id, WorkItem__c>();
        }
        return new Map<Id, WorkItem__c>([
            SELECT Id, Name, BriefDescriptionTxt__c
            FROM WorkItem__c
            WHERE Id IN :workItemIds
            WITH SYSTEM_MODE
        ]);
    }

    private static void decorateWithWorkItemInfo(
        List<Map<String, Object>> events,
        Map<Id, WorkItem__c> workItemMap
    ) {
        for (Map<String, Object> ev : events) {
            Object wiIdObj = ev.get('workItemId');
            if (wiIdObj != null && wiIdObj instanceof Id) {
                WorkItem__c wi = workItemMap.get((Id) wiIdObj);
                if (wi != null) {
                    ev.put('workItemName', wi.Name);
                    ev.put('workItemDescription', wi.BriefDescriptionTxt__c);
                }
            }
        }
    }

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

    private class EventComparator implements Comparator<Map<String, Object>> {
        public Integer compare(Map<String, Object> a, Map<String, Object> b) {
            Datetime tsA = getTimestamp(a);
            Datetime tsB = getTimestamp(b);
            if (tsA == null && tsB == null) { return 0; }
            if (tsA == null) { return 1; }
            if (tsB == null) { return -1; }
            if (tsB > tsA) { return 1; }
            if (tsB < tsA) { return -1; }
            return 0;
        }

        private Datetime getTimestamp(Map<String, Object> m) {
            Object ts = m.get('latestTimestamp');
            if (ts == null) {
                ts = m.get('timestamp');
            }
            return ts instanceof Datetime ? (Datetime) ts : null;
        }
    }
}

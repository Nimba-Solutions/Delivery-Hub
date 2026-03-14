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
@SuppressWarnings('PMD.ApexCRUDViolation,PMD.CyclomaticComplexity,PMD.AvoidDebugStatements,PMD.ExcessiveParameterList')
public with sharing class DeliveryActivityFeedController {

    private static final Integer PAGE_SIZE = 25;

    // ── Unified Activity Feed ──────────────────────────────────────────

    /**
     * @description Returns a unified, chronologically-sorted activity feed.
     * @param filterType One of: 'all', 'comments', 'hours', 'changes'.
     * @param pageOffset Zero-based page offset (0 = first page).
     * @param networkEntityId Optional NetworkEntity__c Id to scope by client.
     * @param workItemId Optional WorkItem__c Id to filter to a single item.
     * @param startDate Optional start date filter.
     * @param endDate Optional end date filter.
     * @return List of event maps, sorted newest-first.
     */
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
        pageOffset = (pageOffset == null || pageOffset < 0) ? 0 : pageOffset;

        // Resolve work item scope
        Set<Id> scopedWorkItemIds = resolveWorkItemScope(networkEntityId, workItemId);

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

        // Resolve work item names for display
        Set<Id> allWorkItemIds = collectWorkItemIds(events);
        Map<Id, WorkItem__c> workItemMap = resolveWorkItemNames(allWorkItemIds);
        decorateWithWorkItemInfo(events, workItemMap);

        // Sort newest first and paginate
        events.sort(new EventComparator());
        Integer totalCount = events.size();
        List<Map<String, Object>> page = paginateEvents(events, pageOffset);

        return new Map<String, Object>{
            'events' => page,
            'totalCount' => totalCount,
            'hasMore' => (pageOffset + 1) * PAGE_SIZE < totalCount
        };
    }

    // ── Conversations (grouped by WorkItem) ────────────────────────────

    /**
     * @description Returns comments grouped by work item for a conversation view.
     * @param pageOffset Zero-based page offset.
     * @param networkEntityId Optional NetworkEntity filter.
     * @return List of conversation thread maps.
     */
    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getConversations(
        Integer pageOffset,
        Id networkEntityId
    ) {
        pageOffset = (pageOffset == null || pageOffset < 0) ? 0 : pageOffset;
        Set<Id> scopedWorkItemIds = resolveWorkItemScope(networkEntityId, null);

        // Query comments for scoped work items
        String query = 'SELECT Id, CreatedDate, AuthorTxt__c, BodyTxt__c, SourcePk__c, '
            + 'WorkItemId__c, CreatedBy.Name '
            + 'FROM WorkItemComment__c ';
        if (scopedWorkItemIds != null) {
            query += 'WHERE WorkItemId__c IN :scopedWorkItemIds ';
        }
        query += 'ORDER BY CreatedDate DESC LIMIT 500';

        List<WorkItemComment__c> comments = Database.query(query);

        // Group by WorkItemId
        Map<Id, List<WorkItemComment__c>> grouped = new Map<Id, List<WorkItemComment__c>>();
        for (WorkItemComment__c c : comments) {
            if (!grouped.containsKey(c.WorkItemId__c)) {
                grouped.put(c.WorkItemId__c, new List<WorkItemComment__c>());
            }
            grouped.get(c.WorkItemId__c).add(c);
        }

        // Resolve work item names
        Map<Id, WorkItem__c> workItemMap = resolveWorkItemNames(grouped.keySet());

        // Build conversation threads sorted by latest activity
        List<Map<String, Object>> threads = new List<Map<String, Object>>();
        for (Id wiId : grouped.keySet()) {
            List<WorkItemComment__c> threadComments = grouped.get(wiId);
            WorkItem__c wi = workItemMap.get(wiId);

            List<Map<String, Object>> commentMaps = new List<Map<String, Object>>();
            for (WorkItemComment__c c : threadComments) {
                String author = String.isNotBlank(c.AuthorTxt__c) ? c.AuthorTxt__c : c.CreatedBy.Name;
                String body = c.BodyTxt__c;
                if (String.isNotBlank(body)) {
                    body = body.stripHtmlTags();
                }
                commentMaps.add(new Map<String, Object>{
                    'id' => c.Id,
                    'author' => author,
                    'body' => body,
                    'source' => String.isNotBlank(c.SourcePk__c) ? c.SourcePk__c : 'Salesforce',
                    'timestamp' => c.CreatedDate
                });
            }

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

        // Sort threads by latest activity (newest first)
        threads.sort(new EventComparator());

        // Paginate
        Integer startIdx = pageOffset * PAGE_SIZE;
        if (startIdx >= threads.size()) {
            return new List<Map<String, Object>>();
        }
        Integer endIdx = Math.min(startIdx + PAGE_SIZE, threads.size());
        List<Map<String, Object>> page = new List<Map<String, Object>>();
        for (Integer i = startIdx; i < endIdx; i++) {
            page.add(threads[i]);
        }
        return page;
    }

    // ── Pending Approvals ──────────────────────────────────────────────

    /**
     * @description Returns Draft WorkLogs pending approval.
     * @param pageOffset Zero-based page offset.
     * @param networkEntityId Optional NetworkEntity filter.
     * @return List of pending work log maps.
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getPendingApprovals(
        Integer pageOffset,
        Id networkEntityId
    ) {
        pageOffset = (pageOffset == null || pageOffset < 0) ? 0 : pageOffset;
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

        // Resolve work item names
        Set<Id> wiIds = new Set<Id>();
        for (WorkLog__c wl : logs) {
            wiIds.add(wl.WorkItemId__c);
        }
        Map<Id, WorkItem__c> workItemMap = resolveWorkItemNames(wiIds);

        List<Map<String, Object>> results = new List<Map<String, Object>>();
        for (WorkLog__c wl : logs) {
            WorkItem__c wi = workItemMap.get(wl.WorkItemId__c);
            results.add(new Map<String, Object>{
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
            });
        }

        return new Map<String, Object>{
            'approvals' => results,
            'totalCount' => results.size()
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

    /**
     * @description Posts a new comment on a work item from the activity feed.
     * @param workItemId The WorkItem__c Id to comment on.
     * @param body The comment text.
     */
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

    // ── Private Helpers ────────────────────────────────────────────────

    /**
     * @description Resolves the set of WorkItem Ids in scope based on filters.
     *              Returns null when no filter is applied (query all).
     */
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
        return null; // No filter — all items
    }

    private static List<Map<String, Object>> queryFeedComments(
        Set<Id> scopedWorkItemIds, Date startDate, Date endDate
    ) {
        List<Map<String, Object>> results = new List<Map<String, Object>>();
        String query = 'SELECT Id, CreatedDate, AuthorTxt__c, BodyTxt__c, SourcePk__c, '
            + 'WorkItemId__c, CreatedBy.Name '
            + 'FROM WorkItemComment__c ';
        List<String> conditions = new List<String>();
        if (scopedWorkItemIds != null) {
            conditions.add('WorkItemId__c IN :scopedWorkItemIds');
        }
        if (startDate != null) {
            conditions.add('CreatedDate >= :startDate');
        }
        if (endDate != null) {
            Datetime endDt = Datetime.newInstance(endDate.addDays(1), Time.newInstance(0, 0, 0, 0));
            conditions.add('CreatedDate < :endDt');
        }
        if (!conditions.isEmpty()) {
            query += 'WHERE ' + String.join(conditions, ' AND ') + ' ';
        }
        query += 'ORDER BY CreatedDate DESC LIMIT 200';

        for (WorkItemComment__c c : Database.query(query)) {
            String author = String.isNotBlank(c.AuthorTxt__c) ? c.AuthorTxt__c : c.CreatedBy.Name;
            String bodyPreview = c.BodyTxt__c;
            if (String.isNotBlank(bodyPreview)) {
                bodyPreview = bodyPreview.stripHtmlTags();
                if (bodyPreview.length() > 200) {
                    bodyPreview = bodyPreview.substring(0, 200) + '...';
                }
            }
            results.add(new Map<String, Object>{
                'id' => c.Id,
                'type' => 'comment',
                'timestamp' => c.CreatedDate,
                'userName' => author,
                'title' => 'Comment by ' + author,
                'detail' => bodyPreview,
                'icon' => 'standard:feedback',
                'workItemId' => c.WorkItemId__c,
                'source' => String.isNotBlank(c.SourcePk__c) ? c.SourcePk__c : 'Salesforce'
            });
        }
        return results;
    }

    private static List<Map<String, Object>> queryFeedWorkLogs(
        Set<Id> scopedWorkItemIds, Date startDate, Date endDate
    ) {
        List<Map<String, Object>> results = new List<Map<String, Object>>();
        String query = 'SELECT Id, CreatedDate, CreatedBy.Name, HoursLoggedNumber__c, '
            + 'WorkDateDate__c, WorkDescriptionTxt__c, WorkItemId__c, StatusPk__c '
            + 'FROM WorkLog__c ';
        List<String> conditions = new List<String>();
        if (scopedWorkItemIds != null) {
            conditions.add('WorkItemId__c IN :scopedWorkItemIds');
        }
        if (startDate != null) {
            conditions.add('CreatedDate >= :startDate');
        }
        if (endDate != null) {
            Datetime endDt = Datetime.newInstance(endDate.addDays(1), Time.newInstance(0, 0, 0, 0));
            conditions.add('CreatedDate < :endDt');
        }
        if (!conditions.isEmpty()) {
            query += 'WHERE ' + String.join(conditions, ' AND ') + ' ';
        }
        query += 'ORDER BY CreatedDate DESC LIMIT 200';

        for (WorkLog__c wl : Database.query(query)) {
            Decimal hours = wl.HoursLoggedNumber__c != null ? wl.HoursLoggedNumber__c : 0;
            String statusLabel = String.isNotBlank(wl.StatusPk__c) ? wl.StatusPk__c : 'Approved';
            String detail = String.isNotBlank(wl.WorkDescriptionTxt__c) ? wl.WorkDescriptionTxt__c : '';
            if (wl.WorkDateDate__c != null) {
                String dateStr = String.valueOf(wl.WorkDateDate__c);
                detail = String.isNotBlank(detail)
                    ? detail + ' (Work date: ' + dateStr + ')'
                    : 'Work date: ' + dateStr;
            }

            results.add(new Map<String, Object>{
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
            });
        }
        return results;
    }

    private static List<Map<String, Object>> queryFeedActivityLogs(
        Set<Id> scopedWorkItemIds, Date startDate, Date endDate
    ) {
        List<Map<String, Object>> results = new List<Map<String, Object>>();

        // RecordIdTxt__c is ExternalId (indexed) — efficient query
        String query = 'SELECT Id, CreatedDate, UserIdTxt__c, ActionTypePk__c, '
            + 'ContextDataTxt__c, RecordIdTxt__c '
            + 'FROM ActivityLog__c ';
        List<String> conditions = new List<String>();
        conditions.add('ActionTypePk__c IN (\'Stage_Change\', \'Field_Change\')');
        if (scopedWorkItemIds != null) {
            Set<String> idStrings = new Set<String>();
            for (Id wiId : scopedWorkItemIds) {
                idStrings.add(String.valueOf(wiId));
            }
            conditions.add('RecordIdTxt__c IN :idStrings');
        }
        if (startDate != null) {
            conditions.add('CreatedDate >= :startDate');
        }
        if (endDate != null) {
            Datetime endDt = Datetime.newInstance(endDate.addDays(1), Time.newInstance(0, 0, 0, 0));
            conditions.add('CreatedDate < :endDt');
        }
        if (!conditions.isEmpty()) {
            query += 'WHERE ' + String.join(conditions, ' AND ') + ' ';
        }
        query += 'ORDER BY CreatedDate DESC LIMIT 200';

        List<ActivityLog__c> logs = Database.query(query);

        // Resolve user names
        Set<Id> userIds = new Set<Id>();
        for (ActivityLog__c al : logs) {
            if (String.isNotBlank(al.UserIdTxt__c)) {
                try {
                    userIds.add((Id) al.UserIdTxt__c);
                } catch (Exception ex) {
                    // Skip invalid user IDs
                }
            }
        }
        Map<Id, String> userNameMap = new Map<Id, String>();
        if (!userIds.isEmpty()) {
            for (User u : [SELECT Id, Name FROM User WHERE Id IN :userIds WITH SYSTEM_MODE]) {
                userNameMap.put(u.Id, u.Name);
            }
        }

        for (ActivityLog__c al : logs) {
            String userName = 'System';
            if (String.isNotBlank(al.UserIdTxt__c) && al.UserIdTxt__c instanceof Id && userNameMap.containsKey(al.UserIdTxt__c)) {
                userName = userNameMap.get(al.UserIdTxt__c);
            }

            Map<String, String> changeInfo = parseChangeContext(al.ContextDataTxt__c, al.ActionTypePk__c);
            Id recordId = null;
            if (String.isNotBlank(al.RecordIdTxt__c)) {
                try {
                    recordId = (Id) al.RecordIdTxt__c;
                } catch (Exception ex) {
                    // Skip invalid record IDs
                }
            }

            results.add(new Map<String, Object>{
                'id' => al.Id,
                'type' => al.ActionTypePk__c == 'Stage_Change' ? 'stage_change' : 'field_change',
                'timestamp' => al.CreatedDate,
                'userName' => userName,
                'title' => changeInfo.get('title'),
                'detail' => changeInfo.get('detail'),
                'icon' => al.ActionTypePk__c == 'Stage_Change' ? 'standard:record' : 'standard:custom_notification',
                'workItemId' => recordId
            });
        }
        return results;
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
                String newStage = (String) ctx.get('newStage');
                String oldStage = (String) ctx.get('oldStage');
                if (String.isNotBlank(newStage)) {
                    info.put('title', 'Stage changed to ' + newStage);
                }
                if (String.isNotBlank(oldStage) && String.isNotBlank(newStage)) {
                    info.put('detail', oldStage + ' \u2192 ' + newStage);
                }
            } else {
                // Field change
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
        } catch (Exception ex) {
            System.debug(LoggingLevel.FINE, 'Activity Feed: Could not parse context: ' + ex.getMessage());
        }
        return info;
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

    /**
     * @description Sorts events by timestamp descending (newest first).
     *              For conversations, sorts by latestTimestamp.
     */
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
            // Conversations use latestTimestamp; events use timestamp
            Object ts = m.get('latestTimestamp');
            if (ts == null) {
                ts = m.get('timestamp');
            }
            return ts instanceof Datetime ? (Datetime) ts : null;
        }
    }
}

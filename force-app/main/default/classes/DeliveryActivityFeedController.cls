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
@SuppressWarnings('PMD.ApexCRUDViolation,PMD.ExcessiveParameterList,PMD.CyclomaticComplexity')
global with sharing class DeliveryActivityFeedController {

    private static final Integer PAGE_SIZE = 25;

    // Field-change events on these (namespace-stripped, lowercase) API names are
    // suppressed from the Activity Feed as cosmetic/ambient noise. Description
    // edits and rollup recalcs don't tell a reader anything they need to act on.
    private static final Set<String> SUPPRESSED_FIELD_API_NAMES = new Set<String>{
        'workdescriptiontxt__c'
    };

    // ── Unified Activity Feed ──────────────────────────────────────────

    /**
     * @description Returns a unified, chronologically-sorted activity feed.
     * @param filterType One of: 'all', 'comments', 'hours', 'changes'.
     * @param pageOffset Zero-based page offset (0 = first page).
     * @param networkEntityId Optional NetworkEntity__c Id to scope by client.
     * @param workItemId Optional WorkItem__c Id to filter to a single item.
     * @param startDate Optional start date filter.
     * @param endDate Optional end date filter.
     * @return Map containing events list, totalCount, and hasMore flag.
     */
    @AuraEnabled(cacheable=true)
    global static Map<String, Object> getActivityFeed(
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
            events.addAll(queryFeedComments(scopedWorkItemIds));
        }
        if (filterType == 'all' || filterType == 'hours') {
            events.addAll(queryFeedWorkLogs(scopedWorkItemIds));
        }
        if (filterType == 'all' || filterType == 'changes') {
            events.addAll(queryFeedActivityLogs(scopedWorkItemIds));
        }
        return events;
    }

    // ── Conversations (grouped by WorkItem) ────────────────────────────

    /**
     * @description Returns comments grouped by work item for a conversation view.
     * @param pageOffset Zero-based page offset.
     * @param networkEntityId Optional NetworkEntity filter.
     * @return List of conversation thread maps.
     */
    @AuraEnabled(cacheable=true)
    global static List<Map<String, Object>> getConversations(
        Integer pageOffset,
        Id networkEntityId
    ) {
        pageOffset = sanitizeOffset(pageOffset);
        Set<Id> scopedWorkItemIds = resolveWorkItemScope(networkEntityId, null);

        List<WorkItemComment__c> comments;
        if (scopedWorkItemIds != null) {
            comments = [
                SELECT Id, CreatedDate, AuthorTxt__c, BodyTxt__c, SourcePk__c,
                       WorkItemId__c, CreatedBy.Name
                FROM WorkItemComment__c
                WHERE WorkItemId__c IN :scopedWorkItemIds
                WITH SYSTEM_MODE
                ORDER BY CreatedDate DESC
                LIMIT 500
            ];
        } else {
            comments = [
                SELECT Id, CreatedDate, AuthorTxt__c, BodyTxt__c, SourcePk__c,
                       WorkItemId__c, CreatedBy.Name
                FROM WorkItemComment__c
                WITH SYSTEM_MODE
                ORDER BY CreatedDate DESC
                LIMIT 500
            ];
        }

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

    /**
     * @description Returns Draft WorkLogs pending approval.
     * @param pageOffset Zero-based page offset.
     * @param networkEntityId Optional NetworkEntity filter.
     * @return Map containing approvals list and totalCount.
     */
    @AuraEnabled(cacheable=true)
    global static Map<String, Object> getPendingApprovals(
        Integer pageOffset,
        Id networkEntityId
    ) {
        pageOffset = sanitizeOffset(pageOffset);
        Set<Id> scopedWorkItemIds = resolveWorkItemScope(networkEntityId, null);

        List<WorkLog__c> logs;
        if (scopedWorkItemIds != null) {
            logs = [
                SELECT Id, CreatedDate, CreatedBy.Name, HoursLoggedNumber__c,
                       WorkDateDate__c, WorkDescriptionTxt__c, WorkItemLookup__c, StatusPk__c
                FROM WorkLog__c
                WHERE StatusPk__c = 'Draft' AND WorkItemLookup__c IN :scopedWorkItemIds
                WITH SYSTEM_MODE
                ORDER BY CreatedDate DESC
                LIMIT 200
            ];
        } else {
            logs = [
                SELECT Id, CreatedDate, CreatedBy.Name, HoursLoggedNumber__c,
                       WorkDateDate__c, WorkDescriptionTxt__c, WorkItemLookup__c, StatusPk__c
                FROM WorkLog__c
                WHERE StatusPk__c = 'Draft'
                WITH SYSTEM_MODE
                ORDER BY CreatedDate DESC
                LIMIT 200
            ];
        }

        Set<Id> wiIds = new Set<Id>();
        for (WorkLog__c wl : logs) {
            wiIds.add(wl.WorkItemLookup__c);
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
        WorkItem__c wi = workItemMap.get(wl.WorkItemLookup__c);
        return new Map<String, Object>{
            'id' => wl.Id,
            'workItemId' => wl.WorkItemLookup__c,
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

    /**
     * @description Batch-approves WorkLogs.
     * @param workLogIds List of WorkLog__c Ids to approve.
     */
    @AuraEnabled
    global static void approveWorkLogs(List<Id> workLogIds) {
        DeliveryTimeLoggerController.approveWorkLogs(workLogIds);
    }

    /**
     * @description Batch-rejects WorkLogs.
     * @param workLogIds List of WorkLog__c Ids to reject.
     */
    @AuraEnabled
    global static void rejectWorkLogs(List<Id> workLogIds) {
        DeliveryTimeLoggerController.rejectWorkLogs(workLogIds);
    }

    // ── Post Comment from Feed ─────────────────────────────────────────

    /**
     * @description Posts a new comment on a work item from the activity feed.
     * @param workItemId The WorkItem__c Id to comment on.
     * @param body The comment text.
     */
    @AuraEnabled
    global static void postCommentFromFeed(Id workItemId, String body) {
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

    // ── Query Methods (static SOQL — no injection risk) ────────────────

    private static List<Map<String, Object>> queryFeedComments(Set<Id> scopedWorkItemIds) {
        List<WorkItemComment__c> records;
        if (scopedWorkItemIds != null) {
            records = [
                SELECT Id, CreatedDate, AuthorTxt__c, BodyTxt__c, SourcePk__c,
                       WorkItemId__c, CreatedBy.Name
                FROM WorkItemComment__c
                WHERE WorkItemId__c IN :scopedWorkItemIds
                WITH SYSTEM_MODE
                ORDER BY CreatedDate DESC
                LIMIT 200
            ];
        } else {
            records = [
                SELECT Id, CreatedDate, AuthorTxt__c, BodyTxt__c, SourcePk__c,
                       WorkItemId__c, CreatedBy.Name
                FROM WorkItemComment__c
                WITH SYSTEM_MODE
                ORDER BY CreatedDate DESC
                LIMIT 200
            ];
        }

        List<Map<String, Object>> results = new List<Map<String, Object>>();
        for (WorkItemComment__c c : records) {
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

    private static List<Map<String, Object>> queryFeedWorkLogs(Set<Id> scopedWorkItemIds) {
        List<WorkLog__c> records;
        if (scopedWorkItemIds != null) {
            records = [
                SELECT Id, CreatedDate, CreatedBy.Name, HoursLoggedNumber__c,
                       WorkDateDate__c, WorkDescriptionTxt__c, WorkItemLookup__c, StatusPk__c
                FROM WorkLog__c
                WHERE WorkItemLookup__c IN :scopedWorkItemIds
                WITH SYSTEM_MODE
                ORDER BY CreatedDate DESC
                LIMIT 200
            ];
        } else {
            records = [
                SELECT Id, CreatedDate, CreatedBy.Name, HoursLoggedNumber__c,
                       WorkDateDate__c, WorkDescriptionTxt__c, WorkItemLookup__c, StatusPk__c
                FROM WorkLog__c
                WITH SYSTEM_MODE
                ORDER BY CreatedDate DESC
                LIMIT 200
            ];
        }

        List<Map<String, Object>> results = new List<Map<String, Object>>();
        for (WorkLog__c wl : records) {
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
            'workItemId' => wl.WorkItemLookup__c,
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

    private static List<Map<String, Object>> queryFeedActivityLogs(Set<Id> scopedWorkItemIds) {
        Set<String> idStrings = toStringSet(scopedWorkItemIds);

        List<ActivityLog__c> logs;
        if (idStrings != null) {
            logs = [
                SELECT Id, CreatedDate, UserIdTxt__c, ActionTypePk__c,
                       ContextDataTxt__c, RecordIdTxt__c
                FROM ActivityLog__c
                WHERE ActionTypePk__c IN ('Stage_Change', 'Field_Change')
                AND RecordIdTxt__c IN :idStrings
                WITH SYSTEM_MODE
                ORDER BY CreatedDate DESC
                LIMIT 200
            ];
        } else {
            logs = [
                SELECT Id, CreatedDate, UserIdTxt__c, ActionTypePk__c,
                       ContextDataTxt__c, RecordIdTxt__c
                FROM ActivityLog__c
                WHERE ActionTypePk__c IN ('Stage_Change', 'Field_Change')
                WITH SYSTEM_MODE
                ORDER BY CreatedDate DESC
                LIMIT 200
            ];
        }

        Map<Id, String> userNameMap = resolveUserNames(logs);

        List<Map<String, Object>> results = new List<Map<String, Object>>();
        for (ActivityLog__c al : logs) {
            Map<String, Object> ev = buildActivityLogEvent(al, userNameMap);
            if (ev != null) {
                results.add(ev);
            }
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
            Id userId = safeToId(al.UserIdTxt__c);
            if (userId != null) {
                userIds.add(userId);
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
        if (al.ActionTypePk__c == 'Field_Change' && shouldSuppressFieldChange(al.ContextDataTxt__c)) {
            return null;
        }
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
        } catch (StringException ex) {
            System.debug(LoggingLevel.FINE, 'Invalid Id string: ' + idString);
            return null;
        }
    }

    /**
     * Returns true when a Field_Change ActivityLog event should NOT render in
     * the Activity Feed. Two suppression rules:
     *   1. Field is in SUPPRESSED_FIELD_API_NAMES (description-only edits etc.)
     *   2. oldValue == newValue (no-op saves; e.g. trigger logic re-flipping
     *      Status to its existing value, or rollup recalcs landing on the
     *      same number).
     * Falls open on parse error so the parseChangeContext fallback path stays
     * the single source of truth for malformed JSON.
     */
    private static Boolean shouldSuppressFieldChange(String contextDataJson) {
        if (String.isBlank(contextDataJson)) {
            return false;
        }
        try {
            Map<String, Object> ctx = (Map<String, Object>) JSON.deserializeUntyped(contextDataJson);
            String fieldName = ctx.get('fieldName') == null
                ? ''
                : stripFieldNamespace(String.valueOf(ctx.get('fieldName'))).toLowerCase();
            if (SUPPRESSED_FIELD_API_NAMES.contains(fieldName)) {
                return true;
            }
            Object oldVal = ctx.get('oldValue');
            Object newVal = ctx.get('newValue');
            if (oldVal == null && newVal == null) {
                return true;
            }
            if (oldVal != null && newVal != null
                && String.valueOf(oldVal) == String.valueOf(newVal)) {
                return true;
            }
            return false;
        } catch (JSONException ex) {
            return false;
        }
    }

    private static String stripFieldNamespace(String apiName) {
        if (String.isNotBlank(apiName) && apiName.countMatches('__') > 1) {
            return apiName.substringAfter('__');
        }
        return apiName;
    }

    private static Map<String, String> parseChangeContext(String contextDataJson, String actionType) {
        Map<String, String> info = new Map<String, String>{
            'title' => actionType == 'Stage_Change' ? 'Stage changed' : 'Field changed',
            'detail' => ''
        };
        if (String.isBlank(contextDataJson)) {
            // No JSON to parse \u2014 surface a fallback detail so the row doesn't
            // render with just a bare label. Diagnosable from the feed itself.
            info.put('detail', '(no change context recorded)');
            return info;
        }
        try {
            Map<String, Object> ctx = (Map<String, Object>) JSON.deserializeUntyped(contextDataJson);
            if (actionType == 'Stage_Change') {
                parseStageChange(ctx, info);
            } else {
                parseFieldChange(ctx, info);
            }
        } catch (JSONException ex) {
            // Don't swallow silently \u2014 surface for the health dashboard /
            // anyone tailing debug logs, and fall back to a non-empty detail
            // so the user-facing row still carries SOME signal.
            System.debug(LoggingLevel.WARN,
                'Activity Feed: malformed context JSON for ' + actionType + ': ' + ex.getMessage());
            info.put('detail', '(change context unparseable)');
        }
        return info;
    }

    private static void parseStageChange(Map<String, Object> ctx, Map<String, String> info) {
        String newStage = (String) ctx.get('newStage');
        String oldStage = (String) ctx.get('oldStage');
        if (String.isNotBlank(newStage)) {
            info.put('title', 'Stage changed to ' + newStage);
        }
        // Always render a from\u2192to detail even when one side is blank \u2014 empty
        // sides become '(none)' so users see WHAT changed instead of a bare
        // "Stage changed" with no context. Initial-stage assignments where
        // oldStage was never set now read as "(none) \u2192 Backlog".
        info.put(
            'detail',
            displayValue(oldStage) + ' \u2192 ' + displayValue(newStage)
        );
    }

    private static void parseFieldChange(Map<String, Object> ctx, Map<String, String> info) {
        String fieldLabel = (String) ctx.get('fieldLabel');
        // ctx.get returns Apex null when the key is missing OR when the JSON
        // value is null. String.valueOf(null) would return the literal "null"
        // string \u2014 defended against here so we render "(empty)" not "null".
        String oldValue = ctx.get('oldValue') == null ? null : String.valueOf(ctx.get('oldValue'));
        String newValue = ctx.get('newValue') == null ? null : String.valueOf(ctx.get('newValue'));
        if (String.isNotBlank(fieldLabel)) {
            info.put('title', fieldLabel + ' changed');
        }
        info.put('detail', displayValue(oldValue) + ' \u2192 ' + displayValue(newValue));
    }

    /**
     * Render a value for the activity-feed detail line. Null / blank become
     * '(empty)' so users see signal instead of a bare arrow or the literal
     * Apex String.valueOf(null) output of "null".
     */
    private static String displayValue(String v) {
        return String.isBlank(v) ? '(empty)' : v;
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
                WHERE ClientNetworkEntityLookup__c = :networkEntityId
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
        /**
         * @description Compares two event maps by timestamp descending (newest first).
         * @param a First event map.
         * @param b Second event map.
         * @return Negative if a is newer, positive if b is newer, zero if equal.
         */
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

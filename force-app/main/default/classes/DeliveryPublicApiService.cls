/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Public REST API for non-Salesforce clients (websites, apps, other platforms).
 * Authenticates via X-Api-Key header matched against NetworkEntity__c.ApiKeyTxt__c,
 * then delegates to DeliveryPortalController for entity-scoped data access.
 * URL Pattern: /services/apexrest/delivery/deliveryhub/v1/api/{resource}
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.ApexCRUDViolation, PMD.CyclomaticComplexity')
@RestResource(urlMapping='/deliveryhub/v1/api/*')
global without sharing class DeliveryPublicApiService {

    /** @description Handles all GET requests. Routes by resource path after authentication. */
    @HttpGet
    global static void handleGet() {
        try {
            NetworkEntity__c entity = authenticateRequest();
            if (entity == null) { return; }

            // Rate limiting (opt-in — only active when PublicApiRateLimitNumber__c is set)
            DeliveryHubSettings__c rlSettings = DeliveryHubSettings__c.getOrgDefaults();
            if (rlSettings != null && rlSettings.PublicApiRateLimitNumber__c != null) {
                Integer publicApiLimit = (Integer) rlSettings.PublicApiRateLimitNumber__c;
                if (DeliveryRateLimitService.isRateLimited(entity.Id, 'PublicAPI', publicApiLimit, 1)) {
                    RestContext.response.statusCode = 429;
                    RestContext.response.addHeader('Retry-After', '3600');
                    RestContext.response.responseBody = Blob.valueOf('{"error":"Rate limit exceeded"}');
                    return;
                }
                DeliveryRateLimitService.recordRequest(entity.Id, 'PublicAPI');
            }

            String resource = extractResource(RestContext.request.requestURI);
            if (handlePreEntityRoutes(resource)) { return; }
            Id entityId = resolveEffectiveEntity(entity.Id);
            if (entityId == null) { return; }
            routeGet(resource, entityId);
        } catch (AuraHandledException e) {
            sendError(400, e.getMessage());
        } catch (Exception e) {
            sendError(500, e.getMessage());
        }
    }

    /** @description Handles all POST requests. Routes by resource path after authentication. */
    @HttpPost
    global static void handlePost() {
        try {
            NetworkEntity__c entity = authenticateRequest();
            if (entity == null) { return; }

            // Rate limiting (opt-in — only active when PublicApiRateLimitNumber__c is set)
            DeliveryHubSettings__c rlSettings2 = DeliveryHubSettings__c.getOrgDefaults();
            if (rlSettings2 != null && rlSettings2.PublicApiRateLimitNumber__c != null) {
                Integer publicApiLimit = (Integer) rlSettings2.PublicApiRateLimitNumber__c;
                if (DeliveryRateLimitService.isRateLimited(entity.Id, 'PublicAPI', publicApiLimit, 1)) {
                    RestContext.response.statusCode = 429;
                    RestContext.response.addHeader('Retry-After', '3600');
                    RestContext.response.responseBody = Blob.valueOf('{"error":"Rate limit exceeded"}');
                    return;
                }
                DeliveryRateLimitService.recordRequest(entity.Id, 'PublicAPI');
            }

            Id entityId = resolveEffectiveEntity(entity.Id);
            if (entityId == null) { return; }
            String resource = extractResource(RestContext.request.requestURI);
            String jsonBody = RestContext.request.requestBody != null ? RestContext.request.requestBody.toString() : '';
            if (String.isBlank(jsonBody)) { sendError(400, 'Request body is required.'); return; }
            routePost(resource, jsonBody, entityId);
        } catch (AuraHandledException e) {
            sendError(400, e.getMessage());
        } catch (Exception e) {
            sendError(500, e.getMessage());
        }
    }

    // ── GET Routing ────────────────────────────────────────────────────

    private static Boolean handlePreEntityRoutes(String resource) {
        if (resource == 'my-entities') {
            String email = getPortalEmail();
            if (String.isBlank(email)) { sendError(400, 'X-Portal-User header is required.'); return true; }
            sendSuccess(DeliveryPortalAccessService.getEntitiesForEmail(email));
            return true;
        }
        if (resource == 'portal-users') {
            String email = getPortalEmail();
            if (String.isBlank(email)) { sendError(400, 'X-Portal-User header is required.'); return true; }
            sendSuccess(DeliveryPortalAccessService.getPortalUsersByEntity(email));
            return true;
        }
        return false;
    }

    private static void routeGet(String resource, Id entityId) {
        if (routeGetCore(resource, entityId)) { return; }
        if (routeGetExtended(resource, entityId)) { return; }
        sendError(404, 'Unknown resource: ' + resource);
    }

    private static Boolean routeGetCore(String resource, Id entityId) {
        if (resource == 'dashboard') { sendSuccess(DeliveryPortalController.getPortalDashboard(entityId)); return true; }
        if (resource == 'work-items') { getWorkItems(entityId); return true; }
        if (resource.startsWith('work-items/')) { getWorkItemDetail(resource, entityId); return true; }
        if (resource == 'activity-feed') { getActivityFeed(entityId); return true; }
        if (resource == 'conversations') { getConversations(entityId); return true; }
        return false;
    }

    private static Boolean routeGetExtended(String resource, Id entityId) {
        if (resource == 'pending-approvals') { getPendingApprovals(entityId); return true; }
        if (resource == 'work-logs') { getWorkLogs(entityId); return true; }
        if (resource == 'files') { getFiles(entityId); return true; }
        if (resource == 'board-summary') { getBoardSummary(); return true; }
        if (resource == 'documents') { sendSuccess(DeliveryDocumentController.getDocumentsForEntity(entityId)); return true; }
        if (resource.startsWith('documents/')) { getDocumentByToken(resource); return true; }
        return false;
    }

    private static void getDocumentByToken(String resource) {
        String token = resource.substringAfter('documents/');
        sendSuccess(DeliveryDocumentController.getDocumentByToken(token));
    }

    private static void getWorkItems(Id entityId) {
        sendSuccess(DeliveryPortalController.getPortalWorkItems(entityId, RestContext.request.params.get('status')));
    }

    private static void getWorkItemDetail(String resource, Id entityId) {
        String workItemId = resource.substringAfter('work-items/');
        try {
            sendSuccess(DeliveryPortalController.getPortalWorkItemDetail(workItemId, entityId));
        } catch (Exception e) {
            sendError(403, 'Access denied.');
        }
    }

    private static void getActivityFeed(Id entityId) {
        String filterType = RestContext.request.params.get('filterType');
        if (String.isBlank(filterType)) { filterType = 'all'; }
        sendSuccess(DeliveryActivityFeedController.getActivityFeed(
            filterType, getPageOffset(), entityId, null, null, null
        ));
    }

    private static void getConversations(Id entityId) {
        sendSuccess(DeliveryActivityFeedController.getConversations(getPageOffset(), entityId));
    }

    private static void getPendingApprovals(Id entityId) {
        sendSuccess(DeliveryActivityFeedController.getPendingApprovals(getPageOffset(), entityId));
    }

    private static void getWorkLogs(Id entityId) {
        String workItemIdParam = RestContext.request.params.get('workItemId');
        List<WorkLog__c> logs;
        if (String.isNotBlank(workItemIdParam)) {
            Id wiId = Id.valueOf(workItemIdParam);
            logs = [
                SELECT Id, WorkItemLookup__c, WorkItemLookup__r.Name, WorkItemLookup__r.BriefDescriptionTxt__c,
                       HoursLoggedNumber__c, WorkDateDate__c, WorkDescriptionTxt__c,
                       StatusPk__c, CreatedDate, CreatedBy.Name
                FROM WorkLog__c
                WHERE WorkItemLookup__c = :wiId AND WorkItemLookup__r.ClientNetworkEntityLookup__c = :entityId
                WITH SYSTEM_MODE ORDER BY WorkDateDate__c DESC, CreatedDate DESC LIMIT 200
            ];
        } else {
            logs = [
                SELECT Id, WorkItemLookup__c, WorkItemLookup__r.Name, WorkItemLookup__r.BriefDescriptionTxt__c,
                       HoursLoggedNumber__c, WorkDateDate__c, WorkDescriptionTxt__c,
                       StatusPk__c, CreatedDate, CreatedBy.Name
                FROM WorkLog__c
                WHERE WorkItemLookup__r.ClientNetworkEntityLookup__c = :entityId
                WITH SYSTEM_MODE ORDER BY CreatedDate DESC LIMIT 200
            ];
        }
        List<Map<String, Object>> result = new List<Map<String, Object>>();
        for (WorkLog__c wl : logs) {
            result.add(buildWorkLogMap(wl));
        }
        sendSuccess(result);
    }

    private static Map<String, Object> buildWorkLogMap(WorkLog__c wl) {
        return new Map<String, Object>{
            'id' => wl.Id, 'workItemId' => wl.WorkItemLookup__c,
            'workItemName' => wl.WorkItemLookup__r.Name,
            'workItemTitle' => wl.WorkItemLookup__r.BriefDescriptionTxt__c,
            'hours' => wl.HoursLoggedNumber__c, 'workDate' => wl.WorkDateDate__c,
            'description' => wl.WorkDescriptionTxt__c, 'status' => wl.StatusPk__c,
            'userName' => wl.CreatedBy.Name, 'createdDate' => wl.CreatedDate
        };
    }

    private static void getFiles(Id entityId) {
        String workItemIdParam = RestContext.request.params.get('workItemId');
        Set<Id> workItemIds = resolveWorkItemIds(entityId, workItemIdParam);
        List<ContentDocumentLink> links = [
            SELECT ContentDocument.Title, ContentDocument.FileExtension,
                   ContentDocument.ContentSize, ContentDocument.CreatedDate,
                   ContentDocument.LatestPublishedVersionId, LinkedEntityId
            FROM ContentDocumentLink WHERE LinkedEntityId IN :workItemIds
            WITH SYSTEM_MODE ORDER BY ContentDocument.CreatedDate DESC LIMIT 500
        ];
        List<Map<String, Object>> files = new List<Map<String, Object>>();
        for (ContentDocumentLink cdl : links) {
            files.add(new Map<String, Object>{
                'id' => cdl.ContentDocument.LatestPublishedVersionId,
                'name' => cdl.ContentDocument.Title,
                'extension' => cdl.ContentDocument.FileExtension,
                'size' => cdl.ContentDocument.ContentSize,
                'createdDate' => cdl.ContentDocument.CreatedDate,
                'workItemId' => cdl.LinkedEntityId
            });
        }
        sendSuccess(files);
    }

    private static Set<Id> resolveWorkItemIds(Id entityId, String workItemIdParam) {
        Set<Id> ids = new Set<Id>();
        List<WorkItem__c> items;
        if (String.isNotBlank(workItemIdParam)) {
            items = [SELECT Id FROM WorkItem__c WHERE Id = :workItemIdParam AND ClientNetworkEntityLookup__c = :entityId WITH SYSTEM_MODE];
        } else {
            items = [SELECT Id FROM WorkItem__c WHERE ClientNetworkEntityLookup__c = :entityId WITH SYSTEM_MODE LIMIT 500];
        }
        for (WorkItem__c wi : items) { ids.add(wi.Id); }
        return ids;
    }

    private static void getBoardSummary() {
        // Use the REST-safe variant — draftBoardSummary() throws AuraHandledException
        // on validation failure, which raises an UNCATCHABLE LimitException when
        // called outside an Aura/VF context (this is a REST endpoint).
        try {
            sendSuccess(new Map<String, Object>{ 'summary' => DeliveryAiController.draftBoardSummaryForRest() });
        } catch (DeliveryHubException e) {
            // Expected: AI not configured, no work items, OpenAI down, etc.
            // Degrade gracefully — the client treats `summary: null` as "no summary available".
            sendSuccess(new Map<String, Object>{ 'summary' => null, 'reason' => e.getMessage() });
        } catch (Exception e) {
            // Unexpected: log + degrade. Don't leak the raw message to the client.
            System.debug(LoggingLevel.WARN, 'getBoardSummary failed: ' + e.getMessage() + '\n' + e.getStackTraceString());
            sendSuccess(new Map<String, Object>{ 'summary' => null });
        }
    }

    // ── POST Routing ───────────────────────────────────────────────────

    private static void routePost(String resource, String jsonBody, Id entityId) {
        if (resource == 'work-items') { postWorkItem(jsonBody, entityId); }
        else if (resource.contains('/comments')) { postComment(resource, jsonBody, entityId); }
        else if (resource == 'approve-worklogs') { approveReject(jsonBody, true); }
        else if (resource == 'reject-worklogs') { approveReject(jsonBody, false); }
        else if (resource == 'log-hours') { postLogHours(jsonBody, entityId); }
        else if (resource == 'document-approve') { postDocumentApprove(jsonBody); }
        else if (resource == 'document-dispute') { postDocumentDispute(jsonBody); }
        else { sendError(404, 'Unknown resource: ' + resource); }
    }

    private static void postWorkItem(String jsonBody, Id entityId) {
        Map<String, Object> bodyMap = (Map<String, Object>) JSON.deserializeUntyped(jsonBody);
        String title = (String) bodyMap.get('title');
        String description = (String) bodyMap.get('description');

        // v0.99 defense-in-depth: reject blank-payload creates at the API edge.
        // Background: the cloudnimbus Slack approval handler at one point
        // POSTed empty suggestedWorkRequest objects and dh-prod accepted them,
        // creating 40 blank WorkItem rows. The downstream submitPortalRequest
        // checks title alone — this check mirrors its contract but surfaces
        // a clean HTTP 400 (rather than AuraHandledException 400) and makes
        // the rule explicit at the REST boundary.
        if (String.isBlank(title) && String.isBlank(description)) {
            sendError(400,
                'Work item must include at least a title or description. '
                + 'Blank payloads are rejected at the ingestor to prevent '
                + 'automation from creating empty records.');
            return;
        }

        Map<String, String> data = new Map<String, String>();
        data.put('title', title);
        data.put('description', description);
        data.put('priority', (String) bodyMap.get('priority'));
        data.put('type', (String) bodyMap.get('type'));
        data.put('networkEntityId', entityId);
        Id newId = DeliveryPortalController.submitPortalRequest(data);
        sendSuccess(new Map<String, Object>{ 'id' => newId, 'status' => 'Created' }, 201);
    }

    private static void postComment(String resource, String jsonBody, Id entityId) {
        String workItemId = resource.substringBetween('work-items/', '/comments');
        if (String.isBlank(workItemId)) { sendError(400, 'Work item ID required.'); return; }
        try {
            DeliveryPortalController.getPortalWorkItemDetail(workItemId, entityId);
        } catch (Exception e) {
            sendError(403, 'Access denied.'); return;
        }
        Map<String, Object> bodyMap = (Map<String, Object>) JSON.deserializeUntyped(jsonBody);
        Id commentId = DeliveryPortalController.addPortalComment(workItemId, (String) bodyMap.get('body'));
        sendSuccess(new Map<String, Object>{ 'id' => commentId, 'status' => 'Created' }, 201);
    }

    private static void approveReject(String jsonBody, Boolean approve) {
        Map<String, Object> bodyMap = (Map<String, Object>) JSON.deserializeUntyped(jsonBody);
        List<Object> rawIds = (List<Object>) bodyMap.get('workLogIds');
        List<Id> ids = new List<Id>();
        if (rawIds != null) { for (Object r : rawIds) { ids.add(Id.valueOf((String) r)); } }
        if (approve) { DeliveryActivityFeedController.approveWorkLogs(ids); }
        else { DeliveryActivityFeedController.rejectWorkLogs(ids); }
        sendSuccess(new Map<String, Object>{ 'status' => approve ? 'Approved' : 'Rejected', 'count' => ids.size() });
    }

    private static void postLogHours(String jsonBody, Id entityId) {
        Map<String, Object> b = (Map<String, Object>) JSON.deserializeUntyped(jsonBody);
        String workItemId = (String) b.get('workItemId');
        Decimal hours = b.get('hours') != null ? (Decimal) b.get('hours') : null;
        if (String.isBlank(workItemId) || hours == null || hours <= 0) {
            sendError(400, 'workItemId and positive hours required.'); return;
        }
        List<WorkItem__c> items = [
            SELECT Id, Name, BriefDescriptionTxt__c FROM WorkItem__c
            WHERE Id = :workItemId AND ClientNetworkEntityLookup__c = :entityId
            WITH SYSTEM_MODE LIMIT 1
        ];
        if (items.isEmpty()) { sendError(403, 'Work item not found or access denied.'); return; }
        String dateStr = (String) b.get('workDate');
        Date workDate = String.isNotBlank(dateStr) ? Date.valueOf(dateStr) : null;
        String description = (String) b.get('workNotes');
        DeliveryTimeLoggerController.logHours(Id.valueOf(workItemId), hours, description, workDate);
        logPortalActivity(items[0], hours, description);
        sendSuccess(new Map<String, Object>{ 'status' => 'Logged', 'hours' => hours }, 201);
    }

    private static void logPortalActivity(WorkItem__c item, Decimal hours, String description) {
        try {
            String portalUser = getPortalEmail();
            ActivityLog__c log = new ActivityLog__c();
            log.ActionTypePk__c = 'Portal_Hours_Logged';
            log.RecordIdTxt__c = item.Id;
            log.ComponentNameTxt__c = 'PortalTimeEntry';
            log.ContextDataTxt__c = JSON.serialize(new Map<String, Object>{
                'workItemId' => item.Id, 'workItemName' => item.Name,
                'hours' => hours, 'portalUser' => portalUser,
                'description' => description
            });
            log.UserIdTxt__c = UserInfo.getUserId();
            Database.insert(log, AccessLevel.SYSTEM_MODE);
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'Portal activity log failed: ' + e.getMessage());
        }
    }

    private static void postDocumentApprove(String jsonBody) {
        Map<String, Object> bodyMap = (Map<String, Object>) JSON.deserializeUntyped(jsonBody);
        String token = (String) bodyMap.get('token');
        if (String.isBlank(token)) { sendError(400, 'token is required.'); return; }
        sendSuccess(DeliveryDocumentController.approveDocumentByToken(token));
    }

    private static void postDocumentDispute(String jsonBody) {
        Map<String, Object> bodyMap = (Map<String, Object>) JSON.deserializeUntyped(jsonBody);
        String token = (String) bodyMap.get('token');
        String reason = (String) bodyMap.get('reason');
        if (String.isBlank(token)) { sendError(400, 'token is required.'); return; }
        sendSuccess(DeliveryDocumentController.disputeDocumentByToken(token, reason));
    }

    // ── Auth + Resolution ──────────────────────────────────────────────

    private static NetworkEntity__c authenticateRequest() {
        String apiKey = RestContext.request.headers.get('X-Api-Key');
        if (String.isBlank(apiKey)) { sendError(401, 'Missing X-Api-Key header.'); return null; }
        List<NetworkEntity__c> entities = [
            SELECT Id, Name, EntityTypePk__c, ConnectionStatusPk__c
            FROM NetworkEntity__c WHERE ApiKeyTxt__c = :apiKey AND ConnectionStatusPk__c = 'Connected'
            WITH SYSTEM_MODE LIMIT 1
        ];
        if (entities.isEmpty()) { sendError(401, 'Invalid API key or entity not connected.'); return null; }
        return entities[0];
    }

    private static Id resolveEffectiveEntity(Id authenticatedEntityId) {
        String portalEmail = getPortalEmail();
        String entityIdParam = RestContext.request.params.get('entityId');
        if (String.isNotBlank(portalEmail) && String.isNotBlank(entityIdParam)) {
            Id requestedId;
            try { requestedId = Id.valueOf(entityIdParam); }
            catch (Exception e) { sendError(400, 'Invalid entityId.'); return null; }
            if (!DeliveryPortalAccessService.validateAccess(portalEmail, requestedId)) {
                sendError(403, 'Portal user does not have access.'); return null;
            }
            return requestedId;
        }
        return authenticatedEntityId;
    }

    // ── Helpers ─────────────────────────────────────────────────────────

    private static String getPortalEmail() {
        return RestContext.request.headers.get('X-Portal-User');
    }

    private static Integer getPageOffset() {
        String p = RestContext.request.params.get('pageOffset');
        if (String.isNotBlank(p)) { try { return Integer.valueOf(p); } catch (Exception e) { return 0; } }
        return 0;
    }

    private static String extractResource(String uri) {
        String marker = '/api/';
        Integer idx = uri.indexOf(marker);
        return idx == -1 ? '' : uri.substring(idx + marker.length());
    }

    private static void sendSuccess(Object data) { sendSuccess(data, 200); }

    private static void sendSuccess(Object data, Integer code) {
        RestContext.response.statusCode = code;
        RestContext.response.addHeader('Content-Type', 'application/json');
        RestContext.response.responseBody = Blob.valueOf(JSON.serialize(new Map<String, Object>{ 'success' => true, 'data' => data }));
    }

    private static void sendError(Integer code, String message) {
        RestContext.response.statusCode = code;
        RestContext.response.addHeader('Content-Type', 'application/json');
        RestContext.response.responseBody = Blob.valueOf(JSON.serialize(new Map<String, Object>{ 'success' => false, 'error' => message }));
    }

    /**
     * @description Generates a cryptographically random API key.
     * @return 64-character hex string
     */
    public static String generateApiKey() {
        return EncodingUtil.convertToHex(Crypto.generateAesKey(256));
    }
}

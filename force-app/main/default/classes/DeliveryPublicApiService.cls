/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Public REST API for non-Salesforce clients (websites, apps, other platforms).
 * Authenticates via X-Api-Key header matched against NetworkEntity__c.ApiKeyTxt__c,
 * then delegates to DeliveryPortalController for entity-scoped data access.
 * URL Pattern: /services/apexrest/delivery/deliveryhub/v1/api/{resource}
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.StdCyclomaticComplexity, PMD.CyclomaticComplexity')
@RestResource(urlMapping='/deliveryhub/v1/api/*')
global without sharing class DeliveryPublicApiService {

    /**
     * @description Handles GET requests for reading data.
     * Routes: /api/dashboard, /api/work-items, /api/work-items/{id}, /api/my-entities,
     *         /api/activity-feed, /api/conversations, /api/pending-approvals
     */
    @HttpGet
    global static void handleGet() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;

        try {
            NetworkEntity__c entity = authenticateRequest(req, res);
            if (entity == null) {
                return; // Response already set by authenticateRequest
            }

            String resource = extractResource(req.requestURI);

            // Portal user entity switching: my-entities route
            if (resource == 'my-entities') {
                String portalEmail = req.headers.get('X-Portal-User');
                if (String.isBlank(portalEmail)) {
                    sendError(res, 400, 'X-Portal-User header is required for my-entities.');
                    return;
                }
                List<Map<String, Object>> entities = DeliveryPortalAccessService.getEntitiesForEmail(portalEmail);
                sendSuccess(res, entities);
                return;
            }

            // Admin route: list all portal users grouped by entity
            if (resource == 'portal-users') {
                String portalEmail = req.headers.get('X-Portal-User');
                if (String.isBlank(portalEmail)) {
                    sendError(res, 400, 'X-Portal-User header is required for portal-users.');
                    return;
                }
                List<Map<String, Object>> usersByEntity = DeliveryPortalAccessService.getPortalUsersByEntity(portalEmail);
                sendSuccess(res, usersByEntity);
                return;
            }

            // Resolve the effective entity: portal user override or authenticated entity
            Id effectiveEntityId = resolveEffectiveEntity(req, res, entity.Id);
            if (effectiveEntityId == null) {
                return; // Response already set (403)
            }

            if (resource == 'dashboard') {
                Map<String, Object> dashboard = DeliveryPortalController.getPortalDashboard(effectiveEntityId);
                sendSuccess(res, dashboard);

            } else if (resource == 'work-items') {
                String statusFilter = req.params.get('status');
                List<Map<String, Object>> items = DeliveryPortalController.getPortalWorkItems(effectiveEntityId, statusFilter);
                sendSuccess(res, items);

            } else if (resource.startsWith('work-items/')) {
                String workItemId = resource.substringAfter('work-items/');
                try {
                    Map<String, Object> detail = DeliveryPortalController.getPortalWorkItemDetail(workItemId, effectiveEntityId);
                    sendSuccess(res, detail);
                } catch (Exception e) {
                    sendError(res, 403, 'Access denied. This work item does not belong to your entity.');
                    return;
                }

            } else if (resource == 'activity-feed') {
                String filterType = req.params.get('filterType');
                if (String.isBlank(filterType)) {
                    filterType = 'all';
                }
                Integer pageOffset = 0;
                if (String.isNotBlank(req.params.get('pageOffset'))) {
                    pageOffset = Integer.valueOf(req.params.get('pageOffset'));
                }
                Map<String, Object> feed = DeliveryActivityFeedController.getActivityFeed(
                    filterType, pageOffset, effectiveEntityId, null, null, null
                );
                sendSuccess(res, feed);

            } else if (resource == 'conversations') {
                Integer pageOffset = 0;
                if (String.isNotBlank(req.params.get('pageOffset'))) {
                    pageOffset = Integer.valueOf(req.params.get('pageOffset'));
                }
                List<Map<String, Object>> conversations = DeliveryActivityFeedController.getConversations(
                    pageOffset, effectiveEntityId
                );
                sendSuccess(res, conversations);

            } else if (resource == 'pending-approvals') {
                Integer pageOffset = 0;
                if (String.isNotBlank(req.params.get('pageOffset'))) {
                    pageOffset = Integer.valueOf(req.params.get('pageOffset'));
                }
                Map<String, Object> approvals = DeliveryActivityFeedController.getPendingApprovals(
                    pageOffset, effectiveEntityId
                );
                sendSuccess(res, approvals);

            } else if (resource == 'work-logs') {
                List<WorkLog__c> logs = [
                    SELECT Id, WorkItemId__c, WorkItemId__r.Name, WorkItemId__r.BriefDescriptionTxt__c,
                           HoursLoggedNumber__c, WorkDateDate__c, WorkDescriptionTxt__c,
                           StatusPk__c, CreatedDate, CreatedBy.Name
                    FROM WorkLog__c
                    WHERE WorkItemId__r.ClientNetworkEntityId__c = :effectiveEntityId
                    WITH SYSTEM_MODE
                    ORDER BY CreatedDate DESC
                    LIMIT 200
                ];
                List<Map<String, Object>> result = new List<Map<String, Object>>();
                for (WorkLog__c wl : logs) {
                    result.add(new Map<String, Object>{
                        'id' => wl.Id,
                        'workItemId' => wl.WorkItemId__c,
                        'workItemName' => wl.WorkItemId__r.Name,
                        'workItemTitle' => wl.WorkItemId__r.BriefDescriptionTxt__c,
                        'hours' => wl.HoursLoggedNumber__c,
                        'workDate' => wl.WorkDateDate__c,
                        'description' => wl.WorkDescriptionTxt__c,
                        'status' => wl.StatusPk__c,
                        'userName' => wl.CreatedBy.Name,
                        'createdDate' => wl.CreatedDate
                    });
                }
                sendSuccess(res, result);

            } else if (resource == 'files') {
                String workItemIdParam = req.params.get('workItemId');
                List<WorkItem__c> scopedItems;
                if (String.isNotBlank(workItemIdParam)) {
                    scopedItems = [SELECT Id FROM WorkItem__c WHERE Id = :workItemIdParam AND ClientNetworkEntityId__c = :effectiveEntityId WITH SYSTEM_MODE];
                } else {
                    scopedItems = [SELECT Id FROM WorkItem__c WHERE ClientNetworkEntityId__c = :effectiveEntityId WITH SYSTEM_MODE LIMIT 500];
                }
                Set<Id> workItemIds = new Set<Id>();
                for (WorkItem__c wi : scopedItems) {
                    workItemIds.add(wi.Id);
                }
                List<ContentDocumentLink> links = [
                    SELECT ContentDocument.Title, ContentDocument.FileExtension,
                           ContentDocument.ContentSize, ContentDocument.CreatedDate,
                           ContentDocument.LatestPublishedVersionId,
                           LinkedEntityId
                    FROM ContentDocumentLink
                    WHERE LinkedEntityId IN :workItemIds
                    WITH SYSTEM_MODE
                    ORDER BY ContentDocument.CreatedDate DESC
                    LIMIT 500
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
                sendSuccess(res, files);

            } else if (resource == 'board-summary') {
                try {
                    String summary = DeliveryAiController.draftBoardSummary();
                    sendSuccess(res, new Map<String, Object>{ 'summary' => summary });
                } catch (Exception e) {
                    sendSuccess(res, new Map<String, Object>{ 'summary' => null });
                }

            } else if (resource == 'documents') {
                List<Map<String, Object>> docs = DeliveryDocumentController.getDocumentsForEntity(effectiveEntityId);
                sendSuccess(res, docs);

            } else {
                sendError(res, 404, 'Unknown resource: ' + resource + '. Available: dashboard, work-items, work-items/{id}, my-entities, portal-users, activity-feed, conversations, pending-approvals, work-logs, files, board-summary, documents');
            }

        } catch (AuraHandledException e) {
            sendError(res, 400, e.getMessage());
        } catch (Exception e) {
            sendError(res, 500, e.getMessage());
        }
    }

    /**
     * @description Handles POST requests for creating data.
     * Routes: /api/work-items (submit request), /api/work-items/{id}/comments (add comment),
     *         /api/approve-worklogs, /api/reject-worklogs
     */
    @SuppressWarnings('PMD.CyclomaticComplexity, PMD.StdCyclomaticComplexity')
    @HttpPost
    global static void handlePost() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;

        try {
            NetworkEntity__c entity = authenticateRequest(req, res);
            if (entity == null) {
                return;
            }

            // Resolve the effective entity: portal user override or authenticated entity
            Id effectiveEntityId = resolveEffectiveEntity(req, res, entity.Id);
            if (effectiveEntityId == null) {
                return; // Response already set (403)
            }

            String resource = extractResource(req.requestURI);
            String jsonBody = req.requestBody != null ? req.requestBody.toString() : '';

            if (String.isBlank(jsonBody)) {
                sendError(res, 400, 'Request body is required.');
                return;
            }

            if (resource == 'work-items') {
                Map<String, Object> bodyMap = (Map<String, Object>) JSON.deserializeUntyped(jsonBody);

                Map<String, String> requestData = new Map<String, String>();
                requestData.put('title', (String) bodyMap.get('title'));
                requestData.put('description', (String) bodyMap.get('description'));
                requestData.put('priority', (String) bodyMap.get('priority'));
                requestData.put('type', (String) bodyMap.get('type'));
                requestData.put('networkEntityId', effectiveEntityId);

                Id newItemId = DeliveryPortalController.submitPortalRequest(requestData);
                sendSuccess(res, new Map<String, Object>{
                    'id' => newItemId,
                    'status' => 'Created'
                }, 201);

            } else if (resource.contains('/comments')) {
                // Pattern: work-items/{id}/comments
                String workItemId = resource.substringBetween('work-items/', '/comments');

                if (String.isBlank(workItemId)) {
                    sendError(res, 400, 'Work item ID is required in URL path.');
                    return;
                }

                // Verify work item belongs to this entity before allowing comment
                try {
                    DeliveryPortalController.getPortalWorkItemDetail(workItemId, effectiveEntityId);
                } catch (Exception e) {
                    sendError(res, 403, 'Access denied. This work item does not belong to your entity.');
                    return;
                }

                Map<String, Object> bodyMap = (Map<String, Object>) JSON.deserializeUntyped(jsonBody);
                String commentBody = (String) bodyMap.get('body');

                Id commentId = DeliveryPortalController.addPortalComment(workItemId, commentBody);
                sendSuccess(res, new Map<String, Object>{
                    'id' => commentId,
                    'status' => 'Created'
                }, 201);

            } else if (resource == 'approve-worklogs') {
                Map<String, Object> bodyMap = (Map<String, Object>) JSON.deserializeUntyped(jsonBody);
                List<Object> rawIds = (List<Object>) bodyMap.get('workLogIds');
                List<Id> workLogIds = new List<Id>();
                if (rawIds != null) {
                    for (Object rawId : rawIds) {
                        workLogIds.add(Id.valueOf((String) rawId));
                    }
                }
                DeliveryActivityFeedController.approveWorkLogs(workLogIds);
                sendSuccess(res, new Map<String, Object>{
                    'status' => 'Approved',
                    'count' => workLogIds.size()
                });

            } else if (resource == 'reject-worklogs') {
                Map<String, Object> bodyMap = (Map<String, Object>) JSON.deserializeUntyped(jsonBody);
                List<Object> rawIds = (List<Object>) bodyMap.get('workLogIds');
                List<Id> workLogIds = new List<Id>();
                if (rawIds != null) {
                    for (Object rawId : rawIds) {
                        workLogIds.add(Id.valueOf((String) rawId));
                    }
                }
                DeliveryActivityFeedController.rejectWorkLogs(workLogIds);
                sendSuccess(res, new Map<String, Object>{
                    'status' => 'Rejected',
                    'count' => workLogIds.size()
                });

            } else if (resource == 'log-hours') {
                Map<String, Object> bodyMap = (Map<String, Object>) JSON.deserializeUntyped(jsonBody);
                String workItemId = (String) bodyMap.get('workItemId');
                Decimal hours = bodyMap.get('hours') != null ? (Decimal) bodyMap.get('hours') : null;
                String workNotes = (String) bodyMap.get('workNotes');
                String workDateStr = (String) bodyMap.get('workDate');
                Date workDate = String.isNotBlank(workDateStr) ? Date.valueOf(workDateStr) : null;

                if (String.isBlank(workItemId) || hours == null || hours <= 0) {
                    sendError(res, 400, 'workItemId and positive hours are required.');
                    return;
                }

                DeliveryTimeLoggerController.logHours(Id.valueOf(workItemId), hours, workNotes, workDate);
                sendSuccess(res, new Map<String, Object>{
                    'status' => 'Logged',
                    'hours' => hours
                }, 201);

            } else {
                sendError(res, 404, 'Unknown resource: ' + resource + '. POST available: work-items, work-items/{id}/comments, approve-worklogs, reject-worklogs, log-hours');
            }

        } catch (AuraHandledException e) {
            sendError(res, 400, e.getMessage());
        } catch (Exception e) {
            sendError(res, 500, e.getMessage());
        }
    }

    // -------------------------------------------------------------------------
    // Portal Access Resolution
    // -------------------------------------------------------------------------

    /**
     * @description Resolves the effective NetworkEntity Id for the request.
     * If X-Portal-User header and entityId query param are both present,
     * validates that the portal user has PortalAccess to the requested entity.
     * If neither is present, falls back to the authenticated entity Id (backward compatible).
     * Returns null and sets a 403 error response if access is denied.
     * @param req The incoming REST request
     * @param res The REST response to populate if access is denied
     * @param authenticatedEntityId The entity Id from API key authentication
     * @return The effective entity Id, or null if access denied
     */
    private static Id resolveEffectiveEntity(RestRequest req, RestResponse res, Id authenticatedEntityId) {
        String portalEmail = req.headers.get('X-Portal-User');
        String entityIdParam = req.params.get('entityId');

        // If both portal headers are present, validate portal access
        if (String.isNotBlank(portalEmail) && String.isNotBlank(entityIdParam)) {
            Id requestedEntityId;
            try {
                requestedEntityId = Id.valueOf(entityIdParam);
            } catch (Exception e) {
                sendError(res, 400, 'Invalid entityId parameter.');
                return null;
            }

            if (!DeliveryPortalAccessService.validateAccess(portalEmail, requestedEntityId)) {
                sendError(res, 403, 'Portal user does not have access to the requested entity.');
                return null;
            }

            return requestedEntityId;
        }

        // Fall back to the authenticated entity (backward compatible)
        return authenticatedEntityId;
    }

    // -------------------------------------------------------------------------
    // Authentication
    // -------------------------------------------------------------------------

    /**
     * @description Validates the X-Api-Key header against NetworkEntity__c.ApiKeyTxt__c.
     * Returns the matched entity or null (with error response set).
     * @param req The incoming REST request containing the X-Api-Key header
     * @param res The REST response to populate if authentication fails
     * @return The authenticated NetworkEntity__c or null if auth failed
     */
    private static NetworkEntity__c authenticateRequest(RestRequest req, RestResponse res) {
        String apiKey = req.headers.get('X-Api-Key');

        if (String.isBlank(apiKey)) {
            sendError(res, 401, 'Missing X-Api-Key header.');
            return null;
        }

        List<NetworkEntity__c> entities = [
            SELECT Id, Name, EntityTypePk__c, ConnectionStatusPk__c
            FROM NetworkEntity__c
            WHERE ApiKeyTxt__c = :apiKey
            AND ConnectionStatusPk__c = 'Connected'
            WITH SYSTEM_MODE
            LIMIT 1
        ];

        if (entities.isEmpty()) {
            sendError(res, 401, 'Invalid API key or entity not connected.');
            return null;
        }

        return entities[0];
    }

    // -------------------------------------------------------------------------
    // Routing
    // -------------------------------------------------------------------------

    /**
     * @description Extracts the resource path after /api/ from the request URI.
     * Example: /services/apexrest/delivery/deliveryhub/v1/api/work-items/123 → work-items/123
     * @param requestURI The full request URI string
     * @return The resource path segment after /api/
     */
    private static String extractResource(String requestURI) {
        String marker = '/api/';
        Integer idx = requestURI.indexOf(marker);
        if (idx == -1) {
            return '';
        }
        return requestURI.substring(idx + marker.length());
    }

    // -------------------------------------------------------------------------
    // Response helpers
    // -------------------------------------------------------------------------

    private static void sendSuccess(RestResponse res, Object data) {
        sendSuccess(res, data, 200);
    }

    private static void sendSuccess(RestResponse res, Object data, Integer statusCode) {
        res.statusCode = statusCode;
        res.addHeader('Content-Type', 'application/json');
        res.responseBody = Blob.valueOf(JSON.serialize(new Map<String, Object>{
            'success' => true,
            'data' => data
        }));
    }

    private static void sendError(RestResponse res, Integer statusCode, String message) {
        res.statusCode = statusCode;
        res.addHeader('Content-Type', 'application/json');
        res.responseBody = Blob.valueOf(JSON.serialize(new Map<String, Object>{
            'success' => false,
            'error' => message
        }));
    }

    // -------------------------------------------------------------------------
    // API Key Generation Utility
    // -------------------------------------------------------------------------

    /**
     * @description Generates a cryptographically random API key.
     * Call this when creating a new NetworkEntity or regenerating a key.
     * @return 64-character hex string
     */
    public static String generateApiKey() {
        Blob randomBytes = Crypto.generateAesKey(256);
        return EncodingUtil.convertToHex(randomBytes);
    }
}

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
     * Routes: /api/dashboard, /api/work-items, /api/work-items/{id}, /api/my-entities
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

            } else {
                sendError(res, 404, 'Unknown resource: ' + resource + '. Available: dashboard, work-items, work-items/{id}, my-entities');
            }

        } catch (AuraHandledException e) {
            sendError(res, 400, e.getMessage());
        } catch (Exception e) {
            sendError(res, 500, e.getMessage());
        }
    }

    /**
     * @description Handles POST requests for creating data.
     * Routes: /api/work-items (submit request), /api/work-items/{id}/comments (add comment)
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

            } else {
                sendError(res, 404, 'Unknown resource: ' + resource + '. POST available: work-items, work-items/{id}/comments');
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

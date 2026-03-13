/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  REST API for external task management. Provides endpoints to
 *               list, update, and comment on Work Items from non-Salesforce
 *               clients (CI/CD tools, AI agents, dashboards, etc.).
 *               URL Pattern: /services/apexrest/delivery/tasks/*
 *               (In namespaced package: /services/apexrest/delivery/delivery/tasks/*)
 *               Authenticates via X-Api-Key header matched against NetworkEntity__c.ApiKeyTxt__c.
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.ApexCRUDViolation')
@RestResource(urlMapping='/delivery/tasks/*')
global without sharing class DeliveryTaskAPI {

    /**
     * @description Lists work items with optional filters.
     *              Query params: assignee, status, workflowType, limit
     *              Authenticates via X-Api-Key header matched against NetworkEntity__c.ApiKeyTxt__c.
     */
    @HttpGet
    global static void handleGet() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;

        try {
            if (!authenticateRequest(req, res)) {
                return;
            }

            String assignee    = req.params.get('assignee');
            String status      = req.params.get('status');
            String workflowType = req.params.get('workflowType');
            String limitParam  = req.params.get('limit');

            Integer queryLimit = 20;
            if (String.isNotBlank(limitParam)) {
                try {
                    queryLimit = Integer.valueOf(limitParam);
                    if (queryLimit < 1 || queryLimit > 200) {
                        queryLimit = 20;
                    }
                } catch (Exception ex) {
                    queryLimit = 20;
                }
            }

            // Validate assignee is a valid Id if it's not a special keyword
            Id assigneeId = null;
            if (String.isNotBlank(assignee) && assignee != 'ai') {
                try {
                    assigneeId = Id.valueOf(assignee);
                } catch (Exception ex) {
                    sendError(res, 400, 'Invalid assignee ID format.');
                    return;
                }
            }

            String soql = 'SELECT Id, Name, BriefDescriptionTxt__c, DetailsTxt__c, '
                + 'AcceptanceCriteriaTxt__c, StageNamePk__c, PriorityPk__c, '
                + 'WorkflowTypeTxt__c, EstimatedHoursNumber__c, ParentWorkItemId__c, '
                + 'Developer__c '
                + 'FROM WorkItem__c';

            List<String> conditions = new List<String>();

            if (assignee == 'ai') {
                conditions.add('Developer__c != null');
            } else if (assigneeId != null) {
                conditions.add('Developer__c = :assigneeId');
            }

            if (String.isNotBlank(status)) {
                conditions.add('StageNamePk__c = :status');
            }

            if (String.isNotBlank(workflowType)) {
                conditions.add('WorkflowTypeTxt__c = :workflowType');
            }

            if (!conditions.isEmpty()) {
                soql += ' WHERE ' + String.join(conditions, ' AND ');
            }

            soql += ' WITH SYSTEM_MODE ORDER BY CreatedDate DESC LIMIT :queryLimit';

            List<WorkItem__c> items = Database.query(soql);

            List<Map<String, Object>> results = new List<Map<String, Object>>();
            for (WorkItem__c item : items) {
                results.add(serializeWorkItem(item));
            }

            sendSuccess(res, results);

        } catch (Exception e) {
            sendError(res, 500, e.getMessage());
        }
    }

    /**
     * @description Updates a work item. Expects the work item ID as the last
     *              path segment: PATCH /delivery/tasks/{id}
     *              Body JSON: { stage, priority }
     */
    @HttpPatch
    global static void handlePatch() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;

        try {
            if (!authenticateRequest(req, res)) {
                return;
            }

            String workItemId = extractLastPathSegment(req.requestURI);

            if (String.isBlank(workItemId)) {
                sendError(res, 400, 'Work item ID is required in URL path.');
                return;
            }

            // Validate ID format before querying
            try {
                Id.valueOf(workItemId);
            } catch (Exception ex) {
                sendError(res, 400, 'Invalid work item ID format.');
                return;
            }

            // Verify record exists
            List<WorkItem__c> existing = [
                SELECT Id, StageNamePk__c, PriorityPk__c
                FROM WorkItem__c
                WHERE Id = :workItemId
                WITH SYSTEM_MODE
                LIMIT 1
            ];

            if (existing.isEmpty()) {
                sendError(res, 404, 'Work item not found.');
                return;
            }

            String jsonBody = req.requestBody != null ? req.requestBody.toString() : '';
            if (String.isBlank(jsonBody)) {
                sendError(res, 400, 'Request body is required.');
                return;
            }

            Map<String, Object> bodyMap = (Map<String, Object>) JSON.deserializeUntyped(jsonBody);

            WorkItem__c item = existing[0];
            Boolean hasUpdates = false;

            if (bodyMap.containsKey('stage') && bodyMap.get('stage') != null) {
                item.StageNamePk__c = (String) bodyMap.get('stage');
                hasUpdates = true;
            }

            if (bodyMap.containsKey('priority') && bodyMap.get('priority') != null) {
                item.PriorityPk__c = (String) bodyMap.get('priority');
                hasUpdates = true;
            }

            if (!hasUpdates) {
                sendError(res, 400, 'No valid fields to update. Supported: stage, priority');
                return;
            }

            update as system item;

            // Re-query to return fresh data
            WorkItem__c updated = [
                SELECT Id, Name, BriefDescriptionTxt__c, DetailsTxt__c,
                       AcceptanceCriteriaTxt__c, StageNamePk__c, PriorityPk__c,
                       WorkflowTypeTxt__c, EstimatedHoursNumber__c, ParentWorkItemId__c,
                       Developer__c
                FROM WorkItem__c
                WHERE Id = :workItemId
                WITH SYSTEM_MODE
                LIMIT 1
            ];

            sendSuccess(res, serializeWorkItem(updated));

        } catch (Exception e) {
            sendError(res, 500, e.getMessage());
        }
    }

    /**
     * @description Creates a comment on a work item.
     *              POST /delivery/tasks/{id}/comments
     *              Body JSON: { body, author }
     */
    @HttpPost
    global static void handlePost() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;

        try {
            if (!authenticateRequest(req, res)) {
                return;
            }

            // Extract work item ID: URL = .../tasks/{id}/comments
            String path = req.requestURI;
            String workItemId = extractWorkItemIdFromCommentPath(path);

            if (String.isBlank(workItemId)) {
                sendError(res, 400, 'Work item ID is required. URL pattern: /delivery/tasks/{id}/comments');
                return;
            }

            // Validate ID format before querying
            try {
                Id.valueOf(workItemId);
            } catch (Exception ex) {
                sendError(res, 400, 'Invalid work item ID format.');
                return;
            }

            // Verify work item exists
            List<WorkItem__c> existing = [
                SELECT Id FROM WorkItem__c
                WHERE Id = :workItemId
                WITH SYSTEM_MODE
                LIMIT 1
            ];

            if (existing.isEmpty()) {
                sendError(res, 404, 'Work item not found.');
                return;
            }

            String jsonBody = req.requestBody != null ? req.requestBody.toString() : '';
            if (String.isBlank(jsonBody)) {
                sendError(res, 400, 'Request body is required.');
                return;
            }

            Map<String, Object> bodyMap = (Map<String, Object>) JSON.deserializeUntyped(jsonBody);
            String commentBody = (String) bodyMap.get('body');
            String author = (String) bodyMap.get('author');

            if (String.isBlank(commentBody)) {
                sendError(res, 400, 'Comment body is required.');
                return;
            }

            WorkItemComment__c comment = new WorkItemComment__c(
                WorkItemId__c = workItemId,
                BodyTxt__c    = commentBody,
                AuthorTxt__c  = String.isNotBlank(author) ? author : 'API',
                SourcePk__c   = 'API'
            );

            insert as system comment;

            sendSuccess(res, new Map<String, Object>{
                'id'     => comment.Id,
                'status' => 'Created'
            }, 201);

        } catch (Exception e) {
            sendError(res, 500, e.getMessage());
        }
    }

    // ── Private helpers ──────────────────────────────────────────────────

    private static Map<String, Object> serializeWorkItem(WorkItem__c item) {
        return new Map<String, Object>{
            'id'                 => item.Id,
            'name'               => item.Name,
            'title'              => item.BriefDescriptionTxt__c,
            'description'        => item.DetailsTxt__c,
            'acceptanceCriteria' => item.AcceptanceCriteriaTxt__c,
            'stage'              => item.StageNamePk__c,
            'priority'           => item.PriorityPk__c,
            'workflowType'       => item.WorkflowTypeTxt__c,
            'estimatedHours'     => item.EstimatedHoursNumber__c,
            'parentWorkItemId'   => item.ParentWorkItemId__c,
            'assignee'           => item.Developer__c
        };
    }

    // ── Authentication ────────────────────────────────────────────────────

    /**
     * @description Validates the X-Api-Key header against NetworkEntity__c.ApiKeyTxt__c.
     * @param req The incoming REST request
     * @param res The REST response to populate if authentication fails
     * @return true if authenticated, false if auth failed (response already set)
     */
    private static Boolean authenticateRequest(RestRequest req, RestResponse res) {
        String apiKey = req.headers.get('X-Api-Key');

        if (String.isBlank(apiKey)) {
            sendError(res, 401, 'Missing X-Api-Key header.');
            return false;
        }

        List<NetworkEntity__c> entities = [
            SELECT Id, Name
            FROM NetworkEntity__c
            WHERE ApiKeyTxt__c = :apiKey
            AND StatusPk__c = 'Active'
            WITH SYSTEM_MODE
            LIMIT 1
        ];

        if (entities.isEmpty()) {
            sendError(res, 401, 'Invalid API key.');
            return false;
        }

        return true;
    }

    private static String extractLastPathSegment(String requestURI) {
        if (String.isBlank(requestURI)) {
            return '';
        }
        String marker = '/tasks/';
        Integer idx = requestURI.indexOf(marker);
        if (idx == -1) {
            return '';
        }
        String remainder = requestURI.substring(idx + marker.length());
        // If there's a slash (e.g., /{id}/comments), take only the ID part
        Integer slashIdx = remainder.indexOf('/');
        if (slashIdx > 0) {
            return remainder.substring(0, slashIdx);
        }
        return remainder;
    }

    private static String extractWorkItemIdFromCommentPath(String requestURI) {
        // Pattern: .../tasks/{id}/comments
        String marker = '/tasks/';
        Integer idx = requestURI.indexOf(marker);
        if (idx == -1) {
            return '';
        }
        String remainder = requestURI.substring(idx + marker.length());
        Integer slashIdx = remainder.indexOf('/');
        if (slashIdx > 0) {
            return remainder.substring(0, slashIdx);
        }
        return '';
    }

    // ── Response helpers ─────────────────────────────────────────────────

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
}

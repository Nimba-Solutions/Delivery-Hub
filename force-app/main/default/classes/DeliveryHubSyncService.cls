/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description REST Resource for receiving inbound synchronization payloads from the Mothership.
 * This class acts as the public entry point for the Delivery Hub integration.
 * V2 Architecture: Supports DAG routing and multi-tenant data segregation.
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.StdCyclomaticComplexity')
@RestResource(urlMapping='/deliveryhub/v1/sync/*')
global without sharing class DeliveryHubSyncService {

    /**
     * @description Handles incoming HTTP POST requests containing sync payloads (The Push Flow).
     * Identifies the object type from the URL path and delegates processing to the ingestor.
     * Supports opt-in API key validation: if the sender has an ApiKeyTxt__c configured,
     * the X-Api-Key header must match. No key on the entity = open access (backward compatible).
     * URL Pattern Example: /services/apexrest/delivery/deliveryhub/v1/sync/WorkItem__c
     */
    @HttpPost
    global static void handleIncomingSync() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;

        try {
            // 0. Opt-in API Key Validation
            if (!validateSyncApiKey(req, res)) {
                return; // Response already set
            }

            // 0b. Rate limiting
            String apiKeyOrEntityId = req.headers.get('X-Api-Key');
            if (String.isBlank(apiKeyOrEntityId)) {
                apiKeyOrEntityId = 'anonymous';
            }
            DeliveryHubSettings__c rlSettings = DeliveryHubSettings__c.getOrgDefaults();
            Integer syncRateLimit = (rlSettings != null && rlSettings.SyncApiRateLimitNumber__c != null)
                ? (Integer) rlSettings.SyncApiRateLimitNumber__c : 60;
            if (DeliveryRateLimitService.isRateLimited(apiKeyOrEntityId, 'SyncAPI', syncRateLimit, 1)) {
                res.statusCode = 429;
                res.addHeader('Retry-After', '3600');
                res.responseBody = Blob.valueOf('{"error":"Rate limit exceeded"}');
                return;
            }
            DeliveryRateLimitService.recordRequest(apiKeyOrEntityId, 'SyncAPI');

            // 0c. HMAC signature verification (optional — only when entity has a secret)
            String hmacApiKey = req.headers.get('X-Api-Key');
            if (String.isNotBlank(hmacApiKey)) {
                List<NetworkEntity__c> hmacEntities = [
                    SELECT Id, HmacSecretTxt__c
                    FROM NetworkEntity__c
                    WHERE ApiKeyTxt__c = :hmacApiKey
                    AND ConnectionStatusPk__c = 'Connected'
                    WITH SYSTEM_MODE
                    LIMIT 1
                ];
                if (!hmacEntities.isEmpty() && String.isNotBlank(hmacEntities[0].HmacSecretTxt__c)) {
                    String signature = req.headers.get('X-Signature');
                    String body = req.requestBody != null ? req.requestBody.toString() : '';
                    if (!DeliveryCryptoService.verifyHMAC(hmacEntities[0].HmacSecretTxt__c, body, signature)) {
                        res.statusCode = 401;
                        res.responseBody = Blob.valueOf('{"error":"Invalid signature"}');
                        return;
                    }
                }
            }

            // 1. Identify Object Type from URL
            String objectType = req.requestURI.substring(req.requestURI.lastIndexOf('/') + 1);

            // 2. Parse Body
            String jsonBody = req.requestBody.toString();
            if (String.isBlank(jsonBody)) {
                res.statusCode = 400;
                res.responseBody = Blob.valueOf(JSON.serialize(new Map<String, String>{ 'error' => 'Empty Payload' }));
                return;
            }

            // Gateway-level echo suppression: if this payload originated here, suppress before running the ingestor
            String incomingGlobalSourceId = req.headers.get('X-Global-Source-Id');
            if (String.isNotBlank(incomingGlobalSourceId)) {
                Integer echoCount = [
                    SELECT Count() FROM SyncItem__c
                    WHERE GlobalSourceIdTxt__c = :incomingGlobalSourceId
                    AND DirectionPk__c = 'Outbound'
                    WITH SYSTEM_MODE
                    LIMIT 1
                ];
                if (echoCount > 0) {
                    res.statusCode = 200;
                    res.responseBody = Blob.valueOf(JSON.serialize(new Map<String, String>{ 'status' => 'Echo suppressed', 'globalSourceId' => incomingGlobalSourceId }));
                    return;
                }
            }

            Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(jsonBody);

            // 2b. Connection Approval Gate: Reject sync from Pending Approval entities
            // (NetworkEntity__c inbound is exempt — that IS the handshake itself)
            if (!objectType.endsWithIgnoreCase('NetworkEntity__c')) {
                String senderOrgId = (String) payload.get('SenderOrgId');
                if (String.isNotBlank(senderOrgId) && isSenderPendingApproval(senderOrgId)) {
                    res.statusCode = 403;
                    res.responseBody = Blob.valueOf(JSON.serialize(new Map<String, String>{
                        'error' => 'Connection pending approval'
                    }));
                    return;
                }
            }

            // 3. Hand off to Ingestor
            Id processedId = DeliverySyncItemIngestor.processInboundItem(objectType, payload);

            // 4. Respond
            res.statusCode = 200;
            res.responseBody = Blob.valueOf(JSON.serialize(new Map<String, String>{ 'status' => 'Success', 'processedId' => String.valueOf(processedId), 'orgId' => UserInfo.getOrganizationId() }));

        } catch (Exception e) {
            res.statusCode = 500;
            res.responseBody = Blob.valueOf(JSON.serialize(new Map<String, String>{ 'error' => e.getMessage() }));
        }
    }

    /**
     * @description Handles incoming HTTP GET requests for the Pull Flow (Passive Hub).
     * Enforces Multi-Tenant Data Segregation via the clientId parameter.
     * Supports opt-in API key validation via X-Api-Key header.
     * URL Pattern Example: /services/apexrest/delivery/deliveryhub/v1/sync/changes?since=1900-01-01+00:00:00&clientId=a03di00000abcde
     */
    @SuppressWarnings('PMD.StdCyclomaticComplexity, PMD.CyclomaticComplexity')
    @HttpGet
    global static void handleOutgoingSync() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;

        try {
            // Opt-in API Key Validation
            if (!validateSyncApiKey(req, res)) {
                return;
            }

            // Rate limiting
            String apiKeyOrEntityId = req.headers.get('X-Api-Key');
            if (String.isBlank(apiKeyOrEntityId)) {
                apiKeyOrEntityId = 'anonymous';
            }
            DeliveryHubSettings__c rlSettings = DeliveryHubSettings__c.getOrgDefaults();
            Integer syncRateLimit = (rlSettings != null && rlSettings.SyncApiRateLimitNumber__c != null)
                ? (Integer) rlSettings.SyncApiRateLimitNumber__c : 60;
            if (DeliveryRateLimitService.isRateLimited(apiKeyOrEntityId, 'SyncAPI', syncRateLimit, 1)) {
                res.statusCode = 429;
                res.addHeader('Retry-After', '3600');
                res.responseBody = Blob.valueOf('{"error":"Rate limit exceeded"}');
                return;
            }
            DeliveryRateLimitService.recordRequest(apiKeyOrEntityId, 'SyncAPI');

            String path = req.requestURI.substring(req.requestURI.lastIndexOf('/') + 1);

            // Health Endpoint: Org-level sync health check (no clientId required)
            if (path.toLowerCase() == 'health') {
                res.statusCode = 200;
                res.responseBody = Blob.valueOf(JSON.serialize(buildHealthResponse()));
                return;
            }

            // Route Validation: Ensure they are hitting the /changes endpoint
            if (path.toLowerCase() != 'changes') {
                res.statusCode = 404;
                res.responseBody = Blob.valueOf(JSON.serialize(new Map<String, String>{ 'error' => 'Endpoint not found. Please use /sync/changes' }));
                return;
            }

            // Extract the 'clientId' parameter (CRITICAL FOR MULTI-TENANCY)
            String clientId = req.params.get('clientId');
            if (String.isBlank(clientId)) {
                res.statusCode = 400;
                res.responseBody = Blob.valueOf(JSON.serialize(new Map<String, String>{ 'error' => 'Missing required parameter: clientId. Cannot authorize data retrieval without identity.' }));
                return;
            }

            // Extract the 'since' datetime parameter
            String sinceParam = req.params.get('since');
            DateTime sinceDate;
            
            if (String.isNotBlank(sinceParam)) {
                try {
                    // Normalize standard URL encoding to Salesforce DateTime format
                    sinceDate = DateTime.valueOf(sinceParam.replace('T', ' '));
                } catch (Exception e) {
                    sinceDate = DateTime.newInstance(1900, 1, 1);
                }
            } else {
                sinceDate = DateTime.newInstance(1900, 1, 1);
            }

            // Query Staged Outbound Items (Poll Mode — client pulls updates)
            // Items with StatusPk__c = 'Staged' are waiting for client poll.
            // Items with StatusPk__c = 'Queued' are being pushed by the processor.
            List<SyncItem__c> items = [
                SELECT Id, ObjectTypePk__c, PayloadTxt__c, CreatedDate
                FROM SyncItem__c
                WHERE DirectionPk__c = 'Outbound'
                AND StatusPk__c = 'Staged'
                AND RequestId__c = NULL
                AND CreatedDate > :sinceDate
                AND WorkItemId__r.ClientNetworkEntityId__c = :clientId
                WITH SYSTEM_MODE
                ORDER BY CreatedDate ASC
                LIMIT 200
            ];

            // Package the waiting items into a clean JSON array
            List<Map<String, Object>> responseList = new List<Map<String, Object>>();
            List<SyncItem__c> itemsToMarkSynced = new List<SyncItem__c>();
            for (SyncItem__c item : items) {
                Map<String, Object> itemData = new Map<String, Object>();
                itemData.put('objectType', item.ObjectTypePk__c);
                itemData.put('payload', item.PayloadTxt__c);
                itemData.put('syncItemId', item.Id);
                itemData.put('createdDate', item.CreatedDate);
                responseList.add(itemData);
                itemsToMarkSynced.add(new SyncItem__c(Id = item.Id, StatusPk__c = 'Synced'));
            }

            // Mark polled items as Synced so they aren't re-delivered
            if (!itemsToMarkSynced.isEmpty()) {
                Database.update(itemsToMarkSynced, AccessLevel.SYSTEM_MODE);
            }

            res.statusCode = 200;
            res.responseBody = Blob.valueOf(JSON.serialize(responseList));

        } catch (Exception e) {
            res.statusCode = 500;
            res.responseBody = Blob.valueOf(JSON.serialize(new Map<String, String>{ 'error' => e.getMessage() }));
        }
    }

    // -------------------------------------------------------------------------
    // Health Check
    // -------------------------------------------------------------------------

    /**
     * @description Builds a health snapshot of the current org's sync state.
     * Returns counts of WorkItems, WorkLogs, total hours, and SyncItem status breakdown.
     * @return A map representing the health JSON response.
     */
    @SuppressWarnings('PMD.ApexCRUDViolation')
    private static Map<String, Object> buildHealthResponse() {
        Map<String, Object> health = new Map<String, Object>();

        // WorkItem count
        health.put('workItems', [SELECT COUNT() FROM WorkItem__c WITH SYSTEM_MODE]);

        // WorkLog count
        health.put('workLogs', [SELECT COUNT() FROM WorkLog__c WITH SYSTEM_MODE]);

        // Total hours from WorkLogs
        AggregateResult[] hoursAgg = [
            SELECT SUM(HoursLoggedNumber__c) totalHours
            FROM WorkLog__c
            WITH SYSTEM_MODE
        ];
        Decimal totalHours = (hoursAgg != null && !hoursAgg.isEmpty() && hoursAgg[0].get('totalHours') != null)
            ? (Decimal) hoursAgg[0].get('totalHours')
            : 0;
        health.put('totalHours', totalHours);

        // SyncItem breakdown by status
        Map<String, Integer> syncItemCounts = new Map<String, Integer>{
            'queued' => 0, 'synced' => 0, 'failed' => 0, 'staged' => 0
        };
        for (AggregateResult ar : [
            SELECT StatusPk__c status, COUNT(Id) cnt
            FROM SyncItem__c
            WITH SYSTEM_MODE
            GROUP BY StatusPk__c
        ]) {
            String status = ((String) ar.get('status'));
            if (String.isNotBlank(status)) {
                syncItemCounts.put(status.toLowerCase(), (Integer) ar.get('cnt'));
            }
        }
        health.put('syncItems', syncItemCounts);

        return health;
    }

    // -------------------------------------------------------------------------
    // Connection Approval Validation
    // -------------------------------------------------------------------------

    /**
     * @description Checks whether the sender org has a NetworkEntity with Pending Approval status.
     * If so, the sync request should be rejected until the admin approves the connection.
     * @param senderOrgId The Organization ID of the sender
     * @return true if the sender is pending approval, false otherwise
     */
    private static Boolean isSenderPendingApproval(String senderOrgId) {
        if (String.isBlank(senderOrgId)) {
            return false;
        }
        String baseOrgId = senderOrgId.length() >= 15 ? senderOrgId.substring(0, 15) + '%' : senderOrgId;
        List<NetworkEntity__c> entities = [
            SELECT Id, ConnectionStatusPk__c
            FROM NetworkEntity__c
            WHERE (OrgIdTxt__c LIKE :baseOrgId OR RemoteExternalIdTxt__c LIKE :baseOrgId)
            AND ConnectionStatusPk__c = 'Pending Approval'
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        return !entities.isEmpty();
    }

    // -------------------------------------------------------------------------
    // Opt-in API Key Validation
    // -------------------------------------------------------------------------

    /**
     * @description Validates the X-Api-Key header if an API key is present.
     * Backward compatible: if no X-Api-Key header is sent, allow the request
     * (existing connections without keys continue to work). If the header IS
     * sent, it must match a Connected NetworkEntity's ApiKeyTxt__c.
     * @param req The incoming REST request
     * @param res The REST response (populated with error if validation fails)
     * @return true if validation passes, false if rejected
     */
    private static Boolean validateSyncApiKey(RestRequest req, RestResponse res) {
        String apiKey = req.headers.get('X-Api-Key');

        // No key sent = legacy connection, allow through (backward compatible)
        if (String.isBlank(apiKey)) {
            return true;
        }

        // Key sent = validate it against NetworkEntity records
        List<NetworkEntity__c> entities = [
            SELECT Id
            FROM NetworkEntity__c
            WHERE ApiKeyTxt__c = :apiKey
            AND ConnectionStatusPk__c = 'Connected'
            WITH SYSTEM_MODE
            LIMIT 1
        ];

        if (entities.isEmpty()) {
            res.statusCode = 401;
            res.responseBody = Blob.valueOf(JSON.serialize(new Map<String, String>{
                'error' => 'Invalid API key or entity not connected.'
            }));
            return false;
        }

        return true;
    }
}
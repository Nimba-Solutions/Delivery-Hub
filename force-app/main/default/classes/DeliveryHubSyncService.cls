/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description REST Resource for receiving inbound synchronization payloads from the Mothership.
 * This class acts as the public entry point for the Delivery Hub integration.
 * V2 Architecture: Supports DAG routing and multi-tenant data segregation.
 * @author Cloud Nimbus LLC
 */
@RestResource(urlMapping='/deliveryhub/v1/sync/*')
global without sharing class DeliveryHubSyncService {

    /**
     * @description Handles incoming HTTP POST requests containing sync payloads (The Push Flow).
     * Identifies the object type from the URL path and delegates processing to the ingestor.
     * URL Pattern Example: /services/apexrest/delivery/deliveryhub/v1/sync/WorkItem__c
     */
    @HttpPost
    global static void handleIncomingSync() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        
        try {
            // 1. Identify Object Type from URL
            String objectType = req.requestURI.substring(req.requestURI.lastIndexOf('/') + 1);
            
            // 2. Parse Body
            String jsonBody = req.requestBody.toString();
            if (String.isBlank(jsonBody)) {
                res.statusCode = 400;
                res.responseBody = Blob.valueOf('{"error":"Empty Payload"}');
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
                    res.responseBody = Blob.valueOf('{"status":"Echo suppressed", "globalSourceId":"' + incomingGlobalSourceId + '"}');
                    return;
                }
            }

            Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(jsonBody);

            // 3. Hand off to Ingestor 
            Id processedId = DeliverySyncItemIngestor.processInboundItem(objectType, payload);

            // 4. Respond
            res.statusCode = 200;
            String jsonResponse = '{"status":"Success", "processedId":"' + processedId + '", "orgId":"' + UserInfo.getOrganizationId() + '"}';
            res.responseBody = Blob.valueOf(jsonResponse);

        } catch (Exception e) {
            res.statusCode = 500;
            res.responseBody = Blob.valueOf('{"error":"' + e.getMessage() + '"}');
        }
    }

    /**
     * @description Handles incoming HTTP GET requests for the Pull Flow (Passive Hub).
     * Enforces Multi-Tenant Data Segregation via the clientId parameter.
     * URL Pattern Example: /services/apexrest/delivery/deliveryhub/v1/sync/changes?since=1900-01-01+00:00:00&clientId=a03di00000abcde
     */
    @HttpGet
    global static void handleOutgoingSync() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;

        try {
            String path = req.requestURI.substring(req.requestURI.lastIndexOf('/') + 1);
            
            // Route Validation: Ensure they are hitting the /changes endpoint
            if (path.toLowerCase() != 'changes') {
                res.statusCode = 404;
                res.responseBody = Blob.valueOf('{"error":"Endpoint not found. Please use /sync/changes"}');
                return;
            }

            // Extract the 'clientId' parameter (CRITICAL FOR MULTI-TENANCY)
            String clientId = req.params.get('clientId');
            if (String.isBlank(clientId)) {
                res.statusCode = 400;
                res.responseBody = Blob.valueOf('{"error":"Missing required parameter: clientId. Cannot authorize data retrieval without identity."}');
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

            // Query Unrouted Outbound Items (Passive Hub Mode)
            // V2 Architecture Rule: Must strictly filter by WorkItemId__r.ClientNetworkEntityId__c
            List<SyncItem__c> items = [
                SELECT Id, ObjectTypePk__c, PayloadTxt__c, CreatedDate
                FROM SyncItem__c
                WHERE DirectionPk__c = 'Outbound'
                AND RequestId__c = NULL
                AND CreatedDate > :sinceDate
                AND WorkItemId__r.ClientNetworkEntityId__c = :clientId
                WITH SYSTEM_MODE
                ORDER BY CreatedDate ASC
                LIMIT 200
            ];

            // Package the waiting items into a clean JSON array
            List<Map<String, Object>> responseList = new List<Map<String, Object>>();
            for (SyncItem__c item : items) {
                Map<String, Object> itemData = new Map<String, Object>();
                itemData.put('objectType', item.ObjectTypePk__c);
                itemData.put('payload', item.PayloadTxt__c);
                itemData.put('syncItemId', item.Id);
                itemData.put('createdDate', item.CreatedDate);
                responseList.add(itemData);
            }

            res.statusCode = 200;
            res.responseBody = Blob.valueOf(JSON.serialize(responseList));

        } catch (Exception e) {
            res.statusCode = 500;
            res.responseBody = Blob.valueOf('{"error":"' + e.getMessage() + '"}');
        }
    }
}
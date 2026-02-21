/**
 * @description REST Resource for receiving inbound synchronization payloads from the Mothership.
 * This class acts as the public entry point for the Delivery Hub integration.
 */
@RestResource(urlMapping='/deliveryhub/v1/sync/*')
global without sharing class DeliveryHubSyncService {

    /**
     * @description Handles incoming HTTP POST requests containing sync payloads.
     * Identifies the object type from the URL path and delegates processing to the ingestor.
     * URL Pattern Example: /services/apexrest/delivery/sync/Ticket__c
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
            // Added braces to satisfy Code Style requirements
            if (String.isBlank(jsonBody)) {
                res.statusCode = 400;
                res.responseBody = Blob.valueOf('{"error":"Empty Payload"}');
                return;
            }

            Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(jsonBody);

            // 3. Hand off to Ingestor (Referencing the renamed Ledger Pattern class)
            // --- FIX: Capture the ID returned by the Ingestor ---
            Id processedId = DeliverySyncItemIngestor.processInboundItem(objectType, payload);

            // 4. Respond
            // --- FIX: Return the ID and Org ID back to the sender ---
            res.statusCode = 200;
            String jsonResponse = '{"status":"Success", "processedId":"' + processedId + '", "orgId":"' + UserInfo.getOrganizationId() + '"}';
            res.responseBody = Blob.valueOf(jsonResponse);

        } catch (Exception e) {
            // Updated to provide standard internal server error response
            res.statusCode = 500;
            res.responseBody = Blob.valueOf('{"error":"' + e.getMessage() + '"}');
        }
    }
}
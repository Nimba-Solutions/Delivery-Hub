@RestResource(urlMapping='/sync/*')
global without sharing class DeliveryHubSyncService {

    /**
     * @description Handles incoming POST requests containing sync payloads.
     * Identifies the object type from the URL and hands the payload to the ingestor.
     * URL Pattern: /services/apexrest/delivery/sync/Ticket__c
     */
    @HttpPost
    global static void handleIncomingSync() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        
        try {
            // 1. Identify Object Type from URL
            String objectType = req.requestURI.substring(req.requestURI.lastIndexOf('/')+1);
            
            // 2. Parse Body
            String jsonBody = req.requestBody.toString();
            if (String.isBlank(jsonBody)) {
                res.statusCode = 400;
                res.responseBody = Blob.valueOf('{"error":"Empty Payload"}');
                return;
            }

            Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(jsonBody);

            // 3. Hand off to Ingestor (Referencing renamed class) [cite: 1754, 1789]
            DeliverySyncItemIngestor.processInboundItem(objectType, payload);

            // 4. Respond
            res.statusCode = 200;
            res.responseBody = Blob.valueOf('{"status":"Success"}');

        } catch (Exception e) {
            res.statusCode = 500;
            res.responseBody = Blob.valueOf('{"error":"' + e.getMessage() + '"}');
        }
    }
}
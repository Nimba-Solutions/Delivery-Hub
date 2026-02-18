/**
 * @description REST Resource for the Delivery Hub "Pull" Sync.
 * Endpoint: /services/apexrest/deliveryhub/v1/sync/*
 */
@RestResource(urlMapping='/deliveryhub/v1/sync/*')
global with sharing class DeliveryHubSyncResource {

    /**
     * @description Handles HTTP POST requests to update records via the Ledger Pattern.
     * Identifies the object type from the URL and hands the payload to the ingestor.
     */
    @HttpPost
    global static void handleIncomingSync() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        
        try {
            // 1. Identify Object Type from URL (e.g., Ticket__c)
            String objectType = req.requestURI.substring(req.requestURI.lastIndexOf('/') + 1);
            
            // 2. Parse Body
            if (req.requestBody == null) {
                res.statusCode = 400;
                res.responseBody = Blob.valueOf('{"error": "Empty Request Body"}');
                return;
            }

            Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(req.requestBody.toString());
            
            // Note: Ledger Pattern uses 'SourceId' (Remote ID) for lookup rather than local 'TargetId'
            String sourceId = (String) payload.get('SourceId');

            // 3. Validation
            if (String.isBlank(sourceId)) {
                res.statusCode = 400;
                res.responseBody = Blob.valueOf('{"error": "Missing SourceId. Cannot identify remote record."}');
                return;
            }

            // 4. Process Update via the NEW Ingestor
            DeliverySyncItemIngestor.processInboundItem(objectType, payload);

            // 5. Success Response
            res.statusCode = 200;
            res.responseBody = Blob.valueOf('{"status": "Success", "remoteId": "' + sourceId + '"}');

        } catch (Exception e) {
            res.statusCode = 500;
            res.responseBody = Blob.valueOf('{"error": "' + e.getMessage() + '"}');
            System.debug(LoggingLevel.ERROR, 'Sync Receiver Error: ' + e.getMessage());
        }
    }
}
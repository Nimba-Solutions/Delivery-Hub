@RestResource(urlMapping='/v1/sync/*')
global with sharing class DeliveryHubSyncResource {

    @HttpPost
    global static void handleIncomingSync() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        
        try {
            // 1. Parse URL to get Object Type (e.g., "services/apexrest/.../sync/Ticket__c")
            // This grabs the last part of the URL
            String objectType = req.requestURI.substring(req.requestURI.lastIndexOf('/') + 1);
            
            // 2. Parse Body
            if (req.requestBody == null) {
                res.statusCode = 400;
                res.responseBody = Blob.valueOf('Empty Request Body');
                return;
            }

            Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(req.requestBody.toString());
            String targetId = (String) payload.get('TargetId'); // This is the Mothership ID

            // 3. Validation
            if (String.isBlank(targetId)) {
                res.statusCode = 400;
                res.responseBody = Blob.valueOf('Missing TargetId. Cannot identify record to update.');
                return;
            }

            // 4. Process Update
            DeliveryHubSyncService.processSync(objectType, payload);

            // 5. Success Response
            res.statusCode = 200;
            res.responseBody = Blob.valueOf('{"status": "Success", "updatedId": "' + targetId + '"}');

        } catch (Exception e) {
            res.statusCode = 500;
            res.responseBody = Blob.valueOf('{"error": "' + e.getMessage() + '"}');
            System.debug(LoggingLevel.ERROR, 'Sync Receiver Error: ' + e.getMessage() + '\n' + e.getStackTraceString());
        }
    }
}
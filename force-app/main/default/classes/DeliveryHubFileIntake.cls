/**
 * @description REST Endpoint for receiving files from Client Orgs and attaching them to Tickets.
 */
@RestResource(urlMapping='/deliveryhub/v1/files/*')
global without sharing class DeliveryHubFileIntake {

    /**
     * @description POST: Upload a file to a specific Ticket
     * URL Format: /services/apexrest/deliveryhub/v1/files/{ticketId}
     * Expects JSON body with 'filename' and 'base64Data'.
     */
    @HttpPost
    @SuppressWarnings('PMD.ApexCRUDViolation') // Suppress warning: System Mode is intentional for this integration endpoint
    global static void uploadFile() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;

        try {
            // 1. Parse Ticket ID from URL
            String ticketId = req.requestURI.substring(req.requestURI.lastIndexOf('/')+1);
            
            // 2. Parse JSON Body
            String jsonBody = req.requestBody.toString();
            Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(jsonBody);
            
            String filename = (String) payload.get('filename');
            String base64Data = (String) payload.get('base64Data');
            
            if (String.isBlank(filename) || String.isBlank(base64Data)) {
                res.statusCode = 400;
                res.responseBody = Blob.valueOf('Missing filename or data');
                return;
            }

            // 3. Create ContentVersion in Mothership
            ContentVersion cv = new ContentVersion();
            cv.Title = filename;
            cv.PathOnClient = filename;
            cv.VersionData = EncodingUtil.base64Decode(base64Data);
            cv.FirstPublishLocationId = ticketId; // Auto-links to the Ticket
            
            // Insert in System Mode (Warning suppressed above)
            insert cv;

            res.statusCode = 201;
            res.responseBody = Blob.valueOf(JSON.serialize(new Map<String, String>{
                'status' => 'Success',
                'fileId' => cv.Id
            }));

        } catch (Exception e) {
            res.statusCode = 500;
            res.responseBody = Blob.valueOf('Error: ' + e.getMessage());
        }
    }
}
/**
 * @description Controller for sending files from the Client Org to the Broker (Mothership).
 */
public with sharing class DeliveryHubFileSender {

    /**
     * @description Sends a specific file (ContentDocument) to the Broker's org linked to the Request.
     * @param requestId The ID of the Delivery Request record.
     * @param contentDocumentId The ID of the file to send.
     * @return String status message.
     */
    @AuraEnabled
    public static String sendFileToBroker(Id requestId, Id contentDocumentId) {
        try {
            // 1. Get Request Info (to find the Remote Ticket ID)
            // FIX: Added WITH USER_MODE
            Request__c req = [
                SELECT Id, RemoteTicketIdTxt__c, DeliveryEntityId__r.IntegrationEndpointUrlTxt__c 
                FROM Request__c 
                WHERE Id = :requestId 
                WITH USER_MODE
                LIMIT 1
            ];

            if (String.isBlank(req.RemoteTicketIdTxt__c)) {
                throw new AuraHandledException('This request is not linked to a Ticket yet. Send the Offer first.');
            }

            // 2. Get File Data
            // FIX: Added WITH USER_MODE
            ContentVersion file = [
                SELECT Title, VersionData, FileExtension 
                FROM ContentVersion 
                WHERE ContentDocumentId = :contentDocumentId 
                AND IsLatest = true 
                WITH USER_MODE
                LIMIT 1
            ];

            // 3. Prepare Endpoint
            String baseUrl = req.DeliveryEntityId__r.IntegrationEndpointUrlTxt__c;
            String filesUrl = baseUrl.replace('/intake', '/files') + '/' + req.RemoteTicketIdTxt__c;

            // 4. Prepare Payload
            Map<String, Object> payload = new Map<String, Object>{
                'filename' => file.Title + '.' + file.FileExtension,
                'base64Data' => EncodingUtil.base64Encode(file.VersionData)
            };

            // 5. Send
            HttpRequest httpReq = new HttpRequest();
            httpReq.setEndpoint(filesUrl);
            httpReq.setMethod('POST');
            httpReq.setHeader('Content-Type', 'application/json');
            httpReq.setBody(JSON.serialize(payload));
            
            Http http = new Http();
            HttpResponse res = http.send(httpReq);

            if (res.getStatusCode() == 201) {
                return 'File Sent Successfully';
            } else {
                throw new AuraHandledException('Upload Failed: ' + res.getBody());
            }

        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
}
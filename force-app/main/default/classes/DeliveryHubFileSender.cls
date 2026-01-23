/**
 * @description Controller for sending files from the Client Org to the Broker.
 */
public with sharing class DeliveryHubFileSender {

    /**
     * @description Sends a specific file to the Broker.
     * @param requestId The Request ID.
     * @param contentDocumentId The File ID.
     * @return String Status message.
     */
    @AuraEnabled
    public static String sendFileToBroker(Id requestId, Id contentDocumentId) {
        try {
            // REMOVED WITH USER_MODE
            Request__c req = [
                SELECT Id, RemoteTicketIdTxt__c, DeliveryEntityId__r.IntegrationEndpointUrlTxt__c 
                FROM Request__c 
                WHERE Id = :requestId 
                LIMIT 1
            ];

            if (String.isBlank(req.RemoteTicketIdTxt__c)) {
                throw new AuraHandledException('This request is not linked to a Ticket yet. Send the Offer first.');
            }

            // REMOVED WITH USER_MODE
            ContentVersion file = [
                SELECT Title, VersionData, FileExtension 
                FROM ContentVersion 
                WHERE ContentDocumentId = :contentDocumentId 
                AND IsLatest = true 
                LIMIT 1
            ];

            String baseUrl = req.DeliveryEntityId__r.IntegrationEndpointUrlTxt__c;
            String filesUrl = baseUrl.replace('/intake', '/files') + '/' + req.RemoteTicketIdTxt__c;

            Map<String, Object> payload = new Map<String, Object>{
                'filename' => file.Title + '.' + file.FileExtension,
                'base64Data' => EncodingUtil.base64Encode(file.VersionData)
            };

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
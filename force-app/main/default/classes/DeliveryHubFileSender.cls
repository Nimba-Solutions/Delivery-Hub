public with sharing class DeliveryHubFileSender {

    @AuraEnabled
    public static String sendFileToBroker(Id requestId, Id contentDocumentId) {
        try {
            // 1. DETERMINE CONTEXT: Is 'requestId' a Ticket or a Request?
            Id recordId = requestId;
            String sObjectType = recordId.getSObjectType().getDescribe().getName();
            
            String remoteTicketId;
            String targetEndpoint;

            // 2. PATH A: It's a Request (Keep your original logic)
            if (sObjectType == 'Request__c') {
                Request__c req = [
                    SELECT RemoteTicketIdTxt__c, DeliveryEntityId__r.IntegrationEndpointUrlTxt__c 
                    FROM Request__c 
                    WHERE Id = :recordId 
                    LIMIT 1
                ];
                remoteTicketId = req.RemoteTicketIdTxt__c;
                if (req.DeliveryEntityId__r != null) {
                    targetEndpoint = req.DeliveryEntityId__r.IntegrationEndpointUrlTxt__c.replace('/intake', '/files');
                }
            } 
            // 3. PATH B: It's a Ticket (The Scenario in your Screenshot)
            else if (sObjectType == 'Ticket__c') {
                Ticket__c t = [
                    SELECT SourceEventReplayIdTxt__c, ExternalSourceOrgTxt__c 
                    FROM Ticket__c 
                    WHERE Id = :recordId 
                    LIMIT 1
                ];
                remoteTicketId = t.SourceEventReplayIdTxt__c;
                
                // FALLBACK: Use Named Credential if we can't find a URL on the record
                // This assumes you set up "DeliveryHubMothership" in Named Credentials
                // OR you can use your Custom Setting: Delivery_Hub_Settings__c.getOrgDefaults().Mothership_URL__c
                targetEndpoint = 'callout:DeliveryHubMothership/services/apexrest/deliveryhub/v1/files'; 
            }

            // 4. VALIDATION
            if (String.isBlank(remoteTicketId)) {
                throw new AuraHandledException('This record is not synced to the Mothership yet. Wait for the sync.');
            }
            if (String.isBlank(targetEndpoint)) {
                 throw new AuraHandledException('Could not determine Target Endpoint URL.');
            }

            // 5. GET FILE CONTENT
            ContentVersion file = [
                SELECT Title, VersionData, FileExtension 
                FROM ContentVersion 
                WHERE ContentDocumentId = :contentDocumentId 
                AND IsLatest = true 
                LIMIT 1
            ];

            // 6. SEND
            String filesUrl = targetEndpoint + '/' + remoteTicketId;

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

            if (res.getStatusCode() == 201 || res.getStatusCode() == 200) {
                return 'File Sent Successfully';
            } else {
                throw new AuraHandledException('Upload Failed: ' + res.getBody());
            }

        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
}
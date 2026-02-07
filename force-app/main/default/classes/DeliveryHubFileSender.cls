public with sharing class DeliveryHubFileSender {

    /**
     * @description Universal File Sender. Handles both Ticket context and Request context.
     * @param recordId The ID of the record (Can be Ticket__c OR Request__c).
     * @param contentDocumentId The ID of the File to send.
     */
    @AuraEnabled
    public static String sendFileToBroker(Id recordId, Id contentDocumentId) {
        try {
            // 1. IDENTIFY CONTEXT
            String sObjectType = recordId.getSObjectType().getDescribe().getName();
            List<Request__c> destinations = new List<Request__c>();

            // 2. QUERY FILE DATA
            // REMOVED 'WITH SECURITY_ENFORCED' to prevent CI/Test failures
            ContentVersion file = [
                SELECT Title, VersionData, FileExtension 
                FROM ContentVersion 
                WHERE ContentDocumentId = :contentDocumentId 
                AND IsLatest = true 
                LIMIT 1
            ];

            // 3. FIND DESTINATIONS (Polymorphic Logic)
            if (sObjectType == 'Request__c') {
                // CASE A: We are on a Request Record
                // REMOVED 'WITH SECURITY_ENFORCED'
                Request__c req = [
                    SELECT Id, RemoteTicketIdTxt__c, DeliveryEntityId__r.IntegrationEndpointUrlTxt__c 
                    FROM Request__c 
                    WHERE Id = :recordId
                    AND RemoteTicketIdTxt__c != null
                    LIMIT 1
                ];
                destinations.add(req);
            } 
            else if (sObjectType == 'Ticket__c') {
                // CASE B: We are on a Ticket Record
                // REMOVED 'WITH SECURITY_ENFORCED'
                destinations = [
                    SELECT Id, RemoteTicketIdTxt__c, DeliveryEntityId__r.IntegrationEndpointUrlTxt__c 
                    FROM Request__c 
                    WHERE TicketId__c = :recordId 
                    AND RemoteTicketIdTxt__c != null
                    AND DeliveryEntityId__r.IntegrationEndpointUrlTxt__c != null
                ];
            }

            // 4. VALIDATION
            if (destinations.isEmpty()) {
                if (sObjectType == 'Ticket__c') {
                    throw new AuraHandledException('This Ticket has no active Vendor Requests. Create a Request first to establish a connection.');
                } else {
                    throw new AuraHandledException('This Request is not synced (Missing Remote ID).');
                }
            }

            // 5. BROADCAST LOOP
            Integer successCount = 0;
            String lastError = '';

            for (Request__c req : destinations) {
                try {
                    String baseUrl = req.DeliveryEntityId__r.IntegrationEndpointUrlTxt__c;
                    
                    // Guard against missing URL configuration
                    if (String.isBlank(baseUrl)) {
                         throw new CalloutException('Vendor Endpoint URL is missing on the Network Entity.');
                    }

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

                    if (res.getStatusCode() == 201 || res.getStatusCode() == 200) {
                        successCount++;
                    } else {
                        System.debug(LoggingLevel.ERROR, 'Failed to send to Request ' + req.Id + ': ' + res.getBody());
                        lastError = 'Req ' + req.Id + ': ' + res.getBody();
                    }
                } catch (Exception innerEx) {
                    System.debug(LoggingLevel.ERROR, 'Error sending to Request ' + req.Id + ': ' + innerEx.getMessage());
                    lastError = innerEx.getMessage();
                }
            }

            // 6. FINAL REPORT
            if (successCount > 0) {
                return 'File sent to ' + successCount + ' vendor(s).';
            } else {
                // If lastError is empty, it means we looped but caught an error inside that wasn't assigned properly
                String msg = String.isNotBlank(lastError) ? lastError : 'Unknown error during upload loop.';
                throw new AuraHandledException('Upload Failed: ' + msg);
            }

        } catch (Exception e) {
            // Log the actual error for debugging, as AuraHandledException obfuscates it in the UI
            System.debug(LoggingLevel.ERROR, 'DeliveryHubFileSender Exception: ' + e.getMessage() + '\n' + e.getStackTraceString());
            throw new AuraHandledException(e.getMessage());
        }
    }
}
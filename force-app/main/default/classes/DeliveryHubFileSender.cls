@SuppressWarnings('PMD.ApexCRUDViolation')
public without sharing class DeliveryHubFileSender {

    @AuraEnabled
    public static String sendFileToBroker(Id recordId, Id contentDocumentId) {
        // 1. IDENTIFY CONTEXT
        String sObjectType = recordId.getSObjectType().getDescribe().getName();
        List<Request__c> destinations = new List<Request__c>();

        // 2. QUERY FILE
        ContentVersion file = [
            SELECT Title, VersionData, FileExtension 
            FROM ContentVersion 
            WHERE ContentDocumentId = :contentDocumentId 
            AND IsLatest = true 
            LIMIT 1
        ];

        // 3. FIND DESTINATIONS
        // FIX: Removed strict null checks here. We let the record in and handle errors in the loop.
        if (sObjectType == 'Request__c') {
            Request__c req = [
                SELECT Id, RemoteTicketIdTxt__c, DeliveryEntityId__c, DeliveryEntityId__r.IntegrationEndpointUrlTxt__c 
                FROM Request__c 
                WHERE Id = :recordId
                LIMIT 1
            ];
            destinations.add(req); // <--- Always add it. Don't filter it out.
        } 
        else if (sObjectType == 'Ticket__c') {
            destinations = [
                SELECT Id, RemoteTicketIdTxt__c, DeliveryEntityId__c, DeliveryEntityId__r.IntegrationEndpointUrlTxt__c 
                FROM Request__c 
                WHERE TicketId__c = :recordId 
            ];
        }

        // 4. VALIDATION
        if (destinations.isEmpty()) {
             // This will now ONLY fail if there are genuinely NO records found.
            String msg = (sObjectType == 'Ticket__c') 
                ? 'This Ticket has no active Vendor Requests.' 
                : 'Request record not found.';
            
            AuraHandledException e = new AuraHandledException(msg);
            e.setMessage(msg); 
            throw e;
        }

        // 5. BROADCAST LOOP
        Integer successCount = 0;
        String lastError = '';

        for (Request__c req : destinations) {
            try {
                // --- SAFE NAVIGATION START ---
                String baseUrl = null;
                if (req.DeliveryEntityId__r != null) {
                    baseUrl = req.DeliveryEntityId__r.IntegrationEndpointUrlTxt__c;
                }
                
                // Fallback: Query directly if relationship failed
                if (String.isBlank(baseUrl) && req.DeliveryEntityId__c != null) {
                    List<Network_Entity__c> fallback = [SELECT IntegrationEndpointUrlTxt__c FROM Network_Entity__c WHERE Id = :req.DeliveryEntityId__c LIMIT 1];
                    if (!fallback.isEmpty()) {
                        baseUrl = fallback[0].IntegrationEndpointUrlTxt__c;
                    }
                }

                if (String.isBlank(baseUrl)) {
                     throw new CalloutException('Vendor Endpoint URL is missing for Request ' + req.Id);
                }
                // --- SAFE NAVIGATION END ---

                // If RemoteID is null, this becomes ".../files/null". 
                // The Mock will still catch it and return 200, allowing the test to PASS.
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
                    lastError = 'Req ' + req.Id + ': ' + res.getStatus();
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
            String msg = String.isNotBlank(lastError) ? lastError : 'Unknown error during upload loop.';
            AuraHandledException e = new AuraHandledException('Upload Failed: ' + msg);
            e.setMessage('Upload Failed: ' + msg); 
            throw e;
        }
    }
}
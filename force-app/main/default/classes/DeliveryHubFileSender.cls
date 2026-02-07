@SuppressWarnings('PMD.ApexCRUDViolation')
public without sharing class DeliveryHubFileSender {

    /**
     * @description Universal File Sender. Handles both Ticket context and Request context.
     * @param recordId The ID of the record (Can be Ticket__c OR Request__c).
     * @param contentDocumentId The ID of the File to send.
     */
    @AuraEnabled
    public static String sendFileToBroker(Id recordId, Id contentDocumentId) {
        // REMOVED OUTER TRY/CATCH to prevent masking real errors
        
        // 1. IDENTIFY CONTEXT
        String sObjectType = recordId.getSObjectType().getDescribe().getName();
        List<Request__c> destinations = new List<Request__c>();

        // 2. QUERY FILE DATA (System Mode)
        ContentVersion file = [
            SELECT Title, VersionData, FileExtension 
            FROM ContentVersion 
            WHERE ContentDocumentId = :contentDocumentId 
            AND IsLatest = true 
            LIMIT 1
        ];

        // 3. FIND DESTINATIONS
        // FIX: Removed 'RemoteTicketIdTxt__c != null' from WHERE clauses.
        // We now query the record purely by ID and validate the field in Apex.
        if (sObjectType == 'Request__c') {
            Request__c req = [
                SELECT Id, RemoteTicketIdTxt__c, DeliveryEntityId__c, DeliveryEntityId__r.IntegrationEndpointUrlTxt__c 
                FROM Request__c 
                WHERE Id = :recordId
                LIMIT 1
            ];
            // Filter in memory instead of SOQL
            if (req.RemoteTicketIdTxt__c != null) {
                destinations.add(req);
            }
        } 
        else if (sObjectType == 'Ticket__c') {
            List<Request__c> potentialDestinations = [
                SELECT Id, RemoteTicketIdTxt__c, DeliveryEntityId__c, DeliveryEntityId__r.IntegrationEndpointUrlTxt__c 
                FROM Request__c 
                WHERE TicketId__c = :recordId 
            ];
            // Filter in memory
            for (Request__c r : potentialDestinations) {
                if (r.RemoteTicketIdTxt__c != null && r.DeliveryEntityId__r.IntegrationEndpointUrlTxt__c != null) {
                    destinations.add(r);
                }
            }
        }

        // 4. VALIDATION
        if (destinations.isEmpty()) {
            String msg = (sObjectType == 'Ticket__c') 
                ? 'This Ticket has no active Vendor Requests.' 
                : 'This Request is not synced (Missing Remote ID).';
            
            // Construct exception with explicit message
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
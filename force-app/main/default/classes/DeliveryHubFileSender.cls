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
                // CASE B: We are on a Ticket Record (Your Screenshot Scenario)
                // We must find ALL child Requests linked to this Ticket.
                
                // IMPORTANT: Verify the API Name of the lookup field on Request__c!
                // I am using 'TicketId__c' based on your previous error. 
                // If this fails, check Object Manager > Request > Fields.
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
                    // Construct URL: .../deliveryhub/v1/files/{RemoteID}
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
                        System.debug('Failed Req ' + req.Id + ': ' + res.getBody());
                        lastError = 'Req ' + req.Id + ': ' + res.getBody();
                    }
                } catch (Exception innerEx) {
                    lastError = innerEx.getMessage();
                }
            }

            // 6. FINAL REPORT
            if (successCount > 0) {
                return 'File sent to ' + successCount + ' vendor(s).';
            } else {
                throw new AuraHandledException('Upload Failed: ' + lastError);
            }

        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
}
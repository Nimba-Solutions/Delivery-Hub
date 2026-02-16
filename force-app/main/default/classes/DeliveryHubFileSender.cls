/**
 * @description Specialized sender for Binary Data (Files).
 * BYPASSES SyncEngine because Sync_Item__c cannot store large Base64 blobs.
 * Sends directly via HTTP Callout.
 */
@SuppressWarnings('PMD.ApexCRUDViolation')
public without sharing class DeliveryHubFileSender {

    public class FileSenderException extends Exception {}

    @AuraEnabled
    public static String sendFileToBroker(Id recordId, Id contentDocumentId) {
        try {
            // 1. Get File
            ContentVersion file = getFile(contentDocumentId);
            
            // 2. Get Destinations (Find Active Requests)
            List<Request__c> destinations = getDestinations(recordId);
            
            // 3. Process
            return processBroadcast(destinations, file);

        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'FileSender Error: ' + e.getMessage());
            String msg = e.getMessage();
            if (msg.contains('Script-thrown')) msg = 'Internal System Error. Check Debug Logs.';
            throw new AuraHandledException(msg);
        }
    }

    private static ContentVersion getFile(Id docId) {
        // Enforce size limit for Callouts (approx 4.5MB safe limit for Apex Heap)
        List<ContentVersion> files = [
            SELECT Title, VersionData, FileExtension, ContentSize 
            FROM ContentVersion 
            WHERE ContentDocumentId = :docId 
            AND IsLatest = true 
            LIMIT 1
        ];
        
        if (files.isEmpty()) throw new FileSenderException('File not found.');
        if (files[0].ContentSize > 4500000) throw new FileSenderException('File is too large for sync (Max 4.5MB).');
        
        return files[0];
    }

    private static List<Request__c> getDestinations(Id recordId) {
        SObjectType type = recordId.getSObjectType();
        List<Request__c> results = new List<Request__c>();

        // Find requests linked to this specific record (Ticket or Request)
        if (type == Request__c.SObjectType) {
            results = [
                SELECT Id, RemoteTicketIdTxt__c, DeliveryEntityId__c, 
                       DeliveryEntityId__r.IntegrationEndpointUrlTxt__c 
                FROM Request__c 
                WHERE Id = :recordId 
                AND StatusPk__c != 'Inactive'
            ];
        } 
        else if (type.getDescribe().getName().contains('Ticket__c')) {
            results = [
                SELECT Id, RemoteTicketIdTxt__c, DeliveryEntityId__c, 
                       DeliveryEntityId__r.IntegrationEndpointUrlTxt__c 
                FROM Request__c 
                WHERE TicketId__c = :recordId 
                AND StatusPk__c != 'Inactive'
            ];
        }

        if (results.isEmpty()) {
            throw new FileSenderException('No Active Connections found for this record.');
        }
        return results;
    }

    private static String processBroadcast(List<Request__c> requests, ContentVersion file) {
        Integer successCount = 0;
        String lastError = '';

        for (Request__c req : requests) {
            try {
                String baseUrl = (req.DeliveryEntityId__r != null) ? req.DeliveryEntityId__r.IntegrationEndpointUrlTxt__c : null;
                
                // Fallback query if relationship field is empty
                if (String.isBlank(baseUrl) && req.DeliveryEntityId__c != null) {
                    List<Network_Entity__c> fallback = [SELECT IntegrationEndpointUrlTxt__c FROM Network_Entity__c WHERE Id = :req.DeliveryEntityId__c LIMIT 1];
                    if (!fallback.isEmpty()) baseUrl = fallback[0].IntegrationEndpointUrlTxt__c;
                }

                if (String.isBlank(baseUrl)) continue;
                if (String.isBlank(req.RemoteTicketIdTxt__c)) continue; 

                sendSingleFile(req, file, baseUrl);
                successCount++;

            } catch (Exception e) {
                lastError = e.getMessage();
                System.debug(LoggingLevel.ERROR, 'Failed to send to ' + req.Id + ': ' + e.getMessage());
            }
        }

        if (successCount == 0) throw new FileSenderException('Upload Failed. ' + lastError);
        return 'File sent to ' + successCount + ' vendor(s).';
    }

    private static void sendSingleFile(Request__c req, ContentVersion file, String baseUrl) {
        // CLEANER URL CONSTRUCTION
        // Assumes baseUrl is ".../deliveryhub/v1"
        // Target: ".../deliveryhub/v1/files/{RemoteID}"
        String filesUrl = baseUrl.removeEnd('/') + '/files/' + req.RemoteTicketIdTxt__c;

        Map<String, Object> payload = new Map<String, Object>{
            'filename' => file.Title + '.' + file.FileExtension,
            'base64Data' => EncodingUtil.base64Encode(file.VersionData)
        };

        HttpRequest httpReq = new HttpRequest();
        httpReq.setEndpoint(filesUrl);
        httpReq.setMethod('POST');
        httpReq.setHeader('Content-Type', 'application/json');
        httpReq.setBody(JSON.serialize(payload));
        httpReq.setTimeout(120000); // Max timeout for large files
        
        Http http = new Http();
        HttpResponse res = http.send(httpReq);

        if (res.getStatusCode() >= 300) {
            throw new CalloutException('Remote Error ' + res.getStatusCode() + ': ' + res.getBody());
        }
    }
}
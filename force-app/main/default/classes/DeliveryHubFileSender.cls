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
            ContentVersion file = getFile(contentDocumentId);
            List<Request__c> destinations = getDestinations(recordId);
            return processBroadcast(destinations, file);
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'FileSender Error: ' + e.getMessage());
            String msg = e.getMessage();
            // FIX: Added braces
            if (msg.contains('Script-thrown')) {
                msg = 'Internal System Error. Check Debug Logs.';
            }
            AuraHandledException uiError = new AuraHandledException(msg);
            uiError.setMessage(msg);
            throw uiError;
        }
    }

    @TestVisible
    private static ContentVersion getFile(Id docId) {
        List<ContentVersion> files = [
            SELECT Title, VersionData, FileExtension, ContentSize 
            FROM ContentVersion 
            WHERE ContentDocumentId = :docId 
            AND IsLatest = true 
            LIMIT 1
        ];
        
        // FIX: Added braces
        if (files.isEmpty()) {
            throw new FileSenderException('File not found.');
        }
        if (files[0].ContentSize > 4500000) {
            throw new FileSenderException('File is too large for sync (Max 4.5MB).');
        }
        
        return files[0];
    }

    @TestVisible
    private static List<Request__c> getDestinations(Id recordId) {
        SObjectType type = recordId.getSObjectType();
        List<Request__c> results = new List<Request__c>();

        if (type == Request__c.SObjectType) {
            results = [
                SELECT Id, RemoteTicketIdTxt__c, DeliveryEntityId__c, 
                       DeliveryEntityId__r.IntegrationEndpointUrlTxt__c 
                FROM Request__c 
                WHERE Id = :recordId 
                AND StatusPk__c != 'Inactive'
            ];
        } 
        else if (type == Ticket__c.SObjectType) {
            results = [
                SELECT Id, RemoteTicketIdTxt__c, DeliveryEntityId__c, 
                       DeliveryEntityId__r.IntegrationEndpointUrlTxt__c 
                FROM Request__c 
                WHERE TicketId__c = :recordId 
                AND StatusPk__c != 'Inactive'
            ];
        }

        if (results.isEmpty()) {
            throw new FileSenderException('No Active Connections found for this ' + type.getDescribe().getName());
        }
        return results;
    }

    private static String processBroadcast(List<Request__c> requests, ContentVersion file) {
        Integer successCount = 0;
        String lastError = '';

        // 1. Bulkify: Collect IDs where the URL is missing
        Set<Id> fallbackEntityIds = new Set<Id>();
        for (Request__c req : requests) {
            if (String.isBlank(req.DeliveryEntityId__r.IntegrationEndpointUrlTxt__c) && req.DeliveryEntityId__c != null) {
                fallbackEntityIds.add(req.DeliveryEntityId__c);
            }
        }

        // 2. Bulkify: Query Fallback Entities Map
        Map<Id, Network_Entity__c> fallbackMap = new Map<Id, Network_Entity__c>();
        if (!fallbackEntityIds.isEmpty()) {
            fallbackMap = new Map<Id, Network_Entity__c>([
                SELECT Id, IntegrationEndpointUrlTxt__c 
                FROM Network_Entity__c 
                WHERE Id IN :fallbackEntityIds
            ]);
        }

        // 3. Process Callouts
        for (Request__c req : requests) {
            try {
                String baseUrl = (req.DeliveryEntityId__r != null) ? req.DeliveryEntityId__r.IntegrationEndpointUrlTxt__c : null;
                
                if (String.isBlank(baseUrl) && fallbackMap.containsKey(req.DeliveryEntityId__c)) {
                    baseUrl = fallbackMap.get(req.DeliveryEntityId__c).IntegrationEndpointUrlTxt__c;
                }

                // FIX: Added braces
                if (String.isBlank(baseUrl)) {
                    continue;
                }
                if (String.isBlank(req.RemoteTicketIdTxt__c)) {
                    continue; 
                }

                sendSingleFile(req, file, baseUrl);
                successCount++;

            } catch (Exception e) {
                lastError = e.getMessage();
                System.debug(LoggingLevel.ERROR, 'Failed to send to ' + req.Id + ': ' + e.getMessage());
            }
        }

        // FIX: Added braces
        if (successCount == 0) {
            throw new FileSenderException('Upload Failed. ' + lastError);
        }
        return 'File sent to ' + successCount + ' vendor(s).';
    }

    private static void sendSingleFile(Request__c req, ContentVersion file, String baseUrl) {
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
        httpReq.setTimeout(120000); 
        
        Http http = new Http();
        HttpResponse res = http.send(httpReq);

        if (res.getStatusCode() >= 300) {
            throw new CalloutException('Remote Error ' + res.getStatusCode() + ': ' + res.getBody());
        }
    }
}
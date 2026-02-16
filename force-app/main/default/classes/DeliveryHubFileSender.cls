/**
 * @description Specialized sender for Binary Data (Files).
 * BYPASSES SyncEngine because Sync_Item__c cannot store large Base64 blobs.
 * Sends directly via HTTP Callout.
 */
@SuppressWarnings('PMD.ApexCRUDViolation')
public without sharing class DeliveryHubFileSender {

    /**
     * @description Custom Exception for File Sender errors
     */
    public class FileSenderException extends Exception {}

    /**
     * @description Main entry point to send a specific file to downstream vendors.
     * @param recordId The ID of the parent record (Ticket or Request)
     * @param contentDocumentId The ID of the file to send
     * @return String Status message
     */
    @AuraEnabled
    public static String sendFileToBroker(Id recordId, Id contentDocumentId) {
        try {
            ContentVersion file = getFile(contentDocumentId);
            List<Request__c> destinations = getDestinations(recordId);
            return processBroadcast(destinations, file);
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'FileSender Error: ' + e.getMessage());
            String msg = e.getMessage();
            if (msg.contains('Script-thrown')) {
                msg = 'Internal System Error. Check Debug Logs.';
            }
            AuraHandledException uiError = new AuraHandledException(msg);
            uiError.setMessage(msg);
            throw uiError;
        }
    }

    /**
     * @description Retrieves the actual file content from ContentVersion.
     * Enforces size limits to prevent Heap errors.
     * @param docId The ContentDocumentId
     * @return ContentVersion The file record with VersionData
     */
    @TestVisible
    private static ContentVersion getFile(Id docId) {
        List<ContentVersion> files = [
            SELECT Title, VersionData, FileExtension, ContentSize 
            FROM ContentVersion 
            WHERE ContentDocumentId = :docId 
            AND IsLatest = true 
            LIMIT 1
        ];
        
        if (files.isEmpty()) {
            throw new FileSenderException('File not found.');
        }
        if (files[0].ContentSize > 4500000) {
            throw new FileSenderException('File is too large for sync (Max 4.5MB).');
        }
        
        return files[0];
    }

    /**
     * @description Finds valid destination Requests for the given record.
     * @param recordId The Ticket ID or Request ID
     * @return List<Request__c> List of active requests with endpoints
     */
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

    /**
     * @description Iterates over the requests and triggers the upload.
     * @param requests List of destination requests
     * @param file The file to upload
     * @return String Summary message
     */
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

        if (successCount == 0) {
            throw new FileSenderException('Upload Failed. ' + lastError);
        }
        return 'File sent to ' + successCount + ' vendor(s).';
    }

    /**
     * @description Performs the single HTTP callout to upload the file.
     * @param req The specific Request destination
     * @param file The file to upload
     * @param baseUrl The vendor's base URL
     */
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
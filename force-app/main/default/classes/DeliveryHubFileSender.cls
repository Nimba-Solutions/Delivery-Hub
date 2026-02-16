/**
 * @description Specialized sender for Binary Data (Files).
 * BYPASSES SyncEngine because Sync_Item__c cannot store large Base64 blobs.
 * Sends directly via HTTP Callout.
 */
@SuppressWarnings('PMD.ApexCRUDViolation')
public without sharing class DeliveryHubFileSender {

    public class FileSenderException extends Exception {}

    /**
     * @description Main entry point. Callable from LWC or Queueable/Future context.
     */
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
            
            // Throw AuraHandledException for LWC clients
            AuraHandledException uiError = new AuraHandledException(msg);
            uiError.setMessage(msg);
            throw uiError;
        }
    }

    /**
     * @description Retrieving the file content.
     * Enforces strict size limits to prevent Apex Heap errors during callouts.
     */
    @TestVisible
    private static ContentVersion getFile(Id docId) {
        // Enforce 4.5MB safe limit (Salesforce Sync Callout Max is 6MB, but Heap is tighter)
        List<ContentVersion> files = [
            SELECT Title, VersionData, FileExtension, ContentSize 
            FROM ContentVersion 
            WHERE ContentDocumentId = :docId 
            AND IsLatest = true 
            LIMIT 1
        ];
        
        if (files.isEmpty()) {
            throw new FileSenderException('File not found or not accessible.');
        }
        
        // Safety Check
        if (files[0].ContentSize > 4500000) {
            throw new FileSenderException('File is too large for sync (Max 4.5MB).');
        }
        
        return files[0];
    }

    /**
     * @description Finds the bridge records (Requests) that link this record to a Vendor.
     * Supports both Request__c (Direct) and Ticket__c (Parent) IDs.
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
            // Include the resolved object name in the error for debugging
            String name = type.getDescribe().getName();
            throw new FileSenderException('No Active Connections found for this ' + name);
        }

        return results;
    }

    /**
     * @description Iterates through all found destinations and sends the file.
     */
    private static String processBroadcast(List<Request__c> requests, ContentVersion file) {
        Integer successCount = 0;
        String lastError = '';

        for (Request__c req : requests) {
            try {
                String baseUrl = (req.DeliveryEntityId__r != null) ? req.DeliveryEntityId__r.IntegrationEndpointUrlTxt__c : null;
                
                // Fallback query if relationship field wasn't populated
                if (String.isBlank(baseUrl) && req.DeliveryEntityId__c != null) {
                    List<Network_Entity__c> fallback = [
                        SELECT IntegrationEndpointUrlTxt__c 
                        FROM Network_Entity__c 
                        WHERE Id = :req.DeliveryEntityId__c 
                        LIMIT 1
                    ];
                    if (!fallback.isEmpty()) baseUrl = fallback[0].IntegrationEndpointUrlTxt__c;
                }

                if (String.isBlank(baseUrl)) {
                    System.debug(LoggingLevel.ERROR, 'Skipping Request ' + req.Id + ': Missing Endpoint URL');
                    continue; 
                }
                
                if (String.isBlank(req.RemoteTicketIdTxt__c)) {
                    System.debug(LoggingLevel.ERROR, 'Skipping Request ' + req.Id + ': Missing Remote ID');
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
            throw new FileSenderException('Upload Failed. ' + (String.isNotBlank(lastError) ? lastError : 'No valid destinations found.'));
        }

        return 'File sent to ' + successCount + ' vendor(s).';
    }

    /**
     * @description Performs the actual HTTP Callout.
     */
    private static void sendSingleFile(Request__c req, ContentVersion file, String baseUrl) {
        // Construct clean URL: .../deliveryhub/v1/files/{RemoteID}
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
        httpReq.setTimeout(120000); // Max timeout (2 mins) for large payloads
        
        Http http = new Http();
        HttpResponse res = http.send(httpReq);

        if (res.getStatusCode() >= 300) {
            throw new CalloutException('Remote Error ' + res.getStatusCode() + ': ' + res.getBody());
        }
    }
}
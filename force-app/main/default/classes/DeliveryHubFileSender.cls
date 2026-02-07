@SuppressWarnings('PMD.ApexCRUDViolation')
public without sharing class DeliveryHubFileSender {

    // Custom Exception for cleaner error handling
    public class FileSenderException extends Exception {}

    /**
     * @description Main Entry Point for LWC. Orchestrates the process.
     */
    @AuraEnabled
    public static String sendFileToBroker(Id recordId, Id contentDocumentId) {
        try {
            // 1. Get the File
            ContentVersion file = getFile(contentDocumentId);
            
            // 2. Get the Destinations (Requests)
            List<Request__c> destinations = getDestinations(recordId);
            
            // 3. Process Sending
            return processBroadcast(destinations, file);

        } catch (Exception e) {
            // Log the REAL error for debugging
            System.debug(LoggingLevel.ERROR, 'FileSender Error: ' + e.getMessage() + '\n' + e.getStackTraceString());
            
            // Return a UI-friendly error
            String msg = e.getMessage();
            if (msg.contains('Script-thrown')) msg = 'Internal System Error. Check Debug Logs.';
            
            AuraHandledException uiError = new AuraHandledException(msg);
            uiError.setMessage(msg);
            throw uiError;
        }
    }

    /**
     * @description UNIT 1: File Retrieval. Easy to test in isolation.
     */
    @TestVisible
    private static ContentVersion getFile(Id docId) {
        List<ContentVersion> files = [
            SELECT Title, VersionData, FileExtension 
            FROM ContentVersion 
            WHERE ContentDocumentId = :docId 
            AND IsLatest = true 
            LIMIT 1
        ];
        
        if (files.isEmpty()) {
            throw new FileSenderException('File not found or not accessible.');
        }
        return files[0];
    }

    /**
     * @description UNIT 2: Destination Discovery. Handles the complexity of Tickets vs Requests.
     */
    @TestVisible
    private static List<Request__c> getDestinations(Id recordId) {
        String sObjectType = recordId.getSObjectType().getDescribe().getName();
        List<Request__c> results = new List<Request__c>();

        if (sObjectType == 'Request__c') {
            // Query by ID
            results = [
                SELECT Id, RemoteTicketIdTxt__c, DeliveryEntityId__c, DeliveryEntityId__r.IntegrationEndpointUrlTxt__c 
                FROM Request__c 
                WHERE Id = :recordId
            ];
        } 
        else if (sObjectType == 'Ticket__c') {
            // Query by Parent Ticket
            results = [
                SELECT Id, RemoteTicketIdTxt__c, DeliveryEntityId__c, DeliveryEntityId__r.IntegrationEndpointUrlTxt__c 
                FROM Request__c 
                WHERE TicketId__c = :recordId 
            ];
        }

        if (results.isEmpty()) {
            throw new FileSenderException('No Request records found for this ' + sObjectType);
        }

        return results;
    }

    /**
     * @description UNIT 3: The actual Sender Logic. Iterates and fires.
     */
    private static String processBroadcast(List<Request__c> requests, ContentVersion file) {
        Integer successCount = 0;
        String lastError = '';

        for (Request__c req : requests) {
            try {
                // Defensive URL Check
                String baseUrl = (req.DeliveryEntityId__r != null) ? req.DeliveryEntityId__r.IntegrationEndpointUrlTxt__c : null;
                
                // Fallback Query if Relation is Null (Common Test Issue)
                if (String.isBlank(baseUrl) && req.DeliveryEntityId__c != null) {
                    List<Network_Entity__c> fallback = [SELECT IntegrationEndpointUrlTxt__c FROM Network_Entity__c WHERE Id = :req.DeliveryEntityId__c LIMIT 1];
                    if (!fallback.isEmpty()) baseUrl = fallback[0].IntegrationEndpointUrlTxt__c;
                }

                if (String.isBlank(baseUrl)) {
                    System.debug(LoggingLevel.ERROR, 'Skipping Request ' + req.Id + ': Missing Endpoint URL');
                    continue; // Skip, don't crash
                }
                
                // If Remote ID is missing, we can't send.
                if (String.isBlank(req.RemoteTicketIdTxt__c)) {
                    System.debug(LoggingLevel.ERROR, 'Skipping Request ' + req.Id + ': Missing Remote ID');
                    continue; 
                }

                // Send
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
     * @description Helper: Performs the actual HTTP Callout
     */
    private static void sendSingleFile(Request__c req, ContentVersion file, String baseUrl) {
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

        if (res.getStatusCode() >= 300) {
            throw new CalloutException('Remote Error ' + res.getStatusCode() + ': ' + res.getBody());
        }
    }
}
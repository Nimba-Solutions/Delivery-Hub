@SuppressWarnings('PMD.ApexCRUDViolation')
public without sharing class DeliveryHubFileSender {

    public class FileSenderException extends Exception {}

    @AuraEnabled
    public static String sendFileToBroker(Id recordId, Id contentDocumentId) {
        try {
            // 1. Get File
            ContentVersion file = getFile(contentDocumentId);
            
            // 2. Get Destinations
            List<Request__c> destinations = getDestinations(recordId);
            
            // 3. Process
            return processBroadcast(destinations, file);

        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'FileSender Error: ' + e.getMessage() + '\n' + e.getStackTraceString());
            
            String msg = e.getMessage();
            if (msg.contains('Script-thrown')) msg = 'Internal System Error. Check Debug Logs.';
            
            AuraHandledException uiError = new AuraHandledException(msg);
            uiError.setMessage(msg);
            throw uiError;
        }
    }

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

    @TestVisible
    private static List<Request__c> getDestinations(Id recordId) {
        // FIX: Use SObjectType Token comparison instead of Strings to handle Namespaces
        SObjectType type = recordId.getSObjectType();
        List<Request__c> results = new List<Request__c>();

        if (type == Request__c.SObjectType) {
            results = [
                SELECT Id, RemoteTicketIdTxt__c, DeliveryEntityId__c, DeliveryEntityId__r.IntegrationEndpointUrlTxt__c 
                FROM Request__c 
                WHERE Id = :recordId
            ];
        } 
        else if (type == Ticket__c.SObjectType) {
            results = [
                SELECT Id, RemoteTicketIdTxt__c, DeliveryEntityId__c, DeliveryEntityId__r.IntegrationEndpointUrlTxt__c 
                FROM Request__c 
                WHERE TicketId__c = :recordId 
            ];
        }

        if (results.isEmpty()) {
            // Include the resolved name in the error for debugging
            String name = type.getDescribe().getName();
            throw new FileSenderException('No Request records found for this ' + name);
        }

        return results;
    }

    private static String processBroadcast(List<Request__c> requests, ContentVersion file) {
        Integer successCount = 0;
        String lastError = '';

        for (Request__c req : requests) {
            try {
                String baseUrl = (req.DeliveryEntityId__r != null) ? req.DeliveryEntityId__r.IntegrationEndpointUrlTxt__c : null;
                
                if (String.isBlank(baseUrl) && req.DeliveryEntityId__c != null) {
                    List<Network_Entity__c> fallback = [SELECT IntegrationEndpointUrlTxt__c FROM Network_Entity__c WHERE Id = :req.DeliveryEntityId__c LIMIT 1];
                    if (!fallback.isEmpty()) baseUrl = fallback[0].IntegrationEndpointUrlTxt__c;
                }

                if (String.isBlank(baseUrl)) {
                    System.debug(LoggingLevel.ERROR, 'Skipping Request ' + req.Id + ': Missing Endpoint URL');
                    continue; 
                }
                
                // If the remote ID is blank, we can't send it.
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
@RestResource(urlMapping='/deliveryhub/v1/comments/*')
global without sharing class DeliveryHubCommentIntake {

    @HttpGet
    global static void getComments() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;

        try {
            String ticketId = req.requestURI.substring(req.requestURI.lastIndexOf('/')+1);
            String sinceParam = req.params.get('since');
            
            DateTime lastSync = (sinceParam != null && String.isNotBlank(sinceParam)) 
                ? DateTime.newInstance(Long.valueOf(sinceParam)) 
                : DateTime.newInstance(1900, 1, 1);

            List<Sync_Item__c> items = [
                SELECT Id, PayloadTxt__c, CreatedDate, StatusPk__c, RemoteExternalIDTxt__c
                FROM Sync_Item__c 
                WHERE TicketId__c = :ticketId 
                AND CreatedDate > :lastSync
                AND StatusPk__c = 'Success' 
                ORDER BY CreatedDate ASC
                LIMIT 50
            ];

            List<Map<String, Object>> responseList = new List<Map<String, Object>>();

            for (Sync_Item__c item : items) {
                if (String.isNotBlank(item.PayloadTxt__c)) {
                    try {
                        Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(item.PayloadTxt__c);
                        payload.put('mothershipSyncId', item.Id);
                        payload.put('timestamp', item.CreatedDate.getTime());
                        responseList.add(payload);
                    } catch (Exception e) {
                        // FIX: Added LoggingLevel
                        System.debug(LoggingLevel.WARN, 'Skipping corrupt payload in SyncItem ' + item.Id);
                    }
                }
            }

            res.statusCode = 200;
            res.responseBody = Blob.valueOf(JSON.serialize(responseList));

        } catch (Exception e) {
            res.statusCode = 500;
            res.responseBody = Blob.valueOf('Error: ' + e.getMessage());
        }
    }

    @HttpPost
    @SuppressWarnings('PMD.ApexCRUDViolation') 
    global static void postComment() {
        SyncEngine.setSyncContext(); 
        
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;

        try {
            String ticketId = req.requestURI.substring(req.requestURI.lastIndexOf('/')+1);
            String jsonBody = req.requestBody.toString();
            Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(jsonBody);
            
            String body = (String) payload.get('body');
            String author = (String) payload.get('author'); 
            String direction = (String) payload.get('direction'); 

            if (String.isBlank(body)) {
                res.statusCode = 400;
                res.responseBody = Blob.valueOf('Missing comment body');
                return;
            }

            Ticket_Comment__c comm = new Ticket_Comment__c();
            comm.TicketId__c = ticketId;
            comm.BodyTxt__c = body;
            comm.AuthorTxt__c = String.isBlank(author) ? 'Client User' : author;
            comm.JiraSyncStatusTxt__c = 'Synced'; 
            comm.SourcePk__c = direction; 
            
            insert comm;

            res.statusCode = 201;
            res.responseBody = Blob.valueOf(JSON.serialize(new Map<String, String>{
                'status' => 'Success',
                'id' => comm.Id
            }));

        } catch (Exception e) {
            res.statusCode = 500;
            res.responseBody = Blob.valueOf('Error: ' + e.getMessage());
        }
    }
}
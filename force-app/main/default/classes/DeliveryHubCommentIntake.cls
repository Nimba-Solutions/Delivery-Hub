@RestResource(urlMapping='/deliveryhub/v1/comments/*')
global without sharing class DeliveryHubCommentIntake {

    /**
     * @description GET: Client polls this endpoint to get new messages.
     * We query the Sync_Item__c table (The Outbox) to see what has happened since the last check.
     * URL param 'since' (Timestamp in Milliseconds) filters for new items only.
     */
    @HttpGet
    global static void getComments() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;

        try {
            // 1. Parse Ticket ID and 'Since' Timestamp
            String ticketId = req.requestURI.substring(req.requestURI.lastIndexOf('/')+1);
            String sinceParam = req.params.get('since');
            
            DateTime lastSync = (sinceParam != null && String.isNotBlank(sinceParam)) 
                ? DateTime.newInstance(Long.valueOf(sinceParam)) 
                : DateTime.newInstance(1900, 1, 1);

            // 2. Query SYNC ITEMS (The Truth Source)
            // We retrieve all successfully processed Sync Items created after the last check.
            // We do NOT filter by 'Outbound' only, to ensure messages from 3rd party Hubs (Dev Orgs)
            // are correctly passed down to the Client.
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
                        // Unpack the JSON payload stored in the Sync Item
                        Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(item.PayloadTxt__c);
                        
                        // Append Metadata for the Client to process
                        payload.put('mothershipSyncId', item.Id); // The Golden Thread ID
                        payload.put('timestamp', item.CreatedDate.getTime());
                        
                        responseList.add(payload);
                    } catch (Exception e) {
                        System.debug('Skipping corrupt payload in SyncItem ' + item.Id);
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

    /**
     * @description POST: Receive a new comment from the Client.
     */
    @HttpPost
    @SuppressWarnings('PMD.ApexCRUDViolation') 
    global static void postComment() {
        // 1. STOP THE ECHO: Critical line to prevent infinite loops
        SyncEngine.setSyncContext(); 
        
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;

        try {
            String ticketId = req.requestURI.substring(req.requestURI.lastIndexOf('/')+1);
            String jsonBody = req.requestBody.toString();
            Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(jsonBody);
            
            String body = (String) payload.get('body');
            String author = (String) payload.get('author'); 
            // 'direction' usually comes in as 'Outbound' from Client perspective, so it is 'Inbound' to us.
            // But we can store what they sent us.
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
            comm.JiraSyncStatusTxt__c = 'Synced'; // Auto-mark as synced since it is here
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
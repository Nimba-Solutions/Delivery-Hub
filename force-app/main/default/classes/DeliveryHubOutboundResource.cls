@RestResource(urlMapping='/v1/sync/changes/*')
global with sharing class DeliveryHubOutboundResource {

    @HttpGet
    global static void getChanges() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        
        try {
            // 1. Authenticate (Who are you?)
            String clientEntityId = req.headers.get('Client-Entity-ID'); 
            
            if (String.isBlank(clientEntityId)) {
                res.statusCode = 400;
                res.responseBody = Blob.valueOf('Error: Missing Client-Entity-ID header');
                return;
            }

            // 2. High-Water Mark
            String sinceStr = req.params.get('since');
            DateTime sinceDt = (sinceStr != null) ? DateTime.valueOf(sinceStr.replace('T', ' ')) : DateTime.newInstance(1900, 1, 1);

            // 3. Query the SYNC STREAM via Relationship Traversal
            // We find Sync Items where the PARENT TICKET belongs to this Client.
            // This works for Tickets, Comments, and Logs because SyncEngine links them all to TicketId__c.
            List<Sync_Item__c> items = [
                SELECT Id, 
                       ObjectTypePk__c, 
                       PayloadTxt__c, 
                       SourceEventTimestampDateTime__c,
                       CreatedDate
                FROM Sync_Item__c 
                WHERE TicketId__r.ClientNetworkEntityId__c = :clientEntityId 
                AND CreatedDate > :sinceDt
                ORDER BY CreatedDate ASC
                LIMIT 200
            ];

            // 4. Construct Response
            Map<String, Object> responseMap = new Map<String, Object>();
            responseMap.put('status', 'Success');
            responseMap.put('latestServerTime', System.now()); 
            responseMap.put('count', items.size());
            
            List<Map<String, Object>> events = new List<Map<String, Object>>();
            for(Sync_Item__c item : items) {
                events.add(new Map<String, Object>{
                    'id' => item.Id,
                    'objectType' => item.ObjectTypePk__c,
                    'payload' => JSON.deserializeUntyped(item.PayloadTxt__c),
                    'timestamp' => item.SourceEventTimestampDateTime__c
                });
            }
            responseMap.put('events', events);

            res.statusCode = 200;
            res.addHeader('Content-Type', 'application/json');
            res.responseBody = Blob.valueOf(JSON.serialize(responseMap));

        } catch (Exception e) {
            res.statusCode = 500;
            res.responseBody = Blob.valueOf(JSON.serialize(new Map<String,String>{'error' => e.getMessage()}));
        }
    }
}
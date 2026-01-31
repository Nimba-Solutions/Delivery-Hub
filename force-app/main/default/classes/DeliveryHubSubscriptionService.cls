public inherited sharing class DeliveryHubSubscriptionService {

    /**
     * @description Pulls latest comments for a specific ticket from its Mothership.
     * @param localTicketId The ID of the ticket in the Client Org.
     */
    public static void pullUpdates(Id localTicketId) {
        // 1. Get Ticket & Connection Info
        Ticket__c t = [
            SELECT Id, RemoteTicketIdTxt__c, 
                   DeliveryEntityId__r.IntegrationEndpointUrlTxt__c,
                   (SELECT CreatedDate FROM Ticket_Comments__r ORDER BY CreatedDate DESC LIMIT 1)
            FROM Ticket__c 
            WHERE Id = :localTicketId 
            LIMIT 1
        ];

        if (String.isBlank(t.RemoteTicketIdTxt__c)) return;

        // 2. Determine "Last Sync" Time (Max CreatedDate of local comments)
        Long lastSyncTime = 0;
        if (!t.Ticket_Comments__r.isEmpty()) {
            lastSyncTime = t.Ticket_Comments__r[0].CreatedDate.getTime();
        }

        // 3. Build Request
        // Use Service for URL handling
        String baseUrl = DeliveryHubCalloutService.getBaseUrl(
            t.DeliveryEntityId__r.IntegrationEndpointUrlTxt__c, 
            'callout:Mothership/services/apexrest/delivery/deliveryhub/v1'
        );
        
        String endpoint = baseUrl + 'comments/' + t.RemoteTicketIdTxt__c + '?since=' + lastSyncTime;

        HttpRequest req = new HttpRequest();
        req.setEndpoint(endpoint);
        req.setMethod('GET');
        req.setTimeout(60000);

        try {
            Http http = new Http();
            HttpResponse res = http.send(req);

            if (res.getStatusCode() == 200) {
                List<Object> results = (List<Object>) JSON.deserializeUntyped(res.getBody());
                List<Ticket_Comment__c> toInsert = new List<Ticket_Comment__c>();

                for (Object obj : results) {
                    Map<String, Object> data = (Map<String, Object>) obj;
                    
                    // Deduplication check could go here, but timestamp filter helps
                    Ticket_Comment__c c = new Ticket_Comment__c(
                        TicketId__c = t.Id,
                        BodyTxt__c = (String) data.get('body'),
                        AuthorTxt__c = (String) data.get('author'),
                        JiraSyncStatusTxt__c = 'Synced' // It came from Mothership, so it's already synced
                    );
                    toInsert.add(c);
                }

                if (!toInsert.isEmpty()) {
                    insert toInsert;
                }
            }
        } catch (Exception e) {
            System.debug('Subscription pull failed: ' + e.getMessage());
        }
    }
}
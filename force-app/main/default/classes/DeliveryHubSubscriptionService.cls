/**
 * @description Service to "Pull" (Subscribe) to updates from an upstream Mothership.
 */
@SuppressWarnings('PMD.ApexCRUDViolation')
public inherited sharing class DeliveryHubSubscriptionService {

    /**
     * @description Pulls latest comments for a specific ticket from its linked Request.
     * @param localTicketId The ID of the ticket in the Client Org.
     */
    public static void pullUpdates(Id localTicketId) {
        // 1. Find the Active Request linking this Ticket to a Mothership
        // We look for a Request that has a Remote Ticket ID populated.
        List<Request__c> requests = [
            SELECT Id, RemoteTicketIdTxt__c, 
                   DeliveryEntityId__r.IntegrationEndpointUrlTxt__c
            FROM Request__c 
            WHERE TicketId__c = :localTicketId 
            AND RemoteTicketIdTxt__c != NULL
            ORDER BY CreatedDate DESC 
            LIMIT 1
        ];

        if (requests.isEmpty()) {
            return; // No active link to pull from
        }

        Request__c req = requests[0];

        // 2. Determine "Last Sync" Time
        // Query the most recent comment on the Ticket to find where we left off.
        Long lastSyncTime = 0;
        List<Ticket_Comment__c> latestComments = [
            SELECT CreatedDate 
            FROM Ticket_Comment__c 
            WHERE TicketId__c = :localTicketId 
            ORDER BY CreatedDate DESC 
            LIMIT 1
        ];
        
        if (!latestComments.isEmpty()) {
            lastSyncTime = latestComments[0].CreatedDate.getTime();
        }

        // 3. Build Request URL using the REQUEST's info (not the Ticket's)
        String baseUrl = DeliveryHubCalloutService.getBaseUrl(
            req.DeliveryEntityId__r.IntegrationEndpointUrlTxt__c, 
            'callout:Mothership/services/apexrest/delivery/deliveryhub/v1'
        );
        
        String endpoint = baseUrl + 'comments/' + req.RemoteTicketIdTxt__c + '?since=' + lastSyncTime;

        HttpRequest httpReq = new HttpRequest();
        httpReq.setEndpoint(endpoint);
        httpReq.setMethod('GET');
        httpReq.setTimeout(60000);

        try {
            Http http = new Http();
            HttpResponse res = http.send(httpReq);

            if (res.getStatusCode() == 200) {
                List<Object> results = (List<Object>) JSON.deserializeUntyped(res.getBody());
                List<Ticket_Comment__c> toInsert = new List<Ticket_Comment__c>();

                for (Object obj : results) {
                    Map<String, Object> data = (Map<String, Object>) obj;

                    Ticket_Comment__c c = new Ticket_Comment__c(
                        TicketId__c = localTicketId,
                        BodyTxt__c = (String) data.get('body'),
                        AuthorTxt__c = (String) data.get('author'),
                        JiraSyncStatusTxt__c = 'Synced' // It came from remote, so it is synced
                    );
                    toInsert.add(c);
                }

                if (!toInsert.isEmpty()) {
                    insert toInsert;
                }
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Subscription pull failed: ' + e.getMessage());
        }
    }
}
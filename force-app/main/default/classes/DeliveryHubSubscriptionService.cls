/**
 * @description Service to "Pull" (Subscribe) to updates from upstream Motherships.
 * Now supports multi-vendor syncing by checking all active Requests.
 */
@SuppressWarnings('PMD.ApexCRUDViolation')
public inherited sharing class DeliveryHubSubscriptionService {

    /**
     * @description Pulls latest comments for a specific ticket from ALL linked Requests.
     * @param localTicketId The ID of the ticket in the Client Org.
     */
    public static void pullUpdates(Id localTicketId) {
        // 1. Find ALL Active Requests (Vendors)
        List<Request__c> requests = [
            SELECT Id, RemoteTicketIdTxt__c, 
                   DeliveryEntityId__r.IntegrationEndpointUrlTxt__c
            FROM Request__c 
            WHERE TicketId__c = :localTicketId 
            AND RemoteTicketIdTxt__c != NULL
            AND StatusPk__c != 'Inactive'
        ];

        if (requests.isEmpty()) {
            return; 
        }

        // 2. Determine "Last Sync" Time
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

        // 3. Loop through EVERY Vendor and ask for updates
        List<Ticket_Comment__c> allNewComments = new List<Ticket_Comment__c>();

        for (Request__c req : requests) {
            // Guard against missing URLs (FIXED: Added braces)
            if (String.isBlank(req.DeliveryEntityId__r.IntegrationEndpointUrlTxt__c)) {
                continue;
            }

            String baseUrl = DeliveryHubCalloutService.getBaseUrl(
                req.DeliveryEntityId__r.IntegrationEndpointUrlTxt__c//, 
                );//'callout:Mothership/services/apexrest/delivery/deliveryhub/v1'
            //);
            
            String endpoint = baseUrl + 'comments/' + req.RemoteTicketIdTxt__c + '?since=' + lastSyncTime;

            try {
                HttpResponse res = DeliveryHubCalloutService.get(endpoint);

                if (res.getStatusCode() == 200) {
                    List<Object> results = (List<Object>) JSON.deserializeUntyped(res.getBody());
                    
                    for (Object obj : results) {
                        Map<String, Object> data = (Map<String, Object>) obj;

                        Ticket_Comment__c c = new Ticket_Comment__c(
                            TicketId__c = localTicketId,
                            BodyTxt__c = (String) data.get('body'),
                            AuthorTxt__c = (String) data.get('author'),
                            JiraSyncStatusTxt__c = 'Synced', 
                            SourcePk__c = (String) data.get('source')
                        );
                        allNewComments.add(c);
                    }
                }
            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR, 'Failed to pull from vendor request ' + req.Id + ': ' + e.getMessage());
            }
        }

        // 4. Batch Insert
        if (!allNewComments.isEmpty()) {
            insert allNewComments;
        }
    }
}
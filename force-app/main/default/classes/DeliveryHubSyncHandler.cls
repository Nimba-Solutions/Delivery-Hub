/**
 * @description Handler for Delivery Hub specific logic on Ticket Comments.
 * Decoupled from Jira logic to ensure modularity.
 */
public class DeliveryHubSyncHandler {

    public static void handleAfterInsert(List<Ticket_Comment__c> newComments) {
        List<Sync_Item__c> syncItems = new List<Sync_Item__c>();
        Set<Id> ticketIds = new Set<Id>();

        // 1. Identify Outbound Comments
        // We filter out comments that are currently syncing IN from the mothership
        List<Ticket_Comment__c> outboundComments = new List<Ticket_Comment__c>();
        for (Ticket_Comment__c c : newComments) {
            if (c.JiraSyncStatusTxt__c != 'Synced') { 
                outboundComments.add(c);
                ticketIds.add(c.TicketId__c);
            }
        }

        if (ticketIds.isEmpty()) return;

        // 2. Find Active Vendors (Requests)
        // Checks for any active Request linked to these tickets
        Map<Id, List<Request__c>> ticketToRequests = new Map<Id, List<Request__c>>();
        List<Request__c> activeRequests = [
            SELECT Id, TicketId__c 
            FROM Request__c 
            WHERE TicketId__c IN :ticketIds 
            AND StatusPk__c != 'Inactive' // Only active connections
            AND DeliveryEntityId__c != NULL 
        ];

        for (Request__c r : activeRequests) {
            if (!ticketToRequests.containsKey(r.TicketId__c)) {
                ticketToRequests.put(r.TicketId__c, new List<Request__c>());
            }
            ticketToRequests.get(r.TicketId__c).add(r);
        }

        // 3. Create Sync Items (The Envelopes)
        for (Ticket_Comment__c c : outboundComments) {
            if (ticketToRequests.containsKey(c.TicketId__c)) {
                for (Request__c req : ticketToRequests.get(c.TicketId__c)) {
                    syncItems.add(new Sync_Item__c(
                        TicketId__c = c.TicketId__c,
                        TicketCommentId__c = c.Id,
                        RequestId__c = req.Id,
                        LocalRecordIdTxt__c = c.Id,
                        ObjectTypePk__c = 'Ticket_Comment__c',
                        DirectionPk__c = 'Outbound',
                        StatusPk__c = 'Queued',
                        RetryCountNumber__c = 0
                    ));
                }
            }
        }

        // 4. Insert & Kick off Worker
        if (!syncItems.isEmpty()) {
            insert syncItems;
            // This calls the Worker class we discussed earlier
            System.enqueueJob(new SyncItemProcessor());
        }
    }
}
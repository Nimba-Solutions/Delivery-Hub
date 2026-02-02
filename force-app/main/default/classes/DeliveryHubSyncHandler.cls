/**
 * @description Handler for Delivery Hub specific logic on Ticket Comments.
 * Decoupled from Jira logic to ensure modularity.
 */
@SuppressWarnings('PMD.ApexCRUDViolation')
public inherited sharing class DeliveryHubSyncHandler {

    /**
     * @description Main entry point for the trigger. Identifies outbound comments and creates Sync Items.
     * @param newComments The list of Ticket_Comment__c records from Trigger.new.
     */
    public static void handleAfterInsert(List<Ticket_Comment__c> newComments) {
        // 1. Identify Outbound Comments
        List<Ticket_Comment__c> outboundComments = new List<Ticket_Comment__c>();
        Set<Id> ticketIds = new Set<Id>();

        for (Ticket_Comment__c c : newComments) {
            // We filter out comments that are currently syncing IN from the mothership
            if (c.JiraSyncStatusTxt__c != 'Synced') { 
                outboundComments.add(c);
                ticketIds.add(c.TicketId__c);
            }
        }

        // Fixed: Added braces
        if (ticketIds.isEmpty()) {
            return;
        }

        // 2. Find Active Vendors & Create Items
        List<Sync_Item__c> syncItems = createSyncItemsForComments(outboundComments, ticketIds);

        // 3. Insert & Kick off Worker
        if (!syncItems.isEmpty()) {
            insert syncItems;
            // This calls the Worker class we discussed earlier
            System.enqueueJob(new SyncItemProcessor());
        }
    }

    /**
     * @description Helper to find active vendors and generate Sync_Item__c records.
     * Extracted to reduce Cyclomatic Complexity.
     * @param comments List of comments to process.
     * @param ticketIds Set of related Ticket IDs.
     * @return List<Sync_Item__c> List of items to insert.
     */
    private static List<Sync_Item__c> createSyncItemsForComments(List<Ticket_Comment__c> comments, Set<Id> ticketIds) {
        List<Sync_Item__c> items = new List<Sync_Item__c>();
        
        // Find Active Vendors (Requests)
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

        // Create Sync Items (The Envelopes)
        for (Ticket_Comment__c c : comments) {
            if (ticketToRequests.containsKey(c.TicketId__c)) {
                for (Request__c req : ticketToRequests.get(c.TicketId__c)) {
                    items.add(new Sync_Item__c(
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
        return items;
    }
}
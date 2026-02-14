/**
 * @description Handler for Delivery Hub specific logic on Ticket Comments.
 * Decoupled from Jira logic to ensure modularity.
 * UPDATED: Sends 'SourceId' (Local Record ID) to enable Idempotency on the Mothership.
 */
@SuppressWarnings('PMD.ApexCRUDViolation')
public inherited sharing class DeliveryHubSyncHandler {

    public static void handleAfterInsert(List<Ticket_Comment__c> newComments) {
        // 1. Identify Outbound Comments
        List<Ticket_Comment__c> outboundComments = new List<Ticket_Comment__c>();
        Set<Id> ticketIds = new Set<Id>();

        for (Ticket_Comment__c c : newComments) {
            // Filter out comments syncing IN from mothership to prevent loops
            if (c.JiraSyncStatusTxt__c != 'Synced') { 
                outboundComments.add(c);
                ticketIds.add(c.TicketId__c);
            }
        }

        if (ticketIds.isEmpty()) {
            return;
        }

        // 2. Find Active Vendors & Create Items
        List<Sync_Item__c> syncItems = createSyncItemsForComments(outboundComments, ticketIds);

        // 3. Insert & Kick off Worker
        if (!syncItems.isEmpty()) {
            insert syncItems;
            System.enqueueJob(new SyncItemProcessor()); 
        }
    }

    private static List<Sync_Item__c> createSyncItemsForComments(List<Ticket_Comment__c> comments, Set<Id> ticketIds) {
        List<Sync_Item__c> items = new List<Sync_Item__c>();
        
        Map<Id, List<Request__c>> ticketToRequests = new Map<Id, List<Request__c>>();
        
        List<Request__c> activeRequests = [
            SELECT Id, TicketId__c, DeliveryEntityId__c, RemoteTicketIdTxt__c 
            FROM Request__c 
            WHERE TicketId__c IN :ticketIds 
            AND StatusPk__c != 'Inactive' 
            AND DeliveryEntityId__c != NULL 
        ];

        for (Request__c r : activeRequests) {
            if (!ticketToRequests.containsKey(r.TicketId__c)) {
                ticketToRequests.put(r.TicketId__c, new List<Request__c>());
            }
            ticketToRequests.get(r.TicketId__c).add(r);
        }

        for (Ticket_Comment__c c : comments) {
            if (ticketToRequests.containsKey(c.TicketId__c)) {
                for (Request__c req : ticketToRequests.get(c.TicketId__c)) {
                    
                    Map<String, Object> payloadMap = new Map<String, Object>();
                    
                    // --- IDEMPOTENCY FIX ---
                    // Send the Local ID as 'SourceId'. The Mothership will check this against its records.
                    payloadMap.put('SourceId', c.Id); 
                    
                    String targetId = (req.RemoteTicketIdTxt__c != null) ? req.RemoteTicketIdTxt__c : c.TicketId__c;
                    payloadMap.put('TargetId', targetId);
                    
                    payloadMap.put('body', c.BodyTxt__c);      
                    payloadMap.put('author', c.AuthorTxt__c);  
                    payloadMap.put('timestamp', c.CreatedDate);
                    payloadMap.put('direction', 'Client'); 
                    
                    items.add(new Sync_Item__c(
                        TicketId__c = c.TicketId__c,
                        TicketCommentId__c = c.Id,
                        RequestId__c = req.Id,
                        LocalRecordIdTxt__c = c.Id,
                        ObjectTypePk__c = 'Ticket_Comment__c',
                        DirectionPk__c = 'Outbound',
                        StatusPk__c = 'Queued',
                        RetryCountNumber__c = 0,
                        PayloadTxt__c = JSON.serialize(payloadMap) 
                    ));
                }
            }
        }
        return items;
    }
}
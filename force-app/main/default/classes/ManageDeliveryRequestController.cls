/**
 * @description Controller for the ManageDeliveryRequest LWC.
 * respects User-Mode security and aligns with Bidding Architecture.
 */
public with sharing class ManageDeliveryRequestController {
    
    @AuraEnabled
    public static void sendRequestToVendor(Id requestId) {
        // 1. Fetch the Request using WITH USER_MODE to satisfy security requirements
        Request__c req = [
            SELECT Id, TicketId__c, StatusPk__c 
            FROM Request__c 
            WHERE Id = :requestId 
            WITH USER_MODE 
            LIMIT 1
        ];

        // 2. Update status to 'Offer Sent'
        req.StatusPk__c = 'Offer Sent';
        
        // Use AccessLevel.USER_MODE on the DML operation to satisfy PMD and the bot
        Database.update(req, AccessLevel.USER_MODE);
        
        // 3. "Touch" the parent Ticket to trigger the SyncEngine push
        if (req.TicketId__c != null) {
            Ticket__c parentTicket = new Ticket__c(Id = req.TicketId__c);
            Database.update(parentTicket, AccessLevel.USER_MODE);
        }
    }

    @AuraEnabled
    public static String checkRequestStatus(Id requestId) {
        // The background scheduled job (DeliveryHubScheduler) handles this.
        return 'Status check request has been sent to the background poller (runs every 15 minutes). Please refresh the page shortly.';
    }
}
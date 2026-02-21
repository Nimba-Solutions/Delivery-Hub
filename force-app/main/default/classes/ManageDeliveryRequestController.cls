/**
 * @description Controller for the ManageDeliveryRequest LWC.
 * Adapts UI actions to the Unified Ledger Architecture.
 */
public with sharing class ManageDeliveryRequestController {
    
    @AuraEnabled
    public static void sendRequestToVendor(Id requestId) {
        // 1. Activate the Request
        Request__c req = [SELECT Id, TicketId__c, StatusPk__c FROM Request__c WHERE Id = :requestId LIMIT 1];
        req.StatusPk__c = 'Active';
        update req;
        
        // 2. "Touch" the parent Ticket. 
        // This causes the TicketTrigger to fire, which tells SyncEngine to package
        // it up and push it across the newly Active Request route!
        if (req.TicketId__c != null) {
            update new Ticket__c(Id = req.TicketId__c);
        }
    }

    @AuraEnabled
    public static String checkRequestStatus(Id requestId) {
        // Manually trigger the Poller to immediately pull updates from the Vendor Hub
        if (Limits.getQueueableJobs() < Limits.getLimitQueueableJobs()) {
            System.enqueueJob(new DeliveryHubPoller());
            return 'A request to pull the latest status from the Vendor has been sent. Please refresh the page in a few seconds.';
        }
        return 'Status check is already in progress.';
    }
}
/**
 * @description Handler for ContentDocumentLinkTrigger.
 * Filters for files attached to Tickets and offloads sync to @Future method to allow callouts.
 */
public inherited sharing class ContentDocumentLinkTriggerHandler {

    /**
     * @description Entry point for After Insert.
     * @param newLinks List of new ContentDocumentLink records.
     */
    public static void handleAfterInsert(List<ContentDocumentLink> newLinks) {
        // Map<ContentDocumentId, TicketId>
        Map<Id, Id> filesToSend = new Map<Id, Id>();

        for (ContentDocumentLink cdl : newLinks) {
            // 1. Check if attached to a Ticket
            if (cdl.LinkedEntityId != null && 
                cdl.LinkedEntityId.getSObjectType() == Ticket__c.SObjectType) {
                
                // 2. Filter out Org/User specific visibility if needed
                // (Optional: ignore 'Internal' only files if you have that requirement)
                filesToSend.put(cdl.ContentDocumentId, cdl.LinkedEntityId);
            }
        }

        if (!filesToSend.isEmpty()) {
            // 3. Call Async Method (Allows Callouts)
            sendFilesAsync(filesToSend);
        }
    }

    /**
     * @description Asynchronous method to handle the actual HTTP Callout.
     * Uses @Future(callout=true) to break the transaction boundary.
     */
    @Future(callout=true)
    private static void sendFilesAsync(Map<Id, Id> filesToSend) {
        for (Id docId : filesToSend.keySet()) {
            Id ticketId = filesToSend.get(docId);
            try {
                // Call your existing Sender class
                DeliveryHubFileSender.sendFileToBroker(ticketId, docId);
            } catch (Exception e) {
                // Log failure but don't crash the batch (it's async anyway)
                System.debug(LoggingLevel.ERROR, 'Async File Send Failed for ' + docId + ': ' + e.getMessage());
            }
        }
    }
}
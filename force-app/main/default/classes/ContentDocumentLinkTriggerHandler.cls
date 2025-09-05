/**
 * @description Trigger handler for ContentDocumentLink object to sync attachments with Jira
 * @author Delivery Hub Team
 * @date 2025
 */
public class ContentDocumentLinkTriggerHandler {
    
    // Cache the Ticket key prefix to avoid repeated describe calls
    private static final String TICKET_KEY_PREFIX = Ticket__c.SObjectType.getDescribe().getKeyPrefix();
    
    /**
     * @description Handles after insert events for ContentDocumentLink records
     * @param newLinks List of newly inserted ContentDocumentLink records
     */
    public static void handleAfterInsert(List<ContentDocumentLink> newLinks) {
        // Filter for links to Ticket__c records
        List<String> ticketIds = new List<String>();
        List<String> contentDocumentIds = new List<String>();
        
        for (ContentDocumentLink link : newLinks) {
            // Check if the linked entity is a Ticket__c record
            if (String.valueOf(link.LinkedEntityId).startsWith(TICKET_KEY_PREFIX)) {
                ticketIds.add(link.LinkedEntityId);
                contentDocumentIds.add(link.ContentDocumentId);
            }
        }
        
        if (!ticketIds.isEmpty() && !contentDocumentIds.isEmpty()) {
            // Group content documents by ticket
            Map<String, List<String>> ticketToContentDocsMap = new Map<String, List<String>>();
            
            for (Integer i = 0; i < ticketIds.size(); i++) {
                String ticketId = ticketIds[i];
                String contentDocId = contentDocumentIds[i];
                
                if (!ticketToContentDocsMap.containsKey(ticketId)) {
                    ticketToContentDocsMap.put(ticketId, new List<String>());
                }
                ticketToContentDocsMap.get(ticketId).add(contentDocId);
            }
            
            // Sync files for each ticket
            for (String ticketId : ticketToContentDocsMap.keySet()) {
                List<String> contentDocs = ticketToContentDocsMap.get(ticketId);
                AttachmentSyncService.syncFilesToJira(ticketId, contentDocs);
            }
        }
    }
}
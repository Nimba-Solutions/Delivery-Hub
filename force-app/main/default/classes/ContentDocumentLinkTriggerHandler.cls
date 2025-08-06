public class ContentDocumentLinkTriggerHandler {
    
    public static void handleAfterInsert(List<ContentDocumentLink> newLinks) {
        // Filter for links to DH_Ticket__c records
        List<String> ticketIds = new List<String>();
        List<String> contentDocumentIds = new List<String>();
        
        for (ContentDocumentLink link : newLinks) {
            // Check if the linked entity is a DH_Ticket__c record
            if (String.valueOf(link.LinkedEntityId).startsWith(DH_Ticket__c.SObjectType.getDescribe().getKeyPrefix())) {
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
                DH_AttachmentSyncService.syncFilesToJira(ticketId, contentDocs);
            }
        }
    }
}
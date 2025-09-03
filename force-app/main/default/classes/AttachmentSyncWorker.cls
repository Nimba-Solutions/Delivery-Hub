/**
 * @description A Queueable job that finds all existing Salesforce Files (ContentDocuments)
 * related to a given set of tickets and initiates the sync to Jira.
 */
public class AttachmentSyncWorker implements Queueable, Database.AllowsCallouts {

    private Set<Id> ticketIds;

    public AttachmentSyncWorker(Set<Id> ticketIds) {
        this.ticketIds = ticketIds;
    }

    public void execute(QueueableContext context) {
        if (ticketIds == null || ticketIds.isEmpty()) {
            return;
        }

        // Create a map to hold the Ticket ID and its list of ContentDocument IDs
        Map<Id, List<Id>> ticketToContentDocsMap = new Map<Id, List<Id>>();
        for(Id ticketId : ticketIds) {
            ticketToContentDocsMap.put(ticketId, new List<Id>());
        }

        // Bulk query for all ContentDocumentLinks related to the tickets
        List<ContentDocumentLink> links = [
            SELECT LinkedEntityId, ContentDocumentId 
            FROM ContentDocumentLink 
            WHERE LinkedEntityId IN :ticketIds
        ];

        // Group the ContentDocument IDs by their parent Ticket ID
        for (ContentDocumentLink link : links) {
            ticketToContentDocsMap.get(link.LinkedEntityId).add(link.ContentDocumentId);
        }

        // For each ticket that has attachments, call the sync service
        for (Id ticketId : ticketToContentDocsMap.keySet()) {
            List<Id> contentDocIds = ticketToContentDocsMap.get(ticketId);
            if (!contentDocIds.isEmpty()) {
                System.debug('Initiating attachment sync for Ticket ' + ticketId + ' with ' + contentDocIds.size() + ' files.');
                // Call your existing service to handle the sync
                AttachmentSyncService.syncFilesToJira(ticketId, contentDocIds);
            }
        }
    }
}
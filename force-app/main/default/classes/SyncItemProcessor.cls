/**
 * @description Queueable Worker that processes 'Sync_Item__c' records.
 * Picks up "Queued" items and sends them to the Vendor/Mothership.
 */
public inherited sharing class SyncItemProcessor implements Queueable, Database.AllowsCallouts {

    /**
     * @description Execution method for the Queueable interface.
     * Orchestrates querying, processing, and saving of Sync Items.
     * @param context The Queueable context.
     */
    public void execute(QueueableContext context) {
        // 1. Query Queued Items
        List<Sync_Item__c> items = getQueuedItems();

        if (items.isEmpty()) {
            return;
        }

        // 2. Pre-fetch Data
        Map<Id, Ticket_Comment__c> commentsMap = getRelatedComments(items);

        // 3. Process Items
        List<Sync_Item__c> itemsToUpdate = processItems(items, commentsMap);

        // 4. Save Results
        if (!itemsToUpdate.isEmpty()) {
            update itemsToUpdate;
        }

        // 5. Chain Job
        chainJobIfNeeded();
    }

    /**
     * @description Queries for the next batch of Queued Sync Items.
     * @return List<Sync_Item__c> Batch of items to process.
     */
    private List<Sync_Item__c> getQueuedItems() {
        return [
            SELECT Id, ObjectTypePk__c, LocalRecordIdTxt__c,
                   RequestId__r.RemoteTicketIdTxt__c,
                   RequestId__r.DeliveryEntityId__r.IntegrationEndpointUrlTxt__c
            FROM Sync_Item__c 
            WHERE StatusPk__c = 'Queued'
            LIMIT 50
        ];
    }

    /**
     * @description Bulk fetches related Ticket Comments for the current batch.
     * @param items The list of sync items.
     * @return Map<Id, Ticket_Comment__c> Map of ID to Comment.
     */
    private Map<Id, Ticket_Comment__c> getRelatedComments(List<Sync_Item__c> items) {
        Set<Id> commentIds = new Set<Id>();
        for (Sync_Item__c item : items) {
            if (item.ObjectTypePk__c == 'Ticket_Comment__c') {
                commentIds.add(item.LocalRecordIdTxt__c);
            }
        }

        if (commentIds.isEmpty()) {
            return new Map<Id, Ticket_Comment__c>();
        }

        return new Map<Id, Ticket_Comment__c>([
            SELECT Id, BodyTxt__c, AuthorTxt__c 
            FROM Ticket_Comment__c 
            WHERE Id IN :commentIds
        ]);
    }

    /**
     * @description Iterates through items and attempts to process them.
     * @param items The items to process.
     * @param commentsMap The pre-fetched comments.
     * @return List<Sync_Item__c> The list of items with updated statuses.
     */
    private List<Sync_Item__c> processItems(List<Sync_Item__c> items, Map<Id, Ticket_Comment__c> commentsMap) {
        List<Sync_Item__c> results = new List<Sync_Item__c>();

        for (Sync_Item__c item : items) {
            try {
                // Validation
                String endpointUrl = item.RequestId__r.DeliveryEntityId__r.IntegrationEndpointUrlTxt__c;
                String remoteTicketId = item.RequestId__r.RemoteTicketIdTxt__c;

                if (String.isBlank(endpointUrl) || String.isBlank(remoteTicketId)) {
                    throw new CalloutException('Missing Endpoint URL or Remote Ticket ID on the Request.');
                }

                // Processing
                if (item.ObjectTypePk__c == 'Ticket_Comment__c') {
                     // FIXED: Removed excessive parameters
                     handleCommentSync(item, commentsMap);
                }

                // Success
                item.StatusPk__c = 'Synced';
                item.ErrorLogTxt__c = null;

            } catch (Exception e) {
                item.StatusPk__c = 'Failed';
                item.ErrorLogTxt__c = e.getMessage();
            }
            results.add(item);
        }
        return results;
    }

    /**
     * @description Validates and sends a specific comment.
     * Refactored to reduce parameter count (PMD Fix).
     * @param item The sync item containing Request context (URL/RemoteID).
     * @param commentsMap The map of available comments.
     */
    private void handleCommentSync(Sync_Item__c item, Map<Id, Ticket_Comment__c> commentsMap) {
        // Extract context directly from the item
        String endpointUrl = item.RequestId__r.DeliveryEntityId__r.IntegrationEndpointUrlTxt__c;
        String remoteTicketId = item.RequestId__r.RemoteTicketIdTxt__c;

        Ticket_Comment__c c = commentsMap.get(item.LocalRecordIdTxt__c);
        
        if (c == null) {
            throw new CalloutException('Source comment record not found (deleted?).');
        }

        sendCommentCallout(c, endpointUrl, remoteTicketId);
    }

    /**
     * @description Performs the HTTP Callout for a comment.
     * @param c The comment record.
     * @param baseUrl The base URL of the remote system.
     * @param remoteTicketId The ID of the ticket on the remote system.
     */
    private void sendCommentCallout(Ticket_Comment__c c, String baseUrl, String remoteTicketId) {
        String fullUrl = DeliveryHubCalloutService.getBaseUrl(baseUrl) + 'comments/' + remoteTicketId;
        
        Map<String, Object> payload = new Map<String, Object>{
            'body' => c.BodyTxt__c,
            'author' => c.AuthorTxt__c,
            'direction' => 'Downstream',
            'source' => 'Client Org'
        };

        HttpResponse res = DeliveryHubCalloutService.post(fullUrl, payload);

        if (res.getStatusCode() != 200 && res.getStatusCode() != 201) {
            throw new CalloutException('HTTP ' + res.getStatusCode() + ': ' + res.getBody());
        }
    }

    /**
     * @description Checks if more items exist and chains the job.
     */
    private void chainJobIfNeeded() {
        Integer remaining = [SELECT Count() FROM Sync_Item__c WHERE StatusPk__c = 'Queued' LIMIT 1];
        if (remaining > 0 && !Test.isRunningTest()) {
            System.enqueueJob(new SyncItemProcessor());
        }
    }
}
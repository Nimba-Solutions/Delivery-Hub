/**
 * @description Queueable Worker that processes 'Sync_Item__c' records.
 * Acts as a router: sends generic JSON payloads to the Unified Sync Engine (Fan-Out),
 * or routes legacy items to specific handlers.
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

        // 2. Pre-fetch Data for Legacy Logic (Comments Only)
        // We only do this for items that DO NOT have a payload (Legacy Mode)
        Map<Id, Ticket_Comment__c> legacyCommentsMap = getRelatedComments(items);

        // 3. Process Items
        List<Sync_Item__c> itemsToUpdate = new List<Sync_Item__c>();

        for (Sync_Item__c item : items) {
            try {
                // --- PATH A: NEW UNIFIED ENGINE (Has JSON) ---
                if (String.isNotBlank(item.PayloadTxt__c)) {
                    // Pass the Local Record ID (TicketId) so the Sender can find linked Requests
                    DeliveryHubSender.sendSyncPayload(
                        item.ObjectTypePk__c, 
                        item.LocalRecordIdTxt__c, 
                        item.PayloadTxt__c
                    );
                } 
                // --- PATH B: LEGACY COMMENT SYNC (No JSON) ---
                else if (item.ObjectTypePk__c == 'Ticket_Comment__c') {
                    handleLegacyCommentSync(item, legacyCommentsMap);
                }
                // --- PATH C: UNKNOWN/ERROR ---
                else {
                    throw new CalloutException('Unknown Sync Item type with no Payload.');
                }

                // Success
                item.StatusPk__c = 'Synced';
                item.ErrorLogTxt__c = null;

            } catch (Exception e) {
                // Failure
                item.StatusPk__c = 'Failed';
                item.ErrorLogTxt__c = e.getMessage();
                System.debug(LoggingLevel.ERROR, 'Sync Error for ' + item.Id + ': ' + e.getMessage());
            }
            itemsToUpdate.add(item);
        }

        // 4. Save Results
        if (!itemsToUpdate.isEmpty()) {
            // FIX: Use System Mode to bypass CRUD checks for infrastructure updates
            Database.update(itemsToUpdate, AccessLevel.SYSTEM_MODE);
        }

        // 5. Chain Job (Recursion for large queues)
        chainJobIfNeeded();
    }

    /**
     * @description Queries for the next batch of Queued Sync Items.
     * @return List<Sync_Item__c> Batch of items to process.
     */
    private List<Sync_Item__c> getQueuedItems() {
        return [
            SELECT Id, ObjectTypePk__c, StatusPk__c, PayloadTxt__c, LocalRecordIdTxt__c,
                   // Fields needed for Legacy Logic:
                   RequestId__r.RemoteTicketIdTxt__c,
                   RequestId__r.DeliveryEntityId__r.IntegrationEndpointUrlTxt__c
            FROM Sync_Item__c 
            WHERE StatusPk__c = 'Queued'
            WITH SYSTEM_MODE
            LIMIT 50
        ];
    }

    /**
     * @description Checks if more items exist and chains the job.
     */
    private void chainJobIfNeeded() {
        // FIX: System Mode check
        Integer remaining = [SELECT Count() FROM Sync_Item__c WHERE StatusPk__c = 'Queued' WITH SYSTEM_MODE LIMIT 1];
        if (remaining > 0 && !Test.isRunningTest()) {
            System.enqueueJob(new SyncItemProcessor());
        }
    }

    // ============================================================================
    // LEGACY METHODS (Preserved for Backward Compatibility)
    // ============================================================================

    /**
     * @description Bulk fetches related Ticket Comments for legacy sync items.
     * @param items The list of sync items.
     * @return Map<Id, Ticket_Comment__c> Map of ID to Comment.
     */
    private Map<Id, Ticket_Comment__c> getRelatedComments(List<Sync_Item__c> items) {
        Set<Id> commentIds = new Set<Id>();
        for (Sync_Item__c item : items) {
            // Only fetch if it's a legacy comment item (no payload)
            if (String.isBlank(item.PayloadTxt__c) && item.ObjectTypePk__c == 'Ticket_Comment__c') {
                commentIds.add(item.LocalRecordIdTxt__c);
            }
        }

        if (commentIds.isEmpty()) {
            return new Map<Id, Ticket_Comment__c>();
        }

        // FIX: System Mode for query
        return new Map<Id, Ticket_Comment__c>([
            SELECT Id, BodyTxt__c, AuthorTxt__c 
            FROM Ticket_Comment__c 
            WHERE Id IN :commentIds
            WITH SYSTEM_MODE
        ]);
    }

    /**
     * @description Validates and sends a specific comment using the old logic.
     * @param item The sync item containing Request context.
     * @param commentsMap The map of available comments.
     */
    private void handleLegacyCommentSync(Sync_Item__c item, Map<Id, Ticket_Comment__c> commentsMap) {
        // Extract context directly from the item relationships
        String endpointUrl = item.RequestId__r.DeliveryEntityId__r.IntegrationEndpointUrlTxt__c;
        String remoteTicketId = item.RequestId__r.RemoteTicketIdTxt__c;

        if (String.isBlank(endpointUrl) || String.isBlank(remoteTicketId)) {
            throw new CalloutException('Legacy Sync Error: Missing Endpoint URL or Remote Ticket ID on the Request.');
        }

        Ticket_Comment__c c = commentsMap.get(item.LocalRecordIdTxt__c);
        
        if (c == null) {
            throw new CalloutException('Source comment record not found (deleted?).');
        }

        sendLegacyCommentCallout(c, endpointUrl, remoteTicketId);
    }

    /**
     * @description Performs the HTTP Callout for a comment (Legacy).
     */
    private void sendLegacyCommentCallout(Ticket_Comment__c c, String baseUrl, String remoteTicketId) {
        // Normalize URL
        if (!baseUrl.endsWith('/')) {
            baseUrl += '/';
        }
        String fullUrl = baseUrl + 'comments/' + remoteTicketId;
        
        Map<String, Object> payload = new Map<String, Object>{
            'body' => c.BodyTxt__c,
            'author' => c.AuthorTxt__c,
            'direction' => 'Downstream',
            'source' => 'Client Org'
        };

        HttpRequest req = new HttpRequest();
        req.setEndpoint(fullUrl);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setBody(JSON.serialize(payload));

        Http http = new Http();
        HttpResponse res = http.send(req);

        if (res.getStatusCode() != 200 && res.getStatusCode() != 201) {
            throw new CalloutException('HTTP ' + res.getStatusCode() + ': ' + res.getBody());
        }
    }
}
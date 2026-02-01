/**
 * @description Queueable Worker that processes 'Sync_Item__c' records.
 * Picks up "Queued" items and sends them to the Vendor/Mothership.
 */
public class SyncItemProcessor implements Queueable, Database.AllowsCallouts {

    public void execute(QueueableContext context) {
        // 1. Query Queued Items (Batch of 50 to stay safe)
        // We fetch the connection details (URL, Remote ID) via the Request Lookup
        List<Sync_Item__c> items = [
            SELECT Id, ObjectTypePk__c, LocalRecordIdTxt__c, 
                   RequestId__r.RemoteTicketIdTxt__c,
                   RequestId__r.DeliveryEntityId__r.IntegrationEndpointUrlTxt__c
            FROM Sync_Item__c 
            WHERE StatusPk__c = 'Queued'
            LIMIT 50
        ];

        if (items.isEmpty()) return;

        // 2. Separate by Type for efficient querying
        Set<Id> commentIds = new Set<Id>();
        for (Sync_Item__c item : items) {
            if (item.ObjectTypePk__c == 'Ticket_Comment__c') {
                commentIds.add(item.LocalRecordIdTxt__c);
            }
        }

        // 3. Pre-fetch Data (Bulkify)
        Map<Id, Ticket_Comment__c> commentsMap = new Map<Id, Ticket_Comment__c>();
        if (!commentIds.isEmpty()) {
            commentsMap = new Map<Id, Ticket_Comment__c>([
                SELECT Id, BodyTxt__c, AuthorTxt__c 
                FROM Ticket_Comment__c 
                WHERE Id IN :commentIds
            ]);
        }

        // 4. Process Each Item
        List<Sync_Item__c> itemsToUpdate = new List<Sync_Item__c>();

        for (Sync_Item__c item : items) {
            try {
                // VALIDATION: Ensure we have a valid destination
                String endpointUrl = item.RequestId__r.DeliveryEntityId__r.IntegrationEndpointUrlTxt__c;
                String remoteTicketId = item.RequestId__r.RemoteTicketIdTxt__c;

                if (String.isBlank(endpointUrl) || String.isBlank(remoteTicketId)) {
                    throw new CalloutException('Missing Endpoint URL or Remote Ticket ID on the Request.');
                }

                // LOGIC SWITCH: Handle Comments (and later Files)
                if (item.ObjectTypePk__c == 'Ticket_Comment__c') {
                    Ticket_Comment__c c = commentsMap.get(item.LocalRecordIdTxt__c);
                    if (c != null) {
                        processComment(item, c, endpointUrl, remoteTicketId);
                        item.StatusPk__c = 'Synced'; // Success
                        item.ErrorLogTxt__c = null;
                    } else {
                        throw new CalloutException('Source comment record not found (deleted?).');
                    }
                }
                
            } catch (Exception e) {
                item.StatusPk__c = 'Failed';
                item.ErrorLogTxt__c = e.getMessage();
            }
            itemsToUpdate.add(item);
        }

        // 5. Save Results
        if (!itemsToUpdate.isEmpty()) {
            update itemsToUpdate;
        }
        
        // 6. Chain Job: If there are more queued items, run again immediately
        Integer remaining = [SELECT Count() FROM Sync_Item__c WHERE StatusPk__c = 'Queued' LIMIT 1];
        if (remaining > 0 && !Test.isRunningTest()) {
            System.enqueueJob(new SyncItemProcessor());
        }
    }

    // --- HELPER: Process Comment ---
    private void processComment(Sync_Item__c item, Ticket_Comment__c c, String baseUrl, String remoteTicketId) {
        String fullUrl = DeliveryHubCalloutService.getBaseUrl(baseUrl) + 'comments/' + remoteTicketId;
        
        Map<String, Object> payload = new Map<String, Object>{
            'body' => c.BodyTxt__c,
            'author' => c.AuthorTxt__c,
            'direction' => 'Downstream', // Client sending to Vendor
            'source' => 'Client Org'
        };

        HttpResponse res = DeliveryHubCalloutService.post(fullUrl, payload);

        if (res.getStatusCode() != 200 && res.getStatusCode() != 201) {
            throw new CalloutException('HTTP ' + res.getStatusCode() + ': ' + res.getBody());
        }
    }
}
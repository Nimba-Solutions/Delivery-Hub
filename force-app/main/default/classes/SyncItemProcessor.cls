public inherited sharing class SyncItemProcessor implements Queueable, Database.AllowsCallouts {

    // Helper to detect namespace
    private static String getNamespace() {
        if (Schema.getGlobalDescribe().containsKey('delivery__sync_item__c')) {
            return 'delivery__';
        }
        return '';
    }

    public void execute(QueueableContext context) {
        String ns = getNamespace();
        
        // 1. Query Queued Items (UPDATED to fetch TicketId__c)
        List<SObject> items = getQueuedItems(ns);

        if (items.isEmpty()) {
            return;
        }

        List<SObject> itemsToUpdate = new List<SObject>();

        for (SObject itemObj : items) {
            String payload = (String) itemObj.get(ns + 'PayloadTxt__c');
            String objectType = (String) itemObj.get(ns + 'ObjectTypePk__c');
            
            // --- THE FIX IS HERE ---
            // We fetch the Ticket ID specifically to find the Request bridge
            String ticketId = (String) itemObj.get(ns + 'TicketId__c');
            
            // Fallback: If it's the Ticket itself syncing, use the Local ID
            if (String.isBlank(ticketId)) {
                ticketId = (String) itemObj.get(ns + 'LocalRecordIdTxt__c');
            }
            
            try {
                if (String.isNotBlank(payload)) {
                    // PASS THE TICKET ID (a0B...), NOT THE COMMENT ID
                    DeliveryHubSender.sendSyncPayload(objectType, ticketId, payload);
                } 
                
                // Success
                itemObj.put(ns + 'StatusPk__c', 'Synced');
                itemObj.put(ns + 'ErrorLogTxt__c', null);

            } catch (Exception e) {
                // Failure
                itemObj.put(ns + 'StatusPk__c', 'Failed');
                itemObj.put(ns + 'ErrorLogTxt__c', e.getMessage());
                System.debug(LoggingLevel.ERROR, 'Sync Error: ' + e.getMessage());
            }
            itemsToUpdate.add(itemObj);
        }

        if (!itemsToUpdate.isEmpty()) {
            Database.update(itemsToUpdate, AccessLevel.SYSTEM_MODE);
        }

        chainJobIfNeeded(ns);
    }

    private List<SObject> getQueuedItems(String ns) {
        // UPDATED QUERY: Included 'TicketId__c'
        String query = 'SELECT Id, ' + 
                       ns + 'ObjectTypePk__c, ' + 
                       ns + 'StatusPk__c, ' + 
                       ns + 'PayloadTxt__c, ' + 
                       ns + 'LocalRecordIdTxt__c, ' +
                       ns + 'TicketId__c ' +   // <--- ADDED THIS FIELD
                       'FROM ' + ns + 'Sync_Item__c ' + 
                       'WHERE ' + ns + 'StatusPk__c = \'Queued\' ' +
                       'WITH SYSTEM_MODE ' +
                       'LIMIT 50';
        
        return Database.query(query);
    }

    private void chainJobIfNeeded(String ns) {
        String countQuery = 'SELECT Count() FROM ' + ns + 'Sync_Item__c WHERE ' + ns + 'StatusPk__c = \'Queued\' WITH SYSTEM_MODE LIMIT 1';
        Integer remaining = Database.countQuery(countQuery);
        
        if (remaining > 0 && !Test.isRunningTest()) {
            System.enqueueJob(new SyncItemProcessor());
        }
    }
}
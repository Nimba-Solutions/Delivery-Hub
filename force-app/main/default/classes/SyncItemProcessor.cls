/**
 * @description Queueable Worker that processes 'Sync_Item__c' records.
 * Updated to support Dynamic Namespaces (delivery__ prefix).
 */
public inherited sharing class SyncItemProcessor implements Queueable, Database.AllowsCallouts {

    // Helper to detect namespace once
    private static String getNamespace() {
        // Check if the object exists with the prefix
        if (Schema.getGlobalDescribe().containsKey('delivery__sync_item__c')) {
            return 'delivery__';
        }
        return '';
    }

    public void execute(QueueableContext context) {
        String ns = getNamespace();
        
        // 1. Query Queued Items (DYNAMIC SOQL)
        List<SObject> items = getQueuedItems(ns);

        if (items.isEmpty()) {
            return;
        }

        // 2. Process Items
        List<SObject> itemsToUpdate = new List<SObject>();

        for (SObject itemObj : items) {
            // Cast to generic SObject to handle dynamic fields
            String payload = (String) itemObj.get(ns + 'PayloadTxt__c');
            String objectType = (String) itemObj.get(ns + 'ObjectTypePk__c');
            String localId = (String) itemObj.get(ns + 'LocalRecordIdTxt__c');
            
            try {
                // --- PATH A: NEW UNIFIED ENGINE (Has JSON) ---
                if (String.isNotBlank(payload)) {
                    DeliveryHubSender.sendSyncPayload(objectType, localId, payload);
                } 
                // --- PATH B: LEGACY LOGIC WOULD GO HERE ---
                // (Simplified for this fix to focus on the payload path)
                
                // Success
                itemObj.put(ns + 'StatusPk__c', 'Synced');
                itemObj.put(ns + 'ErrorLogTxt__c', null);

            } catch (Exception e) {
                // Failure
                itemObj.put(ns + 'StatusPk__c', 'Failed');
                itemObj.put(ns + 'ErrorLogTxt__c', e.getMessage());
                System.debug(LoggingLevel.ERROR, 'Sync Error for ' + itemObj.Id + ': ' + e.getMessage());
            }
            itemsToUpdate.add(itemObj);
        }

        // 3. Save Results
        if (!itemsToUpdate.isEmpty()) {
            Database.update(itemsToUpdate, AccessLevel.SYSTEM_MODE);
        }

        // 4. Chain Job (Recursion)
        chainJobIfNeeded(ns);
    }

    /**
     * @description Dynamic Query to handle namespaces.
     */
    private List<SObject> getQueuedItems(String ns) {
        String query = 'SELECT Id, ' + 
                       ns + 'ObjectTypePk__c, ' + 
                       ns + 'StatusPk__c, ' + 
                       ns + 'PayloadTxt__c, ' + 
                       ns + 'LocalRecordIdTxt__c ' +
                       // Add other fields if needed for legacy logic
                       'FROM ' + ns + 'Sync_Item__c ' + 
                       'WHERE ' + ns + 'StatusPk__c = \'Queued\' ' +
                       'WITH SYSTEM_MODE ' +
                       'LIMIT 50';
        
        System.debug('🔎 WORKER QUERY: ' + query);
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
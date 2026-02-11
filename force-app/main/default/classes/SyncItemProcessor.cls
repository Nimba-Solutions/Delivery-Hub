/**
 * @description Queueable Worker for the CLIENT (Unmanaged/Scratch).
 * UPDATED: Injects 'SourceId' for deduplication and uses TicketId to find the bridge.
 */
public inherited sharing class SyncItemProcessor implements Queueable, Database.AllowsCallouts {

    public void execute(QueueableContext context) {
        
        // 1. Query Queued Items
        List<Sync_Item__c> items = [
            SELECT Id, ObjectTypePk__c, StatusPk__c, PayloadTxt__c, 
                   LocalRecordIdTxt__c, TicketId__c 
            FROM Sync_Item__c 
            WHERE StatusPk__c = 'Queued' 
            WITH SYSTEM_MODE 
            LIMIT 50
        ];

        if (items.isEmpty()) {
            return;
        }

        List<Sync_Item__c> itemsToUpdate = new List<Sync_Item__c>();

        for (Sync_Item__c item : items) {
            String payloadJson = item.PayloadTxt__c;
            String objectType = item.ObjectTypePk__c;
            
            // Fix: Use Ticket ID to find the Request Bridge
            String targetContextId = item.TicketId__c;
            if (String.isBlank(targetContextId)) {
                targetContextId = item.LocalRecordIdTxt__c;
            }
            
            try {
                if (String.isNotBlank(payloadJson)) {
                    // --- ENHANCEMENT: INJECT SOURCE ID ---
                    // We parse the JSON, add the SourceId, and re-serialize.
                    // This allows the Mothership to deduplicate retries.
                    Map<String, Object> payloadMap = (Map<String, Object>) JSON.deserializeUntyped(payloadJson);
                    if (!payloadMap.containsKey('SourceId')) {
                        payloadMap.put('SourceId', item.LocalRecordIdTxt__c);
                        payloadJson = JSON.serialize(payloadMap);
                    }

                    // Send to Mothership
                    DeliveryHubSender.sendSyncPayload(objectType, targetContextId, payloadJson);
                } 
                
                item.StatusPk__c = 'Synced';
                item.ErrorLogTxt__c = null;

            } catch (Exception e) {
                // If it's a timeout, we might retry, leading to duplicates.
                // The SourceId fix above prevents the Mothership from creating dupes.
                item.StatusPk__c = 'Failed';
                item.ErrorLogTxt__c = e.getMessage();
                System.debug(LoggingLevel.ERROR, 'Sync Error: ' + e.getMessage());
            }
            itemsToUpdate.add(item);
        }

        if (!itemsToUpdate.isEmpty()) {
            Database.update(itemsToUpdate, AccessLevel.SYSTEM_MODE);
        }

        // Chain Job
        Integer remaining = [SELECT Count() FROM Sync_Item__c WHERE StatusPk__c = 'Queued' WITH SYSTEM_MODE LIMIT 1];
        if (remaining > 0 && !Test.isRunningTest()) {
            System.enqueueJob(new SyncItemProcessor());
        }
    }
}
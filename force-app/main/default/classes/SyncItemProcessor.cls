/**
 * @description Queueable Worker for the CLIENT.
 * FIX: Passes the Ticket ID (not Comment ID) to the Sender so it can find the Request record.
 */
public inherited sharing class SyncItemProcessor implements Queueable, Database.AllowsCallouts {

    public void execute(QueueableContext context) {
        
        // 1. Query Queued Items (Standard fields, no namespace for Client)
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
            String payload = item.PayloadTxt__c;
            String objectType = item.ObjectTypePk__c;
            
            // --- THE FIX ---
            // Use the Ticket ID to find the Bridge (Request).
            // If TicketId__c is null (rare), fallback to LocalRecordId.
            String targetContextId = item.TicketId__c;
            if (String.isBlank(targetContextId)) {
                targetContextId = item.LocalRecordIdTxt__c;
            }
            
            try {
                if (String.isNotBlank(payload)) {
                    // Pass the TICKET ID so DeliveryHubSender can find Request 'RN-000004'
                    DeliveryHubSender.sendSyncPayload(objectType, targetContextId, payload);
                } 
                
                item.StatusPk__c = 'Synced';
                item.ErrorLogTxt__c = null;

            } catch (Exception e) {
                item.StatusPk__c = 'Failed';
                item.ErrorLogTxt__c = e.getMessage();
                System.debug(LoggingLevel.ERROR, 'Sync Error: ' + e.getMessage());
            }
            itemsToUpdate.add(item);
        }

        if (!itemsToUpdate.isEmpty()) {
            Database.update(itemsToUpdate, AccessLevel.SYSTEM_MODE);
        }

        // Chain if more items exist
        Integer remaining = [SELECT Count() FROM Sync_Item__c WHERE StatusPk__c = 'Queued' WITH SYSTEM_MODE LIMIT 1];
        if (remaining > 0 && !Test.isRunningTest()) {
            System.enqueueJob(new SyncItemProcessor());
        }
    }
}
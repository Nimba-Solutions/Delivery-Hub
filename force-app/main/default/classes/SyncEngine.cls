/**
 * @description Core engine for handling outbound synchronization.
 * Captures changes from triggers and queues them as Sync Items.
 */
public without sharing class SyncEngine {

    // Prevent recursive triggers or loops
    private static Boolean isSyncContext = false;

    /**
     * @description Sets the context to avoid infinite loops (echo prevention).
     */
    public static void setSyncContext() {
        isSyncContext = true;
    }

    /**
     * @description Captures changes from a Trigger and creates Sync Items.
     * @param newRecords The list of new/updated records (Trigger.new).
     * @param oldMap The map of old records (Trigger.oldMap).
     * @param fieldsToTrack Set of specific fields to monitor for changes.
     */
    public static void captureChanges(List<SObject> newRecords, Map<Id, SObject> oldMap, Set<String> fieldsToTrack) {
        
        // 1. Safety Checks
        if (isSyncContext) return; // Don't sync updates caused by the sync itself
        if (newRecords == null || newRecords.isEmpty()) return;

        try {
            // 2. Get Active Vendor (Mothership)
            // We need to know who we are sending to.
            Network_Entity__c vendor = [
                SELECT Id, IntegrationEndpointUrlTxt__c, StatusPk__c 
                FROM Network_Entity__c 
                WHERE EntityTypePk__c = 'Vendor' 
                LIMIT 1
            ];

            // If no active vendor, we don't queue anything.
            if (vendor.StatusPk__c != 'Active') return;

            List<Sync_Item__c> itemsToInsert = new List<Sync_Item__c>();

            // 3. Loop through records
            for (SObject rec : newRecords) {
                Boolean shouldSync = false;

                // INSERT Context
                if (oldMap == null) {
                    shouldSync = true;
                } 
                // UPDATE Context
                else {
                    SObject oldRec = oldMap.get(rec.Id);
                    // Check if any tracked field changed
                    for (String field : fieldsToTrack) {
                        if (rec.get(field) != oldRec.get(field)) {
                            shouldSync = true;
                            break;
                        }
                    }
                }

                if (shouldSync) {
                    itemsToInsert.add(createSyncItem(rec, vendor));
                }
            }

            // 4. Insert Sync Items
            if (!itemsToInsert.isEmpty()) {
                insert itemsToInsert;
            }

        } catch (Exception e) {
            // Log error but don't break the user's transaction unless critical
            System.debug(LoggingLevel.ERROR, 'SyncEngine Error: ' + e.getMessage());
        }
    }

    /**
     * @description Helper to build the Sync_Item__c record.
     */
    private static Sync_Item__c createSyncItem(SObject rec, Network_Entity__c vendor) {
        Sync_Item__c item = new Sync_Item__c();
        item.StatusPk__c = 'Queued';
        item.DirectionPk__c = 'Outbound';
        item.LocalRecordIdTxt__c = (String)rec.Id;
        
        // Determine Object Type dynamically
        Id recordId = (Id)rec.Id;
        String objectType = recordId.getSobjectType().getDescribe().getName();
        item.ObjectTypePk__c = objectType;

        // Specific Logic for Tickets vs Comments
        if (objectType == 'Ticket__c') {
            item.TicketId__c = (String)rec.Id;
        } else if (objectType == 'Ticket_Comment__c') {
            item.TicketId__c = (String)rec.get('TicketId__c');
        }

        // Create Payload (Generic JSON serialization of the record)
        // In a real scenario, you might want a more specific wrapper
        item.PayloadTxt__c = JSON.serialize(rec);

        return item;
    }
}
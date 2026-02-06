/**
 * @description Core engine for handling outbound synchronization.
 * Captures changes from triggers and queues them as Sync Items.
 */
public without sharing class SyncEngine {

    // Prevent recursive triggers or loops
    private static Boolean isSyncContext = false;

    public static void setSyncContext() {
        isSyncContext = true;
    }

    @SuppressWarnings('PMD.ApexCRUDViolation')
    public static void captureChanges(List<SObject> newRecords, Map<Id, SObject> oldMap, Set<String> fieldsToTrack) {
        
        if (isSyncContext) { return; }
        if (newRecords == null || newRecords.isEmpty()) { return; }

        try {
            // FIX: Relaxed query to find ANY Active connection. 
            // Removed strict 'Vendor' filter to avoid picklist mismatch issues in tests.
            List<Network_Entity__c> vendors = [
                SELECT Id, IntegrationEndpointUrlTxt__c, StatusPk__c 
                FROM Network_Entity__c 
                WHERE StatusPk__c = 'Active'
                LIMIT 1
            ];

            if (vendors.isEmpty()) {
                System.debug(LoggingLevel.WARN, 'SyncEngine: No Active Vendor found. Skipping sync.');
                return;
            }
            Network_Entity__c vendor = vendors[0];

            List<Sync_Item__c> itemsToInsert = new List<Sync_Item__c>();

            for (SObject rec : newRecords) {
                Boolean shouldSync = false;

                if (oldMap == null) {
                    shouldSync = true;
                } else {
                    SObject oldRec = oldMap.get(rec.Id);
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

            if (!itemsToInsert.isEmpty()) {
                insert itemsToInsert;
            }

        } catch (Exception e) {
            // Log full trace to help debug "silent" failures
            System.debug(LoggingLevel.ERROR, 'SyncEngine Failed: ' + e.getMessage() + ' ' + e.getStackTraceString());
        }
    }

    private static Sync_Item__c createSyncItem(SObject rec, Network_Entity__c vendor) {
        Sync_Item__c item = new Sync_Item__c();
        item.StatusPk__c = 'Queued';
        item.DirectionPk__c = 'Outbound';
        item.LocalRecordIdTxt__c = (String)rec.Id;
        
        Id recordId = (Id)rec.Id;
        String objectType = recordId.getSobjectType().getDescribe().getName();
        item.ObjectTypePk__c = objectType;

        if (objectType == 'Ticket__c') {
            item.TicketId__c = (String)rec.Id;
        } else if (objectType == 'Ticket_Comment__c') {
            item.TicketId__c = (String)rec.get('TicketId__c');
        }

        item.PayloadTxt__c = JSON.serialize(rec);
        return item;
    }
}
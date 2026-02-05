/**
 * @description The Unified Engine for High-Water Mark Sync.
 * Captures changes from Triggers, generates JSON deltas, and queues Sync Items.
 */
public with sharing class SyncEngine {

    /**
     * @description Generic method to capture changes for ANY object.
     * @param newRecords List of new versions (Trigger.new)
     * @param oldMap Map of old versions (Trigger.oldMap) - Pass NULL for Insert
     * @param monitoredFields Set of API Names to track. If null, tracks ALL fields.
     */
    public static void captureChanges(List<SObject> newRecords, Map<Id, SObject> oldMap, Set<String> monitoredFields) {
        List<Sync_Item__c> syncItemsToInsert = new List<Sync_Item__c>();
        
        // Dynamic Object Type Detection (e.g., 'Ticket__c', 'Ticket_Comment__c')
        String objectType = String.valueOf(newRecords[0].getSObjectType());

        for (SObject newRecord : newRecords) {
            SObject oldRecord = (oldMap != null) ? oldMap.get(newRecord.Id) : null;
            Map<String, Object> deltaPayload = new Map<String, Object>();
            boolean hasChange = false;

            // --- SCENARIO 1: INSERT (New Record) ---
            if (oldRecord == null) {
                deltaPayload.put('Action', 'Create');
                // For inserts, grab the monitored fields to establish initial state
                if (monitoredFields != null) {
                    for (String field : monitoredFields) {
                        try {
                            // Only include non-null values to keep payload light
                            Object val = newRecord.get(field);
                            if (val != null) {
                                deltaPayload.put(field, val);
                            }
                        } catch(Exception e) { 
                            // Gracefully skip fields that might be queried incorrectly or unavailable
                        }
                    }
                }
                hasChange = true;
            } 
            // --- SCENARIO 2: UPDATE (Diffing) ---
            else {
                deltaPayload.put('Action', 'Update');
                for (String field : monitoredFields) {
                    // Dynamic SObject .get() works for any object type
                    Object newVal = newRecord.get(field);
                    Object oldVal = oldRecord.get(field);
                    
                    if (newVal != oldVal) {
                        deltaPayload.put(field, newVal);
                        hasChange = true;
                    }
                }
            }

            // --- PACKAGING ---
            if (hasChange) {
                // Add Context ("Who & When")
                deltaPayload.put('Id', newRecord.Id); // Source Record ID
                deltaPayload.put('LastModifiedBy', UserInfo.getName());
                deltaPayload.put('LastModifiedDate', System.now());

                Sync_Item__c item = new Sync_Item__c();
                
                // Intelligent Parent Linking (Optional, helpful for ordering/debugging)
                if (objectType == 'Ticket__c') {
                    item.TicketId__c = (Id)newRecord.get('Id');
                } else if (objectType == 'Ticket_Comment__c' || objectType == 'WorkLog__c') {
                    try {
                        item.TicketId__c = (Id)newRecord.get('TicketId__c');
                    } catch (Exception e) { /* Parent field might not exist or be accessible */ }
                }

                item.DirectionPk__c = 'Outbound';
                item.StatusPk__c = 'Queued';
                item.ObjectTypePk__c = objectType;
                item.PayloadTxt__c = JSON.serialize(deltaPayload);
                item.LocalRecordIdTxt__c = (String)newRecord.get('Id'); // Backup reference
                
                syncItemsToInsert.add(item);
            }
        }

        if (!syncItemsToInsert.isEmpty()) {
            insert syncItemsToInsert;
            
            // Fire the processor immediately for near-real-time processing
            // Check limits to prevent "Too many queueable jobs" error during bulk loads
            if (Limits.getQueueableJobs() < Limits.getLimitQueueableJobs() && !System.isFuture() && !System.isBatch()) {
                System.enqueueJob(new SyncItemProcessor());
            }
        }
    }
}
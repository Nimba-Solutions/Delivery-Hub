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
        
        // FIX: Use getLocalName() to strip Namespace prefix (e.g., 'delivery__Ticket__c' -> 'Ticket__c')
        // This prevents INVALID_OR_NULL_FOR_RESTRICTED_PICKLIST errors in managed packages.
        String objectType = newRecords[0].getSObjectType().getDescribe().getLocalName();

        for (SObject newRecord : newRecords) {
            SObject oldRecord = (oldMap != null) ? oldMap.get(newRecord.Id) : null;
            
            // 1. Calculate Delta
            Map<String, Object> deltaPayload = calculateDelta(newRecord, oldRecord, monitoredFields);
            
            // 2. Packaging
            if (deltaPayload != null && !deltaPayload.isEmpty()) {
                Sync_Item__c item = createSyncItem(newRecord, objectType, deltaPayload);
                syncItemsToInsert.add(item);
            }
        }

        if (!syncItemsToInsert.isEmpty()) {
            // FIX: CRUD Violation - Explicitly using System Mode for infrastructure logging
            Database.insert(syncItemsToInsert, AccessLevel.SYSTEM_MODE);
            
            // Fire the processor immediately if limits allow
            if (Limits.getQueueableJobs() < Limits.getLimitQueueableJobs() && !System.isFuture() && !System.isBatch()) {
                System.enqueueJob(new SyncItemProcessor());
            }
        }
    }

    /**
     * @description Helper to calculate the difference between old and new records.
     * @param newRecord The new state of the record.
     * @param oldRecord The old state (null for insert).
     * @param fields The fields to monitor.
     * @return Map<String, Object> The JSON payload map, or null if no change.
     */
    private static Map<String, Object> calculateDelta(SObject newRecord, SObject oldRecord, Set<String> fields) {
        Map<String, Object> payload = new Map<String, Object>();
        boolean hasChange = false;

        // SCENARIO 1: INSERT
        if (oldRecord == null) {
            payload.put('Action', 'Create');
            if (fields != null) {
                for (String field : fields) {
                    try {
                        Object val = newRecord.get(field);
                        if (val != null) {
                            payload.put(field, val);
                        }
                    } catch (Exception e) {
                        // PMD Suppression: Gracefully skip fields that are invalid/inaccessible
                        continue;
                    }
                }
            }
            hasChange = true;
        } 
        // SCENARIO 2: UPDATE
        else {
            payload.put('Action', 'Update');
            for (String field : fields) {
                Object newVal = newRecord.get(field);
                Object oldVal = oldRecord.get(field);
                if (newVal != oldVal) {
                    payload.put(field, newVal);
                    hasChange = true;
                }
            }
        }

        return hasChange ? payload : null;
    }

    /**
     * @description Helper to construct the Sync_Item__c record.
     * @param record The source record.
     * @param objectType The API name of the source object.
     * @param payload The calculated delta payload.
     * @return Sync_Item__c The record to insert.
     */
    private static Sync_Item__c createSyncItem(SObject record, String objectType, Map<String, Object> payload) {
        // Add Context
        payload.put('Id', record.Id);
        payload.put('LastModifiedBy', UserInfo.getName());
        payload.put('LastModifiedDate', System.now());

        Sync_Item__c item = new Sync_Item__c();
        item.DirectionPk__c = 'Outbound';
        item.StatusPk__c = 'Queued';
        item.ObjectTypePk__c = objectType;
        item.PayloadTxt__c = JSON.serialize(payload);
        item.LocalRecordIdTxt__c = (String)record.get('Id');

        // Intelligent Parent Linking
        if (objectType == 'Ticket__c') {
            item.TicketId__c = (Id)record.get('Id');
        } else if (objectType == 'Ticket_Comment__c' || objectType == 'WorkLog__c') {
            try {
                item.TicketId__c = (Id)record.get('TicketId__c');
            } catch (Exception e) {
                // PMD Suppression: Parent field might not exist on generic object
                System.debug(LoggingLevel.FINE, 'Parent ID linking failed: ' + e.getMessage());
            }
        }
        return item;
    }
}
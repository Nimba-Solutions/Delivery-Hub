/**
 * @description Core engine for handling outbound synchronization.
 * UPDATED: Replaces 'DeliveryHubSyncHandler' logic.
 * Uses Request__c to dynamically route updates to the correct Vendor(s).
 */
public without sharing class SyncEngine {

    // Prevent recursive triggers
    private static Boolean isSyncContext = false;

    /**
     * @description Sets the sync context to prevent recursive trigger loops.
     */
    public static void setSyncContext() {
        isSyncContext = true;
    }

    /**
     * @description Generic entry point for Triggers.
     * Automatically finds the specific Vendor(s) for these records via Request__c.
     * @param newRecords List of new records (Trigger.new)
     * @param oldMap Map of old records (Trigger.oldMap)
     * @param fieldsToTrack Set of field API names to monitor for changes
     */
    @SuppressWarnings('PMD.ApexCRUDViolation')
    public static void captureChanges(List<SObject> newRecords, Map<Id, SObject> oldMap, Set<String> fieldsToTrack) {
        
        if (isSyncContext) { return; }
        if (newRecords == null || newRecords.isEmpty()) { return; }

        try {
            // 1. EXTRACT TICKET IDs
            Set<Id> ticketIds = new Set<Id>();
            Map<Id, Id> recordToTicketId = new Map<Id, Id>();

            for (SObject rec : newRecords) {
                Id tId = getTicketId(rec); 
                if (tId != null) {
                    ticketIds.add(tId);
                    recordToTicketId.put(rec.Id, tId);
                }
            }

            if (ticketIds.isEmpty()) { return; }

            // 2. FIND ROUTES (The "Network" Logic)
            List<Request__c> connections = [
                SELECT Id, TicketId__c, DeliveryEntityId__c, RemoteTicketIdTxt__c 
                FROM Request__c 
                WHERE TicketId__c IN :ticketIds 
                AND StatusPk__c != 'Inactive' 
                AND DeliveryEntityId__c != NULL
            ];

            Map<Id, List<Request__c>> routes = new Map<Id, List<Request__c>>();
            for (Request__c r : connections) {
                if (!routes.containsKey(r.TicketId__c)) {
                    routes.put(r.TicketId__c, new List<Request__c>());
                }
                routes.get(r.TicketId__c).add(r);
            }

            // 3. GENERATE SYNC ITEMS
            List<Sync_Item__c> itemsToInsert = new List<Sync_Item__c>();

            for (SObject rec : newRecords) {
                
                // --- LOOP PREVENTION START ---
                Object sourceVal = getSafeValue(rec, 'SourcePk__c', 'delivery__SourcePk__c');
                String source = (sourceVal != null) ? (String)sourceVal : null;

                if (String.isNotBlank(source) && source != 'Client') {
                    continue; 
                }
                // --- LOOP PREVENTION END ---

                // Change Detection
                Boolean shouldSync = false;
                if (oldMap == null) {
                    shouldSync = true; 
                } else if (fieldsToTrack != null) {
                    SObject oldRec = oldMap.get(rec.Id);
                    for (String field : fieldsToTrack) {
                        Object newVal = getSafeValue(rec, field, 'delivery__' + field);
                        Object oldVal = getSafeValue(oldRec, field, 'delivery__' + field);
                        
                        if (newVal != oldVal) {
                            shouldSync = true;
                            break;
                        }
                    }
                } else {
                    shouldSync = true;
                }

                Id tId = recordToTicketId.get(rec.Id);
                if (shouldSync && routes.containsKey(tId)) {
                    for (Request__c req : routes.get(tId)) {
                        itemsToInsert.add(createSyncItem(rec, req));
                    }
                }
            }

            if (!itemsToInsert.isEmpty()) {
                insert itemsToInsert;
                
                if (!System.isQueueable() && !System.isFuture() && !System.isBatch()) {
                    System.enqueueJob(new SyncItemProcessor());
                }
            }

        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'SyncEngine Failed: ' + e.getMessage());
        }
    }

    /**
     * @description Helper to dynamically find the Ticket ID from supported objects.
     * @param rec The SObject record to inspect.
     * @return The Id of the related Ticket, or null if not found.
     */
    private static Id getTicketId(SObject rec) {
        String objName = rec.getSObjectType().getDescribe().getName();
        
        if (objName.endsWith('Ticket__c') && !objName.endsWith('Ticket_Comment__c')) {
            return (Id) rec.Id;
        } 
        else if (objName.endsWith('Ticket_Comment__c') || objName.endsWith('Request__c')) { 
            Object tId = getSafeValue(rec, 'TicketId__c', 'delivery__TicketId__c');
            return (tId != null) ? (Id)tId : null;
        }
        return null; 
    }

    /**
     * @description Helper to safely retrieve a field value without try/catch logic.
     * @param rec The SObject record to read from.
     * @param standardField The standard API name of the field.
     * @param namespacedField The namespaced API name of the field.
     * @return The value of the field if found, otherwise null.
     */
    private static Object getSafeValue(SObject rec, String standardField, String namespacedField) {
        Map<String, Object> fields = rec.getPopulatedFieldsAsMap();
        
        if (fields.containsKey(standardField)) {
            return fields.get(standardField);
        } else if (fields.containsKey(namespacedField)) {
            return fields.get(namespacedField);
        }
        return null;
    }

    /**
     * @description Creates a Sync_Item__c record for a specific routing request.
     * @param rec The record being synchronized.
     * @param req The Request (connection) record determining the target.
     * @return A populated Sync_Item__c record.
     */
    private static Sync_Item__c createSyncItem(SObject rec, Request__c req) {
        Sync_Item__c item = new Sync_Item__c();
        item.StatusPk__c = 'Queued';
        item.DirectionPk__c = 'Outbound';
        item.LocalRecordIdTxt__c = (String)rec.Id;
        item.TicketId__c = req.TicketId__c;
        item.RequestId__c = req.Id;
        
        // FIX: Strip namespace to satisfy Restricted Picklist
        String objectType = rec.getSObjectType().getDescribe().getName();
        objectType = objectType.replace('delivery__', ''); 
        item.ObjectTypePk__c = objectType;

        Map<String, Object> payload = rec.getPopulatedFieldsAsMap().clone();
        payload.put('SourceId', rec.Id); 
        payload.put('TargetId', req.RemoteTicketIdTxt__c); 

        item.PayloadTxt__c = JSON.serialize(payload);
        return item;
    }
}
/**
 * @description Core engine for handling outbound synchronization.
 * UPDATED: Replaces 'DeliveryHubSyncHandler' logic.
 * Uses Request__c to dynamically route updates to the correct Vendor(s).
 */
public without sharing class SyncEngine {

    // Prevent recursive triggers
    private static Boolean isSyncContext = false;

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
            // We need to know which Ticket these records belong to (or are) 
            // so we can find the Request connection.
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
            // Find ALL Active Requests linked to these Tickets.
            // This enables the "Daisy Chain" (A->B->C).
            List<Request__c> connections = [
                SELECT Id, TicketId__c, DeliveryEntityId__c, RemoteTicketIdTxt__c 
                FROM Request__c 
                WHERE TicketId__c IN :ticketIds 
                AND StatusPk__c != 'Inactive' 
                AND DeliveryEntityId__c != NULL
            ];

            // Map Ticket ID -> List of Requests (Routes)
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
                // Filter out records that came from the Mothership to prevent "Echoing" them back.
                try {
                    String source = (String) rec.get('SourcePk__c');
                    // If Source is defined and NOT 'Client', ignore it (it's inbound data).
                    // If Source is null, we assume it's local/client and sync it.
                    if (String.isNotBlank(source) && source != 'Client') {
                        continue; 
                    }
                } catch (Exception e) {
                    // Field 'SourcePk__c' might not exist on all objects (e.g. Ticket__c).
                    // Safe to ignore and proceed with sync.
                }
                // --- LOOP PREVENTION END ---

                // Change Detection
                Boolean shouldSync = false;
                if (oldMap == null) {
                    shouldSync = true; // Always sync on Insert
                } else if (fieldsToTrack != null) {
                    SObject oldRec = oldMap.get(rec.Id);
                    for (String field : fieldsToTrack) {
                        if (rec.get(field) != oldRec.get(field)) {
                            shouldSync = true;
                            break;
                        }
                    }
                } else {
                    // If fieldsToTrack is null, assume we sync on any update (or just insert)
                     shouldSync = true;
                }

                // If changed, send to ALL active routes for this Ticket
                Id tId = recordToTicketId.get(rec.Id);
                if (shouldSync && routes.containsKey(tId)) {
                    for (Request__c req : routes.get(tId)) {
                        itemsToInsert.add(createSyncItem(rec, req));
                    }
                }
            }

            if (!itemsToInsert.isEmpty()) {
                insert itemsToInsert;
                
                // Fire the Queueable immediately to send data
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
     */
    private static Id getTicketId(SObject rec) {
        String objName = rec.getSObjectType().getDescribe().getName();
        if (objName == 'Ticket__c') {
            return (Id) rec.get('Id');
        } else if (objName == 'Ticket_Comment__c' || objName == 'Request__c') { 
            return (Id) rec.get('TicketId__c');
        }
        return null; 
    }

    private static Sync_Item__c createSyncItem(SObject rec, Request__c req) {
        Sync_Item__c item = new Sync_Item__c();
        item.StatusPk__c = 'Queued';
        item.DirectionPk__c = 'Outbound';
        
        // Linkage
        item.LocalRecordIdTxt__c = (String)rec.Id;
        item.TicketId__c = req.TicketId__c;     // Link to the Ticket
        item.RequestId__c = req.Id;             // Link to the Bridge

        // Object Type
        String objectType = rec.getSObjectType().getDescribe().getName();
        item.ObjectTypePk__c = objectType;

        // Payload Construction
        Map<String, Object> payload = rec.getPopulatedFieldsAsMap().clone();
        
        // VITAL: Inject the Routing IDs so the Receiver knows what to update
        payload.put('SourceId', rec.Id); 
        payload.put('TargetId', req.RemoteTicketIdTxt__c); 

        item.PayloadTxt__c = JSON.serialize(payload);
        return item;
    }
}
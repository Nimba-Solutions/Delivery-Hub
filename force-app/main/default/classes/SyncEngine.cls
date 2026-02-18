/**
 * @description Core engine for handling outbound synchronization.
 * Implements Push/Pull Architecture with Smart Routing and Allowlist Filtering.
 */
public without sharing class SyncEngine {

    // Prevent recursive triggers during Inbound processing
    private static Boolean isSyncContext = false;

    public static void setSyncContext() {
        isSyncContext = true;
    }

    /**
     * @description Main Entry Point. Captures changes, applies logic, and queues Sync Items.
     * @param newRecords Trigger.new
     * @param oldMap Trigger.oldMap
     * @param allowedFields Set of API names to sync (The Allowlist)
     */
    @SuppressWarnings('PMD.ApexCRUDViolation')
    public static void captureChanges(List<SObject> newRecords, Map<Id, SObject> oldMap, Set<String> allowedFields) {
        
        // 1. Context Check (Optional: relying on Smart Routing is safer for Hubs, but this saves CPU on direct-echo)
        if (isSyncContext) { return; }
        if (newRecords == null || newRecords.isEmpty()) { return; }

        try {
            // 2. Resolve Parent Ticket IDs
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

            // 3. Find Active Routes (Requests)
            // We fetch the RemoteTicketIdTxt__c to perform Smart Routing (Loop Prevention)
            List<Request__c> connections = [
                SELECT Id, TicketId__c, DeliveryEntityId__c, RemoteTicketIdTxt__c, 
                       DeliveryEntityId__r.StatusPk__c
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

            // 4. Process Records
            List<Sync_Item__c> itemsToInsert = new List<Sync_Item__c>();

            for (SObject rec : newRecords) {
                SObject oldRec = (oldMap != null) ? oldMap.get(rec.Id) : null;

                // --- A. Field Change Check (Optimization) ---
                // If allowedFields is provided, check if any of them actually changed.
                Boolean hasChanged = false;
                if (oldRec == null) {
                    hasChanged = true; // Always sync on Insert
                } else if (allowedFields != null && !allowedFields.isEmpty()) {
                    Map<String, Object> newFields = rec.getPopulatedFieldsAsMap();
                    Map<String, Object> oldFields = oldRec.getPopulatedFieldsAsMap();
                    
                    for (String field : allowedFields) {
                        Object nVal = newFields.containsKey(field) ? newFields.get(field) : newFields.get('delivery__' + field);
                        Object oVal = oldFields.containsKey(field) ? oldFields.get(field) : oldFields.get('delivery__' + field);
                        if (nVal != oVal) {
                            hasChanged = true;
                            break;
                        }
                    }
                } else {
                    hasChanged = true; // No allowlist = Sync everything (e.g. Comments)
                }

                if (!hasChanged) { continue; }

                // --- B. Route & Package ---
                Id tId = recordToTicketId.get(rec.Id);
                if (routes.containsKey(tId)) {
                    
                    // Get Origin ID for Smart Routing
                    String originId = getSafeString(rec, 'RemoteExternalIdTxt__c');

                    for (Request__c req : routes.get(tId)) {
                        // --- C. SMART ROUTING (Loop Prevention) ---
                        // If the record came from Vendor A (originId), do NOT send it back to Vendor A (req.RemoteTicketId).
                        if (String.isNotBlank(originId) && originId == req.RemoteTicketIdTxt__c) {
                            continue; 
                        }
                        
                        itemsToInsert.add(createSyncItem(rec, req, allowedFields));
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

    // --- HELPERS ---

    private static Id getTicketId(SObject rec) {
        String objName = rec.getSObjectType().getDescribe().getName();
        // Support Tickets, Comments, and potentially Files (ContentVersion requires extra query usually, simplified here)
        if (objName.endsWith('Ticket__c') && !objName.endsWith('Ticket_Comment__c')) {
            return (Id) rec.Id;
        } 
        // Comments and Requests link via TicketId__c
        Object tId = getSafeValue(rec, 'TicketId__c');
        return (tId != null) ? (Id)tId : null;
    }

    private static Object getSafeValue(SObject rec, String field) {
        Map<String, Object> fields = rec.getPopulatedFieldsAsMap();
        if (fields.containsKey(field)) return fields.get(field);
        if (fields.containsKey('delivery__' + field)) return fields.get('delivery__' + field);
        return null;
    }

    private static String getSafeString(SObject rec, String field) {
        return (String) getSafeValue(rec, field);
    }

    private static Sync_Item__c createSyncItem(SObject rec, Request__c req, Set<String> allowedFields) {
        Sync_Item__c item = new Sync_Item__c();
        item.StatusPk__c = 'Queued';
        item.DirectionPk__c = 'Outbound';
        item.LocalRecordIdTxt__c = (String)rec.Id;
        item.TicketId__c = req.TicketId__c;
        item.RequestId__c = req.Id; // Link strictly to this Request route
        
        String objType = rec.getSObjectType().getDescribe().getName().replace('delivery__', '');
        item.ObjectTypePk__c = objType;

        // --- FIELD FILTERING ---
        Map<String, Object> rawMap = rec.getPopulatedFieldsAsMap();
        Map<String, Object> finalPayload = new Map<String, Object>();

        if (allowedFields != null && !allowedFields.isEmpty()) {
            for (String field : allowedFields) {
                // Check standard
                if (rawMap.containsKey(field)) finalPayload.put(field, rawMap.get(field));
                // Check namespaced
                else if (rawMap.containsKey('delivery__' + field)) finalPayload.put(field, rawMap.get('delivery__' + field));
            }
        } else {
            // If no allowlist (e.g. Comments), copy everything except system fields
            // (You might want to add a default blocklist here in future)
            finalPayload = rawMap.clone();
        }

        // --- HEADER INJECTION ---
        finalPayload.put('SourceId', rec.Id); 
        finalPayload.put('TargetId', req.RemoteTicketIdTxt__c); 

        item.PayloadTxt__c = JSON.serialize(finalPayload);
        return item;
    }
}
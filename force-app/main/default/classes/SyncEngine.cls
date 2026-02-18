/**
 * @description Core engine for handling outbound synchronization.
 * Implements Push/Pull Architecture with Smart Routing and Allowlist Filtering.
 */
public without sharing class SyncEngine {

    // Prevent recursive triggers during Inbound processing
    private static Boolean isSyncContext = false;
    
    // LEDGER PATTERN: In-memory list of Remote IDs to ignore (Prevent Loops/Echoes)
    // The Receiver (Ingestor) populates this before performing DML.
    private static Set<String> blockedOrigins = new Set<String>();

    public static void setSyncContext() {
        isSyncContext = true;
    }
    
    /**
     * @description Called by Ingestor to prevent echoing updates back to this specific origin.
     */
    public static void ignoreOrigin(String remoteId) {
        if (String.isNotBlank(remoteId)) {
            blockedOrigins.add(remoteId);
        }
    }

    /**
     * @description Main Entry Point. Captures changes, applies logic, and queues Sync Items.
     * @param newRecords Trigger.new
     * @param oldMap Trigger.oldMap
     * @param allowedFields Set of API names to sync (The Allowlist)
     */
    @SuppressWarnings('PMD.ApexCRUDViolation')
    public static void captureChanges(List<SObject> newRecords, Map<Id, SObject> oldMap, Set<String> allowedFields) {
        
        // 1. Context Check (Global "Nuclear" Switch)
        if (isSyncContext) {
            return;
        }
        if (newRecords == null || newRecords.isEmpty()) {
            return;
        }

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

            if (ticketIds.isEmpty()) {
                return;
            }

            // 3. Find Active Routes (Requests)
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

                // --- A. Field Change Check ---
                Boolean hasChanged = false;
                if (oldRec == null) {
                    hasChanged = true; 
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
                    hasChanged = true; 
                }

                if (!hasChanged) {
                    continue;
                }

                // --- B. Route & Package ---
                Id tId = recordToTicketId.get(rec.Id);
                if (routes.containsKey(tId)) {
                    
                    for (Request__c req : routes.get(tId)) {
                        // --- C. SMART ROUTING (Loop Prevention) ---
                        // Check against the in-memory blocked list (populated by Receiver)
                        if (blockedOrigins.contains(req.RemoteTicketIdTxt__c)) {
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
        
        if (objName.endsWith('Ticket__c') && !objName.endsWith('Ticket_Comment__c')) {
            return (Id) rec.Id;
        } 
        
        Object tId = getSafeValue(rec, 'TicketId__c');
        if (tId != null) {
            return (Id)tId;
        }
        return null; 
    }

    private static Object getSafeValue(SObject rec, String field) {
        Map<String, Object> fields = rec.getPopulatedFieldsAsMap();
        if (fields.containsKey(field)) {
            return fields.get(field);
        }
        if (fields.containsKey('delivery__' + field)) {
            return fields.get('delivery__' + field);
        }
        return null;
    }

    private static Sync_Item__c createSyncItem(SObject rec, Request__c req, Set<String> allowedFields) {
        Sync_Item__c item = new Sync_Item__c();
        item.StatusPk__c = 'Queued';
        item.DirectionPk__c = 'Outbound';
        item.LocalRecordIdTxt__c = (String)rec.Id;
        item.TicketId__c = req.TicketId__c;
        item.RequestId__c = req.Id; 
        
        String objType = rec.getSObjectType().getDescribe().getName().replace('delivery__', '');
        item.ObjectTypePk__c = objType;

        Map<String, Object> rawMap = rec.getPopulatedFieldsAsMap();
        Map<String, Object> finalPayload = new Map<String, Object>();

        if (allowedFields != null && !allowedFields.isEmpty()) {
            for (String field : allowedFields) {
                if (rawMap.containsKey(field)) {
                    finalPayload.put(field, rawMap.get(field));
                } else if (rawMap.containsKey('delivery__' + field)) {
                    finalPayload.put(field, rawMap.get('delivery__' + field));
                }
            }
        } else {
            finalPayload = rawMap.clone();
        }

        finalPayload.put('SourceId', rec.Id); 
        finalPayload.put('TargetId', req.RemoteTicketIdTxt__c); 

        item.PayloadTxt__c = JSON.serialize(finalPayload);
        return item;
    }
}
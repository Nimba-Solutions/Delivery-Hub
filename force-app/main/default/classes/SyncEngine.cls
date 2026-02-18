/**
 * @description Core engine for handling outbound synchronization.
 * Implements Push/Pull Architecture with Smart Routing and Allowlist Filtering.
 */
public without sharing class SyncEngine {

    private static Boolean isSyncContext = false;
    private static Set<String> blockedOrigins = new Set<String>();

    /**
     * @description Sets the sync context to prevent recursive triggers.
     */
    public static void setSyncContext() {
        isSyncContext = true;
    }
    
    /**
     * @description Called by Ingestor to prevent echoing updates back to this specific origin.
     * @param remoteId The external ID of the source system to block.
     */
    public static void ignoreOrigin(String remoteId) {
        if (String.isNotBlank(remoteId)) {
            blockedOrigins.add(remoteId);
        }
    }

    /**
     * @description Main Entry Point. Captures changes and queues Sync Items.
     */
    @SuppressWarnings('PMD.ApexCRUDViolation')
    public static void captureChanges(List<SObject> newRecords, Map<Id, SObject> oldMap, Set<String> allowedFields) {
        if (isSyncContext || newRecords == null || newRecords.isEmpty()) {
            return;
        }

        try {
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

            List<Request__c> connections = [
                SELECT Id, TicketId__c, RemoteTicketIdTxt__c, DeliveryEntityId__c 
                FROM Request__c 
                WHERE TicketId__c IN :ticketIds AND StatusPk__c != 'Inactive'
            ];

            Map<Id, List<Request__c>> routes = new Map<Id, List<Request__c>>();
            for (Request__c r : connections) {
                // Use Safe Value to get the TicketId in namespaced orgs
                Id rTicketId = (Id) getSafeValue(r, 'TicketId__c');
                if (rTicketId == null) { continue; }
                if (!routes.containsKey(rTicketId)) {
                    routes.put(rTicketId, new List<Request__c>());
                }
                routes.get(rTicketId).add(r);
            }

            List<Sync_Item__c> itemsToInsert = new List<Sync_Item__c>();
            for (SObject rec : newRecords) {
                if (!hasSignificantChange(rec, (oldMap != null ? oldMap.get(rec.Id) : null), allowedFields)) {
                    continue;
                }

                Id tId = recordToTicketId.get(rec.Id);
                if (routes.containsKey(tId)) {
                    for (Request__c req : routes.get(tId)) {
                        // CRITICAL: Use Safe Value for the Echo Suppression Check
                        String remoteId = (String) getSafeValue(req, 'RemoteTicketIdTxt__c');
                        if (String.isNotBlank(remoteId) && blockedOrigins.contains(remoteId)) {
                            continue; 
                        }
                        itemsToInsert.add(createSyncItem(rec, req, allowedFields));
                    }
                }
            }

            if (!itemsToInsert.isEmpty()) {
                insert itemsToInsert;
                if (!System.isQueueable() && !System.isFuture()) {
                    System.enqueueJob(new SyncItemProcessor());
                }
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'SyncEngine Failed: ' + e.getMessage());
        }
    }

    private static Boolean hasSignificantChange(SObject rec, SObject oldRec, Set<String> allowedFields) {
        if (oldRec == null || allowedFields == null || allowedFields.isEmpty()) { return true; }
        for (String field : allowedFields) {
            if (getSafeValue(rec, field) != getSafeValue(oldRec, field)) { return true; }
        }
        return false;
    }

    private static Id getTicketId(SObject rec) {
        String objName = rec.getSObjectType().getDescribe().getName();
        if (objName.endsWith('Ticket__c') && !objName.endsWith('Ticket_Comment__c')) { return (Id) rec.Id; } 
        return (Id) getSafeValue(rec, 'TicketId__c');
    }

    private static Object getSafeValue(SObject rec, String field) {
        Map<String, Object> fields = rec.getPopulatedFieldsAsMap();
        if (fields.containsKey(field)) { return fields.get(field); }
        if (fields.containsKey('delivery__' + field)) { return fields.get('delivery__' + field); }
        return null;
    }

    private static Sync_Item__c createSyncItem(SObject rec, Request__c req, Set<String> allowedFields) {
        Sync_Item__c item = new Sync_Item__c(StatusPk__c = 'Queued', DirectionPk__c = 'Outbound');
        item.LocalRecordIdTxt__c = (String)rec.Id;
        item.TicketId__c = (Id) getSafeValue(req, 'TicketId__c');
        item.RequestId__c = req.Id; 
        item.ObjectTypePk__c = rec.getSObjectType().getDescribe().getName().replace('delivery__', '');

        Map<String, Object> payload = new Map<String, Object>();
        if (allowedFields != null) {
            for (String f : allowedFields) { payload.put(f, getSafeValue(rec, f)); }
        } else {
            payload = rec.getPopulatedFieldsAsMap().clone();
        }
        payload.put('SourceId', rec.Id); 
        payload.put('TargetId', getSafeValue(req, 'RemoteTicketIdTxt__c')); 
        item.PayloadTxt__c = JSON.serialize(payload);
        return item;
    }
}
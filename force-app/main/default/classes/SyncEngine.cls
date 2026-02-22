/**
 * @description Core engine for handling outbound synchronization.
 * Implements Push/Pull Architecture with DAG Routing, Entity Type Enforcement, 
 * and Origin-Based Echo Suppression.
 */
public without sharing class SyncEngine {

    private static Boolean isSyncContext = false;
    @TestVisible private static Set<String> blockedOrigins = new Set<String>();

    public static void setSyncContext() {
        isSyncContext = true;
    }
    
    // Stores the Request ID (Downstream) or Network Entity ID (Upstream) to prevent echo loops
    public static void ignoreOrigin(String originId) {
        if (String.isNotBlank(originId)) {
            blockedOrigins.add(originId.trim());
        }
    }

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

            if (ticketIds.isEmpty()) {
                return;
            }

            // 1. Evaluate Upstream Routing Edges (The Parent Tickets)
            Map<Id, Ticket__c> parentTickets = new Map<Id, Ticket__c>([
                SELECT Id, ClientNetworkEntityId__c, ClientNetworkEntityId__r.EntityTypePk__c 
                FROM Ticket__c 
                WHERE Id IN :ticketIds
                WITH SYSTEM_MODE
            ]);

            // 2. Evaluate Downstream Routing Edges (Active, Typed Requests)
            List<Request__c> connections = [
                SELECT Id, TicketId__c, RemoteTicketIdTxt__c, DeliveryEntityId__c, 
                       DeliveryEntityId__r.IntegrationEndpointUrlTxt__c, 
                       DeliveryEntityId__r.EntityTypePk__c, StatusPk__c 
                FROM Request__c 
                WHERE TicketId__c IN :ticketIds 
                  AND StatusPk__c != 'Inactive' 
                  AND DeliveryEntityId__c != NULL 
                  AND DeliveryEntityId__r.EntityTypePk__c IN ('Vendor', 'Both')
                WITH SYSTEM_MODE
            ];

            Map<Id, List<Request__c>> routes = new Map<Id, List<Request__c>>();
            for (Request__c r : connections) {
                if (!routes.containsKey(r.TicketId__c)) {
                    routes.put(r.TicketId__c, new List<Request__c>());
                }
                routes.get(r.TicketId__c).add(r);
            }

            List<Sync_Item__c> itemsToInsert = new List<Sync_Item__c>();
            for (SObject rec : newRecords) {
                if (!hasSignificantChange(rec, (oldMap != null ? oldMap.get(rec.Id) : null), allowedFields)) {
                    continue;
                }

                Id tId = recordToTicketId.get(rec.Id);
                Ticket__c parentTicket = parentTickets.get(tId);
                List<Request__c> reqs = routes.get(tId);

                // ==========================================
                // FAN OUT DOWNSTREAM (Push to Sub-Vendors)
                // ==========================================
                if (reqs != null && !reqs.isEmpty()) {
                    for (Request__c req : reqs) {
                        // Echo Suppression: Do not bounce back down the edge it arrived on
                        if (blockedOrigins.contains((String)req.Id)) {
                            continue;
                        } 
                        itemsToInsert.add(createSyncItem(rec, req, allowedFields));
                    }
                }

                // ==========================================
                // FAN OUT UPSTREAM (Stage for Client Poller)
                // ==========================================
                if (parentTicket != null && parentTicket.ClientNetworkEntityId__c != null) {
                    String entityType = parentTicket.ClientNetworkEntityId__r.EntityTypePk__c;
                    
                    if (entityType == 'Client' || entityType == 'Both') {
                        // Echo Suppression: Do not stage for the Client if they just pushed this to us
                        if (blockedOrigins.contains((String)parentTicket.ClientNetworkEntityId__c)) {
                            continue;
                        }
                        
                        itemsToInsert.add(createSyncItem(rec, null, allowedFields));
                    }
                }
            }

            if (!itemsToInsert.isEmpty()) {
                Database.insert(itemsToInsert, AccessLevel.SYSTEM_MODE);
                if (Limits.getQueueableJobs() == 0 && !System.isQueueable() && !System.isFuture()) {
                    System.enqueueJob(new SyncItemProcessor());
                }
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'SyncEngine Failed: ' + e.getMessage());
        }
    }

    private static Boolean hasSignificantChange(SObject rec, SObject oldRec, Set<String> allowedFields) {
        if (oldRec == null) {
            return true;
        }
        for (String field : allowedFields) {
            if (getSafeValue(rec, field) != getSafeValue(oldRec, field)) {
                return true;
            }
        }
        return false;
    }

    private static Id getTicketId(SObject rec) {
        String name = rec.getSObjectType().getDescribe().getName();
        if (name.endsWithIgnoreCase('Ticket__c') && !name.endsWithIgnoreCase('Ticket_Comment__c')) {
            return rec.Id;
        }
        return (Id) getSafeValue(rec, 'TicketId__c');
    }

    private static Object getSafeValue(SObject rec, String field) {
        Map<String, Object> fields = rec.getPopulatedFieldsAsMap();
        if (fields.containsKey(field)) {
            return fields.get(field);
        }
        for (String key : fields.keySet()) {
            if (key.endsWithIgnoreCase('__' + field)) {
                return fields.get(key);
            }
        }
        return null;
    }

    private static Sync_Item__c createSyncItem(SObject rec, Request__c req, Set<String> allowedFields) {
        Sync_Item__c item = new Sync_Item__c(StatusPk__c = 'Queued', DirectionPk__c = 'Outbound');
        item.LocalRecordIdTxt__c = (String)rec.Id;
        item.TicketId__c = getTicketId(rec); // MANDATORY: Required for Vendor's SOQL Security Filtering

        String fullApiName = rec.getSObjectType().getDescribe().getName();
        String cleanName = fullApiName.replace('delivery__', '');
        item.ObjectTypePk__c = cleanName;

        populateLookupField(item, cleanName, rec.Id);

        Map<String, Object> payload = new Map<String, Object>();
        for (String f : allowedFields) { 
            payload.put(f, getSafeValue(rec, f)); 
        }
        payload.put('SourceId', rec.Id); 
        
        if (req != null) {
            // Push Mode: Explicit Downstream Route
            item.RequestId__c = req.Id; 
            payload.put('TargetId', req.RemoteTicketIdTxt__c); 
        } else {
            // Hub Mode: Upstream Stage
            payload.put('TargetId', item.TicketId__c);
        }
        
        item.PayloadTxt__c = JSON.serialize(payload);
        return item;
    }

    private static void populateLookupField(SObject item, String cleanName, Id recordId) {
        String lookupField;
        if (cleanName.endsWithIgnoreCase('__c')) {
            lookupField = cleanName.substringBeforeLast('__c').replace('_', '') + 'Id__c';
        } else {
            lookupField = cleanName + 'Id__c';
        }
        
        try {
            item.put(lookupField, recordId);
        } catch (Exception e1) {
            try {
                item.put('delivery__' + lookupField, recordId);
            } catch (Exception e2) {
                System.debug(LoggingLevel.FINE, 'Lookup field mapping skipped for ' + cleanName + ': ' + e2.getMessage());
            }
        }
    }
}
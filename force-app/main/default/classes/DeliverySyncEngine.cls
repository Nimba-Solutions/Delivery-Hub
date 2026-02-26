/**
 * @description Core engine for handling outbound synchronization.
 * Implements Push/Pull Architecture with DAG Routing, Entity Type Enforcement, 
 * Origin-Based Echo Suppression, and Global Traceability (Loop Prevention).
 * @author Cloud Nimbus LLC
 */
public without sharing class DeliverySyncEngine {

    public static Boolean isSyncContext = false;
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
            Set<Id> recordIds = new Set<Id>();
            Map<Id, Id> recordToTicketId = new Map<Id, Id>();

            for (SObject rec : newRecords) {
                recordIds.add(rec.Id);
                Id tId = getTicketId(rec); 
                if (tId != null) {
                    ticketIds.add(tId);
                    recordToTicketId.put(rec.Id, tId);
                }
            }

            if (ticketIds.isEmpty()) {
                return;
            }

            // 1. Fetch Existing Ledger Info to find GlobalSourceId inheritance
            // We look for Inbound items to see if this record was born in another org
            Map<Id, String> recordToGlobalSource = new Map<Id, String>();
            for (Sync_Item__c existingItem : [
                SELECT LocalRecordIdTxt__c, GlobalSourceIdTxt__c 
                FROM Sync_Item__c 
                WHERE LocalRecordIdTxt__c IN :recordIds 
                AND GlobalSourceIdTxt__c != NULL
                WITH SYSTEM_MODE
            ]) {
                recordToGlobalSource.put((Id)existingItem.LocalRecordIdTxt__c, existingItem.GlobalSourceIdTxt__c);
            }

            // 2. Evaluate Upstream Routing Edges (The Parent Tickets)
            Map<Id, WorkItem__c> parentTickets = new Map<Id, WorkItem__c>([
                SELECT Id, ClientNetworkEntityId__c, ClientNetworkEntityId__r.EntityTypePk__c 
                FROM WorkItem__c 
                WHERE Id IN :ticketIds
                WITH SYSTEM_MODE
            ]);

            // 3. Evaluate Downstream Routing Edges (Active, Typed Requests)
            List<WorkRequest__c> connections = [
                SELECT Id, WorkItemId__c, RemoteTicketIdTxt__c, DeliveryEntityId__c, 
                       DeliveryEntityId__r.IntegrationEndpointUrlTxt__c, 
                       DeliveryEntityId__r.EntityTypePk__c, StatusPk__c 
                FROM WorkRequest__c 
                WHERE WorkItemId__c IN :ticketIds 
                  AND StatusPk__c != 'Inactive' 
                  AND DeliveryEntityId__c != NULL 
                  AND DeliveryEntityId__r.EntityTypePk__c IN ('Vendor', 'Both')
                WITH SYSTEM_MODE
            ];

            Map<Id, List<WorkRequest__c>> routes = new Map<Id, List<WorkRequest__c>>();
            for (WorkRequest__c r : connections) {
                if (!routes.containsKey(r.WorkItemId__c)) {
                    routes.put(r.WorkItemId__c, new List<WorkRequest__c>());
                }
                routes.get(r.WorkItemId__c).add(r);
            }

            List<Sync_Item__c> itemsToInsert = new List<Sync_Item__c>();
            for (SObject rec : newRecords) {
                if (!hasSignificantChange(rec, (oldMap != null ? oldMap.get(rec.Id) : null), allowedFields)) {
                    continue;
                }

                Id tId = recordToTicketId.get(rec.Id);
                WorkItem__c parentTicket = parentTickets.get(tId);
                List<WorkRequest__c> reqs = routes.get(tId);

                // Determine Global Source: Inherit from ledger or this is the Birthplace
                String globalSourceId = recordToGlobalSource.containsKey(rec.Id) 
                    ? recordToGlobalSource.get(rec.Id) 
                    : (String)rec.Id;

                // ==========================================
                // FAN OUT DOWNSTREAM (Push to Sub-Vendors)
                // ==========================================
                if (reqs != null && !reqs.isEmpty()) {
                    for (WorkRequest__c req : reqs) {
                        // Kill-Switch: If target is the Global Source or matches incoming edge, suppress circular sync
                        if (blockedOrigins.contains((String)req.Id) || req.RemoteTicketIdTxt__c == globalSourceId) {
                            continue;
                        } 
                        itemsToInsert.add(createSyncItem(rec, req, allowedFields, globalSourceId));
                    }
                }

                // ==========================================
                // FAN OUT UPSTREAM (Stage for Client Poller)
                // ==========================================
                if (parentTicket != null && parentTicket.ClientNetworkEntityId__c != null) {
                    String entityType = parentTicket.ClientNetworkEntityId__r.EntityTypePk__c;
                    
                    if (entityType == 'Client' || entityType == 'Both') {
                        // Kill-Switch: Do not stage for Client if they are the Global Source or sent this to us
                        if (blockedOrigins.contains((String)parentTicket.ClientNetworkEntityId__c) || 
                            (String)parentTicket.ClientNetworkEntityId__c == globalSourceId) {
                            continue;
                        }
                        
                        itemsToInsert.add(createSyncItem(rec, null, allowedFields, globalSourceId));
                    }
                }
            }

            if (!itemsToInsert.isEmpty()) {
                Database.insert(itemsToInsert, AccessLevel.SYSTEM_MODE);
                if (Limits.getQueueableJobs() == 0 && !System.isQueueable() && !System.isFuture()) {
                    System.enqueueJob(new DeliverySyncItemProcessor());
                }
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'DeliverySyncEngine Failed: ' + e.getMessage());
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
        if (name.endsWithIgnoreCase('WorkItem__c') && !name.endsWithIgnoreCase('WorkItemComment__c')) {
            return rec.Id;
        }
        return (Id) getSafeValue(rec, 'WorkItemId__c');
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

    private static Sync_Item__c createSyncItem(SObject rec, WorkRequest__c req, Set<String> allowedFields, String globalSourceId) {
        Sync_Item__c item = new Sync_Item__c(
            StatusPk__c = 'Queued', 
            DirectionPk__c = 'Outbound',
            GlobalSourceIdTxt__c = globalSourceId
        );
        item.LocalRecordIdTxt__c = (String)rec.Id;
        item.WorkItemId__c = getTicketId(rec); // MANDATORY: Required for Vendor's SOQL Security Filtering

        String fullApiName = rec.getSObjectType().getDescribe().getName();
        String cleanName = fullApiName.replace('delivery__', '');
        item.ObjectTypePk__c = cleanName;

        populateLookupField(item, cleanName, rec.Id);

        Map<String, Object> payload = new Map<String, Object>();
        for (String f : allowedFields) { 
            payload.put(f, getSafeValue(rec, f)); 
        }
        payload.put('SourceId', rec.Id); 
        payload.put('GlobalSourceId', globalSourceId); // Pass the passport stamp
        
        // NEW: Inject the Sender Identity so the receiver knows exactly who pushed this payload
        payload.put('SenderOrgId', UserInfo.getOrganizationId()); 
        
        if (req != null) {
            // Push Mode: Explicit Downstream Route
            item.RequestId__c = req.Id; 
            payload.put('TargetId', req.RemoteTicketIdTxt__c); 
        } else {
            // Hub Mode: Upstream Stage
            payload.put('TargetId', item.WorkItemId__c);
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
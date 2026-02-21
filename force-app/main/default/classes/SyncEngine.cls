/**
 * @description Core engine for handling outbound synchronization.
 * Implements Push/Pull Architecture with Smart Routing and Allowlist Filtering.
 * Refactored to enforce downstream-only routing edges and dynamic lookup resolution.
 */
public without sharing class SyncEngine {

    private static Boolean isSyncContext = false;
    @TestVisible private static Set<String> blockedOrigins = new Set<String>();

    public static void setSyncContext() {
        isSyncContext = true;
    }
    
    public static void ignoreOrigin(String remoteId) {
        if (String.isNotBlank(remoteId)) {
            blockedOrigins.add(remoteId.trim());
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

            // Query strictly for downstream routing edges
            List<Request__c> connections = [
                SELECT Id, TicketId__c, RemoteTicketIdTxt__c, DeliveryEntityId__c, 
                       DeliveryEntityId__r.IntegrationEndpointUrlTxt__c, StatusPk__c 
                FROM Request__c 
                WHERE TicketId__c IN :ticketIds AND StatusPk__c != 'Inactive'
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
                List<Request__c> reqs = routes.get(tId);
                
                Boolean hasPushableRoute = false;
                Boolean isBlocked = false;

                if (reqs != null && !reqs.isEmpty()) {
                    for (Request__c req : reqs) {
                        String remoteId = req.RemoteTicketIdTxt__c;
                        
                        // Echo Suppression
                        if (String.isNotBlank(remoteId) && blockedOrigins.contains(remoteId.trim())) {
                            isBlocked = true;
                            continue;
                        } 
                        
                        // Enforce Downstream Routing: Only push if a valid downstream entity exists
                        if (req.StatusPk__c != 'Inactive' && req.DeliveryEntityId__c != null) {
                            itemsToInsert.add(createSyncItem(rec, req, allowedFields));
                            hasPushableRoute = true;
                        }
                    }
                }

                // Passive Hub Mode: Stage for upstream Poller if no downstream push occurred
                if (!hasPushableRoute && !isBlocked) {
                    itemsToInsert.add(createSyncItem(rec, null, allowedFields));
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
        item.TicketId__c = getTicketId(rec);

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
            // Push Mode: Target downstream node's ID
            item.RequestId__c = req.Id; 
            payload.put('TargetId', req.RemoteTicketIdTxt__c); 
        } else {
            // Hub Mode: Stage local ID for upstream Poller translation
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
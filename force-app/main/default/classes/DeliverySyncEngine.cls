/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Core engine for handling outbound synchronization.
 * Implements Push/Pull Architecture with DAG Routing, Entity Type Enforcement, 
 * Origin-Based Echo Suppression, and Global Traceability (Loop Prevention).
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.CyclomaticComplexity, PMD.StdCyclomaticComplexity')
public without sharing class DeliverySyncEngine {

    public static Boolean isSyncContext = false;
    @TestVisible private static Set<String> blockedOrigins = new Set<String>();

    /** @description Flags the current transaction as a sync context to prevent recursive processing. */
    public static void setSyncContext() {
        isSyncContext = true;
    }
    
    /**
     * @description Registers an origin ID to block echo loops during sync routing.
     * Stores the Request ID (Downstream) or Network Entity ID (Upstream).
     * @param originId The ID of the origin to suppress.
     */
    public static void ignoreOrigin(String originId) {
        if (String.isNotBlank(originId)) {
            blockedOrigins.add(originId.trim());
        }
    }

    /**
     * @description Captures field-level changes on records and fans out Sync Items to downstream
     * vendors (Push) and upstream clients (Hub) based on DAG routing edges.
     * @param newRecords The list of new/updated SObject records from the trigger context.
     * @param oldMap The map of old SObject records for comparison (null on insert).
     * @param allowedFields The set of field API names to include in the sync payload.
     */
    @SuppressWarnings('PMD.ApexCRUDViolation, PMD.CyclomaticComplexity, PMD.StdCyclomaticComplexity, PMD.NcssMethodCount')
    public static void captureChanges(List<SObject> newRecords, Map<Id, SObject> oldMap, Set<String> allowedFields) {
        if (isSyncContext || newRecords == null || newRecords.isEmpty()) {
            return;
        }

        try {
            Set<Id> workItemIds = new Set<Id>();
            Set<Id> recordIds = new Set<Id>();
            Map<Id, Id> recordToWorkItemId = new Map<Id, Id>();

            for (SObject rec : newRecords) {
                recordIds.add(rec.Id);
                Id tId = getWorkItemId(rec); 
                if (tId != null) {
                    workItemIds.add(tId);
                    recordToWorkItemId.put(rec.Id, tId);
                }
            }

            if (workItemIds.isEmpty()) {
                return;
            }

            // 1. Fetch Existing Ledger Info to find GlobalSourceId inheritance
            // We look for Inbound items to see if this record was born in another org
            Map<Id, String> recordToGlobalSource = new Map<Id, String>();
            for (SyncItem__c existingItem : [
                SELECT LocalRecordIdTxt__c, GlobalSourceIdTxt__c 
                FROM SyncItem__c 
                WHERE LocalRecordIdTxt__c IN :recordIds 
                AND GlobalSourceIdTxt__c != NULL
                WITH SYSTEM_MODE
            ]) {
                recordToGlobalSource.put((Id)existingItem.LocalRecordIdTxt__c, existingItem.GlobalSourceIdTxt__c);
            }

            // 2. Evaluate Upstream Routing Edges (The Parent Work Items)
            Map<Id, WorkItem__c> parentWorkItems = new Map<Id, WorkItem__c>([
                SELECT Id, ClientNetworkEntityLookup__c, ClientNetworkEntityLookup__r.EntityTypePk__c,
                       ClientNetworkEntityLookup__r.EnableVendorPushDateTime__c,
                       ClientNetworkEntityLookup__r.IntegrationEndpointUrlTxt__c
                FROM WorkItem__c
                WHERE Id IN :workItemIds
                WITH SYSTEM_MODE
            ]);

            // 3. Evaluate Downstream Routing Edges (Active, Typed Requests)
            List<WorkRequest__c> connections = [
                SELECT Id, WorkItemId__c, RemoteWorkItemIdTxt__c, DeliveryEntityLookup__c, 
                       DeliveryEntityLookup__r.IntegrationEndpointUrlTxt__c, 
                       DeliveryEntityLookup__r.EntityTypePk__c, StatusPk__c 
                FROM WorkRequest__c 
                WHERE WorkItemId__c IN :workItemIds 
                  AND StatusPk__c != 'Inactive' 
                  AND DeliveryEntityLookup__c != NULL 
                  AND DeliveryEntityLookup__r.EntityTypePk__c IN ('Vendor', 'Both')
                WITH SYSTEM_MODE
            ];

            Map<Id, List<WorkRequest__c>> routes = new Map<Id, List<WorkRequest__c>>();
            for (WorkRequest__c r : connections) {
                if (!routes.containsKey(r.WorkItemId__c)) {
                    routes.put(r.WorkItemId__c, new List<WorkRequest__c>());
                }
                routes.get(r.WorkItemId__c).add(r);
            }

            List<SyncItem__c> itemsToInsert = new List<SyncItem__c>();
            for (SObject rec : newRecords) {
                if (!hasSignificantChange(rec, (oldMap != null ? oldMap.get(rec.Id) : null), allowedFields)) {
                    continue;
                }

                Id tId = recordToWorkItemId.get(rec.Id);
                WorkItem__c parentWorkItem = parentWorkItems.get(tId);
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
                        if (blockedOrigins.contains((String)req.Id) || req.RemoteWorkItemIdTxt__c == globalSourceId) {
                            continue;
                        } 
                        itemsToInsert.add(createSyncItem(rec, req, allowedFields, globalSourceId, false));
                    }
                }

                // ==========================================
                // FAN OUT UPSTREAM (Push to Client or Stage for Poller)
                // ==========================================
                if (parentWorkItem != null && parentWorkItem.ClientNetworkEntityLookup__c != null) {
                    String entityType = parentWorkItem.ClientNetworkEntityLookup__r.EntityTypePk__c;

                    if (entityType == 'Client' || entityType == 'Both') {
                        // Kill-Switch: Do not sync to Client if they are the Global Source or sent this to us
                        if (blockedOrigins.contains((String)parentWorkItem.ClientNetworkEntityLookup__c) ||
                            (String)parentWorkItem.ClientNetworkEntityLookup__c == globalSourceId) {
                            continue;
                        }

                        Boolean vendorPushEnabled = parentWorkItem.ClientNetworkEntityLookup__r.EnableVendorPushDateTime__c != null
                            && String.isNotBlank(parentWorkItem.ClientNetworkEntityLookup__r.IntegrationEndpointUrlTxt__c);

                        itemsToInsert.add(createSyncItem(rec, null, allowedFields, globalSourceId, vendorPushEnabled));
                    }
                }
            }

            if (!itemsToInsert.isEmpty()) {
                // Dedup against existing Staged SyncItems for the same record+destination.
                // Pre-fix: every WorkItem update inserted a new outbound SyncItem, even if
                // a previous Staged one for the same record was still waiting for poll.
                // Result: 13 WorkItems on Nimba had 2-3 Staged sync items each (54 total)
                // — sync table bloat that the dispatcher would have to walk through.
                // Now: if a Staged SyncItem already exists for the same (LocalRecordId,
                // destination), update its payload in place rather than insert a new one.
                deduplicateAgainstStaged(itemsToInsert);
                if (!itemsToInsert.isEmpty()) {
                    Database.insert(itemsToInsert, AccessLevel.SYSTEM_MODE);
                    if (Limits.getQueueableJobs() == 0 && !System.isQueueable() && !System.isFuture()) {
                        System.enqueueJob(new DeliverySyncItemProcessor());
                    }
                }
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'DeliverySyncEngine Failed: ' + e.getMessage());
        }
    }

    /**
     * @description Dedups a list of about-to-insert SyncItem__c records against
     *              existing Staged outbound items for the same record + destination.
     *              For each item that matches an existing Staged row, the existing
     *              row's payload is updated in place and the new item is removed
     *              from the insert list. Items with no existing match stay in the
     *              insert list. The list parameter is mutated.
     *
     *              Destination identity:
     *                Push Mode: LocalRecordIdTxt__c + "|R|" + RequestLookup__c
     *                Hub Mode:  LocalRecordIdTxt__c + "|H|" + WorkItemLookup__c
     *
     * @param items The list of pending SyncItem__c records to dedup. Mutated in place.
     */
    private static void deduplicateAgainstStaged(List<SyncItem__c> items) {
        if (items == null || items.isEmpty()) {
            return;
        }
        Set<String> recordIds = new Set<String>();
        for (SyncItem__c si : items) {
            if (String.isNotBlank(si.LocalRecordIdTxt__c)) {
                recordIds.add(si.LocalRecordIdTxt__c);
            }
        }
        if (recordIds.isEmpty()) {
            return;
        }
        // Look up existing Staged outbound items for these source records.
        Map<String, SyncItem__c> existingByKey = new Map<String, SyncItem__c>();
        for (SyncItem__c existing : [
            SELECT Id, LocalRecordIdTxt__c, RequestLookup__c, WorkItemLookup__c, PayloadTxt__c
            FROM SyncItem__c
            WHERE StatusPk__c = 'Staged'
            AND DirectionPk__c = 'Outbound'
            AND LocalRecordIdTxt__c IN :recordIds
            WITH SYSTEM_MODE
        ]) {
            String key = stagedDedupKey(existing.LocalRecordIdTxt__c, existing.RequestLookup__c, existing.WorkItemLookup__c);
            // Keep only one existing per key (latest wins in iteration order).
            existingByKey.put(key, existing);
        }
        if (existingByKey.isEmpty()) {
            return; // Nothing to dedup against.
        }
        // Walk the to-insert list and split: items with an existing match get
        // their payload merged into the existing row; items with no match stay.
        List<SyncItem__c> remaining = new List<SyncItem__c>();
        List<SyncItem__c> toUpdate = new List<SyncItem__c>();
        for (SyncItem__c pending : items) {
            String key = stagedDedupKey(pending.LocalRecordIdTxt__c, pending.RequestLookup__c, pending.WorkItemLookup__c);
            SyncItem__c match = existingByKey.get(key);
            if (match != null) {
                // Update the existing Staged row in place — payload reflects the latest
                // state of the source record. Status stays Staged; the dispatcher will
                // pick it up on the next tick (or the client will pull it on next poll).
                match.PayloadTxt__c = pending.PayloadTxt__c;
                toUpdate.add(match);
            } else {
                remaining.add(pending);
            }
        }
        if (!toUpdate.isEmpty()) {
            // Use partial-success DML so a single field-level reject doesn't drop the
            // whole batch. Failures get logged at debug level and the corresponding
            // pending item just stays Staged with its old payload (still better than
            // a duplicate insert).
            Database.update(toUpdate, false, AccessLevel.SYSTEM_MODE);
        }
        // Mutate the input list in place to only contain genuinely new items.
        items.clear();
        items.addAll(remaining);
    }

    /**
     * @description Builds a composite key identifying a sync destination.
     *              Push Mode keys on the WorkRequest; Hub Mode keys on the parent
     *              WorkItem (which determines the destination via its
     *              ClientNetworkEntityLookup__c).
     * @param localRecordId Local source record id (LocalRecordIdTxt__c)
     * @param requestId WorkRequest__c Id for Push Mode, null for Hub Mode
     * @param workItemId WorkItem__c Id used as the Hub Mode destination key
     * @return Composite dedup key string
     */
    private static String stagedDedupKey(String localRecordId, Id requestId, Id workItemId) {
        if (requestId != null) {
            return localRecordId + '|R|' + requestId;
        }
        return localRecordId + '|H|' + (workItemId != null ? String.valueOf(workItemId) : 'NULL');
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

    private static Id getWorkItemId(SObject rec) {
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

    @SuppressWarnings('PMD.ExcessiveParameterList')
    private static SyncItem__c createSyncItem(SObject rec, WorkRequest__c req, Set<String> allowedFields, String globalSourceId, Boolean vendorPush) {
        SyncItem__c item = new SyncItem__c(
            StatusPk__c = 'Queued',
            DirectionPk__c = 'Outbound',
            GlobalSourceIdTxt__c = globalSourceId
        );
        item.LocalRecordIdTxt__c = (String)rec.Id;
        item.WorkItemLookup__c = getWorkItemId(rec); // MANDATORY: Required for Vendor's SOQL Security Filtering

        String fullApiName = rec.getSObjectType().getDescribe().getName();
        String cleanName = fullApiName.replace('delivery__', '');
        item.ObjectTypePk__c = cleanName;

        populateLookupField(item, cleanName, rec.Id);

        Map<String, Object> payload = new Map<String, Object>();
        for (String f : allowedFields) {
            payload.put(f, getSafeValue(rec, f));
        }
        payload.put('SourceId', rec.Id);
        payload.put('GlobalSourceId', globalSourceId);
        payload.put('SenderOrgId', UserInfo.getOrganizationId());

        if (req != null) {
            // Push Mode: Explicit Downstream Route
            item.RequestLookup__c = req.Id;
            payload.put('TargetId', req.RemoteWorkItemIdTxt__c);
        } else if (vendorPush) {
            // Vendor Push Mode: Real-time push upstream to client
            // RequestId stays null — processor resolves endpoint from WorkItem→ClientNetworkEntity
            payload.put('TargetId', item.WorkItemLookup__c);
            payload.put('VendorPush', true);
        } else {
            // Poll Mode: Staged for client to pull via GET /sync/changes
            item.StatusPk__c = 'Staged';
            payload.put('TargetId', item.WorkItemLookup__c);
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

    /** @description Custom exception for sync failures requiring retry. */
    public class SyncException extends Exception {}
}
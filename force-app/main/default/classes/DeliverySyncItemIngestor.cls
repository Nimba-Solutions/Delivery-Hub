/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Logic for processing Inbound Sync Items using the "Ledger Pattern".
 * Strictly enforces DAG topology (no reverse-bridges) and maintains PMD compliance.
 * Captures routing origins and Global Traceability IDs to explicitly prevent echo loops.
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.CyclomaticComplexity, PMD.StdCyclomaticComplexity, PMD.ApexCRUDViolation')
public without sharing class DeliverySyncItemIngestor {

    private static String getNamespacePrefix() {
        String ns = [SELECT NamespacePrefix FROM Organization LIMIT 1].NamespacePrefix;
        return String.isBlank(ns) ? '' : ns + '__';
    }

    private static String stripNamespace(String apiName) {
        if (String.isNotBlank(apiName) && apiName.countMatches('__') > 1) {
            return apiName.substringAfter('__');
        }
        return apiName;
    }

    /**
     * @description Processes an inbound sync payload by resolving the local record via ledger/bridge
     * lookup, mapping fields, auto-parenting upstream clients, and registering echo suppression.
     * @param objectType The API name of the SObject type being synced.
     * @param payload The deserialized JSON payload containing field values and routing metadata.
     * @return The Id of the upserted local record.
     */
    @SuppressWarnings('PMD.CyclomaticComplexity, PMD.StdCyclomaticComplexity, PMD.NcssMethodCount')
    public static Id processInboundItem(String objectType, Map<String, Object> payload) {
        DeliverySyncEngine.setSyncContext();

        Schema.SObjectType targetType = findSObjectType(objectType);
        if (targetType == null) {
            throw new IllegalArgumentException('Invalid Object Type: ' + objectType);
        }

        String sourceId = (String) payload.get('SourceId'); 
        String targetId = (String) payload.get('TargetId'); 
        
        // Extract Traceability & Identity IDs from the incoming payload
        String globalSourceId = (String) payload.get('GlobalSourceId'); 
        String senderOrgId = (String) payload.get('SenderOrgId'); 
        
        Id localRequestId = null;
        Id localRecordId = findLocalId(targetType, sourceId);

        // If it's a Work Item, also check the WorkRequest__c bridge (Downstream Origin).
        // The bridge carries explicit downstream routing context (localRequestId), so
        // we always capture it when present. But we only promote bridge.WorkItemId__c
        // to localRecordId if (a) the ledger lookup didn't already find one and
        // (b) the bridge target still exists locally. Stale bridges that point at
        // deleted records used to silently win and cause permanent sync no-ops.
        if (objectType.endsWithIgnoreCase('WorkItem__c') && !objectType.endsWithIgnoreCase('WorkItemComment__c')) {
            WorkRequest__c bridge = findWorkItemBridge(sourceId);
            if (bridge != null) {
                localRequestId = bridge.Id;
                if (localRecordId == null && validateLocalIdExists(targetType, bridge.WorkItemId__c)) {
                    localRecordId = bridge.WorkItemId__c;
                }
            }
        }

        // Final fallback: explicit TargetId from the payload. Validate it points
        // at a live record before trusting it — without validation, Database.update
        // against a deleted Id silently returns success and the sync becomes a
        // permanent no-op. Falling through to localRecordId == null routes to the
        // insert path, which creates a fresh record AND a ledger entry, allowing
        // the sender's bridge to auto-heal on its next response handshake.
        if (localRecordId == null && String.isNotBlank(targetId) && objectType.endsWithIgnoreCase('WorkItem__c') && !objectType.endsWithIgnoreCase('WorkItemComment__c')) {
            try {
                Id castId = (Id) targetId;
                if (validateLocalIdExists(targetType, castId)) {
                    localRecordId = castId;
                } else {
                    System.debug(LoggingLevel.WARN, 'Inbound TargetId ' + targetId + ' resolves to deleted/missing record — falling through to insert path');
                }
            } catch (Exception e) {
                System.debug(LoggingLevel.FINE, 'TargetId invalid: ' + e.getMessage());
            }
        }

        SObject recordToUpsert = (localRecordId != null) ? targetType.newSObject(localRecordId) : targetType.newSObject();
        
        // For WorkLogs, resolve the parent WorkItem ID from the payload (not TargetId)
        // and strip cross-org lookup IDs BEFORE mapFields runs (applies to both insert and update)
        String parentWorkItemRef = targetId;
        if (objectType.endsWithIgnoreCase('WorkLog__c')) {
            String wiRef = (String) payload.get('WorkItemLookup__c');
            if (String.isBlank(wiRef)) {
                wiRef = (String) payload.get('delivery__WorkItemLookup__c');
            }
            if (String.isNotBlank(wiRef)) {
                parentWorkItemRef = wiRef;
            }
            // Always strip remote lookup IDs — they are invalid cross-org references
            payload.remove('WorkItemLookup__c');
            payload.remove('delivery__WorkItemLookup__c');
            payload.remove('RequestId__c');
            payload.remove('delivery__RequestId__c');
        }

        Id localParentId = null;
        if (localRecordId == null && String.isNotBlank(parentWorkItemRef) && (objectType.containsIgnoreCase('WorkItemComment__c') || objectType.equalsIgnoreCase('ContentVersion') || objectType.endsWithIgnoreCase('WorkLog__c'))) {
            
            // 1. Try to find parent via Request Bridge (Downstream Origin)
            WorkRequest__c parentBridge = findWorkItemBridge(parentWorkItemRef);
            if (parentBridge != null) {
                localParentId = parentBridge.WorkItemId__c;
                localRequestId = parentBridge.Id;
            }

            // 2. Try to find parent via the Ledger (Upstream Origin)
            if (localParentId == null) {
                List<SyncItem__c> ledger = [SELECT LocalRecordIdTxt__c FROM SyncItem__c WHERE RemoteExternalIdTxt__c = :parentWorkItemRef AND ObjectTypePk__c = 'WorkItem__c' WITH SYSTEM_MODE LIMIT 1];
                if (!ledger.isEmpty()) {
                    localParentId = (Id)ledger[0].LocalRecordIdTxt__c;
                }
            }

            // 3. Fallback: Check if parentWorkItemRef is actually a local ID
            if (localParentId == null) {
                try {
                    Id castId = (Id) parentWorkItemRef;
                    if (castId.getSobjectType().getDescribe().getName().endsWithIgnoreCase('WorkItem__c')) {
                        localParentId = castId;
                    }
                } catch (Exception e) {
                    System.debug(LoggingLevel.FINE, 'Parent resolution failed: ' + e.getMessage());
                }
            }

            if (localParentId != null && objectType.containsIgnoreCase('WorkItemComment__c')) {
                putSafe(recordToUpsert, 'WorkItemId__c', localParentId);
            }
            if (objectType.endsWithIgnoreCase('WorkLog__c')) {
                if (localParentId == null) {
                    throw new DeliverySyncEngine.SyncException('Cannot resolve parent WorkItem for WorkLog. Parent ref: ' + parentWorkItemRef + '. The parent WorkItem may not have synced yet.');
                }
                putSafe(recordToUpsert, 'WorkItemLookup__c', localParentId);
                // Find a local WorkRequest for the Master-Detail parent
                List<WorkRequest__c> localRequests = [
                    SELECT Id FROM WorkRequest__c
                    WHERE WorkItemId__c = :localParentId
                    WITH SYSTEM_MODE LIMIT 1
                ];
                if (!localRequests.isEmpty()) {
                    putSafe(recordToUpsert, 'RequestId__c', localRequests[0].Id);
                }
            }
        }

        mapFields(recordToUpsert, payload, targetType);

        // ==========================================
        // NEW: AUTO-PARENTING THE UPSTREAM CLIENT
        // ==========================================
        // Check for Default Billing Entity override
        DeliveryHubSettings__c settings = DeliveryHubSettings__c.getOrgDefaults();
        String defaultBillingEntityId = settings != null ? (String) settings.get('DefaultBillingEntityIdTxt__c') : null;

        if (String.isNotBlank(defaultBillingEntityId) && objectType.endsWithIgnoreCase('WorkItem__c') && !objectType.endsWithIgnoreCase('WorkItemComment__c')) {
            // Override: Use the configured billing entity instead of sender-org auto-detection
            try {
                putSafe(recordToUpsert, 'ClientNetworkEntityLookup__c', (Id) defaultBillingEntityId);
            } catch (Exception e) {
                System.debug(LoggingLevel.FINE, 'Invalid DefaultBillingEntityIdTxt__c: ' + e.getMessage());
            }
        } else if (String.isNotBlank(senderOrgId) && objectType.endsWithIgnoreCase('WorkItem__c') && !objectType.endsWithIgnoreCase('WorkItemComment__c')) {
            try {
                // Grab the 15-char base ID to prevent 18-char mismatch failures on Text fields
                String baseOrgId = senderOrgId.length() >= 15 ? senderOrgId.substring(0, 15) + '%' : senderOrgId;

                // FIX: Look at BOTH OrgIdTxt__c and RemoteExternalIdTxt__c
                String query = 'SELECT Id, EntityTypePk__c FROM NetworkEntity__c WHERE (OrgIdTxt__c LIKE :baseOrgId OR RemoteExternalIdTxt__c LIKE :baseOrgId) LIMIT 1';

                if (String.isNotBlank(getNamespacePrefix())) {
                    query = query.replace('NetworkEntity__c', getNamespacePrefix() + 'NetworkEntity__c')
                                 .replace('OrgIdTxt__c', getNamespacePrefix() + 'OrgIdTxt__c')
                                 .replace('RemoteExternalIdTxt__c', getNamespacePrefix() + 'RemoteExternalIdTxt__c')
                                 .replace('EntityTypePk__c', getNamespacePrefix() + 'EntityTypePk__c');
                }

                List<SObject> entities = Database.query(query); // NOPMD
                if (!entities.isEmpty()) {
                    String eType = (String)entities[0].get(entities[0].getSObjectType().getDescribe().fields.getMap().containsKey('EntityTypePk__c') ? 'EntityTypePk__c' : getNamespacePrefix() + 'EntityTypePk__c');

                    // If the sender is registered as a Client in our org, lock them in as the Client for this Work Item
                    if (eType == 'Client' || eType == 'Both') {
                        putSafe(recordToUpsert, 'ClientNetworkEntityLookup__c', (Id)entities[0].get('Id'));
                    }
                }
            } catch (Exception e) {
                System.debug(LoggingLevel.FINE, 'Failed to resolve Sender Network Entity for Auto-Parenting: ' + e.getMessage());
            }
        }

        // Connection Approval: New inbound NetworkEntity records require admin approval
        if (objectType.endsWithIgnoreCase('NetworkEntity__c') && recordToUpsert.Id == null) {
            putSafe(recordToUpsert, 'ConnectionStatusPk__c', 'Pending Approval');
        }

        if (recordToUpsert.Id != null) {
            Database.update(recordToUpsert, AccessLevel.SYSTEM_MODE);
        } else {
            Database.insert(recordToUpsert, AccessLevel.SYSTEM_MODE);

            // Notify admins of pending connection requests
            if (objectType.endsWithIgnoreCase('NetworkEntity__c')) {
                notifyPendingConnection(recordToUpsert);
            }

            // Pass the localRequestId and globalSourceId down to link the Sync Item
            createLedgerEntry(objectType, sourceId, recordToUpsert.Id, localRequestId, globalSourceId);
            
            if (objectType.equalsIgnoreCase('ContentVersion') && localParentId != null) {
                Id contentDocId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :recordToUpsert.Id LIMIT 1].ContentDocumentId;
                Database.insert(new ContentDocumentLink(
                    ContentDocumentId = contentDocId, LinkedEntityId = localParentId, ShareType = 'V', Visibility = 'AllUsers'
                ), AccessLevel.SYSTEM_MODE);
            }
        }

        // ==========================================
        // ECHO SUPPRESSION: REGISTER ORIGIN ROUTE
        // ==========================================
        if (localRequestId != null) {
            // Origin was a Downstream Vendor via WorkRequest__c
            DeliverySyncEngine.ignoreOrigin(localRequestId);
        } else {
            // No Request found. Origin must be the Upstream Client.
            Id parentWorkItemId = (objectType.endsWithIgnoreCase('WorkItem__c') && !objectType.endsWithIgnoreCase('WorkItemComment__c')) ? recordToUpsert.Id : localParentId;
            
            if (parentWorkItemId != null) {
                try {
                    // Look up the ClientNetworkEntityLookup__c of the target Work Item (which we just stamped!)
                    String query = 'SELECT ClientNetworkEntityLookup__c FROM WorkItem__c WHERE Id = :parentWorkItemId LIMIT 1';
                    if (String.isNotBlank(getNamespacePrefix())) {
                        query = query.replace('WorkItem__c', getNamespacePrefix() + 'WorkItem__c')
                                     .replace('ClientNetworkEntityLookup__c', getNamespacePrefix() + 'ClientNetworkEntityLookup__c');
                    }
                    
                    List<SObject> tix = Database.query(query); // NOPMD
                    if (!tix.isEmpty()) {
                        Id clientId = (Id)tix[0].get(tix[0].getSObjectType().getDescribe().fields.getMap().containsKey('ClientNetworkEntityLookup__c') ? 'ClientNetworkEntityLookup__c' : getNamespacePrefix() + 'ClientNetworkEntityLookup__c');
                        if (clientId != null) {
                            DeliverySyncEngine.ignoreOrigin(clientId);
                        }
                    }
                } catch (Exception e) {
                    System.debug(LoggingLevel.FINE, 'Failed to resolve Upstream Client entity for Echo Suppression: ' + e.getMessage());
                }
            }
        }

        return recordToUpsert.Id;
    }

    /**
     * @description Resolves a remote source Id to a local record Id by walking the
     * Inbound ledger newest-first and returning the first entry whose local target
     * still exists. Stale ledger entries (whose local record has been deleted) are
     * skipped, which is essential to prevent the receiver from resolving to a
     * deleted Id and silently no-op'ing the upsert.
     *
     * Previously this lookup was skipped entirely for WorkItem__c (the bridge was
     * assumed sufficient), but bridges go stale when their local target is deleted
     * and there was no ledger fallback — leaving the receiver with no way to
     * relocate the canonical record.
     * @param type The SObjectType of the record being resolved.
     * @param remoteId The remote source Id to look up in the inbound ledger.
     * @return The local record Id of the active record, or null if no live mapping exists.
     */
    private static Id findLocalId(Schema.SObjectType type, String remoteId) {
        if (String.isBlank(remoteId)) {
            return null;
        }
        String cleanName = stripNamespace(type.getDescribe().getName());

        List<SyncItem__c> ledger = [
            SELECT LocalRecordIdTxt__c
            FROM SyncItem__c
            WHERE RemoteExternalIdTxt__c = :remoteId
            AND ObjectTypePk__c = :cleanName
            AND DirectionPk__c = 'Inbound'
            WITH SYSTEM_MODE
            ORDER BY CreatedDate DESC
            LIMIT 50
        ];

        for (SyncItem__c entry : ledger) {
            Id candidate = (Id) entry.LocalRecordIdTxt__c;
            if (validateLocalIdExists(type, candidate)) {
                return candidate;
            }
        }
        return null;
    }

    /**
     * @description Verifies that a candidate local record Id refers to a live row
     * (not deleted or in the recycle bin). Returns false for null Ids, Ids of the
     * wrong sobject type, and Ids that no longer resolve to a record.
     *
     * This guard exists because Salesforce's Database.update accepts a deleted
     * record's Id without throwing — the call returns success and silently
     * does nothing, which is exactly how stale bridges produced multi-day sync
     * drift before this fix.
     * @param type The expected SObjectType of the candidate Id.
     * @param candidateId The Id to validate.
     * @return True if the Id refers to an active local record of the expected type.
     */
    private static Boolean validateLocalIdExists(Schema.SObjectType type, Id candidateId) {
        if (candidateId == null || candidateId.getSobjectType() != type) {
            return false;
        }
        String soql = 'SELECT Id FROM ' + type.getDescribe().getName() + ' WHERE Id = :candidateId LIMIT 1';
        List<SObject> existing = Database.queryWithBinds(
            soql,
            new Map<String, Object>{ 'candidateId' => candidateId },
            AccessLevel.SYSTEM_MODE
        );
        return !existing.isEmpty();
    }

    // Helper to grab both the Work Item ID and the Request ID
    private static WorkRequest__c findWorkItemBridge(String remoteWorkItemId) {
        List<WorkRequest__c> reqs = [SELECT Id, WorkItemId__c FROM WorkRequest__c WHERE RemoteWorkItemIdTxt__c = :remoteWorkItemId WITH SYSTEM_MODE LIMIT 1];
        return reqs.isEmpty() ? null : reqs[0];
    }

    @SuppressWarnings('PMD.ExcessiveParameterList')
    private static void createLedgerEntry(String objType, String remoteId, Id localId, Id requestId, String globalSourceId) {
        String cleanName = stripNamespace(objType);
        SyncItem__c ledger = new SyncItem__c(
            DirectionPk__c = 'Inbound', 
            StatusPk__c = 'Synced', 
            ObjectTypePk__c = cleanName,
            RemoteExternalIdTxt__c = remoteId, 
            LocalRecordIdTxt__c = (String)localId, 
            PayloadTxt__c = 'Ledger Mapping Created',
            RequestLookup__c = requestId,
            GlobalSourceIdTxt__c = globalSourceId // Stamps the trace ID!
        );
        
        populateLookupField(ledger, cleanName, localId);
        Database.insert(ledger, AccessLevel.SYSTEM_MODE);
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
                System.debug(LoggingLevel.FINE, 'Ledger mapping skipped for ' + cleanName + ': ' + e2.getMessage());
            }
        }
    }

    @SuppressWarnings('PMD.CyclomaticComplexity')
    private static void mapFields(SObject record, Map<String, Object> payload, Schema.SObjectType type) {
        Map<String, SObjectField> fieldMap = type.getDescribe().fields.getMap();
        Map<String, SObjectField> cleanNameIndex = new Map<String, SObjectField>();
        for (String fieldApi : fieldMap.keySet()) {
            cleanNameIndex.put(stripNamespace(fieldApi).toLowerCase(), fieldMap.get(fieldApi));
        }

        for (String key : payload.keySet()) {
            // Ensure the system fields are ignored during standard field mapping
            if (key == 'SourceId' || key == 'TargetId' || key == 'GlobalSourceId' || key == 'SenderOrgId') { continue; }
            
            String searchKey = stripNamespace(key).toLowerCase(); 
            if (cleanNameIndex.containsKey(searchKey)) {
                SObjectField field = cleanNameIndex.get(searchKey);
                Object val = payload.get(key);
                if (val == null) {
                    record.put(field, null);
                    continue;
                }
                Schema.DisplayType dtype = field.getDescribe().getType();
                if (dtype == Schema.DisplayType.DATE) {
                    record.put(field, Date.valueOf((String)val));
                } else if (dtype == Schema.DisplayType.DATETIME) {
                    record.put(field, (DateTime)JSON.deserialize('"' + val + '"', DateTime.class));
                } else if (dtype == Schema.DisplayType.BASE64) {
                    record.put(field, EncodingUtil.base64Decode((String)val));
                } else {
                    record.put(field, val);
                }
            }
        }
    }

    private static void putSafe(SObject rec, String fieldName, Object val) {
        Map<String, SObjectField> fieldMap = rec.getSObjectType().getDescribe().fields.getMap();
        String target = stripNamespace(fieldName).toLowerCase();
        for (String fieldApi : fieldMap.keySet()) {
            if (stripNamespace(fieldApi).toLowerCase() == target) {
                rec.put(fieldMap.get(fieldApi), val);
                return;
            }
        }
    }

    private static Boolean hasField(Schema.SObjectType type, String fieldName) {
        Map<String, SObjectField> fieldMap = type.getDescribe().fields.getMap();
        String target = stripNamespace(fieldName).toLowerCase();
        for (String fieldApi : fieldMap.keySet()) {
            if (stripNamespace(fieldApi).toLowerCase() == target) {
                return true;
            }
        }
        return false;
    }

    /**
     * @description Sends a Slack notification when a new NetworkEntity arrives with
     * Pending Approval status so admins are aware of incoming connection requests.
     * @param entity The newly inserted NetworkEntity__c SObject
     */
    private static void notifyPendingConnection(SObject entity) {
        try {
            DeliveryHubSettings__c settings = DeliveryHubSettings__c.getOrgDefaults();
            if (settings == null || String.isBlank(settings.SlackWebhookUrlTxt__c)) {
                return;
            }
            String entityName = (String) entity.get('Name');
            if (String.isBlank(entityName)) {
                entityName = 'Unknown Org';
            }
            String orgUrl = Url.getOrgDomainUrl().toExternalForm();
            String recordUrl = orgUrl + '/lightning/r/' + entity.getSObjectType().getDescribe().getName() + '/' + entity.Id + '/view';
            Map<String, String> notificationContext = new Map<String, String>{
                'entityName' => entityName,
                'recordUrl' => recordUrl
            };
            DeliverySlackService.postConnectionApprovalRequest(JSON.serialize(notificationContext));
        } catch (Exception e) {
            System.debug(LoggingLevel.FINE, 'Failed to notify pending connection: ' + e.getMessage());
        }
    }

    private static Schema.SObjectType findSObjectType(String apiName) {
        if (String.isBlank(apiName)) { return null; }
        Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
        if (gd.containsKey(apiName)) { return gd.get(apiName); }
        if (gd.containsKey('delivery__' + apiName)) { return gd.get('delivery__' + apiName); }
        
        String target = stripNamespace(apiName).toLowerCase();
        for (String key : gd.keySet()) {
            if (stripNamespace(key).toLowerCase() == target) {
                return gd.get(key);
            }
        }
        return null;
    }
}
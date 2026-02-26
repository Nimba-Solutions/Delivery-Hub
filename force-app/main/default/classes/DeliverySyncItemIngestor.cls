/**
 * @description Logic for processing Inbound Sync Items using the "Ledger Pattern".
 * Strictly enforces DAG topology (no reverse-bridges) and maintains PMD compliance.
 * Captures routing origins and Global Traceability IDs to explicitly prevent echo loops.
 * @author Cloud Nimbus LLC
 */
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
        
        // If it's a Work Item, try to find the Request Bridge (Downstream Origin)
        if (objectType.endsWithIgnoreCase('WorkItem__c') && !objectType.endsWithIgnoreCase('WorkItemComment__c')) {
            WorkRequest__c bridge = findWorkItemBridge(sourceId);
            if (bridge != null) {
                localRecordId = bridge.WorkItemId__c;
                localRequestId = bridge.Id;
            }
        }

        if (localRecordId == null && String.isNotBlank(targetId) && objectType.endsWithIgnoreCase('WorkItem__c') && !objectType.endsWithIgnoreCase('WorkItemComment__c')) {
            try {
                Id castId = (Id) targetId;
                if (castId.getSobjectType() == targetType) {
                    localRecordId = castId;
                }
            } catch (Exception e) {
                System.debug(LoggingLevel.FINE, 'TargetId invalid: ' + e.getMessage());
            }
        }

        SObject recordToUpsert = (localRecordId != null) ? targetType.newSObject(localRecordId) : targetType.newSObject();
        
        Id localParentId = null;
        if (localRecordId == null && String.isNotBlank(targetId) && (objectType.containsIgnoreCase('WorkItemComment__c') || objectType.equalsIgnoreCase('ContentVersion'))) {
            
            // 1. Try to find parent via Request Bridge (Downstream Origin)
            WorkRequest__c parentBridge = findWorkItemBridge(targetId);
            if (parentBridge != null) {
                localParentId = parentBridge.WorkItemId__c;
                localRequestId = parentBridge.Id; 
            }

            // 2. Try to find parent via the Ledger (Upstream Origin)
            if (localParentId == null) {
                List<Sync_Item__c> ledger = [SELECT LocalRecordIdTxt__c FROM Sync_Item__c WHERE RemoteExternalIdTxt__c = :targetId AND ObjectTypePk__c = 'WorkItem__c' WITH SYSTEM_MODE LIMIT 1];
                if (!ledger.isEmpty()) {
                    localParentId = (Id)ledger[0].LocalRecordIdTxt__c;
                }
            }

            // 3. Fallback: Check if targetId is actually a local ID
            if (localParentId == null) {
                try {
                    Id castId = (Id) targetId;
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
        }

        mapFields(recordToUpsert, payload, targetType);

        // ==========================================
        // NEW: AUTO-PARENTING THE UPSTREAM CLIENT
        // ==========================================
        if (String.isNotBlank(senderOrgId) && objectType.endsWithIgnoreCase('WorkItem__c') && !objectType.endsWithIgnoreCase('WorkItemComment__c')) {
            try {
                // Grab the 15-char base ID to prevent 18-char mismatch failures on Text fields
                String baseOrgId = senderOrgId.length() >= 15 ? senderOrgId.substring(0, 15) + '%' : senderOrgId;
                
                // FIX: Look at BOTH OrgIdTxt__c and RemoteExternalIdTxt__c
                String query = 'SELECT Id, EntityTypePk__c FROM Network_Entity__c WHERE (OrgIdTxt__c LIKE :baseOrgId OR RemoteExternalIdTxt__c LIKE :baseOrgId) LIMIT 1';
                
                if (String.isNotBlank(getNamespacePrefix())) {
                    query = query.replace('Network_Entity__c', getNamespacePrefix() + 'Network_Entity__c')
                                 .replace('OrgIdTxt__c', getNamespacePrefix() + 'OrgIdTxt__c')
                                 .replace('RemoteExternalIdTxt__c', getNamespacePrefix() + 'RemoteExternalIdTxt__c')
                                 .replace('EntityTypePk__c', getNamespacePrefix() + 'EntityTypePk__c');
                }
                
                List<SObject> entities = Database.query(query); // NOPMD
                if (!entities.isEmpty()) {
                    String eType = (String)entities[0].get(entities[0].getSObjectType().getDescribe().fields.getMap().containsKey('EntityTypePk__c') ? 'EntityTypePk__c' : getNamespacePrefix() + 'EntityTypePk__c');
                    
                    // If the sender is registered as a Client in our org, lock them in as the Client for this Work Item
                    if (eType == 'Client' || eType == 'Both') {
                        putSafe(recordToUpsert, 'ClientNetworkEntityId__c', (Id)entities[0].get('Id'));
                    }
                }
            } catch (Exception e) {
                System.debug(LoggingLevel.FINE, 'Failed to resolve Sender Network Entity for Auto-Parenting: ' + e.getMessage());
            }
        }

        if (recordToUpsert.Id != null) {
            Database.update(recordToUpsert, AccessLevel.SYSTEM_MODE);
        } else {
            Database.insert(recordToUpsert, AccessLevel.SYSTEM_MODE);
            
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
                    // Look up the ClientNetworkEntityId__c of the target Work Item (which we just stamped!)
                    String query = 'SELECT ClientNetworkEntityId__c FROM WorkItem__c WHERE Id = :parentWorkItemId LIMIT 1';
                    if (String.isNotBlank(getNamespacePrefix())) {
                        query = query.replace('WorkItem__c', getNamespacePrefix() + 'WorkItem__c')
                                     .replace('ClientNetworkEntityId__c', getNamespacePrefix() + 'ClientNetworkEntityId__c');
                    }
                    
                    List<SObject> tix = Database.query(query); // NOPMD
                    if (!tix.isEmpty()) {
                        Id clientId = (Id)tix[0].get(tix[0].getSObjectType().getDescribe().fields.getMap().containsKey('ClientNetworkEntityId__c') ? 'ClientNetworkEntityId__c' : getNamespacePrefix() + 'ClientNetworkEntityId__c');
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

    private static Id findLocalId(Schema.SObjectType type, String remoteId) {
        String objName = type.getDescribe().getName();
        String cleanName = stripNamespace(objName);
        
        if (!cleanName.endsWithIgnoreCase('WorkItem__c') || cleanName.endsWithIgnoreCase('WorkItemComment__c')) {
            List<Sync_Item__c> ledger = [SELECT LocalRecordIdTxt__c FROM Sync_Item__c WHERE RemoteExternalIdTxt__c = :remoteId AND ObjectTypePk__c = :cleanName WITH SYSTEM_MODE LIMIT 1];
            return ledger.isEmpty() ? null : (Id)ledger[0].LocalRecordIdTxt__c;
        }
        return null;
    }

    // Helper to grab both the Work Item ID and the Request ID
    private static WorkRequest__c findWorkItemBridge(String remoteWorkItemId) {
        List<WorkRequest__c> reqs = [SELECT Id, WorkItemId__c FROM WorkRequest__c WHERE RemoteWorkItemIdTxt__c = :remoteWorkItemId WITH SYSTEM_MODE LIMIT 1];
        return reqs.isEmpty() ? null : reqs[0];
    }

    // Updated to accept the requestId and the globalSourceId
    private static void createLedgerEntry(String objType, String remoteId, Id localId, Id requestId, String globalSourceId) {
        String cleanName = stripNamespace(objType);
        Sync_Item__c ledger = new Sync_Item__c(
            DirectionPk__c = 'Inbound', 
            StatusPk__c = 'Synced', 
            ObjectTypePk__c = cleanName,
            RemoteExternalIdTxt__c = remoteId, 
            LocalRecordIdTxt__c = (String)localId, 
            PayloadTxt__c = 'Ledger Mapping Created',
            RequestId__c = requestId,
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
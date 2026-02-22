/**
 * @description Logic for processing Inbound Sync Items using the "Ledger Pattern".
 * Strictly enforces DAG topology (no reverse-bridges) and maintains PMD compliance.
 * Captures routing origins to explicitly prevent echo loops.
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
        SyncEngine.setSyncContext();

        Schema.SObjectType targetType = findSObjectType(objectType);
        if (targetType == null) {
            throw new IllegalArgumentException('Invalid Object Type: ' + objectType);
        }

        String sourceId = (String) payload.get('SourceId'); 
        String targetId = (String) payload.get('TargetId'); 
        
        // We will store the RequestId if we find it so we can link the Inbound Sync Item to it
        Id localRequestId = null;
        
        Id localRecordId = findLocalId(targetType, sourceId);
        
        // If it's a Ticket, try to find the Request Bridge (Downstream Origin)
        if (objectType.endsWithIgnoreCase('Ticket__c') && !objectType.endsWithIgnoreCase('Ticket_Comment__c')) {
            Request__c bridge = findTicketBridge(sourceId);
            if (bridge != null) {
                localRecordId = bridge.TicketId__c;
                localRequestId = bridge.Id;
            }
        }

        if (localRecordId == null && String.isNotBlank(targetId) && objectType.endsWithIgnoreCase('Ticket__c') && !objectType.endsWithIgnoreCase('Ticket_Comment__c')) {
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
        if (localRecordId == null && String.isNotBlank(targetId) && (objectType.containsIgnoreCase('Ticket_Comment__c') || objectType.equalsIgnoreCase('ContentVersion'))) {
            
            // 1. Try to find parent via Request Bridge (Downstream Origin)
            Request__c parentBridge = findTicketBridge(targetId);
            if (parentBridge != null) {
                localParentId = parentBridge.TicketId__c;
                localRequestId = parentBridge.Id; // Capture the Request ID
            }

            // 2. Try to find parent via the Ledger (Upstream Origin)
            if (localParentId == null) {
                List<Sync_Item__c> ledger = [SELECT LocalRecordIdTxt__c FROM Sync_Item__c WHERE RemoteExternalIdTxt__c = :targetId AND ObjectTypePk__c = 'Ticket__c' WITH SYSTEM_MODE LIMIT 1];
                if (!ledger.isEmpty()) {
                    localParentId = (Id)ledger[0].LocalRecordIdTxt__c;
                }
            }

            // 3. Fallback: Check if targetId is actually a local ID
            if (localParentId == null) {
                try {
                    Id castId = (Id) targetId;
                    if (castId.getSobjectType().getDescribe().getName().endsWithIgnoreCase('Ticket__c')) {
                        localParentId = castId;
                    }
                } catch (Exception e) {
                    System.debug(LoggingLevel.FINE, 'Parent resolution failed: ' + e.getMessage());
                }
            }

            if (localParentId != null && objectType.containsIgnoreCase('Ticket_Comment__c')) {
                putSafe(recordToUpsert, 'TicketId__c', localParentId);
            }
        }

        mapFields(recordToUpsert, payload, targetType);

        if (recordToUpsert.Id != null) {
            Database.update(recordToUpsert, AccessLevel.SYSTEM_MODE);
        } else {
            Database.insert(recordToUpsert, AccessLevel.SYSTEM_MODE);
            
            // Pass the localRequestId down to link the Sync Item
            createLedgerEntry(objectType, sourceId, recordToUpsert.Id, localRequestId);
            
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
            // Origin was a Downstream Vendor via Request__c
            SyncEngine.ignoreOrigin(localRequestId);
        } else {
            // No Request found. Origin must be the Upstream Client.
            Id parentTicketId = (objectType.endsWithIgnoreCase('Ticket__c') && !objectType.endsWithIgnoreCase('Ticket_Comment__c')) ? recordToUpsert.Id : localParentId;
            
            if (parentTicketId != null) {
                try {
                    // Look up the ClientNetworkEntityId__c of the target Ticket
                    String query = 'SELECT ClientNetworkEntityId__c FROM Ticket__c WHERE Id = :parentTicketId LIMIT 1';
                    if (String.isNotBlank(getNamespacePrefix())) {
                        query = query.replace('Ticket__c', getNamespacePrefix() + 'Ticket__c')
                                     .replace('ClientNetworkEntityId__c', getNamespacePrefix() + 'ClientNetworkEntityId__c');
                    }
                    
                    List<SObject> tix = Database.query(query); // NOPMD
                    if (!tix.isEmpty()) {
                        Id clientId = (Id)tix[0].get(tix[0].getSObjectType().getDescribe().fields.getMap().containsKey('ClientNetworkEntityId__c') ? 'ClientNetworkEntityId__c' : getNamespacePrefix() + 'ClientNetworkEntityId__c');
                        if (clientId != null) {
                            SyncEngine.ignoreOrigin(clientId);
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
        
        if (!cleanName.endsWithIgnoreCase('Ticket__c') || cleanName.endsWithIgnoreCase('Ticket_Comment__c')) {
            List<Sync_Item__c> ledger = [SELECT LocalRecordIdTxt__c FROM Sync_Item__c WHERE RemoteExternalIdTxt__c = :remoteId AND ObjectTypePk__c = :cleanName WITH SYSTEM_MODE LIMIT 1];
            return ledger.isEmpty() ? null : (Id)ledger[0].LocalRecordIdTxt__c;
        }
        return null;
    }

    // Helper to grab both the Ticket ID and the Request ID
    private static Request__c findTicketBridge(String remoteTicketId) {
        List<Request__c> reqs = [SELECT Id, TicketId__c FROM Request__c WHERE RemoteTicketIdTxt__c = :remoteTicketId WITH SYSTEM_MODE LIMIT 1];
        return reqs.isEmpty() ? null : reqs[0];
    }

    // Updated to accept the requestId
    private static void createLedgerEntry(String objType, String remoteId, Id localId, Id requestId) {
        String cleanName = stripNamespace(objType);
        Sync_Item__c ledger = new Sync_Item__c(
            DirectionPk__c = 'Inbound', 
            StatusPk__c = 'Synced', 
            ObjectTypePk__c = cleanName,
            RemoteExternalIdTxt__c = remoteId, 
            LocalRecordIdTxt__c = (String)localId, 
            PayloadTxt__c = 'Ledger Mapping Created',
            RequestId__c = requestId // FIX: Stamps the Request ID on the Inbound Item!
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
            if (key == 'SourceId' || key == 'TargetId') { continue; }
            String searchKey = stripNamespace(key).toLowerCase(); 
            if (cleanNameIndex.containsKey(searchKey)) {
                SObjectField field = cleanNameIndex.get(searchKey);
                Object val = payload.get(key);
                if (val == null) { continue; }
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
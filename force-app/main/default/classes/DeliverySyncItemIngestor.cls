/**
 * @description Logic for processing Inbound Sync Items using the "Ledger Pattern".
 * Runs in System Mode (without sharing) to bypass FLS restrictions.
 * Uses robust dynamic string stripping to eliminate Namespace issues in any org.
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

    public static void processInboundItem(String objectType, Map<String, Object> payload) {
        SyncEngine.setSyncContext();

        Schema.SObjectType targetType = findSObjectType(objectType);
        if (targetType == null) {
            throw new IllegalArgumentException('Invalid Object Type: ' + objectType);
        }

        String sourceId = (String) payload.get('SourceId'); 
        String targetId = (String) payload.get('TargetId'); 
        
        Id localRecordId = findLocalId(targetType, sourceId);
        SObject recordToUpsert = (localRecordId != null) ? targetType.newSObject(localRecordId) : targetType.newSObject();
        
        // Handle Parenting (Comments)
        if (localRecordId == null && String.isNotBlank(targetId) && objectType.contains('Ticket_Comment__c')) {
            Id localParentId = null;
            try {
                Id castId = (Id) targetId;
                if (castId.getSobjectType().getDescribe().getName().endsWith('Ticket__c')) {
                    localParentId = castId;
                }
            } catch (Exception e) {}

            if (localParentId == null) {
                localParentId = findLocalTicketId(targetId);
            }

            if (localParentId != null) {
                putSafe(recordToUpsert, 'TicketId__c', localParentId);
            }
        }

        mapFields(recordToUpsert, payload, targetType);
        putSafe(recordToUpsert, 'SourcePk__c', 'Vendor'); 

        // Execute DML in System Mode
        if (recordToUpsert.Id != null) {
            Database.update(recordToUpsert, AccessLevel.SYSTEM_MODE);
        } else {
            Database.insert(recordToUpsert, AccessLevel.SYSTEM_MODE);
            createLedgerEntry(objectType, sourceId, recordToUpsert.Id);
            
            // --- FIX: Bridge the Request Record for the Pull Architecture ---
            if (objectType.endsWithIgnoreCase('Ticket__c') && !objectType.endsWithIgnoreCase('Ticket_Comment__c')) {
                String ns = getNamespacePrefix();
                String query = 'SELECT Id FROM ' + ns + 'Request__c WHERE ' + ns + 'TicketId__c = \'' + recordToUpsert.Id + '\'';
                List<SObject> existingReqs = Database.query(query);
                
                if (existingReqs.isEmpty()) {
                    // Create a routing record so SyncEngine can queue Outbound items
                    SObject req = (SObject) Type.forName(ns + 'Request__c').newInstance();
                    req.put(ns + 'TicketId__c', recordToUpsert.Id);
                    req.put(ns + 'RemoteTicketIdTxt__c', sourceId); // Save the Client's Ticket ID!
                    req.put(ns + 'StatusPk__c', 'Active');
                    // We purposefully leave DeliveryEntityId__c NULL so the Vendor does not attempt to push
                    Database.insert(req, AccessLevel.SYSTEM_MODE);
                } else {
                    // If the trigger auto-created one, fix it by stripping the Vendor and adding the Remote ID
                    for (SObject req : existingReqs) {
                        req.put(ns + 'RemoteTicketIdTxt__c', sourceId);
                        req.put(ns + 'DeliveryEntityId__c', null); // Stop the push!
                    }
                    Database.update(existingReqs, AccessLevel.SYSTEM_MODE);
                }
            }
        }
    }

    // --- HELPERS ---

    private static Id findLocalId(Schema.SObjectType type, String remoteId) {
        String objName = type.getDescribe().getName();
        
        if (objName.endsWith('Ticket__c') && !objName.endsWith('Ticket_Comment__c')) {
            List<Request__c> reqs = [SELECT TicketId__c FROM Request__c WHERE RemoteTicketIdTxt__c = :remoteId WITH SYSTEM_MODE LIMIT 1];
            return reqs.isEmpty() ? null : reqs[0].TicketId__c;
        } else {
            String cleanName = stripNamespace(objName);
            List<Sync_Item__c> ledger = [SELECT LocalRecordIdTxt__c FROM Sync_Item__c WHERE RemoteExternalIdTxt__c = :remoteId AND ObjectTypePk__c = :cleanName WITH SYSTEM_MODE LIMIT 1];
            return ledger.isEmpty() ? null : (Id)ledger[0].LocalRecordIdTxt__c;
        }
    }

    private static Id findLocalTicketId(String remoteTicketId) {
        List<Request__c> reqs = [SELECT TicketId__c FROM Request__c WHERE RemoteTicketIdTxt__c = :remoteTicketId WITH SYSTEM_MODE LIMIT 1];
        return reqs.isEmpty() ? null : reqs[0].TicketId__c;
    }

    private static void createLedgerEntry(String objType, String remoteId, Id localId) {
        Sync_Item__c item = new Sync_Item__c();
        item.DirectionPk__c = 'Inbound';
        item.StatusPk__c = 'Synced';
        item.ObjectTypePk__c = stripNamespace(objType);
        item.RemoteExternalIdTxt__c = remoteId;
        item.LocalRecordIdTxt__c = (String)localId;
        item.PayloadTxt__c = 'Ledger Mapping Created';
        Database.insert(item, AccessLevel.SYSTEM_MODE);
    }

    private static void mapFields(SObject record, Map<String, Object> payload, Schema.SObjectType type) {
        Map<String, SObjectField> fieldMap = type.getDescribe().fields.getMap();
        
        Map<String, SObjectField> cleanNameIndex = new Map<String, SObjectField>();
        for (String fieldApi : fieldMap.keySet()) {
            String clean = stripNamespace(fieldApi).toLowerCase();
            cleanNameIndex.put(clean, fieldMap.get(fieldApi));
        }

        for (String key : payload.keySet()) {
            String searchKey = stripNamespace(key).toLowerCase(); 
            if (cleanNameIndex.containsKey(searchKey)) {
                SObjectField field = cleanNameIndex.get(searchKey);
                Object val = payload.get(key);
                Schema.DisplayType dtype = field.getDescribe().getType();
                
                if (val != null) {
                    if (dtype == Schema.DisplayType.DATE) {
                        record.put(field, Date.valueOf((String)val));
                    } else if (dtype == Schema.DisplayType.DATETIME) {
                        record.put(field, (DateTime)JSON.deserialize('"' + val + '"', DateTime.class));
                    } else {
                        record.put(field, val);
                    }
                } else {
                    record.put(field, null);
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

    private static Schema.SObjectType findSObjectType(String apiName) {
        Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
        String target = stripNamespace(apiName).toLowerCase();
        
        for (String key : gd.keySet()) {
            if (stripNamespace(key).toLowerCase() == target) {
                return gd.get(key);
            }
        }
        return null;
    }
}
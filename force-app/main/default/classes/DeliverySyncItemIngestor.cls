/**
 * @description Logic for processing Inbound Sync Items using the "Ledger Pattern".
 * Standardized to handle namespaced and non-namespaced environments.
 */
public without sharing class DeliverySyncItemIngestor {

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
        
        if (localRecordId == null && String.isNotBlank(targetId) && objectType.contains('Ticket_Comment__c')) {
            Id localParentId = findLocalTicketId(targetId);
            if (localParentId != null) {
                putSafe(recordToUpsert, 'TicketId__c', localParentId);
            }
        }

        mapFields(recordToUpsert, payload, targetType);
        putSafe(recordToUpsert, 'SourcePk__c', 'Vendor'); 

        if (recordToUpsert.Id != null) {
            Database.update(recordToUpsert, AccessLevel.SYSTEM_MODE);
        } else {
            Database.insert(recordToUpsert, AccessLevel.SYSTEM_MODE);
            createLedgerEntry(objectType, sourceId, recordToUpsert.Id);
        }
    }

    private static Id findLocalId(Schema.SObjectType type, String remoteId) {
        String objName = type.getDescribe().getName();
        // Use normalized field names to avoid double-prefixing
        if (objName.endsWith('Ticket__c') && !objName.endsWith('Ticket_Comment__c')) {
            List<Request__c> reqs = [SELECT TicketId__c FROM Request__c WHERE RemoteTicketIdTxt__c = :remoteId WITH SYSTEM_MODE LIMIT 1];
            return reqs.isEmpty() ? null : reqs[0].TicketId__c;
        } else {
            // Remove prefix from objName for consistent lookup in standard ObjectTypePk__c field
            String cleanName = objName.contains('__') ? objName.substringAfter('__') : objName;
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
        item.ObjectTypePk__c = objType.contains('__') ? objType.substringAfter('__') : objType;
        item.RemoteExternalIdTxt__c = remoteId;
        item.LocalRecordIdTxt__c = (String)localId;
        item.PayloadTxt__c = 'Ledger Mapping Created';
        Database.insert(item, AccessLevel.SYSTEM_MODE);
    }

    private static void mapFields(SObject record, Map<String, Object> payload, Schema.SObjectType type) {
        Map<String, SObjectField> fieldMap = type.getDescribe().fields.getMap();
        for (String key : payload.keySet()) {
            SObjectField field = fieldMap.containsKey(key) ? fieldMap.get(key) : fieldMap.get('delivery__' + key);
            if (field != null && field.getDescribe().isUpdateable()) {
                record.put(field, payload.get(key));
            }
        }
    }

    private static void putSafe(SObject rec, String field, Object val) {
        Map<String, SObjectField> fieldMap = rec.getSObjectType().getDescribe().fields.getMap();
        if (fieldMap.containsKey(field)) { rec.put(field, val); }
        else if (fieldMap.containsKey('delivery__' + field)) { rec.put('delivery__' + field, val); }
    }

    private static Schema.SObjectType findSObjectType(String apiName) {
        Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
        if (gd.containsKey(apiName)) return gd.get(apiName);
        if (gd.containsKey('delivery__' + apiName)) return gd.get('delivery__' + apiName);
        return null;
    }
}
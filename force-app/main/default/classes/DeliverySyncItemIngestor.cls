/**
 * @description Logic for processing Inbound Sync Items using the "Ledger Pattern".
 * Standardized to handle namespaced environments and ensure field mapping accuracy.
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

        // Apply changes from the payload
        mapFields(recordToUpsert, payload, targetType);
        putSafe(recordToUpsert, 'SourcePk__c', 'Vendor'); 

        // Execute DML
        if (recordToUpsert.Id != null) {
            Database.update(recordToUpsert, AccessLevel.SYSTEM_MODE);
        } else {
            Database.insert(recordToUpsert, AccessLevel.SYSTEM_MODE);
            createLedgerEntry(objectType, sourceId, recordToUpsert.Id);
        }
    }

    private static Id findLocalId(Schema.SObjectType type, String remoteId) {
        String objName = type.getDescribe().getName();
        if (objName.endsWith('Ticket__c') && !objName.endsWith('Ticket_Comment__c')) {
            List<Request__c> reqs = [SELECT TicketId__c FROM Request__c WHERE RemoteTicketIdTxt__c = :remoteId WITH SYSTEM_MODE LIMIT 1];
            return reqs.isEmpty() ? null : reqs[0].TicketId__c;
        } else {
            String cleanName = objName.contains('__') ? objName.split('__')[objName.split('__').size()-2] + '__c' : objName;
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
        item.ObjectTypePk__c = objType.contains('__') ? objType.split('__')[objType.split('__').size()-2] + '__c' : objType;
        item.RemoteExternalIdTxt__c = remoteId;
        item.LocalRecordIdTxt__c = (String)localId;
        item.PayloadTxt__c = 'Ledger Mapping Created';
        Database.insert(item, AccessLevel.SYSTEM_MODE);
    }

    /**
     * @description Robust field mapper. Matches payload keys to SObject fields with namespace awareness.
     */
    private static void mapFields(SObject record, Map<String, Object> payload, Schema.SObjectType type) {
        Map<String, SObjectField> fieldMap = type.getDescribe().fields.getMap();
        // Create a lowercase map for case-insensitive lookup
        Map<String, SObjectField> lowerFieldMap = new Map<String, SObjectField>();
        for (String fieldName : fieldMap.keySet()) {
            lowerFieldMap.put(fieldName.toLowerCase(), fieldMap.get(fieldName));
        }

        for (String key : payload.keySet()) {
            String lowerKey = key.toLowerCase();
            SObjectField field = null;
            
            if (lowerFieldMap.containsKey(lowerKey)) {
                field = lowerFieldMap.get(lowerKey);
            } else if (lowerFieldMap.containsKey('delivery__' + lowerKey)) {
                field = lowerFieldMap.get('delivery__' + lowerKey);
            }

            if (field != null && field.getDescribe().isUpdateable()) {
                record.put(field, payload.get(key));
            }
        }
    }

    private static void putSafe(SObject rec, String field, Object val) {
        Map<String, SObjectField> fieldMap = rec.getSObjectType().getDescribe().fields.getMap();
        String lowerField = field.toLowerCase();
        for (String fName : fieldMap.keySet()) {
            if (fName.toLowerCase() == lowerField || fName.toLowerCase() == 'delivery__' + lowerField) {
                rec.put(fieldMap.get(fName), val);
                return;
            }
        }
    }

    private static Schema.SObjectType findSObjectType(String apiName) {
        Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
        String lowerName = apiName.toLowerCase();
        for (String key : gd.keySet()) {
            if (key.toLowerCase() == lowerName || key.toLowerCase() == 'delivery__' + lowerName) {
                return gd.get(key);
            }
        }
        return null;
    }
}
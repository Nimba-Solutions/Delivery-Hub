/**
 * @description Logic for processing Inbound Sync Items using the "Ledger Pattern".
 * Runs in System Mode (without sharing) to bypass FLS restrictions during Sync.
 */
public without sharing class DeliverySyncItemIngestor {

    // Helper to identify the namespace prefix (e.g. 'delivery__')
    private static String getNamespacePrefix() {
        String ns = [SELECT NamespacePrefix FROM Organization LIMIT 1].NamespacePrefix;
        return String.isBlank(ns) ? '' : ns + '__';
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
            Id localParentId = findLocalTicketId(targetId);
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
        }
    }

    // --- HELPERS ---

    private static Id findLocalId(Schema.SObjectType type, String remoteId) {
        String objName = type.getDescribe().getName();
        if (objName.endsWith('Ticket__c') && !objName.endsWith('Ticket_Comment__c')) {
            // Check for Request bridge first
            List<Request__c> reqs = [SELECT TicketId__c FROM Request__c WHERE RemoteTicketIdTxt__c = :remoteId WITH SYSTEM_MODE LIMIT 1];
            return reqs.isEmpty() ? null : reqs[0].TicketId__c;
        } else {
            // FIX: Safely remove namespace from start, leaving __c suffix intact
            String cleanName = objName.removeStartIgnoreCase(getNamespacePrefix());
            
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
        
        // FIX: Ensure restricted picklist receives "Ticket__c" not "c"
        String cleanType = objType.removeStartIgnoreCase(getNamespacePrefix());
        
        item.ObjectTypePk__c = cleanType;
        item.RemoteExternalIdTxt__c = remoteId;
        item.LocalRecordIdTxt__c = (String)localId;
        item.PayloadTxt__c = 'Ledger Mapping Created';
        Database.insert(item, AccessLevel.SYSTEM_MODE);
    }

    /**
     * @description Robust mapping: Indexes local Schema fields by their "clean" name 
     * to match incoming payload keys regardless of namespace prefix.
     */
    private static void mapFields(SObject record, Map<String, Object> payload, Schema.SObjectType type) {
        Map<String, SObjectField> fieldMap = type.getDescribe().fields.getMap();
        String ns = getNamespacePrefix().toLowerCase();
        
        // 1. Build Index: Clean Name (lowercase) -> Actual SObjectField
        Map<String, SObjectField> cleanNameIndex = new Map<String, SObjectField>();
        for (String fieldApi : fieldMap.keySet()) {
            String lowerApi = fieldApi.toLowerCase();
            String clean = lowerApi.removeStart(ns);
            cleanNameIndex.put(clean, fieldMap.get(fieldApi));
        }

        // 2. Iterate Payload
        for (String key : payload.keySet()) {
            String searchKey = key.toLowerCase();
            if (cleanNameIndex.containsKey(searchKey)) {
                SObjectField field = cleanNameIndex.get(searchKey);
                // System Mode - No isUpdateable() check needed for Sync
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
        String ns = getNamespacePrefix().toLowerCase();
        String target = fieldName.toLowerCase();

        for (String fieldApi : fieldMap.keySet()) {
            String lowerApi = fieldApi.toLowerCase();
            // Match exact or namespaced version
            if (lowerApi == target || lowerApi == (ns + target)) {
                rec.put(fieldMap.get(fieldApi), val);
                return;
            }
        }
    }

    private static Schema.SObjectType findSObjectType(String apiName) {
        Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
        String ns = getNamespacePrefix().toLowerCase();
        String lowerName = apiName.toLowerCase();
        
        for (String key : gd.keySet()) {
            String lowerKey = key.toLowerCase();
            if (lowerKey == lowerName || lowerKey == (ns + lowerName)) {
                return gd.get(key);
            }
        }
        return null;
    }
}
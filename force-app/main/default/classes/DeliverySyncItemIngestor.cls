/**
 * @description Logic for processing Inbound Sync Items using the "Ledger Pattern".
 * Runs in System Mode (without sharing) using direct field lookups to bypass FLS and Namespace issues.
 */
public without sharing class DeliverySyncItemIngestor {

    // Cache the namespace to avoid repeated queries
    private static String cachedNamespace;
    private static String getNamespace() {
        if (cachedNamespace == null) {
            String ns = [SELECT NamespacePrefix FROM Organization LIMIT 1].NamespacePrefix;
            cachedNamespace = String.isBlank(ns) ? '' : ns + '__';
        }
        return cachedNamespace;
    }

    public static void processInboundItem(String objectType, Map<String, Object> payload) {
        SyncEngine.setSyncContext();

        // 1. Resolve SObjectType (Blind Lookup strategy)
        Schema.SObjectType targetType = findSObjectType(objectType);
        if (targetType == null) {
            throw new IllegalArgumentException('Invalid Object Type: ' + objectType);
        }

        String sourceId = (String) payload.get('SourceId'); 
        String targetId = (String) payload.get('TargetId'); 
        
        // 2. Find Local Record
        Id localRecordId = findLocalId(targetType, sourceId);
        SObject recordToUpsert = (localRecordId != null) ? targetType.newSObject(localRecordId) : targetType.newSObject();
        
        // 3. Handle Parenting (Directly set ID)
        if (localRecordId == null && String.isNotBlank(targetId) && objectType.contains('Ticket_Comment__c')) {
            Id localParentId = findLocalTicketId(targetId);
            if (localParentId != null) {
                putSafe(recordToUpsert, 'TicketId__c', localParentId);
            }
        }

        // 4. Map Fields & Audit
        mapFields(recordToUpsert, payload, targetType);
        putSafe(recordToUpsert, 'SourcePk__c', 'Vendor'); 

        // 5. Execute DML (System Mode via Class Declaration + AccessLevel)
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
            // Using Dynamic SOQL to avoid compile-time dependency issues during package install
            String q = 'SELECT TicketId__c FROM Request__c WHERE RemoteTicketIdTxt__c = :remoteId LIMIT 1';
            List<SObject> reqs = Database.query(q);
            return reqs.isEmpty() ? null : (Id)reqs[0].get('TicketId__c');
        } else {
            // Robust Namespace Stripping
            String cleanName = objName.contains('__') ? objName.substringAfterLast('__') : objName;
            String q = 'SELECT LocalRecordIdTxt__c FROM Sync_Item__c WHERE RemoteExternalIdTxt__c = :remoteId AND ObjectTypePk__c = :cleanName LIMIT 1';
            List<SObject> ledger = Database.query(q);
            return ledger.isEmpty() ? null : (Id)((String)ledger[0].get('LocalRecordIdTxt__c'));
        }
    }

    private static Id findLocalTicketId(String remoteTicketId) {
        String q = 'SELECT TicketId__c FROM Request__c WHERE RemoteTicketIdTxt__c = :remoteTicketId LIMIT 1';
        List<SObject> reqs = Database.query(q);
        return reqs.isEmpty() ? null : (Id)reqs[0].get('TicketId__c');
    }

    private static void createLedgerEntry(String objType, String remoteId, Id localId) {
        Sync_Item__c item = new Sync_Item__c();
        item.DirectionPk__c = 'Inbound';
        item.StatusPk__c = 'Synced';
        // Ensure "Ticket__c" is saved, never "delivery__Ticket__c"
        item.ObjectTypePk__c = objType.contains('__') ? objType.substringAfterLast('__') : objType;
        item.RemoteExternalIdTxt__c = remoteId;
        item.LocalRecordIdTxt__c = (String)localId;
        item.PayloadTxt__c = 'Ledger Mapping Created';
        Database.insert(item, AccessLevel.SYSTEM_MODE);
    }

    /**
     * @description Direct Map Lookup - No Iteration.
     */
    private static void mapFields(SObject record, Map<String, Object> payload, Schema.SObjectType type) {
        Map<String, SObjectField> fieldMap = type.getDescribe().fields.getMap();
        String ns = getNamespace();

        for (String key : payload.keySet()) {
            SObjectField field = fieldMap.get(key); // Try exact match (TicketId__c)
            if (field == null && String.isNotBlank(ns)) {
                field = fieldMap.get(ns + key); // Try namespaced match (delivery__TicketId__c)
            }

            if (field != null) { // Trusted System Mode: No isUpdateable check needed
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
        String ns = getNamespace();
        
        SObjectField field = fieldMap.get(fieldName);
        if (field == null && String.isNotBlank(ns)) {
            field = fieldMap.get(ns + fieldName);
        }

        if (field != null) {
            rec.put(field, val);
        }
    }

    private static Schema.SObjectType findSObjectType(String apiName) {
        Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
        String ns = getNamespace();
        
        if (gd.containsKey(apiName)) return gd.get(apiName);
        if (String.isNotBlank(ns) && gd.containsKey(ns + apiName)) return gd.get(ns + apiName);
        return null;
    }
}
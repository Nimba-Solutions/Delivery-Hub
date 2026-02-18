/**
 * @description Logic for processing Inbound Sync Items using the "Ledger Pattern".
 * Does NOT require custom fields on target objects. Uses Sync_Item__c and Request__c as the map.
 */
public without sharing class DeliverySyncItemIngestor {

    /**
     * @description Main entry point for inbound data.
     * @param objectType The API name (e.g., Ticket__c)
     * @param payload The JSON map received from the sender
     */
    public static void processInboundItem(String objectType, Map<String, Object> payload) {
        
        // 1. Prevent Echo Loops
        // We tell the Engine: "We are currently syncing, don't fire outbound triggers."
        SyncEngine.setSyncContext();

        Schema.SObjectType targetType = findSObjectType(objectType);
        if (targetType == null) {
            throw new IllegalArgumentException('Invalid Object Type: ' + objectType);
        }

        // 2. Extract Keys
        String sourceId = (String) payload.get('SourceId'); // The Remote ID
        String targetId = (String) payload.get('TargetId'); // Remote's Parent ID (if linked)
        
        // 3. LEDGER LOOKUP: Find Local Record ID
        Id localRecordId = findLocalId(targetType, sourceId);
        
        SObject recordToUpsert;
        
        if (localRecordId != null) {
            // --- UPDATE PATH ---
            recordToUpsert = targetType.newSObject(localRecordId);
        } else {
            // --- INSERT PATH ---
            recordToUpsert = targetType.newSObject();
            
            // Handle Parenting (e.g., Linking a new Comment to an existing local Ticket)
            if (String.isNotBlank(targetId) && objectType.contains('Ticket_Comment__c')) {
                Id localParentId = findLocalTicketId(targetId);
                if (localParentId != null) {
                    putSafe(recordToUpsert, 'TicketId__c', localParentId);
                }
            } 
        }

        // 4. Map Payload to Fields
        mapFields(recordToUpsert, payload, targetType);

        // 5. Audit: Mark as coming from Vendor
        // Wrapped in try/catch to handle orgs where the SourcePk__c field doesn't exist yet
        try {
            putSafe(recordToUpsert, 'SourcePk__c', 'Vendor'); 
        } catch (Exception e) {
            System.debug(LoggingLevel.FINE, 'SourcePk__c field not found, skipping audit stamp.');
        }

        // 6. Execute DML
        if (recordToUpsert.Id != null) {
            Database.update(recordToUpsert, AccessLevel.SYSTEM_MODE);
        } else {
            Database.insert(recordToUpsert, AccessLevel.SYSTEM_MODE);
            
            // 7. WRITE TO LEDGER
            // Record the mapping so future updates to this Remote ID find this Local ID.
            createLedgerEntry(objectType, sourceId, recordToUpsert.Id);
        }
    }

    // --- LEDGER HELPERS ---

    private static Id findLocalId(Schema.SObjectType type, String remoteId) {
        String objName = type.getDescribe().getName();
        
        if (objName.endsWith('Ticket__c') && !objName.endsWith('Ticket_Comment__c')) {
            // Tickets use the Request table as the bridge
            List<Request__c> reqs = [
                SELECT TicketId__c 
                FROM Request__c 
                WHERE RemoteTicketIdTxt__c = :remoteId 
                LIMIT 1
            ];
            return reqs.isEmpty() ? null : reqs[0].TicketId__c;
        } else {
            // Others use previous Sync_Items as the ledger
            List<Sync_Item__c> ledger = [
                SELECT LocalRecordIdTxt__c 
                FROM Sync_Item__c 
                WHERE RemoteExternalIdTxt__c = :remoteId
                AND ObjectTypePk__c = :objName.replace('delivery__', '')
                LIMIT 1
            ];
            return ledger.isEmpty() ? null : (Id)ledger[0].LocalRecordIdTxt__c;
        }
    }

    private static Id findLocalTicketId(String remoteTicketId) {
        List<Request__c> reqs = [
            SELECT TicketId__c FROM Request__c WHERE RemoteTicketIdTxt__c = :remoteTicketId LIMIT 1
        ];
        return reqs.isEmpty() ? null : reqs[0].TicketId__c;
    }

    private static void createLedgerEntry(String objType, String remoteId, Id localId) {
        Sync_Item__c item = new Sync_Item__c();
        item.DirectionPk__c = 'Inbound';
        item.StatusPk__c = 'Synced';
        item.ObjectTypePk__c = objType.replace('delivery__', '');
        item.RemoteExternalIdTxt__c = remoteId;
        item.LocalRecordIdTxt__c = (String)localId;
        item.PayloadTxt__c = 'Ledger Mapping Created';
        insert item;
    }

    // --- UTILITIES ---

    private static void mapFields(SObject record, Map<String, Object> payload, Schema.SObjectType type) {
        Map<String, SObjectField> fieldMap = type.getDescribe().fields.getMap();
        Set<String> blocklist = new Set<String>{'SourceId', 'TargetId', 'attributes', 'Id'};

        for (String key : payload.keySet()) {
            if (blocklist.contains(key)) continue;

            SObjectField field = fieldMap.get(key);
            if (field == null) field = fieldMap.get('delivery__' + key);

            if (field != null && field.getDescribe().isUpdateable()) {
                Object val = payload.get(key);
                if (val == null) { record.put(field, null); continue; }
                
                Schema.DisplayType dtype = field.getDescribe().getType();
                if (dtype == Schema.DisplayType.DATE) {
                    record.put(field, Date.valueOf((String)val));
                } else if (dtype == Schema.DisplayType.DATETIME) {
                    record.put(field, (DateTime)JSON.deserialize('"' + val + '"', DateTime.class));
                } else {
                    record.put(field, val);
                }
            }
        }
    }

    private static void putSafe(SObject rec, String field, Object val) {
        try {
            rec.put(field, val);
        } catch (Exception e) {
            try { rec.put('delivery__' + field, val); } catch (Exception ex) {}
        }
    }

    private static Schema.SObjectType findSObjectType(String apiName) {
        Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
        if (gd.containsKey(apiName)) return gd.get(apiName);
        if (gd.containsKey('delivery__' + apiName)) return gd.get('delivery__' + apiName);
        return null;
    }
}
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
        SyncEngine.setSyncContext();

        Schema.SObjectType targetType = findSObjectType(objectType);
        if (targetType == null) {
            throw new IllegalArgumentException('Invalid Object Type: ' + objectType);
        }

        // 2. Extract Keys
        String sourceId = (String) payload.get('SourceId'); 
        String targetId = (String) payload.get('TargetId'); 
        
        // 3. LEDGER LOOKUP: Find Local Record ID
        Id localRecordId = findLocalId(targetType, sourceId);
        
        SObject recordToUpsert;
        
        if (localRecordId != null) {
            recordToUpsert = targetType.newSObject(localRecordId);
        } else {
            recordToUpsert = targetType.newSObject();
            
            // Handle Parenting
            if (String.isNotBlank(targetId) && objectType.contains('Ticket_Comment__c')) {
                Id localParentId = findLocalTicketId(targetId);
                if (localParentId != null) {
                    putSafe(recordToUpsert, 'TicketId__c', localParentId);
                }
            } 
        }

        // 4. Map Payload to Fields
        mapFields(recordToUpsert, payload, targetType);

        // 5. Audit Logic
        try {
            putSafe(recordToUpsert, 'SourcePk__c', 'Vendor'); 
        } catch (Exception e) {
            System.debug(LoggingLevel.FINE, 'Audit field missing: ' + e.getMessage());
        }

        // 6. Execute DML with Explicit Access Levels
        if (recordToUpsert.Id != null) {
            Database.update(recordToUpsert, AccessLevel.SYSTEM_MODE);
        } else {
            Database.insert(recordToUpsert, AccessLevel.SYSTEM_MODE);
            
            // 7. WRITE TO LEDGER
            createLedgerEntry(objectType, sourceId, recordToUpsert.Id);
        }
    }

    // --- LEDGER HELPERS ---

    /**
     * @description Finds local ID using SOQL with Security enforcement.
     * @param type The SObjectType of the record being sought.
     * @param remoteId The external ID provided by the remote system.
     * @return Id of the local record if found, otherwise null.
     */
    private static Id findLocalId(Schema.SObjectType type, String remoteId) {
        String objName = type.getDescribe().getName();
        
        if (objName.endsWith('Ticket__c') && !objName.endsWith('Ticket_Comment__c')) {
            List<Request__c> reqs = [
                SELECT TicketId__c 
                FROM Request__c 
                WHERE RemoteTicketIdTxt__c = :remoteId 
                WITH USER_MODE 
                LIMIT 1
            ];
            return reqs.isEmpty() ? null : reqs[0].TicketId__c;
        } else {
            List<Sync_Item__c> ledger = [
                SELECT LocalRecordIdTxt__c 
                FROM Sync_Item__c 
                WHERE RemoteExternalIdTxt__c = :remoteId
                AND ObjectTypePk__c = :objName.replace('delivery__', '')
                WITH USER_MODE 
                LIMIT 1
            ];
            return ledger.isEmpty() ? null : (Id)ledger[0].LocalRecordIdTxt__c;
        }
    }

    /**
     * @description Resolves a remote ticket ID to a local Salesforce Ticket ID.
     * @param remoteTicketId The ticket ID known by the remote system.
     * @return Id of the local Ticket__c record.
     */
    private static Id findLocalTicketId(String remoteTicketId) {
        List<Request__c> reqs = [
            SELECT TicketId__c 
            FROM Request__c 
            WHERE RemoteTicketIdTxt__c = :remoteTicketId 
            WITH USER_MODE 
            LIMIT 1
        ];
        return reqs.isEmpty() ? null : reqs[0].TicketId__c;
    }

    /**
     * @description Records an inbound mapping in the Sync Item ledger.
     * @param objType The type of object being mapped.
     * @param remoteId The ID of the record on the remote system.
     * @param localId The ID of the record on the local system.
     */
    private static void createLedgerEntry(String objType, String remoteId, Id localId) {
        Sync_Item__c item = new Sync_Item__c();
        item.DirectionPk__c = 'Inbound';
        item.StatusPk__c = 'Synced';
        item.ObjectTypePk__c = objType.replace('delivery__', '');
        item.RemoteExternalIdTxt__c = remoteId;
        item.LocalRecordIdTxt__c = (String)localId;
        item.PayloadTxt__c = 'Ledger Mapping Created';
        
        Database.insert(item, AccessLevel.USER_MODE);
    }

    // --- UTILITIES ---

    /**
     * @description Dynamically maps payload keys to SObject fields.
     * @param record The SObject to populate.
     * @param payload Map of field names to values.
     * @param type The SObjectType of the record.
     */
    private static void mapFields(SObject record, Map<String, Object> payload, Schema.SObjectType type) {
        Map<String, SObjectField> fieldMap = type.getDescribe().fields.getMap();
        Set<String> blocklist = new Set<String>{'SourceId', 'TargetId', 'attributes', 'Id'};

        for (String key : payload.keySet()) {
            if (blocklist.contains(key)) { 
                continue; 
            }

            SObjectField field = fieldMap.get(key);
            if (field == null) { 
                field = fieldMap.get('delivery__' + key); 
            }

            if (field != null && field.getDescribe().isUpdateable()) {
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
                } else {
                    record.put(field, val);
                }
            }
        }
    }

    /**
     * @description Safe field assignment with namespace fallback.
     * @param rec The target SObject.
     * @param field The API name of the field.
     * @param val The value to assign.
     */
    private static void putSafe(SObject rec, String field, Object val) {
        try {
            rec.put(field, val);
        } catch (Exception e) {
            try { 
                rec.put('delivery__' + field, val); 
            } catch (Exception ex) {
                System.debug(LoggingLevel.FINEST, 'Namespace fallback failed: ' + ex.getMessage());
            }
        }
    }

    /**
     * @description Identifies a SObjectType by name with namespace flexibility.
     * @param apiName The string name of the object.
     * @return Schema.SObjectType of the found object.
     */
    private static Schema.SObjectType findSObjectType(String apiName) {
        Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
        if (gd.containsKey(apiName)) { 
            return gd.get(apiName); 
        }
        if (gd.containsKey('delivery__' + apiName)) { 
            return gd.get('delivery__' + apiName); 
        }
        return null;
    }
}
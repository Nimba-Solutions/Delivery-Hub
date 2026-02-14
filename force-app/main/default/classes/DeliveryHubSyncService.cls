/**
 * @description Service class to process incoming JSON payloads.
 * Uses Sync_Item__c as a "Translation Ledger" to support Bi-Directional Inserts AND Updates.
 */
public without sharing class DeliveryHubSyncService {

    // Suppress warnings for dynamic SOQL and CRUD (System context is intentional)
    @SuppressWarnings('PMD.ApexCRUDViolation, PMD.ApexSOQLInjection')
    public static void processSync(String objectType, Map<String, Object> payload) {
        Schema.SObjectType targetType = findSObjectType(objectType);
        if (targetType == null) {
            throw new CalloutException('Invalid Object Type: ' + objectType);
        }

        String fns = getFieldNs();
        
        // 1. EXTRACT IDs
        String targetId = (String) payload.get('TargetId');
        if (String.isBlank(targetId)) {
            targetId = (String) payload.get('targetId');
        }
        
        String sourceId = (String) payload.get('SourceId'); 

        // 2. CHECK LEDGER (Find Local Record for Update)
        Id localRecordId = findLocalIdFromLedger(sourceId);

        SObject record = targetType.newSObject();
        Boolean isInsert = true;

        if (localRecordId != null) {
            // UPDATE SCENARIO via Ledger
            record.put('Id', localRecordId);
            isInsert = false;
        } else {
            // INSERT SCENARIO
            isInsert = true;
            if (objectType.contains('Ticket_Comment__c') && String.isNotBlank(targetId)) {
                Id localTicketId = resolveLocalTicketId(targetId);
                record.put(fns + 'TicketId__c', localTicketId);
            } else if (String.isNotBlank(targetId)) {
                // For Tickets, if targetId is provided, try to use it
                try {
                    Id sId = (Id) targetId;
                    if (sId.getSObjectType() == targetType) {
                        record.put('Id', targetId);
                        isInsert = false;
                    }
                } catch (Exception e) { 
                    /* Invalid ID, treat as Insert */ 
                    System.debug(LoggingLevel.FINEST, 'ID Mismatch: ' + e.getMessage());
                }
            }
        }

        // 3. MAP FIELDS
        mapFields(record, payload, targetType);

        // 4. PREVENT PING-PONG LOOP
        setSyncStatus(record, fns);

        // --- DEFENSIVE FIX: Override isInsert if ID exists ---
        if (record.get('Id') != null) {
            isInsert = false;
        }

        // 5. COMMIT
        if (isInsert) {
            Database.insert(record, AccessLevel.SYSTEM_MODE);
            // 6. WRITE RECEIPT (Only needed on Insert)
            if (String.isNotBlank(sourceId)) {
                createLedgerEntry(sourceId, record.Id, objectType);
            }
        } else {
            Database.update(record, AccessLevel.SYSTEM_MODE);
        }
    }

    // --- HELPER METHODS ---

    /**
     * @description Looks up the Local Record ID from the Sync Item Ledger using the Remote Source ID.
     * @param sourceId The remote record ID (SourceId from payload)
     * @return Id The local record ID if found in the ledger, otherwise null.
     */
    private static Id findLocalIdFromLedger(String sourceId) {
        if (String.isBlank(sourceId)) {
            return null;
        }
        
        String fns = getFieldNs();
        // Escape single quotes to satisfy PMD Security
        String efns = String.escapeSingleQuotes(fns);
        
        String query = 'SELECT ' + efns + 'LocalRecordIdTxt__c FROM ' + efns + 'Sync_Item__c ' + 
                       'WHERE ' + efns + 'RemoteExternalIdTxt__c = :sourceId ' +
                       'AND ' + efns + 'LocalRecordIdTxt__c != NULL ' + 
                       'LIMIT 1';
        try {
            List<SObject> items = Database.query(query);
            if (!items.isEmpty()) {
                String localIdStr = (String) items[0].get(fns + 'LocalRecordIdTxt__c');
                return (Id) localIdStr;
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'Ledger Lookup Error: ' + e.getMessage());
        }
        return null;
    }

    /**
     * @description Creates a "Receipt" record in Sync_Item__c to map the remote ID to the new local ID.
     * @param sourceId The remote record ID (SourceId from payload)
     * @param localRecordId The newly inserted local record ID
     * @param objectType The API name of the object type (e.g. Ticket_Comment__c)
     */
    private static void createLedgerEntry(String sourceId, Id localRecordId, String objectType) {
        try {
            String fns = getFieldNs();
            SObject item = Schema.getGlobalDescribe().get(fns + 'Sync_Item__c').newSObject();
            
            item.put(fns + 'RemoteExternalIdTxt__c', sourceId); 
            item.put(fns + 'LocalRecordIdTxt__c', (String)localRecordId);
            item.put(fns + 'StatusPk__c', 'Synced'); 
            item.put(fns + 'DirectionPk__c', 'Inbound');
            item.put(fns + 'ObjectTypePk__c', objectType);
            item.put(fns + 'PayloadTxt__c', 'Ledger Map: ' + sourceId + ' -> ' + localRecordId);
            
            Database.insert(item, AccessLevel.SYSTEM_MODE);
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Failed to create Ledger Entry: ' + e.getMessage());
        }
    }

    private static String cachedFieldNs;
    private static String getFieldNs() {
        if (cachedFieldNs == null) {
            String ns = [SELECT NamespacePrefix FROM Organization LIMIT 1].NamespacePrefix;
            cachedFieldNs = String.isBlank(ns) ? '' : ns + '__';
        }
        return cachedFieldNs;
    }

    private static Id resolveLocalTicketId(String remoteTicketId) {
        List<Request__c> requests = [
            SELECT TicketId__c FROM Request__c
            WHERE RemoteTicketIdTxt__c = :remoteTicketId
            AND StatusPk__c != 'Inactive'
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        return !requests.isEmpty() ? requests[0].TicketId__c : (Id) remoteTicketId;
    }

    private static Schema.SObjectType findSObjectType(String apiName) {
        Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
        if (gd.containsKey(apiName)) {
            return gd.get(apiName);
        }
        String fns = getFieldNs();
        return (String.isNotBlank(fns) && gd.containsKey(fns + apiName)) ? gd.get(fns + apiName) : null;
    }

    private static void mapFields(SObject record, Map<String, Object> payload, Schema.SObjectType targetType) {
        Map<String, Object> fieldsToMap = payload.clone();
        Set<String> metadataKeys = new Set<String>{
            'Id', 'SourceId', 'TargetId', 'targetId', 'Action', 'LastModifiedBy', 'LastModifiedDate', 'direction', 'timestamp'
        };
        for(String key : metadataKeys) {
            fieldsToMap.remove(key);
        }

        Map<String, SObjectField> schemaFields = targetType.getDescribe().fields.getMap();

        for (String payloadKey : fieldsToMap.keySet()) {
            String lowerKey = payloadKey.toLowerCase();
            if (lowerKey == 'body') {
                lowerKey = 'bodytxt__c';
            }
            if (lowerKey == 'author') {
                lowerKey = 'authortxt__c';
            }

            SObjectField field = null;
            for(String fieldApi : schemaFields.keySet()) {
                SObjectField f = schemaFields.get(fieldApi);
                if (f.getDescribe().getLocalName().toLowerCase() == lowerKey) {
                    field = f;
                    break;
                }
            }
            if (field != null) {
                applyField(record, field, fieldsToMap.get(payloadKey));
            }
        }
    }

    private static void applyField(SObject record, SObjectField field, Object val) {
        try {
            Schema.DisplayType dtype = field.getDescribe().getType();
            if (val == null) {
                record.put(field, null);
            } else if (dtype == Schema.DisplayType.DATE) {
                record.put(field, Date.valueOf((String)val));
            } else if (dtype == Schema.DisplayType.DATETIME) {
                String dtStr = (String)val;
                record.put(field, (DateTime)JSON.deserialize('"' + dtStr + '"', DateTime.class));
            } else if (dtype == Schema.DisplayType.PERCENT || dtype == Schema.DisplayType.CURRENCY || dtype == Schema.DisplayType.DOUBLE) {
                record.put(field, Decimal.valueOf(String.valueOf(val)));
            } else {
                record.put(field, val);
            }
        } catch (Exception e) { 
            System.debug(LoggingLevel.WARN, 'Field Mapping Error on ' + field + ': ' + e.getMessage()); 
        }
    }

    private static void setSyncStatus(SObject record, String fns) {
        try { 
            record.put(fns + 'JiraSyncStatusTxt__c', 'Synced'); 
        } catch (Exception e) {
            System.debug(LoggingLevel.FINEST, 'Sync Status field missing: ' + e.getMessage());
        }
    }
}
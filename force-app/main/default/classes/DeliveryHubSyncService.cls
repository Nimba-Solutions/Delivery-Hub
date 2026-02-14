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
        // FIX: Added braces
        if (String.isBlank(targetId)) {
            targetId = (String) payload.get('targetId');
        }
        
        String sourceId = (String) payload.get('SourceId'); 

        // 2. IDEMPOTENCY CHECK (The Ledger)
        if (String.isNotBlank(sourceId) && isDuplicateEvent(sourceId)) {
            System.debug(LoggingLevel.INFO, 'Duplicate Event Skipped. SourceId: ' + sourceId);
            return;
        }

        SObject record = targetType.newSObject();
        Boolean isInsert = true;

        // 3. PARENT RESOLUTION (Specific to Comments)
        if (objectType.contains('Ticket_Comment__c')) {
            isInsert = true;
            if (String.isNotBlank(targetId)) {
                Id localTicketId = resolveLocalTicketId(targetId);
                record.put(fns + 'TicketId__c', localTicketId);
            }
        } else {
            // Logic for standard updates (Tickets, etc.)
            try {
                if (String.isBlank(targetId)) {
                    isInsert = true;
                } else {
                    Id sId = (Id) targetId;
                    if (sId.getSObjectType() == targetType) {
                        record.put('Id', targetId);
                    } else {
                        isInsert = true;
                    }
                }
            } catch (Exception e) {
                isInsert = true;
            }
        }

        // 4. MAP FIELDS
        mapFields(record, payload, targetType);

        // 5. TAG RECORD (Prevent Outbound Loop)
        setSyncStatus(record, fns);

        // 6. COMMIT TARGET RECORD
        if (isInsert) {
            Database.insert(record, AccessLevel.SYSTEM_MODE);
        } else {
            Database.update(record, AccessLevel.SYSTEM_MODE);
        }

        // 7. WRITE RECEIPT TO LEDGER
        if (String.isNotBlank(sourceId)) {
            createReceipt(sourceId, record.Id, objectType);
        }
    }

    // --- HELPER METHODS ---

    /**
     * @description Checks if this Source ID exists in the local Sync_Item__c table.
     * @param sourceId The remote record ID
     * @return Boolean True if duplicate found
     */
    private static Boolean isDuplicateEvent(String sourceId) {
        String fns = getFieldNs();
        String query = 'SELECT Id FROM ' + fns + 'Sync_Item__c ' + 
                       'WHERE ' + fns + 'RemoteExternalIdTxt__c = :sourceId LIMIT 1';
        try {
            List<SObject> existing = Database.query(query);
            return !existing.isEmpty();
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'Ledger Check Failed: ' + e.getMessage());
            return false;
        }
    }

    /**
     * @description Creates a "Receipt" record in Sync_Item__c.
     * @param sourceId The remote record ID
     * @param localRecordId The new local ID
     * @param objectType The API name of the object
     */
    private static void createReceipt(String sourceId, Id localRecordId, String objectType) {
        try {
            String fns = getFieldNs();
            SObject item = Schema.getGlobalDescribe().get(fns + 'Sync_Item__c').newSObject();
            
            item.put(fns + 'RemoteExternalIdTxt__c', sourceId); 
            item.put(fns + 'LocalRecordIdTxt__c', (String)localRecordId);
            item.put(fns + 'StatusPk__c', 'Synced'); 
            item.put(fns + 'DirectionPk__c', 'Inbound');
            item.put(fns + 'PayloadTxt__c', 'Receipt for ' + sourceId);
            item.put(fns + 'ObjectTypePk__c', objectType);
            
            Database.insert(item, AccessLevel.SYSTEM_MODE);
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Failed to create Sync Receipt: ' + e.getMessage());
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
        // FIX: Added braces
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
        // FIX: Added braces
        for(String key : metadataKeys) {
            fieldsToMap.remove(key);
        }

        Map<String, SObjectField> schemaFields = targetType.getDescribe().fields.getMap();

        for (String payloadKey : fieldsToMap.keySet()) {
            String lowerKey = payloadKey.toLowerCase();
            // FIX: Added braces
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
            // FIX: Added braces
            if (field != null) {
                applyField(record, field, fieldsToMap.get(payloadKey));
            }
        }
    }

    private static void applyField(SObject record, SObjectField field, Object val) {
        try {
            Schema.DisplayType dtype = field.getDescribe().getType();
            // FIX: Added braces to entire if/else chain
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
            // FIX: Added debug statement to satisfy EmptyCatchBlock rule
            System.debug(LoggingLevel.FINEST, 'Sync Status field missing: ' + e.getMessage());
        }
    }
}
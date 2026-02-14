/**
 * @description Service class to process incoming JSON payloads.
 * Handles cross-org Ticket_Comment__c parent resolution and prevents Ping-Pong loops.
 * UPDATED: Supports Idempotency AND Edits via Upsert-style logic on SourceId.
 */
public without sharing class DeliveryHubSyncService {

    // Fixed: Combined suppressions into a single string argument
    @SuppressWarnings('PMD.ApexCRUDViolation, PMD.ApexSOQLInjection')
    public static void processSync(String objectType, Map<String, Object> payload) {
        Schema.SObjectType targetType = findSObjectType(objectType);
        if (targetType == null) {
            throw new CalloutException('Invalid Object Type: ' + objectType);
        }

        String fns = getFieldNs();
        SObject record = targetType.newSObject();
        
        // Extract IDs
        String targetId = (String) payload.get('TargetId');
        if (String.isBlank(targetId)) {
            targetId = (String) payload.get('targetId');
        }
        
        String sourceId = (String) payload.get('SourceId'); 

        Boolean isInsert = false;

        // 1. SMART ID & PARENT LOOKUP
        if (objectType.contains('Ticket_Comment__c')) {
            // Check if we already have this record (Handle Edits/Idempotency)
            Id existingId = findRecordBySourceId(targetType, fns, sourceId);
            
            if (existingId != null) {
                // UPDATE SCENARIO
                record.put('Id', existingId);
                isInsert = false;
            } else {
                // INSERT SCENARIO
                isInsert = true;
                if (String.isNotBlank(targetId)) {
                    Id localTicketId = resolveLocalTicketId(targetId);
                    record.put(fns + 'TicketId__c', localTicketId);
                    
                    // Stamp the SourceId so we can find it next time
                    if (String.isNotBlank(sourceId)) {
                        try { 
                            record.put(fns + 'RemoteExternalIdTxt__c', sourceId); 
                        } catch(Exception e) {
                            // Field might not exist on all objects
                        }
                    }
                }
            }
        } else {
            // Standard Logic for other objects
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

        // 2. MAP FIELDS
        mapFields(record, payload, targetType);

        // 3. PREVENT PING-PONG LOOP
        setSyncStatus(record, fns);

        // 4. COMMIT
        if (isInsert) {
            Database.insert(record, AccessLevel.SYSTEM_MODE);
        } else {
            Database.update(record, AccessLevel.SYSTEM_MODE);
        }
    }

    // --- HELPER METHODS ---

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

    /**
     * @description Finds an existing local record ID based on the Remote Source ID.
     */
    private static Id findRecordBySourceId(Schema.SObjectType targetType, String fns, String sourceId) {
        if (String.isBlank(sourceId)) {
            return null;
        }
        try {
            // Safe: targetType.getName() is system derived, others are bind variables
            String query = 'SELECT Id FROM ' + String.escapeSingleQuotes(targetType.getDescribe().getName()) + 
                           ' WHERE ' + String.escapeSingleQuotes(fns) + 'RemoteExternalIdTxt__c = :sourceId LIMIT 1';
            List<SObject> existing = Database.query(query);
            return !existing.isEmpty() ? existing[0].Id : null;
        } catch (Exception e) {
            return null;
        }
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
            // Ignore: Field might not exist on all synced objects
        }
    }
}
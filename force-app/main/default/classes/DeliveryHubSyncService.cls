/**
 * @description Service class to process incoming JSON payloads.
 * CLIENT VERSION: Handles 'Ticket__c' mapping and prevents Ping-Pong loops.
 */
public without sharing class DeliveryHubSyncService {

    public static void processSync(String objectType, Map<String, Object> payload) {
        Schema.SObjectType targetType = findSObjectType(objectType);
        if (targetType == null) {
            throw new CalloutException('Invalid Object Type: ' + objectType);
        }

        SObject record = targetType.newSObject();
        String targetId = (String) payload.get('TargetId');
        Boolean isInsert = false;

        // 1. SMART ID & PARENT LOOKUP
        try {
            if (String.isBlank(targetId)) {
                isInsert = true;
            } else {
                Id sId = (Id) targetId;
                if (sId.getSObjectType() == targetType) {
                    record.put('Id', targetId); // It's an Update
                } else {
                    isInsert = true; // It's an Insert
                    
                    // --- FIX 1: HANDLE FIELD NAME MISMATCH ---
                    // Mothership sends 'TicketId__c', but Client uses 'Ticket__c'
                    if (objectType.contains('Ticket_Comment__c')) {
                         record.put('Ticket__c', targetId);
                    } else {
                         // Default fallback for other objects
                         record.put('TicketId__c', targetId);
                    }
                }
            }
        } catch (Exception e) {
            isInsert = true;
        }

        // 2. MAP FIELDS
        mapFields(record, payload, targetType);

        // --- FIX 2: PREVENT PING-PONG LOOP ---
        // Mark as 'Synced' so the Trigger ignores it and doesn't send it back.
        if (objectType.contains('Ticket_Comment__c')) {
            try {
                record.put('JiraSyncStatusTxt__c', 'Synced');
            } catch (Exception e) {
                System.debug('Could not set Sync Status: ' + e.getMessage());
            }
        }

        // 3. COMMIT
        if (isInsert) {
             Database.insert(record, AccessLevel.SYSTEM_MODE);
        } else {
             Database.update(record, AccessLevel.SYSTEM_MODE);
        }
    }

    // --- HELPER METHODS ---

    private static Schema.SObjectType findSObjectType(String apiName) {
        Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
        if (gd.containsKey(apiName)) return gd.get(apiName);
        return null;
    }

    private static void mapFields(SObject record, Map<String, Object> payload, Schema.SObjectType targetType) {
        Map<String, Object> fieldsToMap = payload.clone();
        
        Set<String> metadataKeys = new Set<String>{
            'Id', 'SourceId', 'TargetId', 'Action', 'LastModifiedBy', 'LastModifiedDate', 'direction', 'timestamp'
        };
        for(String key : metadataKeys) {
            if(fieldsToMap.containsKey(key)) fieldsToMap.remove(key);
        }

        Map<String, SObjectField> schemaFields = targetType.getDescribe().fields.getMap();

        for (String payloadKey : fieldsToMap.keySet()) {
            String lowerKey = payloadKey.toLowerCase();
            
            // Manual Aliases
            if (lowerKey == 'body') lowerKey = 'bodytxt__c';
            if (lowerKey == 'author') lowerKey = 'authortxt__c';

            SObjectField field = null;
            for(String fieldApi : schemaFields.keySet()) {
                SObjectField f = schemaFields.get(fieldApi);
                // Case-insensitive match
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
            System.debug('Mapping Error: ' + e.getMessage()); 
        }
    }
}
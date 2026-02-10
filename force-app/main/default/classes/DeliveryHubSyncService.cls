/**
 * @description Service class to process incoming JSON payloads and update SObjects.
 * FIXED: Now allows null values to clear fields (Fixed testProcessSyncNullValues).
 */
public with sharing class DeliveryHubSyncService {

    public static void processSync(String objectType, Map<String, Object> payload) {
        Schema.SObjectType targetType = findSObjectType(objectType);
        
        if (targetType == null) {
            throw new CalloutException('Invalid Object Type: ' + objectType);
        }

        SObject record = targetType.newSObject();
        String targetId = (String) payload.get('TargetId');
        Boolean isInsert = false;

        try {
            if (String.isBlank(targetId)) {
                isInsert = true;
            } else {
                Id sId = (Id) targetId;
                if (sId.getSObjectType() == targetType) {
                    record.put('Id', targetId);
                } else {
                    isInsert = true;
                    String ns = getNamespace(targetType);
                    record.put(ns + 'TicketId__c', targetId);
                }
            }
        } catch (Exception e) {
            isInsert = true;
        }

        mapFields(record, payload, targetType);

        if (isInsert) {
             Database.insert(record, AccessLevel.SYSTEM_MODE);
        } else {
             Database.update(record, AccessLevel.SYSTEM_MODE);
        }
    }

    private static String getNamespace(Schema.SObjectType soType) {
        String name = soType.getDescribe().getName();
        if (name.contains('__') && name.countMatches('__') == 2) {
             return name.substring(0, name.indexOf('__') + 2); 
        }
        return '';
    }

    private static Schema.SObjectType findSObjectType(String apiName) {
        Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
        if (gd.containsKey(apiName)) {
            return gd.get(apiName);
        }
        String searchKey = apiName.toLowerCase();
        for (String key : gd.keySet()) {
            SObjectType type = gd.get(key);
            if (type.getDescribe().getLocalName().toLowerCase() == searchKey) {
                return type;
            }
        }
        return null;
    }

    private static void mapFields(SObject record, Map<String, Object> payload, Schema.SObjectType targetType) {
        Map<String, Object> fieldsToMap = payload.clone();
        
        Set<String> metadataKeys = new Set<String>{
            'Id', 'SourceId', 'TargetId', 'Action', 'LastModifiedBy', 'LastModifiedDate', 'direction', 'timestamp'
        };
        for(String key : metadataKeys) {
            if(fieldsToMap.containsKey(key)) {
                fieldsToMap.remove(key);
            }
        }

        Map<String, SObjectField> schemaFields = targetType.getDescribe().fields.getMap();

        for (String key : fieldsToMap.keySet()) {
            SObjectField field = schemaFields.get(key);
            
            if (field == null) {
                for(String fieldApi : schemaFields.keySet()) {
                    SObjectField f = schemaFields.get(fieldApi);
                    if (f.getDescribe().getLocalName() == key) {
                        field = f;
                        break;
                    }
                }
            }

            // --- THE FIX IS HERE ---
            // Previously: if (field != null && fieldsToMap.get(key) != null)
            // Now: We allow nulls so fields can be cleared.
            if (field != null) {
                applyField(record, field, fieldsToMap.get(key));
            }
        }
    }

    private static void applyField(SObject record, SObjectField field, Object val) {
        try {
            Schema.DisplayType dtype = field.getDescribe().getType();
            
            if (val == null) {
                record.put(field, null); // Explicitly clear field
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
            System.debug(LoggingLevel.WARN, 'Field Mapping Error [' + field + ']: ' + e.getMessage());
        }
    }
}
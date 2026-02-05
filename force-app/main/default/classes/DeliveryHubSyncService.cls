public with sharing class DeliveryHubSyncService {

    public static void processSync(String objectType, Map<String, Object> payload) {
        // 1. Validate Object Type
        Schema.SObjectType targetType = Schema.getGlobalDescribe().get(objectType);
        if (targetType == null) {
            throw new CalloutException('Invalid Object Type: ' + objectType);
        }

        // 2. Prepare Record
        // We instantiate a generic SObject so this works for Tickets, Comments, anything.
        SObject recordToUpdate = targetType.newSObject();
        recordToUpdate.put('Id', (String) payload.get('TargetId'));

        // 3. Clean Payload (Remove Metadata)
        Map<String, Object> fieldsToMap = payload.clone();
        Set<String> metadataKeys = new Set<String>{
            'Id', 'SourceId', 'TargetId', 'Action', 
            'LastModifiedBy', 'LastModifiedDate'
        };
        for(String key : metadataKeys) {
            fieldsToMap.remove(key);
        }

        // 4. Map Fields Dynamically
        Map<String, SObjectField> schemaFields = targetType.getDescribe().fields.getMap();

        for (String key : fieldsToMap.keySet()) {
            if (schemaFields.containsKey(key)) {
                Object val = fieldsToMap.get(key);
                SObjectField field = schemaFields.get(key);
                Schema.DisplayType dtype = field.getDescribe().getType();
                
                // Handle Data Type Conversions (JSON is loosely typed)
                try {
                    if (val == null) {
                        recordToUpdate.put(key, null);
                    } else if (dtype == Schema.DisplayType.DATE) {
                        recordToUpdate.put(key, Date.valueOf((String)val));
                    } else if (dtype == Schema.DisplayType.DATETIME) {
                        // JSON DateTime string -> Apex DateTime
                        recordToUpdate.put(key, JSON.deserialize('"' + val + '"', DateTime.class));
                    } else if (dtype == Schema.DisplayType.PERCENT || dtype == Schema.DisplayType.CURRENCY || dtype == Schema.DisplayType.DOUBLE) {
                        recordToUpdate.put(key, Decimal.valueOf(String.valueOf(val)));
                    } else {
                        // Text, Picklist, Boolean usually work directly
                        recordToUpdate.put(key, val);
                    }
                } catch (Exception e) {
                    System.debug(LoggingLevel.WARN, 'Field Mapping Error [' + key + ']: ' + e.getMessage());
                    // We skip the failed field but continue with others
                }
            }
        }

        // 5. Commit to Database
        update recordToUpdate;
    }
}
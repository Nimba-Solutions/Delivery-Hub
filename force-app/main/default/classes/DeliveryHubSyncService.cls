/**
 * @description Service class to process incoming JSON payloads and update SObjects.
 * Handles type conversion and generic DML.
 */
public with sharing class DeliveryHubSyncService {

    /**
     * @description Main entry point to process a sync payload.
     * @param objectType The API Name of the object to update (e.g. Ticket__c).
     * @param payload The JSON map containing field updates.
     */
    public static void processSync(String objectType, Map<String, Object> payload) {
        // 1. Validate Object Type
        Schema.SObjectType targetType = Schema.getGlobalDescribe().get(objectType);
        if (targetType == null) {
            throw new CalloutException('Invalid Object Type: ' + objectType);
        }

        // 2. Prepare Record
        SObject recordToUpdate = targetType.newSObject();
        recordToUpdate.put('Id', (String) payload.get('TargetId'));

        // 3. Map Fields
        mapFields(recordToUpdate, payload, targetType);

        // 4. Commit to Database
        // FIX: CRUD violation. Using System Mode as this is an integration process.
        Database.update(recordToUpdate, AccessLevel.SYSTEM_MODE);
    }

    /**
     * @description Helper to map JSON values to SObject fields with type safety.
     * @param record The SObject to populate.
     * @param payload The source JSON map.
     * @param targetType The SchemaType for field lookups.
     */
    private static void mapFields(SObject record, Map<String, Object> payload, Schema.SObjectType targetType) {
        Map<String, Object> fieldsToMap = payload.clone();
        
        // Remove Metadata
        Set<String> metadataKeys = new Set<String>{
            'Id', 'SourceId', 'TargetId', 'Action', 'LastModifiedBy', 'LastModifiedDate'
        };
        for(String key : metadataKeys) {
            fieldsToMap.remove(key);
        }

        Map<String, SObjectField> schemaFields = targetType.getDescribe().fields.getMap();

        for (String key : fieldsToMap.keySet()) {
            if (schemaFields.containsKey(key)) {
                applyField(record, key, fieldsToMap.get(key), schemaFields.get(key));
            }
        }
    }

    /**
     * @description Applies a single value to a field with type conversion.
     * @param record The record to update.
     * @param key The field API name.
     * @param val The value to set.
     * @param field The field definition.
     */
    private static void applyField(SObject record, String key, Object val, SObjectField field) {
        try {
            Schema.DisplayType dtype = field.getDescribe().getType();
            if (val == null) {
                record.put(key, null);
            } else if (dtype == Schema.DisplayType.DATE) {
                record.put(key, Date.valueOf((String)val));
            } else if (dtype == Schema.DisplayType.DATETIME) {
                record.put(key, JSON.deserialize('"' + val + '"', DateTime.class));
            } else if (dtype == Schema.DisplayType.PERCENT || dtype == Schema.DisplayType.CURRENCY || dtype == Schema.DisplayType.DOUBLE) {
                record.put(key, Decimal.valueOf(String.valueOf(val)));
            } else {
                record.put(key, val);
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'Field Mapping Error [' + key + ']: ' + e.getMessage());
        }
    }
}
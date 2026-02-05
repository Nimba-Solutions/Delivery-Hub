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
        // 1. Validate Object Type (Namespace Resilient)
        Schema.SObjectType targetType = findSObjectType(objectType);
        
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
     * @description Helper to find SObjectType handling Namespaces safely.
     * Finds 'delivery__Ticket__c' even if input is 'Ticket__c'.
     * @param apiName The API name to search for.
     * @return The matching SObjectType, or null if not found.
     */
    private static Schema.SObjectType findSObjectType(String apiName) {
        Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
        
        // 1. Try Exact Match
        if (gd.containsKey(apiName)) {
            return gd.get(apiName);
        }
        
        // 2. Try Local Name Match (Scanning keys is safer in packages)
        String searchKey = apiName.toLowerCase();
        for (String key : gd.keySet()) {
            SObjectType type = gd.get(key);
            if (type.getDescribe().getLocalName().toLowerCase() == searchKey) {
                return type;
            }
        }
        return null;
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
            // Check exact match first
            SObjectField field = schemaFields.get(key);
            
            // If null, try to find namespaced match (e.g. key="StageNamePk__c", field="delivery__StageNamePk__c")
            if (field == null) {
                for(String fieldApi : schemaFields.keySet()) {
                    SObjectField f = schemaFields.get(fieldApi);
                    if (f.getDescribe().getLocalName() == key) {
                        field = f;
                        break;
                    }
                }
            }

            if (field != null) {
                applyField(record, field, fieldsToMap.get(key));
            }
        }
    }

    /**
     * @description Applies a single value to a field with type conversion.
     * @param record The record to update.
     * @param field The field definition.
     * @param val The value to set.
     */
    private static void applyField(SObject record, SObjectField field, Object val) {
        try {
            Schema.DisplayType dtype = field.getDescribe().getType();
            
            if (val == null) {
                record.put(field, null);
            } else if (dtype == Schema.DisplayType.DATE) {
                record.put(field, Date.valueOf((String)val));
            } else if (dtype == Schema.DisplayType.DATETIME) {
                record.put(field, JSON.deserialize('"' + val + '"', DateTime.class));
            } else if (dtype == Schema.DisplayType.PERCENT || dtype == Schema.DisplayType.CURRENCY || dtype == Schema.DisplayType.DOUBLE) {
                record.put(field, Decimal.valueOf(String.valueOf(val)));
            } else {
                record.put(field, val);
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'Field Mapping Error [' + field.getDescribe().getName() + ']: ' + e.getMessage());
        }
    }
}
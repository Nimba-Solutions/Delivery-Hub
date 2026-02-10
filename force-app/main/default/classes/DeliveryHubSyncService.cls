/**
 * @description Service class to process incoming JSON payloads and update SObjects.
 * FIXED: Handles INSERT vs UPDATE logic based on ID checks.
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
        SObject record = targetType.newSObject();
        String targetId = (String) payload.get('TargetId');
        Boolean isInsert = false;

        // --- THE FIX: Smart ID Handling ---
        try {
            Id sId = (Id) targetId;
            
            // Check if the ID provided actually matches the Object Type we are processing
            if (sId.getSObjectType() == targetType) {
                // It matches (e.g. Comment ID -> Comment Object), so it's an UPDATE
                record.put('Id', targetId);
            } else {
                // Mismatch (e.g. Ticket ID -> Comment Object), so it's a Parent ID for an INSERT
                isInsert = true;
                
                // We assume the TargetId is the Parent Ticket ID. 
                // We need to set the lookup field 'TicketId__c' (handling namespace)
                String ns = getNamespace(targetType);
                record.put(ns + 'TicketId__c', targetId);
            }
        } catch (Exception e) {
            // If ID is invalid or null, assume Insert (fallback)
            isInsert = true;
        }

        // 3. Map Fields
        mapFields(record, payload, targetType);

        // 4. Commit to Database
        if (isInsert) {
             Database.insert(record, AccessLevel.SYSTEM_MODE);
        } else {
             Database.update(record, AccessLevel.SYSTEM_MODE);
        }
    }

    // --- HELPER METHODS ---

    /**
     * @description Helper to find namespace of the found object type
     */
    private static String getNamespace(Schema.SObjectType soType) {
        String name = soType.getDescribe().getName();
        if (name.contains('__') && name.countMatches('__') == 2) {
             return name.substring(0, name.indexOf('__') + 2); // e.g. "delivery__"
        }
        return '';
    }

    private static Schema.SObjectType findSObjectType(String apiName) {
        Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
        if (gd.containsKey(apiName)) return gd.get(apiName);
        
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
        
        // Remove Metadata so we don't try to map them to fields
        Set<String> metadataKeys = new Set<String>{
            'Id', 'SourceId', 'TargetId', 'Action', 'LastModifiedBy', 'LastModifiedDate', 'direction', 'timestamp'
        };
        for(String key : metadataKeys) {
            if(fieldsToMap.containsKey(key)) fieldsToMap.remove(key);
        }

        Map<String, SObjectField> schemaFields = targetType.getDescribe().fields.getMap();

        for (String key : fieldsToMap.keySet()) {
            SObjectField field = schemaFields.get(key);
            
            // NameSpace Fallback
            if (field == null) {
                for(String fieldApi : schemaFields.keySet()) {
                    SObjectField f = schemaFields.get(fieldApi);
                    if (f.getDescribe().getLocalName() == key) {
                        field = f;
                        break;
                    }
                }
            }

            if (field != null && fieldsToMap.get(key) != null) {
                applyField(record, field, fieldsToMap.get(key));
            }
        }
    }

    private static void applyField(SObject record, SObjectField field, Object val) {
        try {
            Schema.DisplayType dtype = field.getDescribe().getType();
            if (dtype == Schema.DisplayType.DATE) {
                record.put(field, Date.valueOf((String)val));
            } else if (dtype == Schema.DisplayType.DATETIME) {
                // Handle standard JSON DateTime format
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
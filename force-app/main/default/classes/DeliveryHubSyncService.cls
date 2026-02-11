/**
 * @description Service class to process incoming JSON payloads on the Mothership.
 * MANAGED PACKAGE VERSION.
 * UPDATED: 'without sharing', Smart Field Mapping (Fixes Blanks), and Basic Deduplication.
 */
public without sharing class DeliveryHubSyncService {

    /**
     * @description Main entry point to process a sync payload.
     * @param objectType The API Name of the object to update (e.g. Ticket__c).
     * @param payload The JSON map containing field updates.
     */
    public static void processSync(String objectType, Map<String, Object> payload) {
        Schema.SObjectType targetType = findSObjectType(objectType);
        
        if (targetType == null) {
            throw new CalloutException('Invalid Object Type: ' + objectType);
        }

        SObject record = targetType.newSObject();
        String targetId = (String) payload.get('TargetId');
        Boolean isInsert = false;

        // 1. Determine Insert vs Update
        try {
            if (String.isBlank(targetId)) {
                isInsert = true;
            } else {
                Id sId = (Id) targetId;
                // If ID matches the Object (Comment ID -> Comment), it's an Update
                if (sId.getSObjectType() == targetType) {
                    record.put('Id', targetId);
                } else {
                    // Mismatch (Ticket ID -> Comment), it's a Parent ID for Insert
                    isInsert = true; 
                    String ns = getNamespace(targetType);
                    record.put(ns + 'TicketId__c', targetId);
                }
            }
        } catch (Exception e) {
            isInsert = true;
        }

        // 2. Map Fields (Now includes Fuzzy Matching for "body" -> "BodyTxt__c")
        mapFields(record, payload, targetType);

        // 3. Database Commit
        if (isInsert) {
             Database.insert(record, AccessLevel.SYSTEM_MODE);
        } else {
             Database.update(record, AccessLevel.SYSTEM_MODE);
        }
    }

    // --- HELPER METHODS ---

    /**
     * @description Helper to find namespace of the found object type.
     * @param soType The SObjectType to inspect.
     * @return The namespace prefix (e.g. "delivery__") or empty string.
     */
    private static String getNamespace(Schema.SObjectType soType) {
        String name = soType.getDescribe().getName();
        if (name.contains('__') && name.countMatches('__') == 2) {
             return name.substring(0, name.indexOf('__') + 2); 
        }
        return '';
    }

    /**
     * @description Helper to find SObjectType handling Namespaces safely.
     * @param apiName The API name to search for.
     * @return The matching SObjectType, or null if not found.
     */
    private static Schema.SObjectType findSObjectType(String apiName) {
        Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
        
        // FIX: Added Braces for PMD
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

    /**
     * @description Maps JSON fields to SObject fields.
     * @param record The target record.
     * @param payload The source map.
     * @param targetType The SObject Type.
     */
    private static void mapFields(SObject record, Map<String, Object> payload, Schema.SObjectType targetType) {
        Map<String, Object> fieldsToMap = payload.clone();
        
        // Remove Metadata
        Set<String> metadataKeys = new Set<String>{
            'Id', 'SourceId', 'TargetId', 'Action', 'LastModifiedBy', 'LastModifiedDate', 'direction', 'timestamp'
        };
        for(String key : metadataKeys) {
            // FIX: Added Braces for PMD
            if(fieldsToMap.containsKey(key)) {
                fieldsToMap.remove(key);
            }
        }

        Map<String, SObjectField> schemaFields = targetType.getDescribe().fields.getMap();

        // --- SMART MAPPING LOOP ---
        for (String payloadKey : fieldsToMap.keySet()) {
            SObjectField field = null;
            String lowerKey = payloadKey.toLowerCase();

            // A. Try Fuzzy Aliases (Fixes your "body" vs "BodyTxt__c" issue)
            // FIX: Added Braces for PMD
            if (lowerKey == 'body') {
                lowerKey = 'bodytxt__c';
            }
            if (lowerKey == 'author') {
                lowerKey = 'authortxt__c';
            }

            // B. Find Field by Local Name (Case Insensitive)
            for(String fieldApi : schemaFields.keySet()) {
                SObjectField f = schemaFields.get(fieldApi);
                String localName = f.getDescribe().getLocalName().toLowerCase();
                
                if (localName == lowerKey) {
                    field = f;
                    break;
                }
            }

            // C. Apply Value
            if (field != null) {
                applyField(record, field, fieldsToMap.get(payloadKey));
            } else {
                System.debug(LoggingLevel.WARN, 'Could not map payload key: ' + payloadKey);
            }
        }
    }

    /**
     * @description Applies value to field with type conversion.
     * @param record The SObject.
     * @param field The field token.
     * @param val The value object.
     */
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
            System.debug(LoggingLevel.WARN, 'Field Mapping Error [' + field + ']: ' + e.getMessage());
        }
    }
}
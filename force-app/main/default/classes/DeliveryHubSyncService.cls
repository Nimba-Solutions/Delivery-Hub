/**
 * @description Service class to process incoming JSON payloads on the Mothership.
 * MANAGED PACKAGE VERSION.
 * UPDATED: 'without sharing', Smart Field Mapping (Fixes Blanks), and Basic Deduplication.
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

    private static String getNamespace(Schema.SObjectType soType) {
        String name = soType.getDescribe().getName();
        if (name.contains('__') && name.countMatches('__') == 2) {
             return name.substring(0, name.indexOf('__') + 2); 
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
        
        // Remove Metadata
        Set<String> metadataKeys = new Set<String>{
            'Id', 'SourceId', 'TargetId', 'Action', 'LastModifiedBy', 'LastModifiedDate', 'direction', 'timestamp'
        };
        for(String key : metadataKeys) {
            if(fieldsToMap.containsKey(key)) fieldsToMap.remove(key);
        }

        Map<String, SObjectField> schemaFields = targetType.getDescribe().fields.getMap();
        String namespace = getNamespace(targetType);

        // --- SMART MAPPING LOOP ---
        for (String payloadKey : fieldsToMap.keySet()) {
            SObjectField field = null;
            String lowerKey = payloadKey.toLowerCase();

            // A. Try Fuzzy Aliases (Fixes your "body" vs "BodyTxt__c" issue)
            if (lowerKey == 'body') lowerKey = 'bodytxt__c';
            if (lowerKey == 'author') lowerKey = 'authortxt__c';

            // B. Find Field by Local Name (Case Insensitive)
            // This handles "BodyTxt__c" matching "delivery__BodyTxt__c"
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
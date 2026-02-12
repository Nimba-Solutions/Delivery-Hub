/**
 * @description Service class to process incoming JSON payloads.
 * Handles cross-org Ticket_Comment__c parent resolution and prevents Ping-Pong loops.
 */
public without sharing class DeliveryHubSyncService {

    @SuppressWarnings('PMD.ApexCRUDViolation')
    public static void processSync(String objectType, Map<String, Object> payload) {
        Schema.SObjectType targetType = findSObjectType(objectType);
        if (targetType == null) {
            throw new CalloutException('Invalid Object Type: ' + objectType);
        }

        // Namespace prefix for dynamic field puts (e.g., '' on Client, 'delivery__' on Mothership)
        String fns = getFieldNs();

        SObject record = targetType.newSObject();
        String targetId = (String) payload.get('TargetId');
        if (String.isBlank(targetId)) {
            targetId = (String) payload.get('targetId');
        }

        Boolean isInsert = false;

        // 1. SMART ID & PARENT LOOKUP
        // Ticket_Comment__c requires special handling because targetId is the REMOTE Ticket ID.
        if (objectType.contains('Ticket_Comment__c')) {
            isInsert = true;
            if (String.isNotBlank(targetId)) {
                // Resolve the local Ticket record ID using the Request bridge
                Id localTicketId = resolveLocalTicketId(targetId);
                record.put(fns + 'TicketId__c', localTicketId);
            }
        } else {
            try {
                if (String.isBlank(targetId)) {
                    isInsert = true;
                } else {
                    Id sId = (Id) targetId;
                    // If the ID matches our local object type, it's an update
                    if (sId.getSObjectType() == targetType) {
                        record.put('Id', targetId);
                    } else {
                        // Otherwise, treat as a new insert (common during first sync)
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
        // We tag the record so the Trigger/Sender knows this came FROM the Mothership
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

    /**
     * @description Bridges the gap between the Remote Org ID and the Local Record ID.
     */
    private static Id resolveLocalTicketId(String remoteTicketId) {
        List<Request__c> requests = [
            SELECT TicketId__c
            FROM Request__c
            WHERE RemoteTicketIdTxt__c = :remoteTicketId
            AND StatusPk__c != 'Inactive'
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        if (!requests.isEmpty()) {
            return requests[0].TicketId__c;
        }
        // Fallback: If it's already a local ID, return it
        return (Id) remoteTicketId;
    }

    private static Schema.SObjectType findSObjectType(String apiName) {
        Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
        if (gd.containsKey(apiName)) return gd.get(apiName);

        String fns = getFieldNs();
        if (String.isNotBlank(fns)) {
            String namespacedName = fns + apiName;
            if (gd.containsKey(namespacedName)) return gd.get(namespacedName);
        }
        return null;
    }

    private static void mapFields(SObject record, Map<String, Object> payload, Schema.SObjectType targetType) {
        Map<String, Object> fieldsToMap = payload.clone();
        
        // Metadata fields to ignore during field mapping
        Set<String> metadataKeys = new Set<String>{
            'Id', 'SourceId', 'TargetId', 'targetId', 'Action', 'LastModifiedBy', 'LastModifiedDate', 'direction', 'timestamp'
        };
        for(String key : metadataKeys) {
            fieldsToMap.remove(key);
        }

        Map<String, SObjectField> schemaFields = targetType.getDescribe().fields.getMap();

        for (String payloadKey : fieldsToMap.keySet()) {
            String lowerKey = payloadKey.toLowerCase();
            
            // Handle Field Aliases
            if (lowerKey == 'body') lowerKey = 'bodytxt__c';
            if (lowerKey == 'author') lowerKey = 'authortxt__c';

            SObjectField field = null;
            for(String fieldApi : schemaFields.keySet()) {
                SObjectField f = schemaFields.get(fieldApi);
                if (f.getDescribe().getLocalName().toLowerCase() == lowerKey) {
                    field = f;
                    break;
                }
            }

            if (field != null && field.getDescribe().isUpdateable()) {
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
                // ISO 8601 Date format handling
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

    /**
     * @description Sets the sync status to prevent the local trigger from 
     * re-sending this record back to the Mothership.
     */
    private static void setSyncStatus(SObject record, String fns) {
        try {
            // Attempt to set sync status for loop prevention
            record.put(fns + 'JiraSyncStatusTxt__c', 'Synced');
        } catch (Exception e) {
            // Field might not exist on all synced objects; ignore safely.
        }
    }
}
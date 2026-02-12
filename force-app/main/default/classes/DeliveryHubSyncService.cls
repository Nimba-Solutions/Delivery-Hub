/**
 * @description Service class to process incoming JSON payloads.
 * Handles cross-org Ticket_Comment__c parent resolution and prevents Ping-Pong loops.
 */
public without sharing class DeliveryHubSyncService {

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
        // For Ticket_Comment__c, targetId is ALWAYS the parent Ticket ID from
        // the Mothership, never a local comment ID. Key prefix collision between
        // orgs (a08 = Ticket__c on Mothership, Ticket_Comment__c on Client)
        // means getSObjectType() gives a false match. Always INSERT for comments.
        if (objectType.contains('Ticket_Comment__c')) {
            isInsert = true;
            if (String.isNotBlank(targetId)) {
                Id localTicketId = resolveLocalTicketId(targetId);
                record.put(fns + 'TicketId__c', localTicketId);
            }
        } else {
            try {
                if (String.isBlank(targetId)) {
                    isInsert = true;
                } else {
                    Id sId = (Id) targetId;
                    if (sId.getSObjectType() == targetType) {
                        record.put('Id', targetId);
                    } else {
                        isInsert = true;
                        record.put(fns + 'TicketId__c', targetId);
                    }
                }
            } catch (Exception e) {
                isInsert = true;
            }
        }

        // 2. MAP FIELDS
        mapFields(record, payload, targetType);

        // --- FIX 2: PREVENT PING-PONG LOOP ---
        // Mark as 'Synced' so the Trigger ignores it and doesn't send it back.
        if (objectType.contains('Ticket_Comment__c')) {
            try {
                record.put(fns + 'JiraSyncStatusTxt__c', 'Synced');
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

    // Cached namespace prefix for dynamic field puts.
    // Returns '' on Client (no namespace) or 'delivery__' on Mothership.
    private static String cachedFieldNs;
    private static String getFieldNs() {
        if (cachedFieldNs == null) {
            String ns = [SELECT NamespacePrefix FROM Organization].NamespacePrefix;
            cachedFieldNs = String.isBlank(ns) ? '' : ns + '__';
        }
        return cachedFieldNs;
    }

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
        return (Id) remoteTicketId;
    }

    private static Schema.SObjectType findSObjectType(String apiName) {
        Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
        if (gd.containsKey(apiName)) return gd.get(apiName);

        // On Mothership (managed package), getGlobalDescribe() keys include
        // the namespace prefix (e.g., 'delivery__Ticket_Comment__c').
        // The Client sends objectType without prefix, so try with namespace.
        String fns = getFieldNs();
        if (String.isNotBlank(fns)) {
            String namespacedName = fns + apiName;
            if (gd.containsKey(namespacedName)) return gd.get(namespacedName);
        }
        return null;
    }

    private static void mapFields(SObject record, Map<String, Object> payload, Schema.SObjectType targetType) {
        Map<String, Object> fieldsToMap = payload.clone();
        
        Set<String> metadataKeys = new Set<String>{
            'Id', 'SourceId', 'TargetId', 'targetId', 'Action', 'LastModifiedBy', 'LastModifiedDate', 'direction', 'timestamp'
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
/**
 * @description Logic for processing Inbound Sync Items using the "Ledger Pattern".
 * Runs in System Mode (without sharing) to bypass FLS restrictions.
 * Uses robust dynamic string stripping to eliminate Namespace issues in any org.
 */
public without sharing class DeliverySyncItemIngestor {

    private static String getNamespacePrefix() {
        String ns = [SELECT NamespacePrefix FROM Organization LIMIT 1].NamespacePrefix;
        return String.isBlank(ns) ? '' : ns + '__';
    }

    private static String stripNamespace(String apiName) {
        if (String.isNotBlank(apiName) && apiName.countMatches('__') > 1) {
            return apiName.substringAfter('__');
        }
        return apiName;
    }

    // --- FIX: Changed return type from void to Id ---
    public static Id processInboundItem(String objectType, Map<String, Object> payload) {
        SyncEngine.setSyncContext();

        Schema.SObjectType targetType = findSObjectType(objectType);
        if (targetType == null) {
            throw new IllegalArgumentException('Invalid Object Type: ' + objectType);
        }

        String sourceId = (String) payload.get('SourceId'); 
        String targetId = (String) payload.get('TargetId'); 
        
        Id localRecordId = findLocalId(targetType, sourceId);
        
        // --- FIX 1: HUB TICKET UPDATES ---
        if (localRecordId == null && String.isNotBlank(targetId) && objectType.endsWithIgnoreCase('Ticket__c') && !objectType.endsWithIgnoreCase('Ticket_Comment__c')) {
            try {
                Id castId = (Id) targetId;
                if (castId.getSobjectType() == targetType) {
                    localRecordId = castId;
                }
            } catch (Exception e) {
                System.debug(LoggingLevel.FINE, 'TargetId is not a valid local ID: ' + e.getMessage());
            }
        }

        SObject recordToUpsert = (localRecordId != null) ? targetType.newSObject(localRecordId) : targetType.newSObject();
        
        // --- FIX 2: PARENTING FOR COMMENTS AND FILES ---
        Id localParentId = null;
        if (localRecordId == null && String.isNotBlank(targetId) && (objectType.containsIgnoreCase('Ticket_Comment__c') || objectType.equalsIgnoreCase('ContentVersion'))) {
            
            localParentId = findLocalTicketId(targetId);

            if (localParentId == null) {
                try {
                    Id castId = (Id) targetId;
                    if (castId.getSobjectType().getDescribe().getName().endsWithIgnoreCase('Ticket__c')) {
                        String query = 'SELECT Id FROM ' + castId.getSobjectType().getDescribe().getName() + ' WHERE Id = \'' + castId + '\' LIMIT 1';
                        if (!Database.query(query).isEmpty()) {
                            localParentId = castId;
                        }
                    }
                } catch (Exception e) {
                    System.debug(LoggingLevel.FINE, 'TargetId fallback failed: ' + e.getMessage());
                }
            }

            if (localParentId != null && objectType.containsIgnoreCase('Ticket_Comment__c')) {
                putSafe(recordToUpsert, 'TicketId__c', localParentId);
            }
        }

        mapFields(recordToUpsert, payload, targetType);
        
        // --- NEW FIX: Check if SourcePk__c exists before setting it ---
        if (hasField(targetType, 'SourcePk__c')) {
            putSafe(recordToUpsert, 'SourcePk__c', 'Vendor'); 
        }

        // Execute DML in System Mode
        if (recordToUpsert.Id != null) {
            Database.update(recordToUpsert, AccessLevel.SYSTEM_MODE);
        } else {
            Database.insert(recordToUpsert, AccessLevel.SYSTEM_MODE);
            createLedgerEntry(objectType, sourceId, recordToUpsert.Id);
            
            // --- FIX 3: ATTACH FILES TO TICKETS ---
            if (objectType.equalsIgnoreCase('ContentVersion') && localParentId != null) {
                Id contentDocId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :recordToUpsert.Id LIMIT 1].ContentDocumentId;
                ContentDocumentLink cdl = new ContentDocumentLink(
                    ContentDocumentId = contentDocId,
                    LinkedEntityId = localParentId,
                    ShareType = 'V',
                    Visibility = 'AllUsers'
                );
                Database.insert(cdl, AccessLevel.SYSTEM_MODE);
            }
            
            if (objectType.endsWithIgnoreCase('Ticket__c') && !objectType.endsWithIgnoreCase('Ticket_Comment__c')) {
                String ns = getNamespacePrefix();
                String query = 'SELECT Id FROM ' + ns + 'Request__c WHERE ' + ns + 'TicketId__c = \'' + recordToUpsert.Id + '\'';
                List<SObject> existingReqs = Database.query(query);
                
                if (!existingReqs.isEmpty()) {
                    for (SObject req : existingReqs) {
                        req.put(ns + 'RemoteTicketIdTxt__c', sourceId); 
                    }
                    Database.update(existingReqs, AccessLevel.SYSTEM_MODE);
                }
            }
        }
        
        // --- FIX: Return the newly inserted/updated ID back to the caller ---
        return recordToUpsert.Id;
    }

    // --- HELPERS ---

    private static Boolean hasField(Schema.SObjectType type, String fieldName) {
        Map<String, SObjectField> fieldMap = type.getDescribe().fields.getMap();
        String target = stripNamespace(fieldName).toLowerCase();
        for (String fieldApi : fieldMap.keySet()) {
            if (stripNamespace(fieldApi).toLowerCase() == target) {
                return true;
            }
        }
        return false;
    }

    private static Id findLocalId(Schema.SObjectType type, String remoteId) {
        String objName = type.getDescribe().getName();
        
        if (objName.endsWith('Ticket__c') && !objName.endsWith('Ticket_Comment__c')) {
            List<Request__c> reqs = [SELECT TicketId__c FROM Request__c WHERE RemoteTicketIdTxt__c = :remoteId WITH SYSTEM_MODE LIMIT 1];
            return reqs.isEmpty() ? null : reqs[0].TicketId__c;
        } else {
            String cleanName = stripNamespace(objName);
            List<Sync_Item__c> ledger = [SELECT LocalRecordIdTxt__c FROM Sync_Item__c WHERE RemoteExternalIdTxt__c = :remoteId AND ObjectTypePk__c = :cleanName WITH SYSTEM_MODE LIMIT 1];
            return ledger.isEmpty() ? null : (Id)ledger[0].LocalRecordIdTxt__c;
        }
    }

    private static Id findLocalTicketId(String remoteTicketId) {
        List<Request__c> reqs = [SELECT TicketId__c FROM Request__c WHERE RemoteTicketIdTxt__c = :remoteTicketId WITH SYSTEM_MODE LIMIT 1];
        return reqs.isEmpty() ? null : reqs[0].TicketId__c;
    }

    private static void createLedgerEntry(String objType, String remoteId, Id localId) {
        Sync_Item__c item = new Sync_Item__c();
        item.DirectionPk__c = 'Inbound';
        item.StatusPk__c = 'Synced';
        item.ObjectTypePk__c = stripNamespace(objType);
        item.RemoteExternalIdTxt__c = remoteId;
        item.LocalRecordIdTxt__c = (String)localId;
        item.PayloadTxt__c = 'Ledger Mapping Created';
        Database.insert(item, AccessLevel.SYSTEM_MODE);
    }

    private static void mapFields(SObject record, Map<String, Object> payload, Schema.SObjectType type) {
        Map<String, SObjectField> fieldMap = type.getDescribe().fields.getMap();
        
        Map<String, SObjectField> cleanNameIndex = new Map<String, SObjectField>();
        for (String fieldApi : fieldMap.keySet()) {
            String clean = stripNamespace(fieldApi).toLowerCase();
            cleanNameIndex.put(clean, fieldMap.get(fieldApi));
        }

        for (String key : payload.keySet()) {
            if (key == 'SourceId' || key == 'TargetId') {
                continue;
            }

            String searchKey = stripNamespace(key).toLowerCase(); 
            if (cleanNameIndex.containsKey(searchKey)) {
                SObjectField field = cleanNameIndex.get(searchKey);
                Object val = payload.get(key);
                Schema.DisplayType dtype = field.getDescribe().getType();
                
                if (val != null) {
                    if (dtype == Schema.DisplayType.DATE) {
                        record.put(field, Date.valueOf((String)val));
                    } else if (dtype == Schema.DisplayType.DATETIME) {
                        record.put(field, (DateTime)JSON.deserialize('"' + val + '"', DateTime.class));
                    } else if (dtype == Schema.DisplayType.BASE64) {
                        record.put(field, EncodingUtil.base64Decode((String)val));
                    } else {
                        record.put(field, val);
                    }
                } else {
                    if (field.getDescribe().isNillable() && field.getDescribe().isCustom()) {
                        record.put(field, null);
                    }
                }
            }
        }
    }

    private static void putSafe(SObject rec, String fieldName, Object val) {
        Map<String, SObjectField> fieldMap = rec.getSObjectType().getDescribe().fields.getMap();
        String target = stripNamespace(fieldName).toLowerCase();

        for (String fieldApi : fieldMap.keySet()) {
            if (stripNamespace(fieldApi).toLowerCase() == target) {
                rec.put(fieldMap.get(fieldApi), val);
                return;
            }
        }
    }

    private static Schema.SObjectType findSObjectType(String apiName) {
        Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
        
        // --- FAST PATH: Try an exact match first! (Case-insensitive) ---
        if (gd.containsKey(apiName)) {
            return gd.get(apiName);
        }
        
        // --- FALLBACK: If not found (e.g. namespace issues), do the loop ---
        String target = stripNamespace(apiName).toLowerCase();
        for (String key : gd.keySet()) {
            if (stripNamespace(key).toLowerCase() == target) {
                return gd.get(key);
            }
        }
        return null;
    }
}
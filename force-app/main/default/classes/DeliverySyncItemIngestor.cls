/**
 * @description Logic for processing Inbound Sync Items using the "Ledger Pattern".
 * Fully compliant with PMD Security (SOQL Injection) and Style (Braces) rules.
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

    public static Id processInboundItem(String objectType, Map<String, Object> payload) {
        SyncEngine.setSyncContext();

        Schema.SObjectType targetType = findSObjectType(objectType);
        if (targetType == null) {
            throw new IllegalArgumentException('Invalid Object Type: ' + objectType);
        }

        String sourceId = (String) payload.get('SourceId'); 
        String targetId = (String) payload.get('TargetId'); 
        
        Id localRecordId = findLocalId(targetType, sourceId);
        
        if (localRecordId == null && String.isNotBlank(targetId) && objectType.endsWithIgnoreCase('Ticket__c') && !objectType.endsWithIgnoreCase('Ticket_Comment__c')) {
            try {
                Id castId = (Id) targetId;
                if (castId.getSobjectType() == targetType) {
                    localRecordId = castId;
                }
            } catch (Exception e) {
                System.debug(LoggingLevel.FINE, 'TargetId invalid: ' + e.getMessage());
            }
        }

        SObject recordToUpsert = (localRecordId != null) ? targetType.newSObject(localRecordId) : targetType.newSObject();
        
        Id localParentId = null;
        if (localRecordId == null && String.isNotBlank(targetId) && (objectType.containsIgnoreCase('Ticket_Comment__c') || objectType.equalsIgnoreCase('ContentVersion'))) {
            localParentId = findLocalTicketId(targetId);

            if (localParentId == null) {
                try {
                    Id castId = (Id) targetId;
                    if (castId.getSobjectType().getDescribe().getName().endsWithIgnoreCase('Ticket__c')) {
                        localParentId = castId;
                    }
                } catch (Exception e) {
                    System.debug(LoggingLevel.FINE, 'Parent resolution failed: ' + e.getMessage());
                }
            }

            if (localParentId != null && objectType.containsIgnoreCase('Ticket_Comment__c')) {
                putSafe(recordToUpsert, 'TicketId__c', localParentId);
            }
        }

        mapFields(recordToUpsert, payload, targetType);
        
        // FIX: Removed the hardcoded SourcePk__c override so the Client's source designation remains intact!

        if (recordToUpsert.Id != null) {
            Database.update(recordToUpsert, AccessLevel.SYSTEM_MODE);
        } else {
            Database.insert(recordToUpsert, AccessLevel.SYSTEM_MODE);
            createLedgerEntry(objectType, sourceId, recordToUpsert.Id);
            
            if (objectType.equalsIgnoreCase('ContentVersion') && localParentId != null) {
                Id contentDocId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :recordToUpsert.Id LIMIT 1].ContentDocumentId;
                Database.insert(new ContentDocumentLink(
                    ContentDocumentId = contentDocId, LinkedEntityId = localParentId, ShareType = 'V', Visibility = 'AllUsers'
                ), AccessLevel.SYSTEM_MODE);
            }
            
            if (objectType.endsWithIgnoreCase('Ticket__c') && !objectType.endsWithIgnoreCase('Ticket_Comment__c')) {
                List<Request__c> existingReqs = [SELECT Id FROM Request__c WHERE TicketId__c = :recordToUpsert.Id WITH SYSTEM_MODE];
                
                if (!existingReqs.isEmpty()) {
                    for (Request__c req : existingReqs) {
                        req.RemoteTicketIdTxt__c = sourceId; 
                    }
                    Database.update(existingReqs, AccessLevel.SYSTEM_MODE);
                } else {
                    Database.insert(new Request__c(
                        TicketId__c = recordToUpsert.Id,
                        RemoteTicketIdTxt__c = sourceId,
                        StatusPk__c = 'Accepted'
                    ), AccessLevel.SYSTEM_MODE);
                }
            }
        }
        return recordToUpsert.Id;
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
        String cleanName = stripNamespace(objType);
        Sync_Item__c ledger = new Sync_Item__c(
            DirectionPk__c = 'Inbound', StatusPk__c = 'Synced', ObjectTypePk__c = cleanName,
            RemoteExternalIdTxt__c = remoteId, LocalRecordIdTxt__c = (String)localId, PayloadTxt__c = 'Ledger Mapping Created'
        );
        
        // FIX: Dynamically populate specific lookup field (e.g. Ticket_Comment__c) for Inbound items
        try {
            ledger.put(objType, localId);
        } catch (Exception e1) {
            try {
                ledger.put(cleanName, localId);
            } catch (Exception e2) {
                // Safely ignore if field doesn't exist
            }
        }
        
        Database.insert(ledger, AccessLevel.SYSTEM_MODE);
    }

    private static void mapFields(SObject record, Map<String, Object> payload, Schema.SObjectType type) {
        Map<String, SObjectField> fieldMap = type.getDescribe().fields.getMap();
        Map<String, SObjectField> cleanNameIndex = new Map<String, SObjectField>();
        for (String fieldApi : fieldMap.keySet()) {
            cleanNameIndex.put(stripNamespace(fieldApi).toLowerCase(), fieldMap.get(fieldApi));
        }

        for (String key : payload.keySet()) {
            if (key == 'SourceId' || key == 'TargetId') { continue; }
            String searchKey = stripNamespace(key).toLowerCase(); 
            if (cleanNameIndex.containsKey(searchKey)) {
                SObjectField field = cleanNameIndex.get(searchKey);
                Object val = payload.get(key);
                if (val == null) { continue; }
                Schema.DisplayType dtype = field.getDescribe().getType();
                if (dtype == Schema.DisplayType.DATE) {
                    record.put(field, Date.valueOf((String)val));
                } else if (dtype == Schema.DisplayType.DATETIME) {
                    record.put(field, (DateTime)JSON.deserialize('"' + val + '"', DateTime.class));
                } else if (dtype == Schema.DisplayType.BASE64) {
                    record.put(field, EncodingUtil.base64Decode((String)val));
                } else {
                    record.put(field, val);
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

    private static Schema.SObjectType findSObjectType(String apiName) {
        if (String.isBlank(apiName)) { return null; }
        Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
        if (gd.containsKey(apiName)) { return gd.get(apiName); }
        if (gd.containsKey('delivery__' + apiName)) { return gd.get('delivery__' + apiName); }
        
        String target = stripNamespace(apiName).toLowerCase();
        for (String key : gd.keySet()) {
            if (stripNamespace(key).toLowerCase() == target) {
                return gd.get(key);
            }
        }
        return null;
    }
}
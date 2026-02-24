/**
 * @description Handler for ContentDocumentLinkTrigger.
 * Evaluates files attached to Tickets and creates Outbound Ledger entries (Sync_Item__c)
 * feeding them into the Unified Sync Architecture.
 */
@SuppressWarnings('PMD.ApexCRUDViolation')
public without sharing class DeliveryContentDocumentLinkTriggerHandler {

    public static void handleAfterInsert(List<ContentDocumentLink> newLinks) {
        
        // ==========================================
        // ECHO SUPPRESSION: Abort if Downloading
        // ==========================================
        if (DeliverySyncEngine.isSyncContext) {
            System.debug(LoggingLevel.INFO, 'CDLTrigger: Sync Context active. Suppressing outbound file echo.');
            return;
        }

        // --- DELIVERY HUB UNIFIED LEDGER ---
        Map<Id, Id> docToTicketMap = new Map<Id, Id>();

        for (ContentDocumentLink cdl : newLinks) {
            if (cdl.LinkedEntityId != null) {
                String sObjName = cdl.LinkedEntityId.getSObjectType().getDescribe().getName();
                if (sObjName.endsWithIgnoreCase('Ticket__c')) {
                    docToTicketMap.put(cdl.ContentDocumentId, cdl.LinkedEntityId);
                }
            }
        }

        if (docToTicketMap.isEmpty()) {
            return;
        }

        // 3. Query the actual File Data
        List<ContentVersion> cvs = [
            SELECT Id, ContentDocumentId, Title, VersionData, PathOnClient, FileExtension, FileType
            FROM ContentVersion
            WHERE ContentDocumentId IN :docToTicketMap.keySet()
            AND IsLatest = true
            WITH SYSTEM_MODE
        ];

        if (cvs.isEmpty()) {
            return;
        }

        // 4. Query Routes (Request__c Bridge) exactly like DeliverySyncEngine
        Set<Id> ticketIds = new Set<Id>(docToTicketMap.values());
        List<Request__c> connections = [
            SELECT Id, TicketId__c, RemoteTicketIdTxt__c, DeliveryEntityId__c 
            FROM Request__c 
            WHERE TicketId__c IN :ticketIds AND StatusPk__c != 'Inactive'
            WITH SYSTEM_MODE
        ];

        Map<Id, List<Request__c>> routes = new Map<Id, List<Request__c>>();
        for (Request__c r : connections) {
            Id tId = (Id) r.get('TicketId__c'); // Dynamic get for namespace safety
            if (!routes.containsKey(tId)) {
                routes.put(tId, new List<Request__c>());
            }
            routes.get(tId).add(r);
        }

        // 5. Generate Sync_Item__c Payloads
        List<Sync_Item__c> itemsToInsert = new List<Sync_Item__c>();

        for (ContentVersion cv : cvs) {
            Id tId = docToTicketMap.get(cv.ContentDocumentId);
            List<Request__c> reqs = routes.get(tId);

            // Build base payload
            Map<String, Object> payload = new Map<String, Object>();
            payload.put('Title', cv.Title);
            payload.put('PathOnClient', cv.PathOnClient);
            payload.put('SourceId', cv.Id); 
            
            // ARCHITECTURE WARNING: Long Text Area limits are ~131k characters. 
            if (cv.VersionData != null) {
                payload.put('VersionData', EncodingUtil.base64Encode(cv.VersionData));
            }

            if (reqs != null && !reqs.isEmpty()) {
                Boolean routed = false;
                // PUSH MODEL (Client Side): Generate routed items
                for (Request__c req : reqs) {
                    String remoteId = (String) req.get('RemoteTicketIdTxt__c');
                    if (String.isNotBlank(remoteId)) {
                        itemsToInsert.add(createFileItem(cv, tId, req.Id, remoteId, payload));
                        routed = true;
                    }
                }
                
                // HUB MODEL (Vendor Hub): Fallback if routes exist but are blank
                if (!routed) {
                    itemsToInsert.add(createFileItem(cv, tId, null, tId, payload));
                }
            } else {
                // HUB MODEL (Vendor Hub): No routes exist, create passive unrouted item
                itemsToInsert.add(createFileItem(cv, tId, null, tId, payload));
            }
        }

        // 6. Execute DML and Enqueue Processor
        if (!itemsToInsert.isEmpty()) {
            Database.insert(itemsToInsert, AccessLevel.SYSTEM_MODE);
            
            if (!System.isQueueable() && !System.isFuture()) {
                Integer maxJobs = Test.isRunningTest() ? 1 : Limits.getLimitQueueableJobs();
                if (Limits.getQueueableJobs() < maxJobs) {
                    System.enqueueJob(new DeliverySyncItemProcessor());
                }
            }
        }
    }

    private static Sync_Item__c createFileItem(ContentVersion cv, Id ticketId, Id reqId, String targetId, Map<String, Object> basePayload) {
        Sync_Item__c item = new Sync_Item__c(StatusPk__c = 'Queued', DirectionPk__c = 'Outbound');
        item.LocalRecordIdTxt__c = cv.Id;
        item.TicketId__c = ticketId;
        item.RequestId__c = reqId;
        item.ObjectTypePk__c = 'ContentVersion';
        
        // FIX: Inject Global Traceability to prevent downstream loop failures
        item.GlobalSourceIdTxt__c = cv.Id; 
        
        Map<String, Object> payload = basePayload.clone();
        payload.put('TargetId', targetId);
        payload.put('GlobalSourceId', cv.Id);
        payload.put('SenderOrgId', UserInfo.getOrganizationId());
        
        item.PayloadTxt__c = JSON.serialize(payload);
        return item;
    }
}
/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Handler for ContentDocumentLinkTrigger.
 * Evaluates files attached to Work Items and creates Outbound Ledger entries (SyncItem__c)
 * feeding them into the Unified Sync Architecture.
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.ApexCRUDViolation, PMD.CyclomaticComplexity, PMD.StdCyclomaticComplexity')
public without sharing class DeliveryContentDocLinkTriggerHandler {

    /**
     * @description Evaluates ContentDocumentLink records inserted on Work Items,
     *              resolves sync routes, and creates outbound SyncItem__c ledger entries.
     * @param newLinks List of newly inserted ContentDocumentLink records
     */
    @SuppressWarnings('PMD.NcssMethodCount')
    public static void handleAfterInsert(List<ContentDocumentLink> newLinks) {
        
        // ==========================================
        // ECHO SUPPRESSION: Abort if Downloading
        // ==========================================
        if (DeliverySyncEngine.isSyncContext) {
            System.debug(LoggingLevel.INFO, 'CDLTrigger: Sync Context active. Suppressing outbound file echo.');
            return;
        }

        // --- DELIVERY HUB UNIFIED LEDGER ---
        Map<Id, Id> docToWorkItemMap = new Map<Id, Id>();

        for (ContentDocumentLink cdl : newLinks) {
            if (cdl.LinkedEntityId != null) {
                String sObjName = cdl.LinkedEntityId.getSObjectType().getDescribe().getName();
                if (sObjName.endsWithIgnoreCase('WorkItem__c')) {
                    docToWorkItemMap.put(cdl.ContentDocumentId, cdl.LinkedEntityId);
                }
            }
        }

        if (docToWorkItemMap.isEmpty()) {
            return;
        }

        // 3. Query the actual File Data
        List<ContentVersion> cvs = [
            SELECT Id, ContentDocumentId, Title, VersionData, PathOnClient, FileExtension, FileType
            FROM ContentVersion
            WHERE ContentDocumentId IN :docToWorkItemMap.keySet()
            AND IsLatest = true
            WITH SYSTEM_MODE
        ];

        if (cvs.isEmpty()) {
            return;
        }

        // 4. Query Routes (WorkRequest__c Bridge) exactly like DeliverySyncEngine
        Set<Id> workItemIds = new Set<Id>(docToWorkItemMap.values());
        List<WorkRequest__c> connections = [
            SELECT Id, WorkItemId__c, RemoteWorkItemIdTxt__c, DeliveryEntityId__c 
            FROM WorkRequest__c 
            WHERE WorkItemId__c IN :workItemIds AND StatusPk__c != 'Inactive'
            WITH SYSTEM_MODE
        ];

        Map<Id, List<WorkRequest__c>> routes = new Map<Id, List<WorkRequest__c>>();
        for (WorkRequest__c r : connections) {
            Id tId = (Id) r.get('WorkItemId__c'); // Dynamic get for namespace safety
            if (!routes.containsKey(tId)) {
                routes.put(tId, new List<WorkRequest__c>());
            }
            routes.get(tId).add(r);
        }

        // 5. Generate SyncItem__c Payloads
        List<SyncItem__c> itemsToInsert = new List<SyncItem__c>();

        for (ContentVersion cv : cvs) {
            Id tId = docToWorkItemMap.get(cv.ContentDocumentId);
            List<WorkRequest__c> reqs = routes.get(tId);

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
                for (WorkRequest__c req : reqs) {
                    String remoteId = (String) req.get('RemoteWorkItemIdTxt__c');
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

    /**
     * @description Constructs a SyncItem__c record for an outbound file sync payload.
     * @param cv The ContentVersion record for the file
     * @param workItemId The parent Work Item Id
     * @param reqId The WorkRequest Id (nullable for hub model)
     * @param targetId The target identifier for routing
     * @param basePayload Base payload map to clone and enrich
     * @return A fully populated SyncItem__c record ready for insert
     */
    @SuppressWarnings('PMD.ExcessiveParameterList')
    private static SyncItem__c createFileItem(ContentVersion cv, Id workItemId, Id reqId, String targetId, Map<String, Object> basePayload) {
        SyncItem__c item = new SyncItem__c(StatusPk__c = 'Queued', DirectionPk__c = 'Outbound');
        item.LocalRecordIdTxt__c = cv.Id;
        item.WorkItemId__c = workItemId;
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
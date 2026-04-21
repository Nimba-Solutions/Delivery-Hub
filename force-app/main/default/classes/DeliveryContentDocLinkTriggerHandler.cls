/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Handler for ContentDocumentLinkTrigger.
 * Evaluates files attached to Work Items and creates Outbound Ledger entries (SyncItem__c)
 * feeding them into the Unified Sync Architecture.
 *
 * CROSS-ORG FILE BYTE TRANSPORT — metadata-only pattern (2026-04-21 rewrite):
 *   Prior behavior inlined base64(VersionData) into SyncItem__c.PayloadTxt__c, a
 *   Long Text Area field with a 131,072 character cap. Base64 expansion (4/3) +
 *   envelope overhead made anything ~95 KB+ fail DML with STRING_TOO_LONG. The
 *   previous band-aid (PR #672) silently skipped VersionData over a 90,000 char
 *   encoded threshold — the receiver never saw the bytes.
 *
 *   Current behavior emits a metadata-only payload: title, size, sha256 (when
 *   bytes are cheaply digestible), source ContentVersion Id, and a transport
 *   marker. The receiver sees FileTransport=pull-callout and issues an
 *   authenticated HTTP callout back to the source org's /delivery/fileBytes
 *   REST endpoint to fetch the actual bytes on demand. This is the standard
 *   metadata + binary-by-reference pattern. See DeliveryFileBytesResource and
 *   DeliveryFileBytesFetcher.
 *
 *   Future ceiling: Winter '26 API v65 introduces an Http pattern that can
 *   stream ContentVersion bytes without loading them into Apex heap, raising
 *   the per-file ceiling from 12 MB (async heap) to ~16 MB. This org is still
 *   on API v61 (see sfdx-project.json / cumulusci.yml). Upgrade path is
 *   documented at https://developer.salesforce.com/blogs/2025/09/winter26-developers.
 *
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.ApexCRUDViolation, PMD.CyclomaticComplexity, PMD.StdCyclomaticComplexity')
public without sharing class DeliveryContentDocLinkTriggerHandler {

    /**
     * @description Maximum ContentVersion size (in bytes) for which we will
     *              compute a SHA-256 in the trigger synchronously. Sync Apex
     *              heap is 6 MB; we stay well under to leave room for the
     *              trigger's other work. Files above this threshold ship with
     *              Sha256=null and Oversized=true so the receiver can choose
     *              to either skip verification or defer to a post-insert job.
     */
    @TestVisible
    private static final Integer MAX_SYNC_HASH_BYTES = 4000000;

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
            SELECT Id, ContentDocumentId, Title, VersionData, PathOnClient,
                   FileExtension, FileType, ContentSize
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
            SELECT Id, WorkItemId__c, RemoteWorkItemIdTxt__c, DeliveryEntityLookup__c
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

        // 5. Generate SyncItem__c Payloads — metadata only, bytes via pull callout.
        List<SyncItem__c> itemsToInsert = new List<SyncItem__c>();

        for (ContentVersion cv : cvs) {
            Id tId = docToWorkItemMap.get(cv.ContentDocumentId);
            List<WorkRequest__c> reqs = routes.get(tId);

            // Build metadata-only payload. No VersionData key — the receiver
            // issues an authenticated callout to /delivery/fileBytes to fetch
            // the actual bytes after it sees FileTransport=pull-callout.
            Map<String, Object> payload = new Map<String, Object>();
            payload.put('Title', cv.Title);
            payload.put('PathOnClient', cv.PathOnClient);
            payload.put('SourceId', cv.Id);
            payload.put('ContentDocumentId', cv.ContentDocumentId);
            payload.put('FileExtension', cv.FileExtension);
            payload.put('FileType', cv.FileType);
            payload.put('ContentSize', cv.ContentSize);
            payload.put('FileTransport', 'pull-callout');

            // Cheap integrity hash when the file is small enough to digest
            // synchronously without blowing the 6 MB sync heap. Larger files
            // are flagged Oversized=true and ship without a sha256 — the
            // receiver MAY verify sha256 post-fetch but does not require it.
            Boolean oversized = cv.ContentSize != null && cv.ContentSize > MAX_SYNC_HASH_BYTES;
            if (!oversized && cv.VersionData != null) {
                Blob digest = Crypto.generateDigest('SHA-256', cv.VersionData);
                payload.put('Sha256', EncodingUtil.convertToHex(digest));
            } else {
                payload.put('Sha256', null);
                if (oversized) {
                    payload.put('Oversized', true);
                }
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
        item.WorkItemLookup__c = workItemId;
        item.RequestLookup__c = reqId;
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

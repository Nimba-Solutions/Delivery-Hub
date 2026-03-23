/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Queueable reconciliation engine that detects sync drift between orgs.
 * Scans all active downstream connections (Vendor/Both entities) and verifies that every
 * WorkItem and WorkLog has a corresponding outbound SyncItem. Missing items are created
 * as Queued SyncItems and fed into DeliverySyncItemProcessor for delivery.
 * Designed to be self-healing: runs daily via DeliveryHubScheduler or on-demand via
 * anonymous Apex (DeliverySyncReconciler.reconcileAll()).
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.CyclomaticComplexity, PMD.StdCyclomaticComplexity, PMD.NcssMethodCount, PMD.AvoidGlobalModifier')
global without sharing class DeliverySyncReconciler implements Queueable, Database.AllowsCallouts {

    /** @description Index into the list of entities to process (supports chaining). */
    private Integer entityIndex;

    /** @description Maximum SyncItems to insert per execution to stay within governor limits. */
    private static final Integer BATCH_LIMIT = 200;

    /** @description The full set of WorkItem fields that the reconciler syncs downstream. */
    private static final Set<String> WORK_ITEM_SYNC_FIELDS = new Set<String>{
        'BriefDescriptionTxt__c', 'DetailsTxt__c', 'StageNamePk__c', 'StatusPk__c',
        'PriorityPk__c', 'DeveloperDaysSizeNumber__c', 'EstimatedHoursNumber__c',
        'ClientPreApprovedHoursNumber__c', 'Developer__c', 'CalculatedETADate__c',
        'ProjectedUATReadyDate__c', 'AcceptanceCriteriaTxt__c', 'StepsToReproduceTxt__c',
        'ClientIntentionPk__c', 'RequestTypePk__c', 'Tags__c', 'WorkflowTypeTxt__c',
        'Epic__c', 'SLATargetDate__c', 'IsActiveBool__c', 'SortOrderNumber__c'
    };

    /**
     * @description Constructs a new reconciler starting from the first entity.
     */
    global DeliverySyncReconciler() {
        this.entityIndex = 0;
    }

    /**
     * @description Constructs a new reconciler starting from a specific entity index.
     * @param startIndex The zero-based index into the entity list to resume from.
     */
    global DeliverySyncReconciler(Integer startIndex) {
        this.entityIndex = startIndex;
    }

    /**
     * @description Convenience method to enqueue a full reconciliation run.
     * Callable from anonymous Apex: delivery.DeliverySyncReconciler.reconcileAll();
     */
    global static void reconcileAll() {
        System.enqueueJob(new DeliverySyncReconciler());
    }

    /**
     * @description Queueable execute method. Processes one entity at a time, creating
     * missing SyncItems for WorkItems and WorkLogs, then chains to the next entity.
     * @param context The QueueableContext provided by the Apex runtime.
     */
    @SuppressWarnings('PMD.ApexCRUDViolation')
    global void execute(QueueableContext context) {
        try {
            // 1. Query all connected downstream entities
            List<NetworkEntity__c> entities = [
                SELECT Id, Name, IntegrationEndpointUrlTxt__c
                FROM NetworkEntity__c
                WHERE EntityTypePk__c IN ('Vendor', 'Both')
                AND ConnectionStatusPk__c = 'Connected'
                AND IntegrationEndpointUrlTxt__c != NULL
                WITH SYSTEM_MODE
                ORDER BY Id
            ];

            if (entities.isEmpty() || entityIndex >= entities.size()) {
                return;
            }

            NetworkEntity__c entity = entities[entityIndex];
            List<SyncItem__c> itemsToInsert = new List<SyncItem__c>();

            // 2. Find all active WorkRequests linked to this entity
            List<WorkRequest__c> requests = [
                SELECT Id, WorkItemId__c, RemoteWorkItemIdTxt__c
                FROM WorkRequest__c
                WHERE DeliveryEntityId__c = :entity.Id
                AND StatusPk__c != 'Inactive'
                WITH SYSTEM_MODE
            ];

            if (!requests.isEmpty()) {
                // 3. Collect IDs for bulk queries
                Set<Id> requestIds = new Set<Id>();
                Set<Id> workItemIds = new Set<Id>();
                Map<Id, WorkRequest__c> workItemToRequest = new Map<Id, WorkRequest__c>();

                for (WorkRequest__c req : requests) {
                    requestIds.add(req.Id);
                    if (req.WorkItemId__c != null) {
                        workItemIds.add(req.WorkItemId__c);
                        workItemToRequest.put(req.WorkItemId__c, req);
                    }
                }

                // 4. Find which requests already have a Synced outbound WorkItem SyncItem
                Set<Id> coveredRequestIds = new Set<Id>();
                for (SyncItem__c existing : [
                    SELECT RequestId__c
                    FROM SyncItem__c
                    WHERE RequestId__c IN :requestIds
                    AND ObjectTypePk__c = 'WorkItem__c'
                    AND DirectionPk__c = 'Outbound'
                    AND StatusPk__c = 'Synced'
                    WITH SYSTEM_MODE
                ]) {
                    coveredRequestIds.add(existing.RequestId__c);
                }

                // 5. Query full WorkItem data for gap items
                Set<Id> gapWorkItemIds = new Set<Id>();
                Map<Id, WorkRequest__c> gapWorkItemToRequest = new Map<Id, WorkRequest__c>();
                for (WorkRequest__c req : requests) {
                    if (!coveredRequestIds.contains(req.Id) && req.WorkItemId__c != null) {
                        gapWorkItemIds.add(req.WorkItemId__c);
                        gapWorkItemToRequest.put(req.WorkItemId__c, req);
                    }
                }

                if (!gapWorkItemIds.isEmpty()) {
                    Map<Id, WorkItem__c> gapWorkItems = new Map<Id, WorkItem__c>([
                        SELECT Id, BriefDescriptionTxt__c, DetailsTxt__c, StageNamePk__c, StatusPk__c,
                               PriorityPk__c, DeveloperDaysSizeNumber__c, EstimatedHoursNumber__c,
                               ClientPreApprovedHoursNumber__c, Developer__c, CalculatedETADate__c,
                               ProjectedUATReadyDate__c, AcceptanceCriteriaTxt__c, StepsToReproduceTxt__c,
                               ClientIntentionPk__c, RequestTypePk__c, Tags__c, WorkflowTypeTxt__c,
                               Epic__c, SLATargetDate__c, IsActiveBool__c, SortOrderNumber__c
                        FROM WorkItem__c
                        WHERE Id IN :gapWorkItemIds
                        WITH SYSTEM_MODE
                    ]);

                    for (Id wiId : gapWorkItemIds) {
                        if (itemsToInsert.size() >= BATCH_LIMIT) {
                            break;
                        }
                        WorkItem__c wi = gapWorkItems.get(wiId);
                        WorkRequest__c req = gapWorkItemToRequest.get(wiId);
                        if (wi != null && req != null) {
                            itemsToInsert.add(buildWorkItemSyncItem(wi, req));
                        }
                    }
                }

                // 6. Reconcile WorkLogs for all work items linked via requests
                if (itemsToInsert.size() < BATCH_LIMIT && !workItemIds.isEmpty()) {
                    // Find all WorkLogs for these WorkItems
                    List<WorkLog__c> workLogs = [
                        SELECT Id, WorkItemId__c, HoursLoggedNumber__c, WorkDateDate__c,
                               WorkDescriptionTxt__c, StatusPk__c
                        FROM WorkLog__c
                        WHERE WorkItemId__c IN :workItemIds
                        WITH SYSTEM_MODE
                    ];

                    if (!workLogs.isEmpty()) {
                        // Find which WorkLogs already have a Synced outbound SyncItem
                        Set<String> workLogIds = new Set<String>();
                        for (WorkLog__c wl : workLogs) {
                            workLogIds.add((String) wl.Id);
                        }

                        Set<String> coveredWorkLogIds = new Set<String>();
                        for (SyncItem__c existing : [
                            SELECT LocalRecordIdTxt__c
                            FROM SyncItem__c
                            WHERE LocalRecordIdTxt__c IN :workLogIds
                            AND ObjectTypePk__c = 'WorkLog__c'
                            AND DirectionPk__c = 'Outbound'
                            AND StatusPk__c = 'Synced'
                            WITH SYSTEM_MODE
                        ]) {
                            coveredWorkLogIds.add(existing.LocalRecordIdTxt__c);
                        }

                        String senderOrgId = UserInfo.getOrganizationId();
                        for (WorkLog__c wl : workLogs) {
                            if (itemsToInsert.size() >= BATCH_LIMIT) {
                                break;
                            }
                            if (coveredWorkLogIds.contains((String) wl.Id)) {
                                continue;
                            }
                            WorkRequest__c parentReq = workItemToRequest.get(wl.WorkItemId__c);
                            if (parentReq == null) {
                                continue;
                            }
                            itemsToInsert.add(buildWorkLogSyncItem(wl, parentReq, senderOrgId));
                        }
                    }
                }
            }

            // 7. Insert all missing SyncItems
            if (!itemsToInsert.isEmpty()) {
                Database.insert(itemsToInsert, AccessLevel.SYSTEM_MODE);

                // Enqueue processor to push the new items
                if (!Test.isRunningTest() && Limits.getQueueableJobs() < 2) {
                    System.enqueueJob(new DeliverySyncItemProcessor());
                }
            }

            // 8. Chain to next entity if more remain
            if (entityIndex + 1 < entities.size() && !Test.isRunningTest()) {
                System.enqueueJob(new DeliverySyncReconciler(entityIndex + 1));
            }

        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'DeliverySyncReconciler Failed: ' + e.getMessage() + ' | ' + e.getStackTraceString());
        }
    }

    /**
     * @description Builds a Queued outbound SyncItem for a WorkItem that is missing from
     * the sync ledger. Mirrors the payload structure produced by DeliverySyncEngine.createSyncItem.
     * @param wi The WorkItem record with all syncable fields populated.
     * @param req The WorkRequest bridge linking the WorkItem to the downstream entity.
     * @return A new SyncItem__c ready for insert.
     */
    private SyncItem__c buildWorkItemSyncItem(WorkItem__c wi, WorkRequest__c req) {
        Map<String, Object> payload = new Map<String, Object>();

        // Map all syncable fields
        Map<String, Object> populatedFields = wi.getPopulatedFieldsAsMap();
        for (String field : WORK_ITEM_SYNC_FIELDS) {
            if (populatedFields.containsKey(field)) {
                payload.put(field, populatedFields.get(field));
            }
        }

        // Standard routing metadata
        payload.put('SourceId', wi.Id);
        payload.put('GlobalSourceId', (String) wi.Id);
        payload.put('SenderOrgId', UserInfo.getOrganizationId());
        payload.put('TargetId', req.RemoteWorkItemIdTxt__c);

        return new SyncItem__c(
            ObjectTypePk__c      = 'WorkItem__c',
            LocalRecordIdTxt__c  = (String) wi.Id,
            WorkItemId__c        = wi.Id,
            RequestId__c         = req.Id,
            DirectionPk__c       = 'Outbound',
            StatusPk__c          = 'Queued',
            GlobalSourceIdTxt__c = (String) wi.Id,
            PayloadTxt__c        = JSON.serialize(payload)
        );
    }

    /**
     * @description Builds a Queued outbound SyncItem for a WorkLog that is missing from
     * the sync ledger. Mirrors the payload structure produced by DeliveryWorkLogTriggerHandler.
     * @param wl The WorkLog record to sync.
     * @param parentReq The WorkRequest linking the parent WorkItem to the downstream entity.
     * @param senderOrgId The current org's Organization ID for routing metadata.
     * @return A new SyncItem__c ready for insert.
     */
    private SyncItem__c buildWorkLogSyncItem(WorkLog__c wl, WorkRequest__c parentReq, String senderOrgId) {
        Map<String, Object> payload = new Map<String, Object>{
            'SourceId'               => (String) wl.Id,
            'GlobalSourceId'         => (String) wl.Id,
            'SenderOrgId'            => senderOrgId,
            'WorkItemId__c'          => wl.WorkItemId__c,
            'HoursLoggedNumber__c'   => wl.HoursLoggedNumber__c,
            'WorkDateDate__c'        => String.valueOf(wl.WorkDateDate__c),
            'WorkDescriptionTxt__c'  => wl.WorkDescriptionTxt__c,
            'StatusPk__c'            => wl.StatusPk__c
        };

        return new SyncItem__c(
            ObjectTypePk__c      = 'WorkLog__c',
            LocalRecordIdTxt__c  = (String) wl.Id,
            WorkItemId__c        = wl.WorkItemId__c,
            RequestId__c         = parentReq.Id,
            DirectionPk__c       = 'Outbound',
            StatusPk__c          = 'Queued',
            GlobalSourceIdTxt__c = (String) wl.Id,
            PayloadTxt__c        = JSON.serialize(payload)
        );
    }
}

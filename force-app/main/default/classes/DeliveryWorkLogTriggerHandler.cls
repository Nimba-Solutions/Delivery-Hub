/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Trigger handler for WorkLog__c. On insert, queues an outbound SyncItem__c
 *              for each WorkLog whose parent Work Item has a client Network Entity linked.
 *              When approval is required (RequireWorkLogApprovalDate__c is set), only
 *              Approved WorkLogs generate SyncItems. Draft logs sync on approval via
 *              onAfterUpdate.
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.ApexCRUDViolation')
public with sharing class DeliveryWorkLogTriggerHandler {

    /**
     * @description Processes newly inserted WorkLog records and creates outbound sync items
     *              for those tied to client-linked work items. When approval is required,
     *              only logs with StatusPk__c = 'Approved' (or null for backward compat)
     *              generate sync items.
     * @param newLogs List of newly inserted WorkLog__c records.
     */
    public static void onAfterInsert(List<WorkLog__c> newLogs) {
        if (!DeliveryTriggerControl.runAfterLogic) {
            return;
        }
        List<WorkLog__c> eligible = filterEligibleForSync(newLogs);
        if (eligible.isEmpty()) {
            return;
        }
        createSyncItemsForLogs(eligible);
    }

    /**
     * @description Processes updated WorkLog records. When a log transitions to 'Approved',
     *              creates outbound sync items (the approval → sync trigger).
     * @param newLogs List of updated WorkLog__c records.
     * @param oldMap Map of old WorkLog__c records keyed by Id.
     */
    public static void onAfterUpdate(List<WorkLog__c> newLogs, Map<Id, WorkLog__c> oldMap) {
        if (!DeliveryTriggerControl.runAfterLogic) {
            return;
        }
        List<WorkLog__c> newlyApproved = new List<WorkLog__c>();
        for (WorkLog__c wl : newLogs) {
            WorkLog__c old = oldMap.get(wl.Id);
            if (wl.StatusPk__c == 'Approved' && old.StatusPk__c != 'Approved') {
                newlyApproved.add(wl);
            }
        }
        if (newlyApproved.isEmpty()) {
            return;
        }
        createSyncItemsForLogs(newlyApproved);
    }

    // ── Shared sync item creation ──────────────────────────────────────

    private static void createSyncItemsForLogs(List<WorkLog__c> logs) {
        Set<Id> workItemIds = new Set<Id>();
        for (WorkLog__c wl : logs) {
            if (wl.WorkItemId__c != null) {
                workItemIds.add(wl.WorkItemId__c);
            }
        }
        if (workItemIds.isEmpty()) {
            return;
        }

        Map<Id, WorkItem__c> clientWorkItems = new Map<Id, WorkItem__c>([
            SELECT Id, ClientNetworkEntityId__c
            FROM WorkItem__c
            WHERE Id IN :workItemIds
            AND ClientNetworkEntityId__c != null
            WITH SYSTEM_MODE
        ]);

        if (clientWorkItems.isEmpty()) {
            return;
        }

        List<SyncItem__c> syncItems = buildSyncItems(logs, clientWorkItems);
        if (!syncItems.isEmpty()) {
            Database.insert(syncItems, AccessLevel.SYSTEM_MODE);
        }
    }

    // ── Approval gate filter ───────────────────────────────────────────

    /**
     * @description Filters WorkLogs eligible for immediate sync on insert.
     *              When approval is required, only 'Approved' logs pass.
     *              When approval is NOT required (default), all logs pass
     *              (null StatusPk__c treated as Approved for backward compat).
     * @param logs The WorkLog records to filter.
     * @return Filtered list of WorkLogs eligible for sync.
     */
    private static List<WorkLog__c> filterEligibleForSync(List<WorkLog__c> logs) {
        if (!isApprovalRequired()) {
            return logs;
        }
        List<WorkLog__c> eligible = new List<WorkLog__c>();
        for (WorkLog__c wl : logs) {
            // Null status = legacy log created before approval was enabled → treat as Approved
            if (wl.StatusPk__c == null || wl.StatusPk__c == 'Approved') {
                eligible.add(wl);
            }
        }
        return eligible;
    }

    /**
     * @description Checks whether WorkLog approval is required based on the
     *              org-level DeliveryHubSettings__c.RequireWorkLogApprovalDate__c.
     * @return true when the DateTime field is populated (approval policy is active).
     */
    public static Boolean isApprovalRequired() {
        DeliveryHubSettings__c settings = DeliveryHubSettings__c.getOrgDefaults();
        return settings.RequireWorkLogApprovalDate__c != null;
    }

    /**
     * @description Builds the list of SyncItem__c records for WorkLogs on client-linked work items.
     * @param logs The WorkLog records to evaluate.
     * @param clientWorkItems Map of work item Ids that have a client entity linked.
     * @return List of SyncItem__c records ready for insert.
     */
    private static List<SyncItem__c> buildSyncItems(List<WorkLog__c> logs, Map<Id, WorkItem__c> clientWorkItems) {
        List<SyncItem__c> items = new List<SyncItem__c>();
        for (WorkLog__c wl : logs) {
            if (!clientWorkItems.containsKey(wl.WorkItemId__c)) {
                continue;
            }
            Map<String, Object> payload = new Map<String, Object>{
                'WorkItemId__c'            => wl.WorkItemId__c,
                'HoursLoggedNumber__c'   => wl.HoursLoggedNumber__c,
                'WorkDateDate__c'        => String.valueOf(wl.WorkDateDate__c),
                'WorkDescriptionTxt__c'  => wl.WorkDescriptionTxt__c
            };
            items.add(new SyncItem__c(
                ObjectTypePk__c         = 'WorkLog__c',
                LocalRecordIdTxt__c     = wl.Id,
                WorkItemId__c             = wl.WorkItemId__c,
                DirectionPk__c          = 'Outbound',
                StatusPk__c             = 'Queued',
                PayloadTxt__c           = JSON.serialize(payload)
            ));
        }
        return items;
    }
}

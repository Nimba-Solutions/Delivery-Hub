/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Trigger handler for WorkLog__c. On insert, queues an outbound SyncItem__c
 *              for each WorkLog whose parent Work Item has a client Network Entity linked.
 *              This seeds the sync queue so the scheduled processor can push logged hours
 *              to the client org once the sync pipeline supports WorkLog payloads.
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.ApexCRUDViolation')
public with sharing class DeliveryWorkLogTriggerHandler {

    /**
     * @description Processes newly inserted WorkLog records and creates outbound sync items
     *              for those tied to client-linked work items.
     * @param newLogs List of newly inserted WorkLog__c records.
     */
    public static void onAfterInsert(List<WorkLog__c> newLogs) {
        if (!DeliveryTriggerControl.runAfterLogic) {
            return;
        }
        Set<Id> workItemIds = new Set<Id>();
        for (WorkLog__c wl : newLogs) {
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

        List<SyncItem__c> syncItems = buildSyncItems(newLogs, clientWorkItems);
        if (!syncItems.isEmpty()) {
            // FIX: SYSTEM_MODE to prevent packaging test failures on namespaced fields
            Database.insert(syncItems, AccessLevel.SYSTEM_MODE);
        }
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

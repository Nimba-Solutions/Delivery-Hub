/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Trigger handler for WorkItemDependency__c. Delegates to the field
 *               tracking service for create, update, and delete DML events.
 *               Also publishes `dependency_change` Platform Events on the existing
 *               DeliveryWorkItemChange__e channel so the gantt LWC can re-render
 *               its dep arrows live when other clients add/remove/reparent deps.
 *               Gated by DeliveryHubSettings__c.EnableLiveGanttEventsDateTime__c —
 *               same toggle that controls task_upsert events from PR #731.
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.ApexCRUDViolation')
public with sharing class DeliveryDependencyTriggerHandler {

    /**
     * @description Handles after-insert: tracks creation of dependency records and
     *              fires dependency_change events for both endpoints of each new dep.
     * @param newRecords List of newly inserted WorkItemDependency__c records.
     */
    public static void onAfterInsert(List<WorkItemDependency__c> newRecords) {
        if (!DeliveryTriggerControl.runAfterLogic) { return; }
        DeliveryFieldTrackingService.trackCreates(newRecords);
        publishDependencyChangeEvents(newRecords);
    }

    /**
     * @description Handles after-update: tracks field changes on dependency records
     *              and fires dependency_change events for both endpoints of each
     *              updated dep (covers reparent / type changes).
     * @param newRecords List of updated WorkItemDependency__c records.
     * @param oldMap Map of pre-update WorkItemDependency__c records.
     */
    public static void onAfterUpdate(List<WorkItemDependency__c> newRecords, Map<Id, WorkItemDependency__c> oldMap) {
        if (!DeliveryTriggerControl.runAfterLogic) { return; }
        DeliveryFieldTrackingService.trackChanges(newRecords, oldMap);
        publishDependencyChangeEvents(newRecords);
    }

    /**
     * @description Handles before-delete: tracks deletion of dependency records and
     *              fires dependency_change events for both endpoints so the gantt
     *              re-renders without the removed arrow.
     * @param oldRecords List of WorkItemDependency__c records being deleted.
     */
    public static void onBeforeDelete(List<WorkItemDependency__c> oldRecords) {
        if (!DeliveryTriggerControl.runAfterLogic) { return; }
        DeliveryFieldTrackingService.trackDeletes(oldRecords);
        publishDependencyChangeEvents(oldRecords);
    }

    /**
     * @description Emit one DeliveryWorkItemChange__e per affected WorkItem
     *              (both Blocking + Blocked endpoints) with ChangeTypeTxt__c =
     *              'dependency_change'. Subscribers (deliveryProFormaTimeline,
     *              deliveryRecordLiveRefresh) refetch on match and re-render
     *              the dep arrows / record-page panels.
     *
     *              Fast-exits when the live-events toggle is null. Reuses the
     *              same toggle as task_upsert publishing — admins flip both
     *              ChangeTypes on/off together.
     * @param deps List of dependency records (current state for insert/update,
     *             pre-delete state for delete).
     */
    private static void publishDependencyChangeEvents(List<WorkItemDependency__c> deps) {
        DeliveryHubSettings__c settings = DeliveryHubSettings__c.getInstance();
        if (settings == null || settings.Id == null || settings.EnableLiveGanttEventsDateTime__c == null) {
            return;
        }
        Set<Id> affectedWorkItems = new Set<Id>();
        for (WorkItemDependency__c d : deps) {
            if (d.BlockingWorkItemLookup__c != null) {
                affectedWorkItems.add(d.BlockingWorkItemLookup__c);
            }
            if (d.BlockedWorkItemLookup__c != null) {
                affectedWorkItems.add(d.BlockedWorkItemLookup__c);
            }
        }
        if (affectedWorkItems.isEmpty()) {
            return;
        }
        List<DeliveryWorkItemChange__e> events = new List<DeliveryWorkItemChange__e>();
        for (Id wiId : affectedWorkItems) {
            events.add(new DeliveryWorkItemChange__e(
                WorkItemIdTxt__c = wiId,
                ChangeTypeTxt__c = 'dependency_change'
            ));
        }
        EventBus.publish(events);
    }
}

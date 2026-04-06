/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Trigger handler for WorkItemDependency__c. Delegates to the field
 *               tracking service for create, update, and delete DML events.
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.ApexCRUDViolation')
public with sharing class DeliveryDependencyTriggerHandler {

    /**
     * @description Handles after-insert: tracks creation of dependency records.
     * @param newRecords List of newly inserted WorkItemDependency__c records.
     */
    public static void onAfterInsert(List<WorkItemDependency__c> newRecords) {
        if (!DeliveryTriggerControl.runAfterLogic) { return; }
        DeliveryFieldTrackingService.trackCreates(newRecords);
    }

    /**
     * @description Handles after-update: tracks field changes on dependency records.
     * @param newRecords List of updated WorkItemDependency__c records.
     * @param oldMap Map of pre-update WorkItemDependency__c records.
     */
    public static void onAfterUpdate(List<WorkItemDependency__c> newRecords, Map<Id, WorkItemDependency__c> oldMap) {
        if (!DeliveryTriggerControl.runAfterLogic) { return; }
        DeliveryFieldTrackingService.trackChanges(newRecords, oldMap);
    }

    /**
     * @description Handles before-delete: tracks deletion of dependency records.
     * @param oldRecords List of WorkItemDependency__c records being deleted.
     */
    public static void onBeforeDelete(List<WorkItemDependency__c> oldRecords) {
        if (!DeliveryTriggerControl.runAfterLogic) { return; }
        DeliveryFieldTrackingService.trackDeletes(oldRecords);
    }
}

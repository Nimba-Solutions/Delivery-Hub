/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Trigger handler for WorkRequest__c. Delegates to the field
 *               tracking service for create, update, and delete DML events.
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.ApexDoc, PMD.ApexCRUDViolation')
public with sharing class DeliveryWorkRequestTriggerHandler {

    /**
     * @description Handles after-insert: tracks creation of work request records.
     * @param newRecords List of newly inserted WorkRequest__c records.
     */
    public static void onAfterInsert(List<WorkRequest__c> newRecords) {
        if (!DeliveryTriggerControl.runAfterLogic) { return; }
        DeliveryFieldTrackingService.trackCreates(newRecords);
    }

    /**
     * @description Handles after-update: tracks field changes on work request records.
     * @param newRecords List of updated WorkRequest__c records.
     * @param oldMap Map of pre-update WorkRequest__c records.
     */
    public static void onAfterUpdate(List<WorkRequest__c> newRecords, Map<Id, WorkRequest__c> oldMap) {
        if (!DeliveryTriggerControl.runAfterLogic) { return; }
        DeliveryFieldTrackingService.trackChanges(newRecords, oldMap);
    }

    /**
     * @description Handles before-delete: tracks deletion of work request records.
     * @param oldRecords List of WorkRequest__c records being deleted.
     */
    public static void onBeforeDelete(List<WorkRequest__c> oldRecords) {
        if (!DeliveryTriggerControl.runAfterLogic) { return; }
        DeliveryFieldTrackingService.trackDeletes(oldRecords);
    }
}

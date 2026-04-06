/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Trigger handler for DeliveryDocument__c. Delegates to the field
 *               tracking service for create, update, and delete DML events.
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.ApexCRUDViolation')
public with sharing class DeliveryDocumentTriggerHandler {

    /**
     * @description Handles after-insert: tracks creation of document records.
     * @param newRecords List of newly inserted DeliveryDocument__c records.
     */
    public static void onAfterInsert(List<DeliveryDocument__c> newRecords) {
        if (!DeliveryTriggerControl.runAfterLogic) { return; }
        DeliveryFieldTrackingService.trackCreates(newRecords);
    }

    /**
     * @description Handles after-update: tracks field changes on document records.
     * @param newRecords List of updated DeliveryDocument__c records.
     * @param oldMap Map of pre-update DeliveryDocument__c records.
     */
    public static void onAfterUpdate(List<DeliveryDocument__c> newRecords, Map<Id, DeliveryDocument__c> oldMap) {
        if (!DeliveryTriggerControl.runAfterLogic) { return; }
        DeliveryFieldTrackingService.trackChanges(newRecords, oldMap);
    }

    /**
     * @description Handles before-delete: tracks deletion of document records.
     * @param oldRecords List of DeliveryDocument__c records being deleted.
     */
    public static void onBeforeDelete(List<DeliveryDocument__c> oldRecords) {
        if (!DeliveryTriggerControl.runAfterLogic) { return; }
        DeliveryFieldTrackingService.trackDeletes(oldRecords);
    }
}

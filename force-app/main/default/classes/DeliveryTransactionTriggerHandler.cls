/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Trigger handler for DeliveryTransaction__c. Delegates to the field
 *               tracking service for create, update, and delete DML events.
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.ApexDoc, PMD.ApexCRUDViolation')
public with sharing class DeliveryTransactionTriggerHandler {

    /**
     * @description Handles after-insert: tracks creation of transaction records.
     * @param newRecords List of newly inserted DeliveryTransaction__c records.
     */
    public static void onAfterInsert(List<DeliveryTransaction__c> newRecords) {
        if (!DeliveryTriggerControl.runAfterLogic) { return; }
        DeliveryFieldTrackingService.trackCreates(newRecords);
    }

    /**
     * @description Handles after-update: tracks field changes on transaction records.
     * @param newRecords List of updated DeliveryTransaction__c records.
     * @param oldMap Map of pre-update DeliveryTransaction__c records.
     */
    public static void onAfterUpdate(List<DeliveryTransaction__c> newRecords, Map<Id, DeliveryTransaction__c> oldMap) {
        if (!DeliveryTriggerControl.runAfterLogic) { return; }
        DeliveryFieldTrackingService.trackChanges(newRecords, oldMap);
    }

    /**
     * @description Handles before-delete: tracks deletion of transaction records.
     * @param oldRecords List of DeliveryTransaction__c records being deleted.
     */
    public static void onBeforeDelete(List<DeliveryTransaction__c> oldRecords) {
        if (!DeliveryTriggerControl.runAfterLogic) { return; }
        DeliveryFieldTrackingService.trackDeletes(oldRecords);
    }
}

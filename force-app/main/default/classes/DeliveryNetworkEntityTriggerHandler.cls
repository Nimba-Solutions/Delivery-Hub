/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Trigger handler for NetworkEntity__c. Delegates to the field
 *               tracking service for create, update, and delete DML events.
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.ApexCRUDViolation')
public with sharing class DeliveryNetworkEntityTriggerHandler {

    /**
     * @description Handles after-insert: tracks creation of entity records.
     * @param newRecords List of newly inserted NetworkEntity__c records.
     */
    public static void onAfterInsert(List<NetworkEntity__c> newRecords) {
        if (!DeliveryTriggerControl.runAfterLogic) { return; }
        DeliveryFieldTrackingService.trackCreates(newRecords);
    }

    /**
     * @description Handles after-update: tracks field changes on entity records.
     * @param newRecords List of updated NetworkEntity__c records.
     * @param oldMap Map of pre-update NetworkEntity__c records.
     */
    public static void onAfterUpdate(List<NetworkEntity__c> newRecords, Map<Id, NetworkEntity__c> oldMap) {
        if (!DeliveryTriggerControl.runAfterLogic) { return; }
        DeliveryFieldTrackingService.trackChanges(newRecords, oldMap);
    }

    /**
     * @description Handles before-delete: tracks deletion of entity records.
     * @param oldRecords List of NetworkEntity__c records being deleted.
     */
    public static void onBeforeDelete(List<NetworkEntity__c> oldRecords) {
        if (!DeliveryTriggerControl.runAfterLogic) { return; }
        DeliveryFieldTrackingService.trackDeletes(oldRecords);
    }
}

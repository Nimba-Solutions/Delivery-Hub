/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Trigger for NetworkEntity__c. Delegates all logic to DeliveryNetworkEntityTriggerHandler.
 * @author Cloud Nimbus LLC
 */
trigger DeliveryNetworkEntityTrigger on NetworkEntity__c (after insert, after update, before delete) { //NOPMD - AvoidLogicInTrigger: trivial guards + handler delegation only
    if (Trigger.isAfter && Trigger.isInsert) {
        DeliveryNetworkEntityTriggerHandler.onAfterInsert(Trigger.new);
    }
    if (Trigger.isAfter && Trigger.isUpdate) {
        DeliveryNetworkEntityTriggerHandler.onAfterUpdate(Trigger.new, Trigger.oldMap);
    }
    if (Trigger.isBefore && Trigger.isDelete) {
        DeliveryNetworkEntityTriggerHandler.onBeforeDelete(Trigger.old);
    }
}

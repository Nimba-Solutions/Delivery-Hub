/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Trigger for DeliveryTransaction__c. Delegates all logic to DeliveryTransactionTriggerHandler.
 * @author Cloud Nimbus LLC
 */
trigger DeliveryTransactionTrigger on DeliveryTransaction__c (after insert, after update, before delete) { //NOPMD - AvoidLogicInTrigger: trivial guards + handler delegation only
    if (Trigger.isAfter && Trigger.isInsert) {
        DeliveryTransactionTriggerHandler.onAfterInsert(Trigger.new);
    }
    if (Trigger.isAfter && Trigger.isUpdate) {
        DeliveryTransactionTriggerHandler.onAfterUpdate(Trigger.new, Trigger.oldMap);
    }
    if (Trigger.isBefore && Trigger.isDelete) {
        DeliveryTransactionTriggerHandler.onBeforeDelete(Trigger.old);
    }
}

/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Trigger for WorkRequest__c. Delegates all logic to DeliveryWorkRequestTriggerHandler.
 * @author Cloud Nimbus LLC
 */
trigger DeliveryWorkRequestTrigger on WorkRequest__c (after insert, after update, before delete) { //NOPMD - AvoidLogicInTrigger: trivial guards + handler delegation only
    if (Trigger.isAfter && Trigger.isInsert) {
        DeliveryWorkRequestTriggerHandler.onAfterInsert(Trigger.new);
    }
    if (Trigger.isAfter && Trigger.isUpdate) {
        DeliveryWorkRequestTriggerHandler.onAfterUpdate(Trigger.new, Trigger.oldMap);
    }
    if (Trigger.isBefore && Trigger.isDelete) {
        DeliveryWorkRequestTriggerHandler.onBeforeDelete(Trigger.old);
    }
}

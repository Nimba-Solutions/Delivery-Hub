/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Trigger for WorkItemDependency__c. Delegates all logic to DeliveryDependencyTriggerHandler.
 * @author Cloud Nimbus LLC
 */
trigger DeliveryDependencyTrigger on WorkItemDependency__c (after insert, after update, before delete) { //NOPMD - AvoidLogicInTrigger: trivial guards + handler delegation only
    if (Trigger.isAfter && Trigger.isInsert) {
        DeliveryDependencyTriggerHandler.onAfterInsert(Trigger.new);
    }
    if (Trigger.isAfter && Trigger.isUpdate) {
        DeliveryDependencyTriggerHandler.onAfterUpdate(Trigger.new, Trigger.oldMap);
    }
    if (Trigger.isBefore && Trigger.isDelete) {
        DeliveryDependencyTriggerHandler.onBeforeDelete(Trigger.old);
    }
}

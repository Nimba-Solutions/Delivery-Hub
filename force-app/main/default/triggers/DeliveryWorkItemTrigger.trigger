/**
 * @author Cloud Nimbus LLC
 */
trigger DeliveryWorkItemTrigger on WorkItem__c (before insert, after insert, after update, before update, before delete) { //NOPMD - AvoidLogicInTrigger: trivial guards + handler delegation only

    if (DeliveryWorkItemTriggerHandler.triggerDisabled) {
        return;
    }
    // We keep all logic out of the trigger body
    if (Trigger.isBefore && Trigger.isInsert) {
        DeliveryWorkItemTriggerHandler.handleBeforeInsert(Trigger.new);
    }
    if (Trigger.isBefore && Trigger.isUpdate) {
        DeliveryWorkItemTriggerHandler.handleBeforeUpdate(Trigger.new, Trigger.oldMap);
    }
    if (Trigger.isBefore && Trigger.isDelete) {
        DeliveryWorkItemTriggerHandler.handleBeforeDelete(Trigger.old);
    }
    if (Trigger.isAfter) {
        DeliveryWorkItemTriggerHandler.handleAfter(
            Trigger.new,
            Trigger.oldMap,
            Trigger.isInsert,
            Trigger.isUpdate
        );
    }
}
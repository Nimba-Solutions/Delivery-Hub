/**
 * @description Trigger for WorkLog__c. Delegates all logic to DeliveryWorkLogTriggerHandler.
 * @author Cloud Nimbus LLC
 */
trigger DeliveryWorkLogTrigger on WorkLog__c (before insert, before update, before delete, after insert, after update) { // NOPMD
    if (Trigger.isBefore && Trigger.isInsert) {
        DeliveryWorkLogTriggerHandler.onBeforeInsert(Trigger.new);
    }
    if (Trigger.isBefore && Trigger.isUpdate) {
        DeliveryWorkLogTriggerHandler.onBeforeUpdate(Trigger.new, Trigger.oldMap);
    }
    if (Trigger.isBefore && Trigger.isDelete) {
        DeliveryWorkLogTriggerHandler.onBeforeDelete(Trigger.old);
    }
    if (Trigger.isAfter && Trigger.isInsert) {
        DeliveryWorkLogTriggerHandler.onAfterInsert(Trigger.new);
    }
    if (Trigger.isAfter && Trigger.isUpdate) {
        DeliveryWorkLogTriggerHandler.onAfterUpdate(Trigger.new, Trigger.oldMap);
    }
}

/**
 * @description Trigger for WorkLog__c. Delegates all logic to DeliveryWorkLogTriggerHandler.
 * @author Cloud Nimbus LLC
 */
trigger DeliveryWorkLogTrigger on WorkLog__c (after insert, after update) { // NOPMD
    if (Trigger.isAfter && Trigger.isInsert) {
        DeliveryWorkLogTriggerHandler.onAfterInsert(Trigger.new);
    }
    if (Trigger.isAfter && Trigger.isUpdate) {
        DeliveryWorkLogTriggerHandler.onAfterUpdate(Trigger.new, Trigger.oldMap);
    }
}

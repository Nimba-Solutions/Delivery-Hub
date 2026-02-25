/**
 * @description Trigger for WorkLog__c. Delegates all logic to DeliveryWorkLogTriggerHandler.
 */
trigger DeliveryWorkLogTrigger on WorkLog__c (after insert) { // NOPMD
    DeliveryWorkLogTriggerHandler.onAfterInsert(Trigger.new);
}

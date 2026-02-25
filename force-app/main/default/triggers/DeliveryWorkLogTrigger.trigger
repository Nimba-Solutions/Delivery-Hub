trigger DeliveryWorkLogTrigger on WorkLog__c (after insert) {
    if (Trigger.isAfter && Trigger.isInsert) {
        DeliveryWorkLogTriggerHandler.onAfterInsert(Trigger.new);
    }
}

/**
 * @author Cloud Nimbus LLC
 */
trigger DeliveryWorkItemTrigger on WorkItem__c (after insert, after update, before update) {
    
    if (DeliveryWorkItemTriggerHandler.triggerDisabled) {
        return;
    }
	 // We keep all logic out of the trigger body
    if (Trigger.isAfter) {
    DeliveryWorkItemTriggerHandler.handleAfter(
        Trigger.new,
        Trigger.oldMap,
        Trigger.isInsert,
        Trigger.isUpdate
    );
    }
    if (Trigger.isBefore && Trigger.isUpdate) {
        DeliveryWorkItemTriggerHandler.handleBeforeUpdate(Trigger.new, Trigger.oldMap);
    }
}
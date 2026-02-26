/**
 * @description Trigger for Ticket Comments. Delegates all logic to DeliveryWorkItemCommentTriggerHandler.
 * @author Cloud Nimbus LLC
 */
trigger DeliveryWorkItemCommentTrigger on WorkItemComment__c (after insert, after update) { // NOPMD
    if (Trigger.isAfter) {
        if (Trigger.isInsert) {
            DeliveryWorkItemCommentTriggerHandler.handleAfterInsert(Trigger.new, Trigger.newMap);
        }
        if (Trigger.isUpdate) {
            DeliveryWorkItemCommentTriggerHandler.handleAfterUpdate(Trigger.newMap, Trigger.oldMap);
        }
    }
}
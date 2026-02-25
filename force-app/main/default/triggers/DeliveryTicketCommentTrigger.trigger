/**
 * @description Trigger for Ticket Comments. Delegates all logic to DeliveryTicketCommentTriggerHandler.
 * @author Cloud Nimbus LLC
 */
trigger DeliveryTicketCommentTrigger on Ticket_Comment__c (after insert, after update) { // NOPMD
    if (Trigger.isAfter) {
        if (Trigger.isInsert) {
            DeliveryTicketCommentTriggerHandler.handleAfterInsert(Trigger.new, Trigger.newMap);
        }
        if (Trigger.isUpdate) {
            DeliveryTicketCommentTriggerHandler.handleAfterUpdate(Trigger.newMap, Trigger.oldMap);
        }
    }
}
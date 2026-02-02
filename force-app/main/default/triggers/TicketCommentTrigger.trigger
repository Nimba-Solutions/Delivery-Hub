/**
 * @description Trigger for Ticket Comments. Delegates all logic to TicketCommentTriggerHandler.
 */
trigger TicketCommentTrigger on Ticket_Comment__c (after insert, after update) { // NOPMD
    if (Trigger.isAfter) {
        if (Trigger.isInsert) {
            TicketCommentTriggerHandler.handleAfterInsert(Trigger.new, Trigger.newMap);
        }
        if (Trigger.isUpdate) {
            TicketCommentTriggerHandler.handleAfterUpdate(Trigger.newMap, Trigger.oldMap);
        }
    }
}
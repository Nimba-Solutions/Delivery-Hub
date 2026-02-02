trigger TicketCommentTrigger on Ticket_Comment__c (after insert, after update) {
    if (Trigger.isAfter) {
        if (Trigger.isInsert) {
            TicketCommentTriggerHandler.handleAfterInsert(Trigger.new, Trigger.newMap);
        }
        if (Trigger.isUpdate) {
            TicketCommentTriggerHandler.handleAfterUpdate(Trigger.newMap, Trigger.oldMap);
        }
    }
}
trigger TicketCommentTrigger on Ticket_Comment__c (after insert, after update) {
    // Flattened logic to satisfy PMD "AvoidLogicInTrigger"
    if (Trigger.isInsert && Trigger.isAfter) {
        TicketCommentTriggerHandler.handleAfterInsert(Trigger.new, Trigger.newMap);
    } 
    else if (Trigger.isUpdate && Trigger.isAfter) {
        TicketCommentTriggerHandler.handleAfterUpdate(Trigger.newMap, Trigger.oldMap);
    }
}
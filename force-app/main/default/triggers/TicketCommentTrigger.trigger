/**
 * @description Trigger for Ticket Comments. Delegates all logic to TicketCommentTriggerHandler.
 * Suppressing 'AvoidLogicInTrigger' because we must use IF statements to dispatch events.
 */
@SuppressWarnings('PMD.AvoidLogicInTrigger')
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
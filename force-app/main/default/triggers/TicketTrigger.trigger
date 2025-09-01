trigger TicketTrigger on Ticket__c (after insert, after update, before update) {
	 // We keep all logic out of the trigger body
    if (Trigger.isAfter) {
    TicketTriggerHandler.handleAfter(
        Trigger.new,
        Trigger.oldMap,
        Trigger.isInsert,
        Trigger.isUpdate
    );
    }
    if (Trigger.isBefore && Trigger.isUpdate) {
        TicketTriggerHandler.handleBeforeUpdate(Trigger.new, Trigger.oldMap);
    }
}
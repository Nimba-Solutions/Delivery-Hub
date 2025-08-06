trigger DH_TicketTrigger on DH_Ticket__c (after insert, after update, before update) {
    // We keep all logic out of the trigger body
    if (Trigger.isAfter) {
    DH_TicketTriggerHandler.handleAfter(
        Trigger.new,
        Trigger.oldMap,
        Trigger.isInsert,
        Trigger.isUpdate
    );
    }
    if (Trigger.isBefore && Trigger.isUpdate) {
        DH_TicketTriggerHandler.handleBeforeUpdate(Trigger.new, Trigger.oldMap);
    }
}
trigger DH_TicketTrigger on DH_Ticket__c (after insert, after update) {
    // We keep all logic out of the trigger body
    DH_TicketTriggerHandler.handleAfter(
        Trigger.new,
        Trigger.oldMap,
        Trigger.isInsert,
        Trigger.isUpdate
    );
}
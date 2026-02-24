trigger DeliveryTicketTrigger on Ticket__c (after insert, after update, before update) {
    
    if (DeliveryTicketTriggerHandler.triggerDisabled) {
        return;
    }
	 // We keep all logic out of the trigger body
    if (Trigger.isAfter) {
    DeliveryTicketTriggerHandler.handleAfter(
        Trigger.new,
        Trigger.oldMap,
        Trigger.isInsert,
        Trigger.isUpdate
    );
    }
    if (Trigger.isBefore && Trigger.isUpdate) {
        DeliveryTicketTriggerHandler.handleBeforeUpdate(Trigger.new, Trigger.oldMap);
    }
}
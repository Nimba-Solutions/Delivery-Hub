trigger TicketCommentTrigger on Ticket_Comment__c (after insert,after update) {
	if (Trigger.isAfter) {
            if (Trigger.isInsert) {
                JiraCommentSyncHelper.handleAfterInsert(Trigger.newMap);
            }
            if (Trigger.isUpdate) {
                JiraCommentSyncHelper.handleAfterUpdate(Trigger.newMap, Trigger.oldMap);
            }
        }


    // --- 2. Delivery Hub Integration Logic ---
    // (Calls the new separate helper class for the Client/Vendor sync)
    if (Trigger.isAfter && Trigger.isInsert) {
        DeliveryHubSyncHandler.handleAfterInsert(Trigger.new);
    }
}
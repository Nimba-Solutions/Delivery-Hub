trigger TicketComment_JiraSync on Ticket_Comment__c (after insert,after update) {
	if (Trigger.isAfter) {
            if (Trigger.isInsert) {
                JiraCommentSyncHelper.handleAfterInsert(Trigger.newMap);
            }
            if (Trigger.isUpdate) {
                JiraCommentSyncHelper.handleAfterUpdate(Trigger.newMap, Trigger.oldMap);
            }
        }
}
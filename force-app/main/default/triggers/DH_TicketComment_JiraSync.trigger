trigger TicketComment_JiraSync on Ticket_Comment__c (after insert) {
    JiraCommentSyncHelper.handleAfterInsert(Trigger.newMap);
}
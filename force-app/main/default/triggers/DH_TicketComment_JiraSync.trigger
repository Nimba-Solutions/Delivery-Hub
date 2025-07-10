trigger DH_TicketComment_JiraSync on DH_Ticket_Comment__c (after insert) {
    JiraCommentSyncHelper.handleAfterInsert(Trigger.newMap);
}
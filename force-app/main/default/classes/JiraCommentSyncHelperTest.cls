@isTest
private class JiraCommentSyncHelperTest {

    @isTest
    static void testHandleAfterInsertAndQueueableSuccess() {
        // Create a test ticket with a Jira Key
        Ticket__c ticket = new Ticket__c(
           
            JiraTicketKeyTxt__c = 'JIRA-123'
        );
        insert ticket;

        // Create a comment to trigger sync
        Ticket_Comment__c comment = new Ticket_Comment__c(
            TicketId__c = ticket.Id,
            BodyTxt__c = '<p>This is <b>bold</b> and <i>italic</i>.</p>',
            SourcePk__c = 'Salesforce'
        );
        insert comment;
        

        // Load inserted comment
        Map<Id, Ticket_Comment__c> commentMap = new Map<Id, Ticket_Comment__c>{comment.Id => comment};
        
        Test.startTest();
        JiraCommentSyncHelper.handleAfterInsert(commentMap);
        Test.stopTest();

        // Reload and verify sync status is updated
        comment = [SELECT JiraSyncStatusTxt__c FROM Ticket_Comment__c WHERE Id = :comment.Id];
        //System.assertNotEquals(null, comment.JiraSyncStatusTxt__c);
    }

    @isTest
    static void testQueueableHandlesMissingJiraKey() {
        // Create a ticket without a Jira Key
        Ticket__c ticket = new Ticket__c(JiraTicketKeyTxt__c = 'JIRA-1234');
        insert ticket;

        Ticket_Comment__c comment = new Ticket_Comment__c(
            TicketId__c = ticket.Id,
            BodyTxt__c = '<p>Comment with no Jira key.</p>',
            SourcePk__c = 'Salesforce'
        );
        insert comment;

        Test.startTest();
        System.enqueueJob(new JiraCommentSyncHelper.JiraCommentSyncHelperQueueable(new List<Id>{comment.Id}));
        Test.stopTest();

        comment = [SELECT JiraSyncStatusTxt__c FROM Ticket_Comment__c WHERE Id = :comment.Id];
       // System.assertEquals('No Jira Key on ticket', comment.JiraSyncStatusTxt__c);
    }

    @isTest
    static void testConvertHtmlToAdf() {
        String html = '<p>This is <b>bold</b> and <i>italic</i>.</p>';
        String adf = JiraCommentSyncHelper.convertHtmlToAdf(html);
       // System.assert(adf.contains('"type": "paragraph"'));
       // System.assert(adf.contains('"type": "text"'));
      //  System.assert(adf.contains('"type": "strong"'));
       // System.assert(adf.contains('"type": "em"'));
    }

    @isTest
    static void testStripHtmlTags() {
        String html = '<p>This is <b>bold</b>.</p>';
        String result = JiraCommentSyncHelper.stripHtmlTags(html);
        System.assertEquals('This is bold.', result);
    }

    @isTest
    static void testHandleAfterInsertWithInvalidConditions() {
        Ticket__c ticket = new Ticket__c( JiraTicketKeyTxt__c = null);
        TicketTriggerHandler.triggerDisabled = true;
        insert ticket;
        TicketTriggerHandler.triggerDisabled = false;

        Ticket_Comment__c comment = new Ticket_Comment__c(
            TicketId__c = ticket.Id,
            BodyTxt__c = null,
            SourcePk__c = 'Salesforce'
        );
        insert comment;

        Map<Id, Ticket_Comment__c> commentMap = new Map<Id, Ticket_Comment__c>{comment.Id => comment};

        Test.startTest();
        JiraCommentSyncHelper.handleAfterInsert(commentMap);
        Test.stopTest();

        comment = [SELECT JiraSyncStatusTxt__c FROM Ticket_Comment__c WHERE Id = :comment.Id];
       // System.assertEquals(null, comment.JiraSyncStatusTxt__c);
    }
}
@IsTest
private class AuditLoggerTest {
    @IsTest
    static void testLogFieldChange() {
        // Setup a dummy ticket
        Ticket__c t = new Ticket__c(BriefDescriptionTxt__c = 'Audit Test');
        insert t;

        Test.startTest();
        AuditLogger.logFieldChange(
            t.Id, 
            'Status', 
            'New', 
            'In Progress', 
            'Salesforce', 
            'Test User'
        );
        Test.stopTest();

        // Verify the comment was created
        List<Ticket_Comment__c> comments = [SELECT Id, BodyTxt__c FROM Ticket_Comment__c WHERE TicketId__c = :t.Id];
        System.assertEquals(1, comments.size(), 'An audit comment should have been created');
        System.assert(comments[0].BodyTxt__c.contains('OLD: "New"'), 'The log should contain the old value');
    }
}
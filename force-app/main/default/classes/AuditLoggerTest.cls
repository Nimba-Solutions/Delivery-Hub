/**
 * @description Test class for AuditLogger utility.
 * Verifies that field changes are correctly logged as ticket comments.
 */
@IsTest
private class AuditLoggerTest {

    /**
     * @description Verifies that logFieldChange creates a comment with the correct formatted text.
     */
    @IsTest
    static void testLogFieldChange() {
        // ARRANGE: Setup a ticket for logging
        Ticket__c t = new Ticket__c(BriefDescriptionTxt__c = 'Audit Test');
        insert t;

        // ACT: Log a simulated field change
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

        // ASSERT: Query the latest comment for this ticket
        List<Ticket_Comment__c> comments = [
            SELECT Id, BodyTxt__c 
            FROM Ticket_Comment__c 
            WHERE TicketId__c = :t.Id 
            ORDER BY CreatedDate DESC 
            LIMIT 1
        ];

        System.assertEquals(1, comments.size(), 'An audit comment should have been created.');
        
        // Debug the actual body if the assertion is failing to help identify formatting issues
        String actualBody = comments[0].BodyTxt__c;
        System.debug(LoggingLevel.INFO, 'Actual Audit Log Body: ' + actualBody);

        // Check for the core components of the log message
        System.assert(actualBody.contains('OLD: "New"'), 'The log should contain the old value "New".');
        System.assert(actualBody.contains('NEW: "In Progress"'), 'The log should contain the new value "In Progress".');
        System.assert(actualBody.contains('Salesforce'), 'The log should identify the source as Salesforce.');
    }
}
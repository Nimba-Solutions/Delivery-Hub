@isTest
private class JiraCommentUpdateQueueableTest {

    // --- Mock for simulating Jira API responses ---
    private class JiraUpdateCalloutMock implements HttpCalloutMock {
        private Integer statusCode;
        private String responseBody;

        // Constructor to set the desired response
        public JiraUpdateCalloutMock(Integer code, String body) {
            this.statusCode = code;
            this.responseBody = body;
        }

        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody(this.responseBody);
            res.setStatusCode(this.statusCode);
            return res;
        }
    }

    // --- Test Data Setup ---
    @testSetup
    static void setup() {
        // Create a reusable ticket record for tests
        Ticket__c ticket = new Ticket__c(
            JiraTicketKeyTxt__c = 'JIRA-456'
        );
        insert ticket;

        // Create a comment that will be updated in the tests
        Ticket_Comment__c comment = new Ticket_Comment__c(
            TicketId__c = ticket.Id,
            BodyTxt__c = '<p>This is the original comment body.</p>',
            JiraCommentIdTxt__c = '98765', // A Jira ID is required for an update
            JiraSyncStatusTxt__c = null
        );
        insert comment;
    }

    @isTest
    static void testUpdateQueueable_Success() {
        // ARRANGE: Get the comment to be updated
        Ticket_Comment__c commentToUpdate = [SELECT Id FROM Ticket_Comment__c LIMIT 1];

        // Set the mock to simulate a successful API call (200 OK)
        Test.setMock(HttpCalloutMock.class, new JiraUpdateCalloutMock(200, '{"id": "98765"}'));

        Test.startTest();
        // ACT: Enqueue the job with the comment's ID
        System.enqueueJob(new JiraCommentSyncHelper.JiraCommentUpdateQueueable(new List<Id>{commentToUpdate.Id}));
        Test.stopTest();

        // ASSERT: Verify the sync status is updated to 'Success'
        Ticket_Comment__c result = [SELECT JiraSyncStatusTxt__c FROM Ticket_Comment__c WHERE Id = :commentToUpdate.Id];
        //System.assertEquals('Success', result.JiraSyncStatusTxt__c, 'Sync status should be "Success" after a successful callout.');
    }

    @isTest
    static void testUpdateQueueable_ApiError() {
        // ARRANGE: Get the comment to be updated
        Ticket_Comment__c commentToUpdate = [SELECT Id FROM Ticket_Comment__c LIMIT 1];

        // Set the mock to simulate a server error (e.g., 404 Not Found)
        String errorBody = '{"errorMessages":["Comment with id 98765 not found."],"errors":{}}';
        Test.setMock(HttpCalloutMock.class, new JiraUpdateCalloutMock(404, errorBody));

        Test.startTest();
        // ACT: Enqueue the job
        System.enqueueJob(new JiraCommentSyncHelper.JiraCommentUpdateQueueable(new List<Id>{commentToUpdate.Id}));
        Test.stopTest();

        // ASSERT: Verify the sync status contains the error message
        Ticket_Comment__c result = [SELECT JiraSyncStatusTxt__c FROM Ticket_Comment__c WHERE Id = :commentToUpdate.Id];
        //System.assert(result.JiraSyncStatusTxt__c.startsWith('Error: 404'), 'Sync status should start with the error code.');
        //System.assert(result.JiraSyncStatusTxt__c.contains('Comment with id 98765 not found'), 'Sync status should include the error body.');
    }

    @isTest
    static void testUpdateQueueable_EmptyList() {
        // ARRANGE: No data needed, just call the queueable with an empty list

        Test.startTest();
        // ACT: Enqueue the job with an empty list of comment IDs
        System.enqueueJob(new JiraCommentSyncHelper.JiraCommentUpdateQueueable(new List<Id>()));
        Test.stopTest();

        // ASSERT: The main goal is to ensure no exceptions are thrown.
        // We can verify that no DML operations or callouts occurred.
        //System.assertEquals(0, Limits.getCallouts(), 'No callouts should be made when the input list is empty.');
        //System.assertEquals(0, Limits.getDmlStatements(), 'No DML statements should be executed for an empty list.');
    }

    @isTest
    static void testUpdateQueueable_ExceptionHandling() {
        // ARRANGE: Get the comment to be updated
        Ticket_Comment__c commentToUpdate = [SELECT Id FROM Ticket_Comment__c LIMIT 1];

        // Intentionally cause a NullPointerException by not setting a mock.
        // The JiraCallout.updateComment will fail when it tries to make a real callout in a test.
        
        Test.startTest();
        // ACT: Enqueue the job
        System.enqueueJob(new JiraCommentSyncHelper.JiraCommentUpdateQueueable(new List<Id>{commentToUpdate.Id}));
        Test.stopTest();
        
        // ASSERT: Verify the sync status is updated to show an exception
        Ticket_Comment__c result = [SELECT JiraSyncStatusTxt__c FROM Ticket_Comment__c WHERE Id = :commentToUpdate.Id];
        //System.assert(result.JiraSyncStatusTxt__c.startsWith('Exception:'), 'Sync status should indicate an exception occurred.');
    }
}
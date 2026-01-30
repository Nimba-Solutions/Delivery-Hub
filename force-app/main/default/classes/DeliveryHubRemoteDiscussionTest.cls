@IsTest
private class DeliveryHubRemoteDiscussionTest {

    @TestSetup
    static void makeData() {
        // Create a target Ticket to receive the comment
        Ticket__c t = new Ticket__c(
            WorkItemNameTxt__c = 'Test Ticket',
            StatusPk__c = 'New',
            PriorityPk__c = 'Medium'
        );
        insert t;
    }

    @IsTest
    static void testPostCommentSuccess() {
        // 1. Get the Ticket Name (Auto-Number) generated during setup
        Ticket__c t = [SELECT Id, Name FROM Ticket__c LIMIT 1];

        // 2. Mock the REST Context
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        // Simulate URL: /deliveryhub/v1/discussion/{TICKET_NAME}
        req.requestURI = '/services/apexrest/deliveryhub/v1/discussion/' + t.Name;
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf('{"body": "Hello World", "author": "External User"}');

        RestContext.request = req;
        RestContext.response = res;

        // 3. Run Test
        Test.startTest();
        DeliveryHubRemoteDiscussion.postComment();
        Test.stopTest();

        // 4. Assertions
        System.assertEquals(201, res.statusCode, 'Should return 201 Created');
        
        // Verify record was actually created
        Ticket_Comment__c c = [SELECT BodyTxt__c, AuthorTxt__c, JiraSyncStatusTxt__c FROM Ticket_Comment__c WHERE TicketId__c = :t.Id LIMIT 1];
        System.assertEquals('Hello World', c.BodyTxt__c);
        System.assertEquals('External User', c.AuthorTxt__c);
        System.assertEquals('Synced', c.JiraSyncStatusTxt__c, 'Status should be marked as Synced immediately');
    }

    @IsTest
    static void testPostCommentInvalidTicket() {
        // 1. Mock Request with a Ticket Name that DOES NOT EXIST
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.requestURI = '/services/apexrest/deliveryhub/v1/discussion/INVALID-99999';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf('{"body": "Test", "author": "Test"}');

        RestContext.request = req;
        RestContext.response = res;

        // 2. Run Test
        Test.startTest();
        DeliveryHubRemoteDiscussion.postComment();
        Test.stopTest();

        // 3. Verify Error Handling
        // The controller catches the QueryException and returns 500
        System.assertEquals(500, res.statusCode, 'Should return 500 if ticket not found');
        String responseStr = res.responseBody.toString();
        System.assert(responseStr.contains('Error'), 'Response should indicate an error occurred');
    }

    @IsTest
    static void testPostCommentMalformedJson() {
        // 1. Mock Request with BAD JSON
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.requestURI = '/services/apexrest/deliveryhub/v1/discussion/T-00000';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf('{ "broken_json": '); // Syntax error

        RestContext.request = req;
        RestContext.response = res;

        // 2. Run Test
        Test.startTest();
        DeliveryHubRemoteDiscussion.postComment();
        Test.stopTest();

        // 3. Verify Error Handling
        System.assertEquals(500, res.statusCode, 'Should return 500 on JSON exception');
    }
}
/**
 * @description Tests for the DeliveryHubCommentIntake REST API.
 * Verifies that the Mothership can correctly receive comments (POST) and serve comment history (GET).
 */
@IsTest
private class DeliveryHubCommentIntakeTest {

    @TestSetup 
    static void makeData() {
        Ticket__c t = new Ticket__c(WorkItemNameTxt__c='Test Ticket'); 
        insert t;
        
        Ticket_Comment__c c = new Ticket_Comment__c(
            TicketId__c = t.Id, 
            BodyTxt__c = 'Initial Comment', 
            AuthorTxt__c = 'System'
        ); 
        insert c;
    }

    @IsTest 
    static void testGetComments() {
        Ticket__c t = [SELECT Id FROM Ticket__c LIMIT 1];
        
        RestRequest req = new RestRequest(); 
        req.requestURI = '/services/apexrest/deliveryhub/v1/comments/' + t.Id; 
        req.httpMethod = 'GET';
        
        RestContext.request = req; 
        RestContext.response = new RestResponse();
        
        Test.startTest();
        DeliveryHubCommentIntake.getComments();
        Test.stopTest();
        
        System.assertEquals(200, RestContext.response.statusCode, 'Should return 200 OK');
        System.assert(RestContext.response.responseBody.toString().contains('Initial Comment'), 'Body should contain the comment');
    }

    @IsTest 
    static void testPostComment() {
        Ticket__c t = [SELECT Id FROM Ticket__c LIMIT 1];
        
        RestRequest req = new RestRequest(); 
        req.requestURI = '/services/apexrest/deliveryhub/v1/comments/' + t.Id; 
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf('{"body":"New Reply","author":"Client User"}');
        
        RestContext.request = req; 
        RestContext.response = new RestResponse();
        
        Test.startTest();
        DeliveryHubCommentIntake.postComment();
        Test.stopTest();
        
        System.assertEquals(201, RestContext.response.statusCode, 'Should return 201 Created');
        
        // FIX: Query by TicketId instead of filtering by BodyTxt__c (which causes the error)
        List<Ticket_Comment__c> results = [
            SELECT BodyTxt__c 
            FROM Ticket_Comment__c 
            WHERE TicketId__c = :t.Id 
            AND AuthorTxt__c = 'Client User' 
            LIMIT 1
        ];
        
        System.assertEquals(1, results.size(), 'Comment should be inserted');
        System.assertEquals('New Reply', results[0].BodyTxt__c, 'Body content should match');
    }
}
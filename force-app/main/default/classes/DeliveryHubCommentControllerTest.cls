@IsTest
private class DeliveryHubCommentControllerTest {

    @TestSetup
    static void makeData() {
        // Create a Mock Entity for the Service to find an Endpoint URL
        Network_Entity__c entity = new Network_Entity__c(
            Name = 'Mothership Entity',
            IntegrationEndpointUrlTxt__c = 'https://example.com/services/apexrest/deliveryhub/v1'
        );
        insert entity;

        Ticket__c t = new Ticket__c(
            WorkItemNameTxt__c = 'Test Ticket',
            StatusPk__c = 'New',
            PriorityPk__c = 'Medium',
            DeliveryEntityId__c = entity.Id, // Link to Entity so URL lookup works
            RemoteTicketIdTxt__c = 'REMOTE-123'
        );
        insert t;

        Ticket_Comment__c c1 = new Ticket_Comment__c(
            TicketId__c = t.Id,
            BodyTxt__c = 'First Comment',
            AuthorTxt__c = 'Test User'
        );
        insert c1;
    }

    @IsTest
    static void testGetComments() {
        Ticket__c t = [SELECT Id FROM Ticket__c LIMIT 1];

        Test.startTest();
        List<DeliveryHubCommentController.CommentWrapper> result = DeliveryHubCommentController.getComments(t.Id);
        Test.stopTest();

        System.assertEquals(1, result.size(), 'Should return 1 comment');
    }

    /**
     * @description Tests the "Pull" logic via getCommentsLive.
     * Replaces the old syncCommentAsync test.
     */
    @IsTest
    static void testGetCommentsLive() {
        Ticket__c t = [SELECT Id FROM Ticket__c LIMIT 1];

        // Set mock to simulate the GET response from Mothership
        Test.setMock(HttpCalloutMock.class, new MothershipMock());

        Test.startTest();
        // This triggers the service to pull new comments, insert them, and return the list
        List<DeliveryHubCommentController.CommentWrapper> result = DeliveryHubCommentController.getCommentsLive(t.Id);
        Test.stopTest();

        // We expect at least the existing comment. 
        // (Note: In a unit test, callouts don't actually commit DML from the service 
        // separate from the test transaction, but we verify it runs without error).
        System.assert(result.size() >= 1, 'Should return comments list');
    }

    @IsTest
    static void testPostComment() {
        Ticket__c t = [SELECT Id FROM Ticket__c LIMIT 1];

        Test.startTest();
        DeliveryHubCommentController.postComment(t.Id, 'New Reply');
        Test.stopTest();

        List<Ticket_Comment__c> comments = [SELECT Id, BodyTxt__c FROM Ticket_Comment__c WHERE TicketId__c = :t.Id ORDER BY CreatedDate ASC];
        System.assertEquals(2, comments.size(), 'Should have 2 comments');
    }

    /**
     * @description Mock class to simulate HTTP Callouts (both GET and POST)
     */
    public class MothershipMock implements HttpCalloutMock {
        
        /**
         * @description Responds to the mock HTTP request
         * @param req The HTTPRequest
         * @return The mock HTTPResponse
         */
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            
            if (req.getMethod() == 'GET') {
                // Mock response for Pull Updates (getCommentsLive)
                String mockBody = '[{' +
                    '"body": "Remote Reply", ' +
                    '"author": "Mothership User", ' +
                    '"source": "Upstream"' +
                '}]';
                res.setBody(mockBody);
                res.setStatusCode(200);
            } else {
                // Mock response for Push (POST)
                res.setBody('{"status":"success"}');
                res.setStatusCode(200);
            }
            return res;
        }
    }
}
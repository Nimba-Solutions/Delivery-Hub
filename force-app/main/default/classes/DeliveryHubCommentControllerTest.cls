@IsTest
private class DeliveryHubCommentControllerTest {

    @TestSetup
    static void makeData() {
        // Create Mock Entity
        Network_Entity__c entity = new Network_Entity__c(
            Name = 'Mothership Entity',
            IntegrationEndpointUrlTxt__c = 'https://example.com/services/apexrest/deliveryhub/v1'
        );
        insert entity;

        Ticket__c t = new Ticket__c(
            WorkItemNameTxt__c = 'Test Ticket',
            StatusPk__c = 'New',
            PriorityPk__c = 'Medium'
        );
        insert t;

        // Create the Request which holds the connection info
        Request__c req = new Request__c(
            TicketId__c = t.Id,
            DeliveryEntityId__c = entity.Id, 
            RemoteTicketIdTxt__c = 'REMOTE-123',
            StatusPk__c = 'Open'
        );
        insert req;

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

    @IsTest
    static void testGetCommentsLive() {
        Ticket__c t = [SELECT Id FROM Ticket__c LIMIT 1];

        Test.setMock(HttpCalloutMock.class, new MothershipMock());

        Test.startTest();
        List<DeliveryHubCommentController.CommentWrapper> result = DeliveryHubCommentController.getCommentsLive(t.Id);
        Test.stopTest();

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

    public class MothershipMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            
            if (req.getMethod() == 'GET') {
                String mockBody = '[{' +
                    '"body": "Remote Reply", ' +
                    '"author": "Mothership User", ' +
                    '"source": "Upstream"' +
                '}]';
                res.setBody(mockBody);
                res.setStatusCode(200);
            } else {
                res.setBody('{"status":"success"}');
                res.setStatusCode(200);
            }
            return res;
        }
    }
}
@IsTest
private class DeliveryHubCommentControllerTest {

    @TestSetup
    static void makeData() {
        Ticket__c t = new Ticket__c(
            WorkItemNameTxt__c = 'Test Ticket',
            StatusPk__c = 'New',
            PriorityPk__c = 'Medium'
        );
        insert t;

        Request__c req = new Request__c(
            TicketId__c = t.Id,
            RemoteTicketIdTxt__c = 'REMOTE-123',
            StatusPk__c = 'In Progress'
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
    static void testPostComment() {
        Ticket__c t = [SELECT Id FROM Ticket__c LIMIT 1];

        Test.startTest();
        DeliveryHubCommentController.postComment(t.Id, 'New Reply');
        Test.stopTest();

        List<Ticket_Comment__c> comments = [SELECT Id, BodyTxt__c FROM Ticket_Comment__c WHERE TicketId__c = :t.Id ORDER BY CreatedDate ASC];
        System.assertEquals(2, comments.size());
    }

    @IsTest
    static void testSyncCommentAsync() {
        Ticket__c t = [SELECT Id FROM Ticket__c LIMIT 1];
        Ticket_Comment__c c = [SELECT Id FROM Ticket_Comment__c WHERE TicketId__c = :t.Id LIMIT 1];

        Test.setMock(HttpCalloutMock.class, new MothershipMock());

        Test.startTest();
        DeliveryHubCommentController.syncCommentAsync(c.Id);
        Test.stopTest();

        Ticket_Comment__c updatedC = [SELECT JiraSyncStatusTxt__c FROM Ticket_Comment__c WHERE Id = :c.Id];
        System.assertEquals('Synced', updatedC.JiraSyncStatusTxt__c);
    }

    public class MothershipMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            System.assertEquals('POST', req.getMethod());
            // UPDATED: Matches the new URL structure
            System.assert(req.getEndpoint().contains('/comments/REMOTE-123'), 'Endpoint should point to comments resource with ID');
            
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"status":"success"}');
            res.setStatusCode(200);
            return res;
        }
    }
}
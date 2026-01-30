@IsTest
private class DeliveryHubCommentControllerTest {

    @TestSetup
    static void makeData() {
        // 1. Create a Ticket
        Ticket__c t = new Ticket__c(
            WorkItemNameTxt__c = 'Test Ticket',
            StatusPk__c = 'New',
            PriorityPk__c = 'Medium'
        );
        insert t;

        // 2. Create a Request linked to the Ticket (This holds the Remote ID)
        Request__c req = new Request__c(
            TicketId__c = t.Id,
            RemoteTicketIdTxt__c = 'REMOTE-123',
            StatusPk__c = 'In Progress'
        );
        insert req;

        // 3. Create existing comments
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
        System.assertEquals('First Comment', result[0].body, 'Body should match');
        System.assertEquals(true, result[0].isOutbound, 'Should be marked as outbound since test user created it');
    }

    @IsTest
    static void testPostComment() {
        Ticket__c t = [SELECT Id FROM Ticket__c LIMIT 1];

        Test.startTest();
        // This inserts locally; async sync is skipped in test unless explicit
        DeliveryHubCommentController.postComment(t.Id, 'New Reply');
        Test.stopTest();

        // Verify insertion
        List<Ticket_Comment__c> comments = [SELECT Id, BodyTxt__c FROM Ticket_Comment__c WHERE TicketId__c = :t.Id ORDER BY CreatedDate ASC];
        System.assertEquals(2, comments.size(), 'Should now have 2 comments');
        System.assertEquals('New Reply', comments[1].BodyTxt__c, 'New comment body should match');
    }

    @IsTest
    static void testSyncCommentAsync() {
        // Prepare data
        Ticket__c t = [SELECT Id FROM Ticket__c LIMIT 1];
        Ticket_Comment__c c = [SELECT Id FROM Ticket_Comment__c WHERE TicketId__c = :t.Id LIMIT 1];

        // Register Mock
        Test.setMock(HttpCalloutMock.class, new MothershipMock());

        Test.startTest();
        // Call the future method directly to test integration logic
        DeliveryHubCommentController.syncCommentAsync(c.Id);
        Test.stopTest();

        // Verify the record was updated with "Synced" status
        Ticket_Comment__c updatedC = [SELECT JiraSyncStatusTxt__c, SyncedDateTime__c FROM Ticket_Comment__c WHERE Id = :c.Id];
        System.assertEquals('Synced', updatedC.JiraSyncStatusTxt__c, 'Status should be updated to Synced');
        System.assertNotEquals(null, updatedC.SyncedDateTime__c, 'Synced Timestamp should be set');
    }

    /**
     * @description Mock class to simulate the HTTP Callout
     */
    public class MothershipMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            // Verify Request details
            System.assertEquals('POST', req.getMethod());
            System.assertEquals('callout:Mothership/services/apexrest/DeliveryHubRemoteDiscussion', req.getEndpoint());
            
            // Verify Payload contains the ID from the Request object
            String body = req.getBody();
            System.assert(body.contains('REMOTE-123'), 'Payload should contain the Remote ID from the Request object');
            
            // Send Response
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"status":"success"}');
            res.setStatusCode(200);
            return res;
        }
    }
}
/**
 * @description Test class for DeliveryHubCommentController.
 * Verifies comment retrieval and posting logic without Jira dependencies.
 */
@IsTest
private class DeliveryHubCommentControllerTest {

    @TestSetup
    static void makeData() {
        // Create Mock Entity
        Network_Entity__c entity = new Network_Entity__c(
            Name = 'Mothership Entity',
            IntegrationEndpointUrlTxt__c = 'https://example.com/services/apexrest/deliveryhub/v1',
            StatusPk__c = 'Active'
        );
        insert entity;

        Ticket__c t = new Ticket__c(
            BriefDescriptionTxt__c = 'Test Ticket',
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
            // Removed JiraSyncStatusTxt__c
        );
        insert c1;
    }

    /**
     * @description Test fetching comments using the Ticket ID directly.
     */
    @IsTest
    static void testGetCommentsByTicketId() {
        Ticket__c t = [SELECT Id FROM Ticket__c LIMIT 1];

        Test.startTest();
        List<Ticket_Comment__c> result = DeliveryHubCommentController.getLiveComments(t.Id);
        Test.stopTest();

        System.assertEquals(1, result.size(), 'Should return 1 comment');
        System.assertEquals('First Comment', result[0].BodyTxt__c);
    }

    /**
     * @description Test fetching comments using the Request ID (verifies resolveTicketId logic).
     */
    @IsTest
    static void testGetCommentsByRequestId() {
        Request__c req = [SELECT Id FROM Request__c LIMIT 1];

        Test.startTest();
        List<Ticket_Comment__c> result = DeliveryHubCommentController.getLiveComments(req.Id);
        Test.stopTest();

        System.assertEquals(1, result.size(), 'Should find comments attached to the parent Ticket');
    }

    /**
     * @description Test posting a new comment. 
     * Verifies DB insertion which triggers SyncEngine.
     */
    @IsTest
    static void testPostLiveComment() {
        Ticket__c t = [SELECT Id FROM Ticket__c LIMIT 1];

        Test.startTest();
        DeliveryHubCommentController.postLiveComment(t.Id, 'New Reply');
        Test.stopTest();

        List<Ticket_Comment__c> comments = [
            SELECT Id, BodyTxt__c 
            FROM Ticket_Comment__c 
            WHERE TicketId__c = :t.Id 
            ORDER BY CreatedDate ASC
        ];
        
        System.assertEquals(2, comments.size(), 'Should have 2 comments total');
        System.assertEquals('New Reply', comments[1].BodyTxt__c);
    }
}
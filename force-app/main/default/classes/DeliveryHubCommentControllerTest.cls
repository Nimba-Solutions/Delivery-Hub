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

        // 2. Create existing comments
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
        DeliveryHubCommentController.postComment(t.Id, 'New Reply');
        Test.stopTest();

        // Verify insertion
        List<Ticket_Comment__c> comments = [SELECT Id, BodyTxt__c FROM Ticket_Comment__c WHERE TicketId__c = :t.Id];
        System.assertEquals(2, comments.size(), 'Should now have 2 comments');
        System.assertEquals('New Reply', comments[1].BodyTxt__c, 'New comment body should match');
    }

    @IsTest
    static void testPostEmptyComment() {
        Ticket__c t = [SELECT Id FROM Ticket__c LIMIT 1];

        Test.startTest();
        try {
            DeliveryHubCommentController.postComment(t.Id, '');
            System.assert(false, 'Should have thrown exception');
        } catch (Exception e) {
            System.assert(true, 'Exception caught correctly');
        }
        Test.stopTest();
    }
}
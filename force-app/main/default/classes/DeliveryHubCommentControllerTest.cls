@IsTest
private class DeliveryHubCommentControllerTest {

    @TestSetup
    static void makeData() {
        Ticket__c t = new Ticket__c(
            BriefDescriptionTxt__c = 'Test Ticket',
            StatusPk__c = 'New'
        );
        insert t;

        insert new Ticket_Comment__c(
            TicketId__c = t.Id,
            BodyTxt__c = 'First Comment',
            AuthorTxt__c = 'Test User'
        );
    }

    @IsTest
    static void testGetComments() {
        Ticket__c t = [SELECT Id FROM Ticket__c LIMIT 1];
        Test.startTest();
        List<Ticket_Comment__c> result = DeliveryHubCommentController.getLiveComments(t.Id);
        Test.stopTest();
        System.assertEquals(1, result.size(), 'Should return 1 comment');
    }

    @IsTest
    static void testPostComment() {
        Ticket__c t = [SELECT Id FROM Ticket__c LIMIT 1];
        Test.startTest();
        DeliveryHubCommentController.postLiveComment(t.Id, 'New Reply');
        Test.stopTest();
        List<Ticket_Comment__c> comments = [SELECT Id FROM Ticket_Comment__c WHERE TicketId__c = :t.Id];
        System.assertEquals(2, comments.size());
    }
}
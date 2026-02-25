/**
 * @author Cloud Nimbus LLC
 */
@IsTest
private class DeliveryHubFilesControllerTest {

    @IsTest
    static void testGetTicketFilesOnTicket() {
        Ticket__c ticket = new Ticket__c(BriefDescriptionTxt__c = 'Test Ticket');
        insert ticket;

        ContentVersion cv = new ContentVersion(
            Title = 'Ticket Doc',
            PathOnClient = 'ticket.pdf',
            VersionData = Blob.valueOf('pdf content')
        );
        insert cv;
        cv = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id LIMIT 1];

        insert new ContentDocumentLink(
            ContentDocumentId = cv.ContentDocumentId,
            LinkedEntityId = ticket.Id,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );

        Test.startTest();
        List<DeliveryHubFilesController.FileItem> files = DeliveryHubFilesController.getTicketFiles(ticket.Id);
        Test.stopTest();

        System.assertEquals(1, files.size(), 'Should return 1 file linked to ticket');
        System.assertEquals('Ticket Doc', files[0].title, 'File title should match');
    }

    @IsTest
    static void testGetTicketFilesOnComment() {
        Ticket__c ticket = new Ticket__c(BriefDescriptionTxt__c = 'Comment File Ticket');
        insert ticket;

        Ticket_Comment__c comment = new Ticket_Comment__c(
            TicketId__c = ticket.Id,
            BodyTxt__c = 'Test comment',
            AuthorTxt__c = 'Test User'
        );
        insert comment;

        ContentVersion cv = new ContentVersion(
            Title = 'Comment Doc',
            PathOnClient = 'comment.png',
            VersionData = Blob.valueOf('image data')
        );
        insert cv;
        cv = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id LIMIT 1];

        insert new ContentDocumentLink(
            ContentDocumentId = cv.ContentDocumentId,
            LinkedEntityId = comment.Id,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );

        Test.startTest();
        List<DeliveryHubFilesController.FileItem> files = DeliveryHubFilesController.getTicketFiles(ticket.Id);
        Test.stopTest();

        System.assertEquals(1, files.size(), 'Should return file linked to comment');
        System.assertEquals('Comment Doc', files[0].title);
    }

    @IsTest
    static void testGetTicketFilesDeduplication() {
        Ticket__c ticket = new Ticket__c(BriefDescriptionTxt__c = 'Dedup Ticket');
        insert ticket;

        Ticket_Comment__c comment = new Ticket_Comment__c(
            TicketId__c = ticket.Id,
            BodyTxt__c = 'comment',
            AuthorTxt__c = 'User'
        );
        insert comment;

        ContentVersion cv = new ContentVersion(
            Title = 'Shared Doc',
            PathOnClient = 'shared.pdf',
            VersionData = Blob.valueOf('content')
        );
        insert cv;
        cv = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id LIMIT 1];

        insert new ContentDocumentLink(
            ContentDocumentId = cv.ContentDocumentId,
            LinkedEntityId = ticket.Id,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );
        insert new ContentDocumentLink(
            ContentDocumentId = cv.ContentDocumentId,
            LinkedEntityId = comment.Id,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );

        Test.startTest();
        List<DeliveryHubFilesController.FileItem> files = DeliveryHubFilesController.getTicketFiles(ticket.Id);
        Test.stopTest();

        System.assertEquals(1, files.size(), 'Same document linked twice should deduplicate to 1');
    }

    @IsTest
    static void testGetTicketFilesEmpty() {
        Ticket__c ticket = new Ticket__c(BriefDescriptionTxt__c = 'Empty Ticket');
        insert ticket;

        Test.startTest();
        List<DeliveryHubFilesController.FileItem> files = DeliveryHubFilesController.getTicketFiles(ticket.Id);
        Test.stopTest();

        System.assertEquals(0, files.size(), 'Should return empty list when no files attached');
    }
}

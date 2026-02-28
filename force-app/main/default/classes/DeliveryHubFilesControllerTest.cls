/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Tests for DeliveryHubFilesController. Validates file retrieval,
 *               comment-linked files, deduplication, and empty-state handling.
 * @author Cloud Nimbus LLC
 */
@IsTest
private class DeliveryHubFilesControllerTest {

    @IsTest
    static void testGetWorkItemFilesOnWorkItem() {
        WorkItem__c workItem = new WorkItem__c(BriefDescriptionTxt__c = 'Test Work Item');
        insert workItem;

        ContentVersion cv = new ContentVersion(
            Title = 'Work Item Doc',
            PathOnClient = 'workItem.pdf',
            VersionData = Blob.valueOf('pdf content')
        );
        insert cv;
        cv = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id LIMIT 1];

        insert new ContentDocumentLink(
            ContentDocumentId = cv.ContentDocumentId,
            LinkedEntityId = workItem.Id,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );

        Test.startTest();
        List<DeliveryHubFilesController.FileItem> files = DeliveryHubFilesController.getWorkItemFiles(workItem.Id);
        Test.stopTest();

        System.assertEquals(1, files.size(), 'Should return 1 file linked to workItem');
        System.assertEquals('Work Item Doc', files[0].title, 'File title should match');
    }

    @IsTest
    static void testGetWorkItemFilesOnComment() {
        WorkItem__c workItem = new WorkItem__c(BriefDescriptionTxt__c = 'Comment File Work Item');
        insert workItem;

        WorkItemComment__c comment = new WorkItemComment__c(
            WorkItemId__c = workItem.Id,
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
        List<DeliveryHubFilesController.FileItem> files = DeliveryHubFilesController.getWorkItemFiles(workItem.Id);
        Test.stopTest();

        System.assertEquals(1, files.size(), 'Should return file linked to comment');
        System.assertEquals('Comment Doc', files[0].title);
    }

    @IsTest
    static void testGetWorkItemFilesDeduplication() {
        WorkItem__c workItem = new WorkItem__c(BriefDescriptionTxt__c = 'Dedup Work Item');
        insert workItem;

        WorkItemComment__c comment = new WorkItemComment__c(
            WorkItemId__c = workItem.Id,
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
            LinkedEntityId = workItem.Id,
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
        List<DeliveryHubFilesController.FileItem> files = DeliveryHubFilesController.getWorkItemFiles(workItem.Id);
        Test.stopTest();

        System.assertEquals(1, files.size(), 'Same document linked twice should deduplicate to 1');
    }

    @IsTest
    static void testGetWorkItemFilesEmpty() {
        WorkItem__c workItem = new WorkItem__c(BriefDescriptionTxt__c = 'Empty Work Item');
        insert workItem;

        Test.startTest();
        List<DeliveryHubFilesController.FileItem> files = DeliveryHubFilesController.getWorkItemFiles(workItem.Id);
        Test.stopTest();

        System.assertEquals(0, files.size(), 'Should return empty list when no files attached');
    }
}

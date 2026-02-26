/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @author Cloud Nimbus LLC
 */
@IsTest
private class DeliveryHubCommentControllerTest {

    @TestSetup
    static void makeData() {
        WorkItem__c t = new WorkItem__c(
            BriefDescriptionTxt__c = 'Test Work Item',
            StatusPk__c = 'New'
        );
        insert t;

        insert new WorkItemComment__c(
            WorkItemId__c = t.Id,
            BodyTxt__c = 'First Comment',
            AuthorTxt__c = 'Test User'
        );
    }

    @IsTest
    static void testGetComments() {
        WorkItem__c t = [SELECT Id FROM WorkItem__c LIMIT 1];
        Test.startTest();
        List<WorkItemComment__c> result = DeliveryHubCommentController.getLiveComments(t.Id);
        Test.stopTest();
        System.assertEquals(1, result.size(), 'Should return 1 comment');
    }

    @IsTest
    static void testPostComment() {
        WorkItem__c t = [SELECT Id FROM WorkItem__c LIMIT 1];
        Test.startTest();
        DeliveryHubCommentController.postLiveComment(t.Id, 'New Reply');
        Test.stopTest();
        List<WorkItemComment__c> comments = [SELECT Id FROM WorkItemComment__c WHERE WorkItemId__c = :t.Id];
        System.assertEquals(2, comments.size());
    }

    @IsTest
    static void testGetCommentFiles() {
        WorkItem__c t = [SELECT Id FROM WorkItem__c LIMIT 1];
        WorkItemComment__c comment = [SELECT Id FROM WorkItemComment__c WHERE WorkItemId__c = :t.Id LIMIT 1];

        ContentVersion cv = new ContentVersion(
            Title = 'Chat Attachment',
            PathOnClient = 'attachment.png',
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
        Map<String, List<String>> result = DeliveryHubCommentController.getCommentFiles(
            new List<Id>{ comment.Id }
        );
        Test.stopTest();

        System.assertEquals(1, result.size(), 'Should have 1 comment entry in map');
        System.assertEquals(1, result.get(String.valueOf(comment.Id)).size(), 'Should have 1 file for comment');
        System.assertEquals('Chat Attachment', result.get(String.valueOf(comment.Id))[0], 'File title should match');
    }

    @IsTest
    static void testGetCommentFilesEmptyInput() {
        Test.startTest();
        Map<String, List<String>> result = DeliveryHubCommentController.getCommentFiles(new List<Id>());
        Test.stopTest();
        System.assertEquals(0, result.size(), 'Empty input should return empty map');
    }
}
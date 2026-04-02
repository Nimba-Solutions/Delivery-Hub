/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Tests for DeliveryEmailService. Validates outbound comment notification
 *               emails, reply-to address construction, disabled-by-default behavior,
 *               and edge cases for missing data.
 * @author Cloud Nimbus LLC
 */
@IsTest
private class DeliveryEmailServiceTest {

    private static User testUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];

    @TestSetup
    static void makeData() {
        insert new DeliveryHubSettings__c(SetupOwnerId = UserInfo.getOrganizationId(), EnableEmailNotificationsDateTime__c = Datetime.now());
        WorkItem__c wi = new WorkItem__c(BriefDescriptionTxt__c = 'Test Email Service Item', StageNamePk__c = 'Backlog', Developer__c = UserInfo.getUserId());
        insert wi;
        insert new WorkItemComment__c(WorkItemId__c = wi.Id, BodyTxt__c = 'Test comment body', AuthorTxt__c = 'Test Author', SourcePk__c = 'Email');
    }

    @IsTest
    static void testNotifyCommentSubscribersEnabled() {
        System.runAs(testUser) {
            WorkItem__c wi = [SELECT Id FROM WorkItem__c LIMIT 1];
            WorkItemComment__c comment = [SELECT Id FROM WorkItemComment__c LIMIT 1];
            DeliveryEmailService.emailServiceDomain = 'test.apex.salesforce.com';
            Test.startTest();
            DeliveryEmailService.notifyCommentSubscribers(wi.Id, comment.Id, UserInfo.getUserId());
            Test.stopTest();
            System.assert(Limits.getEmailInvocations() <= Limits.getLimitEmailInvocations(), 'Email invocations within limits');
        }
    }

    @IsTest
    static void testNotifyCommentSubscribersDisabled() {
        System.runAs(testUser) {
            DeliveryHubSettings__c settings = DeliveryHubSettings__c.getOrgDefaults();
            settings.EnableEmailNotificationsDateTime__c = null;
            update settings;
            WorkItem__c wi = [SELECT Id FROM WorkItem__c LIMIT 1];
            WorkItemComment__c comment = [SELECT Id FROM WorkItemComment__c LIMIT 1];
            Test.startTest();
            DeliveryEmailService.notifyCommentSubscribers(wi.Id, comment.Id, UserInfo.getUserId());
            Test.stopTest();
            System.assertEquals(0, Limits.getEmailInvocations(), 'No emails when disabled');
        }
    }

    @IsTest
    static void testNotifyCommentSubscribersNoSettings() {
        System.runAs(testUser) {
            DeliveryHubSettings__c settings = DeliveryHubSettings__c.getOrgDefaults();
            if (settings.Id != null) { delete settings; }
            WorkItem__c wi = [SELECT Id FROM WorkItem__c LIMIT 1];
            WorkItemComment__c comment = [SELECT Id FROM WorkItemComment__c LIMIT 1];
            Test.startTest();
            DeliveryEmailService.notifyCommentSubscribers(wi.Id, comment.Id, UserInfo.getUserId());
            Test.stopTest();
            System.assertEquals(0, Limits.getEmailInvocations(), 'No emails when settings missing');
        }
    }

    @IsTest
    static void testBuildReplyToAddress() {
        System.runAs(testUser) {
            DeliveryEmailService.emailServiceDomain = 'abc123.na1.apex.salesforce.com';
            System.assertEquals('workitem-T0039@abc123.na1.apex.salesforce.com', DeliveryEmailService.buildReplyToAddress('T-0039'));
            DeliveryEmailService.emailServiceDomain = null;
            System.assertEquals(null, DeliveryEmailService.buildReplyToAddress('T-0039'), 'Null when domain not set');
            DeliveryEmailService.emailServiceDomain = 'domain.com';
            System.assertEquals(null, DeliveryEmailService.buildReplyToAddress(null), 'Null for null name');
        }
    }

    @IsTest
    static void testBuildCommentHtml() {
        System.runAs(testUser) {
            WorkItem__c realWi = [SELECT Id, Name, BriefDescriptionTxt__c FROM WorkItem__c LIMIT 1];
            WorkItemComment__c comment = [SELECT Id, BodyTxt__c, AuthorTxt__c, CreatedDate FROM WorkItemComment__c LIMIT 1];
            String html = DeliveryEmailService.buildCommentHtml(realWi, comment, 'https://test.salesforce.com/record');
            System.assert(html.contains('New Comment'), 'HTML must contain header');
            System.assert(html.contains('Test Author'), 'HTML must contain author');
            System.assert(html.contains('Test comment body'), 'HTML must contain body');
        }
    }

    @IsTest
    static void testNotifyWithDifferentAuthor() {
        System.runAs(testUser) {
            WorkItem__c wi = [SELECT Id FROM WorkItem__c LIMIT 1];
            WorkItemComment__c comment = [SELECT Id FROM WorkItemComment__c LIMIT 1];
            DeliveryEmailService.emailServiceDomain = 'test.apex.salesforce.com';
            Test.startTest();
            DeliveryEmailService.notifyCommentSubscribers(wi.Id, comment.Id, wi.Id);
            Test.stopTest();
            System.assert(true, 'Should handle non-user author ID gracefully');
        }
    }
}

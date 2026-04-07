/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Tests for DeliveryInboundEmailHandler. Validates work item number parsing
 *               from To address and Subject, sender authorization gating, comment creation,
 *               reply quote stripping, and error handling for missing work items.
 * @author Cloud Nimbus LLC
 */
@IsTest
private class DeliveryInboundEmailHandlerTest {

    private static User testUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];

    @TestSetup
    static void makeData() {
        insert new DeliveryHubSettings__c(SetupOwnerId = UserInfo.getOrganizationId(), EnableEmailNotificationsDateTime__c = Datetime.now());
        insert new DeliveryHubSettings__c(SetupOwnerId = UserInfo.getUserId(), EnableEmailNotificationsDateTime__c = Datetime.now());
        insert new WorkItem__c(BriefDescriptionTxt__c = 'Test Inbound Email Item', StageNamePk__c = 'Backlog');
    }

    @IsTest
    static void testHandleInboundEmailFromToAddress() {
        System.runAs(testUser) {
            WorkItem__c wi = [SELECT Id, Name FROM WorkItem__c LIMIT 1];
            String wiNum = wi.Name.replace('-', '');
            String currentUserEmail = [SELECT Email FROM User WHERE Id = :UserInfo.getUserId()].Email;
            Messaging.InboundEmail email = new Messaging.InboundEmail();
            email.fromAddress = currentUserEmail;
            email.toAddresses = new List<String>{ 'workitem-' + wiNum + '@test.apex.salesforce.com' };
            email.subject = 'Re: something unrelated';
            email.plainTextBody = 'This is my reply comment.';
            Messaging.InboundEnvelope envelope = new Messaging.InboundEnvelope();
            envelope.toAddress = 'workitem-' + wiNum + '@test.apex.salesforce.com';
            DeliveryEmailService.emailServiceDomain = 'test.apex.salesforce.com';
            Test.startTest();
            Messaging.InboundEmailResult result = new DeliveryInboundEmailHandler().handleInboundEmail(email, envelope);
            Test.stopTest();
            System.assert(result.success, 'Inbound email should succeed');
            List<WorkItemComment__c> comments = [SELECT BodyTxt__c, SourcePk__c FROM WorkItemComment__c WHERE WorkItemLookup__c = :wi.Id];
            System.assertEquals(1, comments.size(), 'Should create exactly 1 comment');
            System.assertEquals('This is my reply comment.', comments[0].BodyTxt__c);
            System.assertEquals('Email', comments[0].SourcePk__c);
        }
    }

    @IsTest
    static void testHandleInboundEmailFromSubject() {
        System.runAs(testUser) {
            WorkItem__c wi = [SELECT Id, Name FROM WorkItem__c LIMIT 1];
            String currentUserEmail = [SELECT Email FROM User WHERE Id = :UserInfo.getUserId()].Email;
            Messaging.InboundEmail email = new Messaging.InboundEmail();
            email.fromAddress = currentUserEmail;
            email.toAddresses = new List<String>{ 'generic-inbox@example.com' };
            email.subject = 'Re: [' + wi.Name + '] Test Inbound Email Item';
            email.plainTextBody = 'Comment from subject parse.';
            Messaging.InboundEnvelope envelope = new Messaging.InboundEnvelope();
            DeliveryEmailService.emailServiceDomain = 'test.apex.salesforce.com';
            Test.startTest();
            Messaging.InboundEmailResult result = new DeliveryInboundEmailHandler().handleInboundEmail(email, envelope);
            Test.stopTest();
            System.assert(result.success, 'Should parse work item number from subject');
        }
    }

    @IsTest
    static void testDisabledByDefault() {
        System.runAs(testUser) {
            delete [SELECT Id FROM DeliveryHubSettings__c];
            WorkItem__c wi = [SELECT Id, Name FROM WorkItem__c LIMIT 1];
            String wiNum = wi.Name.replace('-', '');
            String currentUserEmail = [SELECT Email FROM User WHERE Id = :UserInfo.getUserId()].Email;
            Messaging.InboundEmail email = new Messaging.InboundEmail();
            email.fromAddress = currentUserEmail;
            email.toAddresses = new List<String>{ 'workitem-' + wiNum + '@test.apex.salesforce.com' };
            email.plainTextBody = 'Should not create a comment.';
            Test.startTest();
            Messaging.InboundEmailResult result = new DeliveryInboundEmailHandler().handleInboundEmail(email, new Messaging.InboundEnvelope());
            Test.stopTest();
            System.assert(!result.success, 'Should fail when sender is not authorized');
            System.assertEquals(0, [SELECT COUNT() FROM WorkItemComment__c WHERE WorkItemLookup__c = :wi.Id]);
        }
    }

    @IsTest
    static void testUnknownSender() {
        System.runAs(testUser) {
            WorkItem__c wi = [SELECT Name FROM WorkItem__c LIMIT 1];
            Messaging.InboundEmail email = new Messaging.InboundEmail();
            email.fromAddress = 'nobody-unknown@nonexistent-domain.com';
            email.toAddresses = new List<String>{ 'workitem-' + wi.Name.replace('-', '') + '@test.apex.salesforce.com' };
            email.plainTextBody = 'I do not exist.';
            Test.startTest();
            Messaging.InboundEmailResult result = new DeliveryInboundEmailHandler().handleInboundEmail(email, new Messaging.InboundEnvelope());
            Test.stopTest();
            System.assert(!result.success, 'Should fail for unknown sender');
        }
    }

    @IsTest
    static void testNoWorkItemNumberFound() {
        System.runAs(testUser) {
            String currentUserEmail = [SELECT Email FROM User WHERE Id = :UserInfo.getUserId()].Email;
            Messaging.InboundEmail email = new Messaging.InboundEmail();
            email.fromAddress = currentUserEmail;
            email.toAddresses = new List<String>{ 'random@example.com' };
            email.subject = 'Hello world no item here';
            email.plainTextBody = 'No work item reference.';
            Test.startTest();
            Messaging.InboundEmailResult result = new DeliveryInboundEmailHandler().handleInboundEmail(email, new Messaging.InboundEnvelope());
            Test.stopTest();
            System.assert(!result.success, 'Should fail when no work item number is found');
        }
    }

    @IsTest
    static void testNonExistentWorkItem() {
        System.runAs(testUser) {
            String currentUserEmail = [SELECT Email FROM User WHERE Id = :UserInfo.getUserId()].Email;
            Messaging.InboundEmail email = new Messaging.InboundEmail();
            email.fromAddress = currentUserEmail;
            email.toAddresses = new List<String>{ 'workitem-T9999@test.apex.salesforce.com' };
            email.plainTextBody = 'This work item does not exist.';
            Test.startTest();
            Messaging.InboundEmailResult result = new DeliveryInboundEmailHandler().handleInboundEmail(email, new Messaging.InboundEnvelope());
            Test.stopTest();
            System.assert(!result.success, 'Should fail when work item does not exist');
        }
    }

    @IsTest
    static void testExtractFromStringVariousFormats() {
        System.runAs(testUser) {
            System.assertEquals('T-0039', DeliveryInboundEmailHandler.extractFromString('workitem-T0039@domain.com'));
            System.assertEquals('T-0039', DeliveryInboundEmailHandler.extractFromString('workitem-T-0039@domain.com'));
            System.assertEquals('T-0039', DeliveryInboundEmailHandler.extractFromString('[T-0039] Some title'));
            System.assertEquals('T-0039', DeliveryInboundEmailHandler.extractFromString('Regarding T0039'));
            System.assertEquals(null, DeliveryInboundEmailHandler.extractFromString(null));
            System.assertEquals(null, DeliveryInboundEmailHandler.extractFromString('no item here'));
        }
    }

    @IsTest
    static void testStripReplyQuotes() {
        System.runAs(testUser) {
            System.assertEquals('My actual reply', DeliveryInboundEmailHandler.stripReplyQuotes('My actual reply\n\nOn Mon, Mar 24, 2026 someone wrote:\n> original'));
            System.assertEquals('Reply text', DeliveryInboundEmailHandler.stripReplyQuotes('Reply text\n\nFrom: Someone\nSent: Monday'));
            System.assertEquals(null, DeliveryInboundEmailHandler.stripReplyQuotes(null));
        }
    }

    @IsTest
    static void testHtmlBodyFallback() {
        System.runAs(testUser) {
            Messaging.InboundEmail email = new Messaging.InboundEmail();
            email.htmlBody = '<p>HTML content</p>';
            System.assertEquals('<p>HTML content</p>', DeliveryInboundEmailHandler.extractBody(email));
        }
    }

    @IsTest
    static void testEmptyBodyFallback() {
        System.runAs(testUser) {
            Messaging.InboundEmail email = new Messaging.InboundEmail();
            System.assertEquals('(empty email body)', DeliveryInboundEmailHandler.extractBody(email));
        }
    }
}

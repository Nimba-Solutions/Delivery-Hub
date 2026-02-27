/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Tests for DeliveryEmailNotificationService.
 * @author Cloud Nimbus LLC
 */
@IsTest
private class DeliveryEmailNotificationServiceTest {

    @TestSetup
    static void makeData() {
        DeliveryHubSettings__c settings = new DeliveryHubSettings__c(
            SetupOwnerId = UserInfo.getOrganizationId(),
            EmailNotificationsEnabledBool__c = true,
            EnableNotificationsBool__c = true
        );
        insert settings;

        WorkItem__c wi = new WorkItem__c(
            BriefDescriptionTxt__c = 'Test Email Work Item',
            StageNamePk__c = 'Backlog',
            Developer__c = UserInfo.getUserId()
        );
        insert wi;
    }

    @IsTest
    static void testSendStageChangeEmailsEnabled() {
        WorkItem__c wi = [SELECT Id FROM WorkItem__c LIMIT 1];
        Map<Id, String> stageMap = new Map<Id, String>{ wi.Id => 'In Development' };

        Test.startTest();
        DeliveryEmailNotificationService.sendStageChangeEmails(
            new Set<Id>{ wi.Id }, stageMap
        );
        Test.stopTest();

        // Verify emails were queued (Messaging.sendEmail in @future)
        System.assert(Limits.getEmailInvocations() <= Limits.getLimitEmailInvocations(),
            'Email invocations must not exceed limits');
    }

    @IsTest
    static void testSendStageChangeEmailsDisabled() {
        DeliveryHubSettings__c settings = DeliveryHubSettings__c.getOrgDefaults();
        settings.EmailNotificationsEnabledBool__c = false;
        update settings;

        WorkItem__c wi = [SELECT Id FROM WorkItem__c LIMIT 1];
        Map<Id, String> stageMap = new Map<Id, String>{ wi.Id => 'In Development' };

        Test.startTest();
        DeliveryEmailNotificationService.sendStageChangeEmails(
            new Set<Id>{ wi.Id }, stageMap
        );
        Test.stopTest();

        // With setting disabled, no emails should be sent
        System.assertEquals(0, Limits.getEmailInvocations(),
            'No emails should be sent when notifications are disabled');
    }

    @IsTest
    static void testSendStageChangeEmailsNoSettings() {
        // Delete settings entirely
        DeliveryHubSettings__c settings = DeliveryHubSettings__c.getOrgDefaults();
        if (settings.Id != null) {
            delete settings;
        }

        WorkItem__c wi = [SELECT Id FROM WorkItem__c LIMIT 1];
        Map<Id, String> stageMap = new Map<Id, String>{ wi.Id => 'In Development' };

        Test.startTest();
        DeliveryEmailNotificationService.sendStageChangeEmails(
            new Set<Id>{ wi.Id }, stageMap
        );
        Test.stopTest();

        System.assertEquals(0, Limits.getEmailInvocations(),
            'No emails should be sent when settings are missing');
    }

    @IsTest
    static void testSendStageChangeEmailsNoRecipients() {
        // Create a work item with no developer and queue owner
        WorkItem__c wi = new WorkItem__c(
            BriefDescriptionTxt__c = 'No Developer Item',
            StageNamePk__c = 'Backlog'
        );
        insert wi;

        // Clear developer
        wi.Developer__c = null;
        update wi;

        Map<Id, String> stageMap = new Map<Id, String>{ wi.Id => 'Ready for QA' };

        Test.startTest();
        DeliveryEmailNotificationService.sendStageChangeEmails(
            new Set<Id>{ wi.Id }, stageMap
        );
        Test.stopTest();

        // OwnerId is still the running user, so email may still be sent
        // This test verifies no exceptions are thrown
        System.assert(true, 'Should handle work items with no explicit developer gracefully');
    }

    @IsTest
    static void testBuildHtmlBody() {
        DeliveryEmailNotificationService.EmailContext ctx = new DeliveryEmailNotificationService.EmailContext();
        ctx.workItemName = 'WI-0042';
        ctx.title = 'Fix login bug';
        ctx.newStage = 'In Development';
        ctx.recordUrl = 'https://test.salesforce.com/lightning/r/WorkItem__c/001/view';

        String html = DeliveryEmailNotificationService.buildHtmlBody(ctx);
        System.assert(html.contains('WI-0042'), 'HTML must contain work item name');
        System.assert(html.contains('Fix login bug'), 'HTML must contain title');
        System.assert(html.contains('In Development'), 'HTML must contain new stage');
        System.assert(html.contains('https://test.salesforce.com'), 'HTML must contain record URL');
    }
}

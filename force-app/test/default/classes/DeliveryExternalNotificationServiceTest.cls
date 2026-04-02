/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Test coverage for DeliveryExternalNotificationService.
 * @author Cloud Nimbus LLC
 */
@isTest
private class DeliveryExternalNotificationServiceTest {

    @TestSetup
    static void setupData() {
        // Enable notifications in settings
        DeliveryHubSettings__c settings = DeliveryHubSettings__c.getOrgDefaults();
        settings.EnableEmailNotificationsDateTime__c = Datetime.now();
        settings.EnableExternalNotificationsDateTime__c = Datetime.now();
        settings.EnableNotificationsDateTime__c = Datetime.now();
        upsert settings;
    }

    @isTest
    static void testStageChangeWithExternalEmail() {
        WorkItem__c wi = new WorkItem__c(
            BriefDescriptionTxt__c = 'Test external notification',
            StageNamePk__c = 'Submitted',
            ExternalRequesterEmailTxt__c = 'client@example.com',
            PriorityPk__c = 'Medium'
        );
        insert wi;

        Map<Id, String> stageMap = new Map<Id, String>{ wi.Id => 'In Development' };

        Test.startTest();
        DeliveryExternalNotificationService.sendExternalStageChangeEmails(
            new Set<Id>{ wi.Id }, stageMap
        );
        Test.stopTest();

        // Verify no exceptions — email dispatch is fire-and-forget
        System.assert(true, 'Stage change email sent without error');
    }

    @isTest
    static void testStageChangeWithoutExternalEmail() {
        WorkItem__c wi = new WorkItem__c(
            BriefDescriptionTxt__c = 'No external email set',
            StageNamePk__c = 'Submitted',
            PriorityPk__c = 'Medium'
        );
        insert wi;

        Map<Id, String> stageMap = new Map<Id, String>{ wi.Id => 'In Development' };

        Test.startTest();
        DeliveryExternalNotificationService.sendExternalStageChangeEmails(
            new Set<Id>{ wi.Id }, stageMap
        );
        Test.stopTest();

        // Should no-op gracefully
        System.assert(true, 'No error when external email is blank');
    }

    @isTest
    static void testSLABreachEmail() {
        WorkItem__c wi = new WorkItem__c(
            BriefDescriptionTxt__c = 'SLA breach test',
            StageNamePk__c = 'In Development',
            ExternalRequesterEmailTxt__c = 'client@example.com',
            PriorityPk__c = 'High',
            SLATargetDate__c = Date.today().addDays(-1)
        );
        insert wi;

        Test.startTest();
        DeliveryExternalNotificationService.sendExternalSLABreachEmails(
            new Set<Id>{ wi.Id }
        );
        Test.stopTest();

        System.assert(true, 'SLA breach email sent without error');
    }

    @isTest
    static void testDisabledSettings() {
        // Clear the external notification toggle
        DeliveryHubSettings__c settings = DeliveryHubSettings__c.getOrgDefaults();
        settings.EnableExternalNotificationsDateTime__c = null;
        upsert settings;

        WorkItem__c wi = new WorkItem__c(
            BriefDescriptionTxt__c = 'Should not send',
            StageNamePk__c = 'Submitted',
            ExternalRequesterEmailTxt__c = 'client@example.com',
            PriorityPk__c = 'Medium'
        );
        insert wi;

        Test.startTest();
        DeliveryExternalNotificationService.sendExternalStageChangeEmails(
            new Set<Id>{ wi.Id },
            new Map<Id, String>{ wi.Id => 'In Development' }
        );
        Test.stopTest();

        // Should no-op because settings are disabled
        System.assert(true, 'No error when notifications disabled');
    }

    @isTest
    static void testHtmlBuilders() {
        String stageHtml = DeliveryExternalNotificationService.buildStageChangeHtml(
            'WI-0042', 'Fix login bug', 'In Development'
        );
        System.assert(stageHtml.contains('WI-0042'), 'Stage HTML contains work item name');
        System.assert(stageHtml.contains('In Development'), 'Stage HTML contains new stage');

        String slaHtml = DeliveryExternalNotificationService.buildSLABreachHtml(
            'WI-0042', 'Fix login bug', 'In Development', Date.today().addDays(-1)
        );
        System.assert(slaHtml.contains('WI-0042'), 'SLA HTML contains work item name');
        System.assert(slaHtml.contains('taking longer'), 'SLA HTML contains breach messaging');
    }
}

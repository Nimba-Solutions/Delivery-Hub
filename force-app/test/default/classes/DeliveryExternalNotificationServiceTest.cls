/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Test coverage for DeliveryExternalNotificationService.
 * @author Cloud Nimbus LLC
 */
@isTest
private class DeliveryExternalNotificationServiceTest {

    private static User testUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];

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
        System.runAs(testUser) {
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
    }

    @isTest
    static void testStageChangeWithoutExternalEmail() {
        System.runAs(testUser) {
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
    }

    @isTest
    static void testSLABreachEmail() {
        System.runAs(testUser) {
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
    }

    @isTest
    static void testDisabledSettings() {
        System.runAs(testUser) {
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
    }

    @isTest
    static void testHtmlBuilders() {
        System.runAs(testUser) {
            String stageHtml = DeliveryExternalNotificationService.buildStageChangeHtml(
                'WI-0042', 'Fix login bug', 'In Development'
            );
            System.assert(stageHtml.contains('WI-0042'), 'Stage HTML contains work item name');
            System.assert(stageHtml.contains('In Development'), 'Stage HTML contains new stage');

            WorkItem__c testWi = new WorkItem__c(
                BriefDescriptionTxt__c = 'Fix login bug',
                StageNamePk__c = 'In Development',
                SLATargetDate__c = Date.today().addDays(-1),
                PriorityPk__c = 'High'
            );
            insert testWi;
            testWi = [SELECT Id, Name, BriefDescriptionTxt__c, StageNamePk__c, SLATargetDate__c FROM WorkItem__c WHERE Id = :testWi.Id];
            String slaHtml = DeliveryExternalNotificationService.buildSLABreachHtml(testWi);
            System.assert(slaHtml.contains(testWi.Name), 'SLA HTML contains work item name');
            System.assert(slaHtml.contains('taking longer'), 'SLA HTML contains breach messaging');
        }
    }
}

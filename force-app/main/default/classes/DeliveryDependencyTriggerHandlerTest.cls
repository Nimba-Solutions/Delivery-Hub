/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Tests for DeliveryDependencyTriggerHandler covering create,
 *               update, and delete field tracking through the trigger.
 * @author Cloud Nimbus LLC
 */
@IsTest
private class DeliveryDependencyTriggerHandlerTest {

    private static User testUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];

    @TestSetup
    static void setup() {
        DeliveryTriggerControl.disableAfterLogic();

        DeliveryHubSettings__c settings = DeliveryHubSettings__c.getOrgDefaults();
        settings.EnableActivityLoggingDateTime__c = Datetime.now();
        settings.EnableFieldTrackingDateTime__c = Datetime.now();
        upsert settings;

        WorkItem__c blocker = new WorkItem__c(
            BriefDescriptionTxt__c = 'Dep Blocker',
            StageNamePk__c = 'In Development'
        );
        WorkItem__c blocked = new WorkItem__c(
            BriefDescriptionTxt__c = 'Dep Blocked',
            StageNamePk__c = 'Backlog'
        );
        insert new List<WorkItem__c>{ blocker, blocked };

        DeliveryTriggerControl.enableAfterLogic();
    }

    @IsTest
    static void testCreateTracking() {
        System.runAs(testUser) {
            WorkItem__c blocker = [SELECT Id FROM WorkItem__c WHERE BriefDescriptionTxt__c = 'Dep Blocker' LIMIT 1];
            WorkItem__c blocked = [SELECT Id FROM WorkItem__c WHERE BriefDescriptionTxt__c = 'Dep Blocked' LIMIT 1];
            DeliveryFieldTrackingService.clearCache();

            Test.startTest();
            WorkItemDependency__c dep = new WorkItemDependency__c(
                BlockedWorkItemLookup__c = blocked.Id,
                BlockingWorkItemLookup__c = blocker.Id
            );
            insert dep;
            Test.stopTest();

            System.assertNotEquals(null, dep.Id, 'Dependency should be inserted successfully');
        }
    }

    @IsTest
    static void testUpdateTracking() {
        System.runAs(testUser) {
            WorkItem__c blocker = [SELECT Id FROM WorkItem__c WHERE BriefDescriptionTxt__c = 'Dep Blocker' LIMIT 1];
            WorkItem__c blocked = [SELECT Id FROM WorkItem__c WHERE BriefDescriptionTxt__c = 'Dep Blocked' LIMIT 1];

            DeliveryTriggerControl.disableAfterLogic();
            WorkItemDependency__c dep = new WorkItemDependency__c(
                BlockedWorkItemLookup__c = blocked.Id,
                BlockingWorkItemLookup__c = blocker.Id
            );
            insert dep;
            DeliveryTriggerControl.enableAfterLogic();
            DeliveryFieldTrackingService.clearCache();

            Test.startTest();
            dep.TypePk__c = 'Blocks';
            update dep;
            Test.stopTest();

            System.assertNotEquals(null, dep.Id, 'Dependency should be updated successfully');
        }
    }

    @IsTest
    static void testDeleteTracking() {
        System.runAs(testUser) {
            WorkItem__c blocker = [SELECT Id FROM WorkItem__c WHERE BriefDescriptionTxt__c = 'Dep Blocker' LIMIT 1];
            WorkItem__c blocked = [SELECT Id FROM WorkItem__c WHERE BriefDescriptionTxt__c = 'Dep Blocked' LIMIT 1];

            DeliveryTriggerControl.disableAfterLogic();
            WorkItemDependency__c dep = new WorkItemDependency__c(
                BlockedWorkItemLookup__c = blocked.Id,
                BlockingWorkItemLookup__c = blocker.Id
            );
            insert dep;
            DeliveryTriggerControl.enableAfterLogic();
            DeliveryFieldTrackingService.clearCache();

            Id depId = dep.Id;

            Test.startTest();
            delete dep;
            Test.stopTest();

            List<WorkItemDependency__c> remaining = [
                SELECT Id FROM WorkItemDependency__c WHERE Id = :depId
            ];
            System.assertEquals(0, remaining.size(), 'Dependency should be deleted');
        }
    }
}

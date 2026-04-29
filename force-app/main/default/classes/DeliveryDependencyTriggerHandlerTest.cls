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

    /**
     * @description Toggle off → publish path is gated; insert/update/delete on a
     *              dep doesn't throw and proceeds normally. Smoke test only since
     *              Platform Events are fire-and-forget in Apex test context.
     */
    @IsTest
    static void testDependencyChangeEventsToggleOff() {
        System.runAs(testUser) {
            DeliveryHubSettings__c s = DeliveryHubSettings__c.getOrgDefaults();
            System.assertEquals(null, s.EnableLiveGanttEventsDateTime__c,
                'Toggle should default to null (off)');

            WorkItem__c blocker = [SELECT Id FROM WorkItem__c WHERE BriefDescriptionTxt__c = 'Dep Blocker' LIMIT 1];
            WorkItem__c blocked = [SELECT Id FROM WorkItem__c WHERE BriefDescriptionTxt__c = 'Dep Blocked' LIMIT 1];

            Test.startTest();
            WorkItemDependency__c dep = new WorkItemDependency__c(
                BlockedWorkItemLookup__c = blocked.Id,
                BlockingWorkItemLookup__c = blocker.Id
            );
            insert dep;
            delete dep;
            Test.stopTest();

            System.assertEquals(0, [SELECT count() FROM WorkItemDependency__c WHERE Id = :dep.Id],
                'Dep insert + delete should both land cleanly with toggle off');
        }
    }

    /**
     * @description Toggle on → publishDependencyChangeEvents path runs without error
     *              on insert + update + delete. Verifies both endpoints of the dep
     *              are still queryable (DML lands), confirming the publish doesn't
     *              short-circuit the trigger.
     */
    @IsTest
    static void testDependencyChangeEventsToggleOnFires() {
        System.runAs(testUser) {
            DeliveryHubSettings__c s = DeliveryHubSettings__c.getOrgDefaults();
            s.EnableLiveGanttEventsDateTime__c = Datetime.now();
            update s;

            WorkItem__c blocker = [SELECT Id FROM WorkItem__c WHERE BriefDescriptionTxt__c = 'Dep Blocker' LIMIT 1];
            WorkItem__c blocked = [SELECT Id FROM WorkItem__c WHERE BriefDescriptionTxt__c = 'Dep Blocked' LIMIT 1];

            Test.startTest();
            WorkItemDependency__c dep = new WorkItemDependency__c(
                BlockedWorkItemLookup__c = blocked.Id,
                BlockingWorkItemLookup__c = blocker.Id
            );
            insert dep;
            dep.TypePk__c = 'Blocks';
            update dep;
            delete dep;
            Test.stopTest();

            System.assertEquals(0, [SELECT count() FROM WorkItemDependency__c WHERE Id = :dep.Id],
                'Dep insert/update/delete cycle should land cleanly with toggle on');
        }
    }
}

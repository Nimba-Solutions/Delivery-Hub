/**
 * @description Tests for DeliveryWorkItemDependenciesController.
 * @author Cloud Nimbus LLC
 */
@IsTest
private class DeliveryWorkItemDepsControllerTest {

    @TestSetup
    static void setup() {
        WorkItem__c blocker = new WorkItem__c(BriefDescriptionTxt__c = 'Blocker', StageNamePk__c = 'In Development');
        WorkItem__c blocked = new WorkItem__c(BriefDescriptionTxt__c = 'Blocked', StageNamePk__c = 'Ready for Development');
        insert new List<WorkItem__c>{ blocker, blocked };

        insert new WorkItemDependency__c(
            BlockingWorkItemId__c = blocker.Id,
            BlockedWorkItemId__c  = blocked.Id,
            TypePk__c          = 'Blocks'
        );
    }

    @IsTest
    static void testGetDependenciesBlocking() {
        WorkItem__c blocker = [SELECT Id FROM WorkItem__c WHERE BriefDescriptionTxt__c = 'Blocker' LIMIT 1];
        Map<String, Object> result = DeliveryWorkItemDependenciesController.getDependencies(blocker.Id);
        List<Object> blocking = (List<Object>) result.get('blocking');
        System.assertEquals(1, blocking.size(), 'Should find 1 work item being blocked');
    }

    @IsTest
    static void testGetDependenciesBlockedBy() {
        WorkItem__c blocked = [SELECT Id FROM WorkItem__c WHERE BriefDescriptionTxt__c = 'Blocked' LIMIT 1];
        Map<String, Object> result = DeliveryWorkItemDependenciesController.getDependencies(blocked.Id);
        List<Object> blockedBy = (List<Object>) result.get('blockedBy');
        System.assertEquals(1, blockedBy.size(), 'Should find 1 blocker');
    }

    @IsTest
    static void testGetDependenciesNone() {
        WorkItem__c lone = new WorkItem__c(BriefDescriptionTxt__c = 'Solo', StageNamePk__c = 'Backlog');
        insert lone;
        Map<String, Object> result = DeliveryWorkItemDependenciesController.getDependencies(lone.Id);
        List<Object> blocking  = (List<Object>) result.get('blocking');
        List<Object> blockedBy = (List<Object>) result.get('blockedBy');
        System.assertEquals(0, blocking.size());
        System.assertEquals(0, blockedBy.size());
    }
}

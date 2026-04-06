/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Test class for DeliveryWorkItemDependenciesController.
 *               Covers getDependencies with blocking, blocked-by, and no-dependency scenarios.
 *               Verifies DependencyRow field population.
 * @author Cloud Nimbus LLC
 */
@IsTest
private class DeliveryWorkItemDependenciesControllerTest {

    private static User testUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];

    @TestSetup
    static void setupData() {
        DeliveryTriggerControl.disableAfterLogic();

        WorkItem__c blockerItem = new WorkItem__c(
            BriefDescriptionTxt__c = 'Blocker Work Item',
            StageNamePk__c = 'In Development'
        );
        WorkItem__c blockedItem = new WorkItem__c(
            BriefDescriptionTxt__c = 'Blocked Work Item',
            StageNamePk__c = 'Ready for Development'
        );
        WorkItem__c loneItem = new WorkItem__c(
            BriefDescriptionTxt__c = 'Lone Work Item No Deps',
            StageNamePk__c = 'Backlog'
        );
        insert new List<WorkItem__c>{ blockerItem, blockedItem, loneItem };

        insert new WorkItemDependency__c(
            BlockingWorkItemId__c = blockerItem.Id,
            BlockedWorkItemId__c = blockedItem.Id,
            TypePk__c = 'Blocks'
        );

        DeliveryTriggerControl.enableAfterLogic();
    }

    @IsTest
    static void testGetBlockingItems() {
        System.runAs(testUser) {
            WorkItem__c blocker = [
                SELECT Id FROM WorkItem__c
                WHERE BriefDescriptionTxt__c = 'Blocker Work Item' LIMIT 1
            ];

            Test.startTest();
            Map<String, Object> result = DeliveryWorkItemDependenciesController.getDependencies(blocker.Id);
            Test.stopTest();

            List<Object> blocking = (List<Object>) result.get('blocking');
            List<Object> blockedBy = (List<Object>) result.get('blockedBy');

            System.assertEquals(1, blocking.size(), 'Blocker should have 1 item it is blocking');
            System.assertEquals(0, blockedBy.size(), 'Blocker should not be blocked by anything');

            // Verify the DependencyRow fields
            DeliveryWorkItemDependenciesController.DependencyRow row =
                (DeliveryWorkItemDependenciesController.DependencyRow) blocking[0];
            System.assertNotEquals(null, row.id, 'Row ID should be populated');
            System.assertNotEquals(null, row.name, 'Row name should be populated');
            System.assertEquals('Blocked Work Item', row.title, 'Row title should match');
            System.assertEquals('Ready for Development', row.stage, 'Row stage should match');
            System.assertEquals('Blocks', row.type, 'Row type should match');
        }
    }

    @IsTest
    static void testGetBlockedByItems() {
        System.runAs(testUser) {
            WorkItem__c blocked = [
                SELECT Id FROM WorkItem__c
                WHERE BriefDescriptionTxt__c = 'Blocked Work Item' LIMIT 1
            ];

            Test.startTest();
            Map<String, Object> result = DeliveryWorkItemDependenciesController.getDependencies(blocked.Id);
            Test.stopTest();

            List<Object> blocking = (List<Object>) result.get('blocking');
            List<Object> blockedBy = (List<Object>) result.get('blockedBy');

            System.assertEquals(0, blocking.size(), 'Blocked item should not be blocking anything');
            System.assertEquals(1, blockedBy.size(), 'Blocked item should have 1 blocker');

            DeliveryWorkItemDependenciesController.DependencyRow row =
                (DeliveryWorkItemDependenciesController.DependencyRow) blockedBy[0];
            System.assertEquals('Blocker Work Item', row.title, 'Blocker title should match');
            System.assertEquals('In Development', row.stage, 'Blocker stage should match');
        }
    }

    @IsTest
    static void testNoDependencies() {
        System.runAs(testUser) {
            WorkItem__c lone = [
                SELECT Id FROM WorkItem__c
                WHERE BriefDescriptionTxt__c = 'Lone Work Item No Deps' LIMIT 1
            ];

            Test.startTest();
            Map<String, Object> result = DeliveryWorkItemDependenciesController.getDependencies(lone.Id);
            Test.stopTest();

            List<Object> blocking = (List<Object>) result.get('blocking');
            List<Object> blockedBy = (List<Object>) result.get('blockedBy');

            System.assertEquals(0, blocking.size(), 'Should have no blocking items');
            System.assertEquals(0, blockedBy.size(), 'Should have no blocked-by items');
        }
    }

    @IsTest
    static void testMultipleDependencies() {
        System.runAs(testUser) {
            WorkItem__c blocker = [
                SELECT Id FROM WorkItem__c
                WHERE BriefDescriptionTxt__c = 'Blocker Work Item' LIMIT 1
            ];

            // Add the lone item as another blocked item
            WorkItem__c lone = [
                SELECT Id FROM WorkItem__c
                WHERE BriefDescriptionTxt__c = 'Lone Work Item No Deps' LIMIT 1
            ];
            insert new WorkItemDependency__c(
                BlockingWorkItemId__c = blocker.Id,
                BlockedWorkItemId__c = lone.Id,
                TypePk__c = 'Blocks'
            );

            Test.startTest();
            Map<String, Object> result = DeliveryWorkItemDependenciesController.getDependencies(blocker.Id);
            Test.stopTest();

            List<Object> blocking = (List<Object>) result.get('blocking');
            System.assertEquals(2, blocking.size(), 'Blocker should now have 2 items it is blocking');
        }
    }
}

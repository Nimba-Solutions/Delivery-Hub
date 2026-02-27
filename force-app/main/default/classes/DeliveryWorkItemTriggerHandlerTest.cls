/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @author Cloud Nimbus LLC
 */
@IsTest
public class DeliveryWorkItemTriggerHandlerTest {

    @TestSetup
    static void setup() {
        insert new DeliveryHubSettings__c(AutoCreateWorkRequestBool__c = true);
        NetworkEntity__c vendor = new NetworkEntity__c(Name='V', EntityTypePk__c='Vendor', StatusPk__c='Active', IntegrationEndpointUrlTxt__c='https://f.com');
        insert vendor;
        insert new WorkItem__c(BriefDescriptionTxt__c = 'Blocker', StatusPk__c = 'In Progress', StageNamePk__c = 'In Development');
    }

    @IsTest
    static void testDeliverySyncEngineIntegrationOnUpdate() {
        WorkItem__c t = [SELECT Id FROM WorkItem__c LIMIT 1];
        NetworkEntity__c v = [SELECT Id FROM NetworkEntity__c LIMIT 1];
        insert new WorkRequest__c(WorkItemId__c = t.Id, DeliveryEntityId__c = v.Id, StatusPk__c = 'Active', RemoteWorkItemIdTxt__c = 'R-123');

        delete [SELECT Id FROM SyncItem__c];

        Test.startTest();
        t.BriefDescriptionTxt__c = 'Sync Update';
        update t;
        Test.stopTest();

        List<SyncItem__c> items = [SELECT Id FROM SyncItem__c WHERE WorkItemId__c = :t.Id];
        System.assert(items.size() >= 1, 'Sync Engine should trigger on update');
    }

    @IsTest
    static void testAutoWorkRequestCreation() {
        // Settings have AutoCreateWorkRequestBool__c = true from setup
        // and an active vendor exists, so inserting a work item should auto-create a request
        Test.startTest();
        WorkItem__c newItem = new WorkItem__c(
            BriefDescriptionTxt__c = 'Auto Request Test',
            StageNamePk__c = 'Backlog'
        );
        insert newItem;
        Test.stopTest();

        List<WorkRequest__c> requests = [
            SELECT Id, StatusPk__c, WorkItemId__c
            FROM WorkRequest__c
            WHERE WorkItemId__c = :newItem.Id
        ];
        System.assert(!requests.isEmpty(), 'A WorkRequest should be auto-created on insert when AutoCreate is enabled');
        System.assertEquals('Draft', requests[0].StatusPk__c, 'Auto-created request should have Draft status');
    }

    @IsTest
    static void testStageChangePlatformEvent() {
        WorkItem__c t = [SELECT Id, StageNamePk__c FROM WorkItem__c LIMIT 1];

        Test.startTest();
        t.StageNamePk__c = 'Ready for QA';
        update t;
        Test.stopTest();

        // Platform events are fire-and-forget; verify the update succeeded without error
        WorkItem__c updated = [SELECT StageNamePk__c FROM WorkItem__c WHERE Id = :t.Id];
        System.assertEquals('Ready for QA', updated.StageNamePk__c, 'Stage should be updated');
    }

    @IsTest
    static void testBlockedDependencyValidation() {
        WorkItem__c blocker = [SELECT Id FROM WorkItem__c WHERE BriefDescriptionTxt__c = 'Blocker' LIMIT 1];

        // Create a second work item that is blocked by the first
        WorkItem__c blocked = new WorkItem__c(
            BriefDescriptionTxt__c = 'Blocked Item',
            StageNamePk__c = 'Backlog'
        );
        insert blocked;

        insert new WorkItemDependency__c(
            BlockedWorkItemId__c = blocked.Id,
            BlockingWorkItemId__c = blocker.Id
        );

        Test.startTest();
        blocked.StageNamePk__c = 'In Development';
        try {
            update blocked;
            System.assert(false, 'Should have thrown a validation error for blocked dependency');
        } catch (DmlException e) {
            System.assert(e.getMessage().contains('blocked by'), 'Error message should mention blocked dependency');
        }
        Test.stopTest();
    }
}

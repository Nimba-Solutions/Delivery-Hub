/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Tests for DeliveryWorkLogTriggerHandler.
 * @author Cloud Nimbus LLC
 */
@IsTest
private class DeliveryWorkLogTriggerHandlerTest {

    @TestSetup
    static void setup() {
        NetworkEntity__c client = new NetworkEntity__c(
            Name = 'Test Client', EntityTypePk__c = 'Client', StatusPk__c = 'Active'
        );
        NetworkEntity__c vendor = new NetworkEntity__c(
            Name = 'Test Vendor', EntityTypePk__c = 'Vendor', StatusPk__c = 'Active'
        );
        insert new List<NetworkEntity__c>{ client, vendor };

        WorkItem__c linkedWorkItem = new WorkItem__c(
            BriefDescriptionTxt__c   = 'Client Work Item',
            StageNamePk__c           = 'In Development',
            ClientNetworkEntityId__c = client.Id
        );
        WorkItem__c unlinkedWorkItem = new WorkItem__c(
            BriefDescriptionTxt__c = 'No Client Work Item',
            StageNamePk__c         = 'In Development'
        );
        insert new List<WorkItem__c>{ linkedWorkItem, unlinkedWorkItem };

        // Every WorkLog__c is Master-Detail to WorkRequest__c — create one per work item
        insert new List<WorkRequest__c>{
            new WorkRequest__c(
                WorkItemId__c           = linkedWorkItem.Id,
                DeliveryEntityId__c   = vendor.Id,
                QuotedHoursNumber__c  = 20,
                HourlyRateCurrency__c = 100,
                StatusPk__c           = 'Accepted'
            ),
            new WorkRequest__c(
                WorkItemId__c           = unlinkedWorkItem.Id,
                DeliveryEntityId__c   = vendor.Id,
                QuotedHoursNumber__c  = 10,
                HourlyRateCurrency__c = 100,
                StatusPk__c           = 'Accepted'
            )
        };
    }

    @IsTest
    static void testWorkLogOnClientWorkItemCreatesSyncItem() {
        WorkItem__c workItem   = [SELECT Id FROM WorkItem__c WHERE BriefDescriptionTxt__c = 'Client Work Item' LIMIT 1];
        WorkRequest__c request = [SELECT Id FROM WorkRequest__c WHERE WorkItemId__c = :workItem.Id LIMIT 1];

        Test.startTest();
        insert new WorkLog__c(
            RequestId__c           = request.Id,
            WorkItemId__c            = workItem.Id,
            HoursLoggedNumber__c   = 3.5,
            WorkDateDate__c        = Date.today(),
            WorkDescriptionTxt__c  = 'Implemented feature X'
        );
        Test.stopTest();

        List<SyncItem__c> items = [
            SELECT ObjectTypePk__c, DirectionPk__c, StatusPk__c, WorkItemId__c
            FROM SyncItem__c
            WHERE WorkItemId__c = :workItem.Id
            AND ObjectTypePk__c = 'WorkLog__c'
        ];
        System.assertEquals(1, items.size(), 'Should create 1 sync item for client-linked work item');
        System.assertEquals('WorkLog__c', items[0].ObjectTypePk__c);
        System.assertEquals('Outbound', items[0].DirectionPk__c);
        System.assertEquals('Queued', items[0].StatusPk__c);
    }

    @IsTest
    static void testWorkLogOnUnlinkedWorkItemNoSyncItem() {
        WorkItem__c workItem   = [SELECT Id FROM WorkItem__c WHERE BriefDescriptionTxt__c = 'No Client Work Item' LIMIT 1];
        WorkRequest__c request = [SELECT Id FROM WorkRequest__c WHERE WorkItemId__c = :workItem.Id LIMIT 1];

        Test.startTest();
        insert new WorkLog__c(
            RequestId__c           = request.Id,
            WorkItemId__c            = workItem.Id,
            HoursLoggedNumber__c   = 2.0,
            WorkDateDate__c        = Date.today(),
            WorkDescriptionTxt__c  = 'Internal work only'
        );
        Test.stopTest();

        List<SyncItem__c> items = [SELECT Id FROM SyncItem__c WHERE WorkItemId__c = :workItem.Id AND ObjectTypePk__c = 'WorkLog__c'];
        System.assertEquals(0, items.size(), 'Should not create sync items for work items without a client');
    }

    @IsTest
    static void testTriggerControlDisabled() {
        WorkItem__c workItem   = [SELECT Id FROM WorkItem__c WHERE BriefDescriptionTxt__c = 'Client Work Item' LIMIT 1];
        WorkRequest__c request = [SELECT Id FROM WorkRequest__c WHERE WorkItemId__c = :workItem.Id LIMIT 1];

        DeliveryTriggerControl.disableAfterLogic();

        Test.startTest();
        insert new WorkLog__c(
            RequestId__c           = request.Id,
            WorkItemId__c            = workItem.Id,
            HoursLoggedNumber__c   = 1.0,
            WorkDateDate__c        = Date.today(),
            WorkDescriptionTxt__c  = 'Trigger disabled test'
        );
        Test.stopTest();

        DeliveryTriggerControl.enableAfterLogic();

        List<SyncItem__c> items = [SELECT Id FROM SyncItem__c WHERE WorkItemId__c = :workItem.Id AND ObjectTypePk__c = 'WorkLog__c'];
        System.assertEquals(0, items.size(), 'Should not create sync items when trigger control is disabled');
    }
}

/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Tests for DeliveryWorkLogTriggerHandler.
 * @author Cloud Nimbus LLC
 */
@IsTest
private class DeliveryWorkLogTriggerHandlerTest {

    private static User testUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];

    @TestSetup
    static void setup() {
        NetworkEntity__c client = new NetworkEntity__c(
            Name = 'Test Client', EntityTypePk__c = 'Client', StatusPk__c = 'Active',
            IntegrationEndpointUrlTxt__c = 'https://test-client.example.com'
        );
        NetworkEntity__c vendor = new NetworkEntity__c(
            Name = 'Test Vendor', EntityTypePk__c = 'Vendor', StatusPk__c = 'Active'
        );
        insert new List<NetworkEntity__c>{ client, vendor };

        WorkItem__c linkedWorkItem = new WorkItem__c(
            BriefDescriptionTxt__c   = 'Client Work Item',
            StageNamePk__c           = 'In Development',
            ClientNetworkEntityLookup__c = client.Id
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
                DeliveryEntityLookup__c   = vendor.Id,
                QuotedHoursNumber__c  = 20,
                HourlyRateCurrency__c = 100,
                StatusPk__c           = 'Accepted'
            ),
            new WorkRequest__c(
                WorkItemId__c           = unlinkedWorkItem.Id,
                DeliveryEntityLookup__c   = vendor.Id,
                QuotedHoursNumber__c  = 10,
                HourlyRateCurrency__c = 100,
                StatusPk__c           = 'Accepted'
            )
        };
    }

    @IsTest
    static void testWorkLogOnClientWorkItemCreatesSyncItem() {
        System.runAs(testUser) {
            WorkItem__c workItem   = [SELECT Id FROM WorkItem__c WHERE BriefDescriptionTxt__c = 'Client Work Item' LIMIT 1];
            WorkRequest__c request = [SELECT Id FROM WorkRequest__c WHERE WorkItemId__c = :workItem.Id LIMIT 1];

            Test.startTest();
            insert new WorkLog__c(
                RequestId__c           = request.Id,
                WorkItemLookup__c            = workItem.Id,
                HoursLoggedNumber__c   = 3.5,
                WorkDateDate__c        = Date.today(),
                WorkDescriptionTxt__c  = 'Implemented feature X'
            );
            Test.stopTest();

            List<SyncItem__c> items = [
                SELECT ObjectTypePk__c, DirectionPk__c, StatusPk__c, WorkItemLookup__c
                FROM SyncItem__c
                WHERE WorkItemLookup__c = :workItem.Id
                AND ObjectTypePk__c = 'WorkLog__c'
            ];
            System.assertEquals(1, items.size(), 'Should create 1 sync item for client-linked work item');
            System.assertEquals('WorkLog__c', items[0].ObjectTypePk__c);
            System.assertEquals('Outbound', items[0].DirectionPk__c);
            System.assertEquals('Queued', items[0].StatusPk__c);
        }
    }

    @IsTest
    static void testWorkLogOnUnlinkedWorkItemNoSyncItem() {
        System.runAs(testUser) {
            WorkItem__c workItem   = [SELECT Id FROM WorkItem__c WHERE BriefDescriptionTxt__c = 'No Client Work Item' LIMIT 1];
            WorkRequest__c request = [SELECT Id FROM WorkRequest__c WHERE WorkItemId__c = :workItem.Id LIMIT 1];

            Test.startTest();
            insert new WorkLog__c(
                RequestId__c           = request.Id,
                WorkItemLookup__c            = workItem.Id,
                HoursLoggedNumber__c   = 2.0,
                WorkDateDate__c        = Date.today(),
                WorkDescriptionTxt__c  = 'Internal work only'
            );
            Test.stopTest();

            List<SyncItem__c> items = [SELECT Id FROM SyncItem__c WHERE WorkItemLookup__c = :workItem.Id AND ObjectTypePk__c = 'WorkLog__c'];
            System.assertEquals(0, items.size(), 'Should not create sync items for work items without a client');
        }
    }

    @IsTest
    static void testTriggerControlDisabled() {
        System.runAs(testUser) {
            WorkItem__c workItem   = [SELECT Id FROM WorkItem__c WHERE BriefDescriptionTxt__c = 'Client Work Item' LIMIT 1];
            WorkRequest__c request = [SELECT Id FROM WorkRequest__c WHERE WorkItemId__c = :workItem.Id LIMIT 1];

            DeliveryTriggerControl.disableAfterLogic();

            Test.startTest();
            insert new WorkLog__c(
                RequestId__c           = request.Id,
                WorkItemLookup__c            = workItem.Id,
                HoursLoggedNumber__c   = 1.0,
                WorkDateDate__c        = Date.today(),
                WorkDescriptionTxt__c  = 'Trigger disabled test'
            );
            Test.stopTest();

            DeliveryTriggerControl.enableAfterLogic();

            List<SyncItem__c> items = [SELECT Id FROM SyncItem__c WHERE WorkItemLookup__c = :workItem.Id AND ObjectTypePk__c = 'WorkLog__c'];
            System.assertEquals(0, items.size(), 'Should not create sync items when trigger control is disabled');
        }
    }

    // ── Approval gate tests ────────────────────────────────────────────

    @IsTest
    static void testApprovalGateBlocksDraftSync() {
        System.runAs(testUser) {
            // Enable approval
            DeliveryHubSettings__c settings = DeliveryHubSettings__c.getOrgDefaults();
            settings.RequireWorkLogApprovalDateTime__c = Datetime.now();
            upsert settings;

            WorkItem__c workItem   = [SELECT Id FROM WorkItem__c WHERE BriefDescriptionTxt__c = 'Client Work Item' LIMIT 1];
            WorkRequest__c request = [SELECT Id FROM WorkRequest__c WHERE WorkItemId__c = :workItem.Id LIMIT 1];

            Test.startTest();
            insert new WorkLog__c(
                RequestId__c           = request.Id,
                WorkItemLookup__c            = workItem.Id,
                HoursLoggedNumber__c   = 2.0,
                WorkDateDate__c        = Date.today(),
                WorkDescriptionTxt__c  = 'Draft log test',
                StatusPk__c            = 'Draft'
            );
            Test.stopTest();

            List<SyncItem__c> items = [SELECT Id FROM SyncItem__c WHERE WorkItemLookup__c = :workItem.Id AND ObjectTypePk__c = 'WorkLog__c'];
            System.assertEquals(0, items.size(), 'Draft WorkLog should NOT create SyncItem when approval is required');
        }
    }

    @IsTest
    static void testApprovalOnUpdateCreatesSyncItem() {
        System.runAs(testUser) {
            // Enable approval
            DeliveryHubSettings__c settings = DeliveryHubSettings__c.getOrgDefaults();
            settings.RequireWorkLogApprovalDateTime__c = Datetime.now();
            upsert settings;

            WorkItem__c workItem   = [SELECT Id FROM WorkItem__c WHERE BriefDescriptionTxt__c = 'Client Work Item' LIMIT 1];
            WorkRequest__c request = [SELECT Id FROM WorkRequest__c WHERE WorkItemId__c = :workItem.Id LIMIT 1];

            // Insert as Draft — no SyncItem expected
            WorkLog__c draftLog = new WorkLog__c(
                RequestId__c           = request.Id,
                WorkItemLookup__c            = workItem.Id,
                HoursLoggedNumber__c   = 4.0,
                WorkDateDate__c        = Date.today(),
                WorkDescriptionTxt__c  = 'Approval update test',
                StatusPk__c            = 'Draft'
            );
            insert draftLog;

            List<SyncItem__c> beforeItems = [SELECT Id FROM SyncItem__c WHERE WorkItemLookup__c = :workItem.Id AND ObjectTypePk__c = 'WorkLog__c'];
            System.assertEquals(0, beforeItems.size(), 'No SyncItem before approval');

            Test.startTest();
            draftLog.StatusPk__c = 'Approved';
            update draftLog;
            Test.stopTest();

            List<SyncItem__c> afterItems = [
                SELECT ObjectTypePk__c, DirectionPk__c, StatusPk__c
                FROM SyncItem__c
                WHERE WorkItemLookup__c = :workItem.Id
                AND ObjectTypePk__c = 'WorkLog__c'
            ];
            System.assertEquals(1, afterItems.size(), 'Approving a Draft log should create SyncItem');
            System.assertEquals('Outbound', afterItems[0].DirectionPk__c);
            System.assertEquals('Queued', afterItems[0].StatusPk__c);
        }
    }

    @IsTest
    static void testNoApprovalSettingSyncsImmediately() {
        System.runAs(testUser) {
            // Explicitly ensure setting is NOT set (default behavior)
            DeliveryHubSettings__c settings = DeliveryHubSettings__c.getOrgDefaults();
            settings.RequireWorkLogApprovalDateTime__c = null;
            upsert settings;

            WorkItem__c workItem   = [SELECT Id FROM WorkItem__c WHERE BriefDescriptionTxt__c = 'Client Work Item' LIMIT 1];
            WorkRequest__c request = [SELECT Id FROM WorkRequest__c WHERE WorkItemId__c = :workItem.Id LIMIT 1];

            Test.startTest();
            insert new WorkLog__c(
                RequestId__c           = request.Id,
                WorkItemLookup__c            = workItem.Id,
                HoursLoggedNumber__c   = 1.5,
                WorkDateDate__c        = Date.today(),
                WorkDescriptionTxt__c  = 'No approval setting test'
            );
            Test.stopTest();

            List<SyncItem__c> items = [SELECT Id FROM SyncItem__c WHERE WorkItemLookup__c = :workItem.Id AND ObjectTypePk__c = 'WorkLog__c'];
            System.assertEquals(1, items.size(), 'Without approval setting, WorkLog should sync immediately');
        }
    }

    @IsTest
    static void testOrphanWorkLogBlocked() {
        System.runAs(testUser) {
            WorkRequest__c request = [SELECT Id FROM WorkRequest__c LIMIT 1];

            Test.startTest();
            try {
                insert new WorkLog__c(
                    RequestId__c           = request.Id,
                    WorkItemLookup__c            = null,
                    HoursLoggedNumber__c   = 2.0,
                    WorkDateDate__c        = Date.today(),
                    WorkDescriptionTxt__c  = 'Orphan log should fail'
                );
                System.assert(false, 'Should have thrown DmlException for missing WorkItemId');
            } catch (DmlException e) {
                System.assert(e.getMessage().contains('Work Item is required'),
                    'Error should mention Work Item requirement: ' + e.getMessage());
            }
            Test.stopTest();
        }
    }

    @IsTest
    static void testBulkApproval() {
        System.runAs(testUser) {
            // Enable approval
            DeliveryHubSettings__c settings = DeliveryHubSettings__c.getOrgDefaults();
            settings.RequireWorkLogApprovalDateTime__c = Datetime.now();
            upsert settings;

            WorkItem__c workItem   = [SELECT Id FROM WorkItem__c WHERE BriefDescriptionTxt__c = 'Client Work Item' LIMIT 1];
            WorkRequest__c request = [SELECT Id FROM WorkRequest__c WHERE WorkItemId__c = :workItem.Id LIMIT 1];

            // Insert 20 Draft WorkLogs
            List<WorkLog__c> draftLogs = new List<WorkLog__c>();
            for (Integer i = 0; i < 20; i++) {
                draftLogs.add(new WorkLog__c(
                    RequestId__c           = request.Id,
                    WorkItemLookup__c            = workItem.Id,
                    HoursLoggedNumber__c   = 1.0,
                    WorkDateDate__c        = Date.today(),
                    WorkDescriptionTxt__c  = 'Bulk test log ' + i,
                    StatusPk__c            = 'Draft'
                ));
            }
            insert draftLogs;

            // Verify no SyncItems yet
            List<SyncItem__c> beforeItems = [SELECT Id FROM SyncItem__c WHERE WorkItemLookup__c = :workItem.Id AND ObjectTypePk__c = 'WorkLog__c'];
            System.assertEquals(0, beforeItems.size(), 'No SyncItems before bulk approval');

            // Approve all in one DML
            Test.startTest();
            for (WorkLog__c wl : draftLogs) {
                wl.StatusPk__c = 'Approved';
            }
            update draftLogs;
            Test.stopTest();

            List<SyncItem__c> afterItems = [SELECT Id FROM SyncItem__c WHERE WorkItemLookup__c = :workItem.Id AND ObjectTypePk__c = 'WorkLog__c'];
            System.assertEquals(20, afterItems.size(), 'Bulk approval should create 20 SyncItems');
        }
    }
}

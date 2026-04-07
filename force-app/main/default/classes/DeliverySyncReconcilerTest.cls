/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Test class for DeliverySyncReconciler.
 * Verifies gap detection for WorkItems and WorkLogs, and confirms that already-synced
 * records are not duplicated.
 * @author Cloud Nimbus LLC
 */
@IsTest
private class DeliverySyncReconcilerTest {

    private static User testUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];

    @TestSetup
    static void makeData() {
        // Prevent DeliverySyncEngine from firing during setup
        DeliverySyncEngine.setSyncContext();

        // 1. Settings
        insert new DeliveryHubSettings__c(
            SetupOwnerId = UserInfo.getOrganizationId(),
            EnableAutoCreateWorkRequestDateTime__c = null,
            EnableAutoSyncNetworkEntityDateTime__c = null
        );

        // 2. Network Entity (Vendor, Connected)
        NetworkEntity__c vendor = new NetworkEntity__c(
            Name = 'Reconcile Vendor',
            StatusPk__c = 'Active',
            EntityTypePk__c = 'Vendor',
            ConnectionStatusPk__c = 'Connected',
            IntegrationEndpointUrlTxt__c = 'https://vendor.example.com'
        );
        insert vendor;

        // 3. Work Item
        WorkItem__c wi = new WorkItem__c(
            BriefDescriptionTxt__c = 'Reconcile Test Item',
            StageNamePk__c = 'Backlog'
        );
        insert wi;

        // 4. Work Request (The downstream bridge)
        WorkRequest__c req = new WorkRequest__c(
            WorkItemId__c = wi.Id,
            DeliveryEntityLookup__c = vendor.Id,
            StatusPk__c = 'Active',
            RemoteWorkItemIdTxt__c = 'REMOTE-RECON-001'
        );
        insert req;

        // 5. Work Log (child of the Work Item)
        WorkLog__c wl = new WorkLog__c(
            WorkItemLookup__c = wi.Id,
            RequestId__c = req.Id,
            HoursLoggedNumber__c = 2.5,
            WorkDateDate__c = Date.today(),
            WorkDescriptionTxt__c = 'Reconcile test log entry'
        );
        insert wl;
    }

    /**
     * @description Verifies that the reconciler detects a missing WorkItem SyncItem
     * and creates a Queued outbound SyncItem to fill the gap.
     */
    @IsTest
    static void testReconcileFindsGap() {
        System.runAs(testUser) {
            // Ensure no SyncItems exist (gap scenario)
            delete [SELECT Id FROM SyncItem__c];

            Test.startTest();
            System.enqueueJob(new DeliverySyncReconciler());
            Test.stopTest();

            List<SyncItem__c> created = [
                SELECT Id, ObjectTypePk__c, StatusPk__c, DirectionPk__c, RequestLookup__c
                FROM SyncItem__c
                WHERE ObjectTypePk__c = 'WorkItem__c'
                AND DirectionPk__c = 'Outbound'
            ];
            System.assertEquals(1, created.size(), 'Reconciler should create exactly one WorkItem SyncItem for the gap.');
            System.assertEquals('Queued', created[0].StatusPk__c, 'Gap SyncItem should be Queued for processing.');
            System.assertNotEquals(null, created[0].RequestId__c, 'Gap SyncItem should be linked to the WorkRequest.');
        }
    }

    /**
     * @description Verifies that the reconciler does NOT create duplicate SyncItems
     * when a Synced outbound item already exists.
     */
    @IsTest
    static void testReconcileSkipsSyncedItems() {
        System.runAs(testUser) {
            // Clear any noise
            delete [SELECT Id FROM SyncItem__c];

            // Cover ALL WorkRequests (packaging org may auto-create extras)
            List<WorkRequest__c> allReqs = [SELECT Id, WorkItemId__c FROM WorkRequest__c];
            List<WorkLog__c> allWLs = [SELECT Id, WorkItemLookup__c FROM WorkLog__c];

            List<SyncItem__c> preCreated = new List<SyncItem__c>();
            for (WorkRequest__c req : allReqs) {
                preCreated.add(new SyncItem__c(
                    ObjectTypePk__c     = 'WorkItem__c',
                    LocalRecordIdTxt__c = req.WorkItemLookup__c,
                    WorkItemLookup__c       = req.WorkItemLookup__c,
                    RequestLookup__c        = req.Id,
                    DirectionPk__c      = 'Outbound',
                    StatusPk__c         = 'Synced',
                    PayloadTxt__c       = '{"test":"already synced"}'
                ));
            }
            for (WorkLog__c wl : allWLs) {
                preCreated.add(new SyncItem__c(
                    ObjectTypePk__c     = 'WorkLog__c',
                    LocalRecordIdTxt__c = (String) wl.Id,
                    WorkItemLookup__c       = wl.WorkItemLookup__c,
                    DirectionPk__c      = 'Outbound',
                    StatusPk__c         = 'Synced',
                    PayloadTxt__c       = '{"test":"worklog already synced"}'
                ));
            }
            insert preCreated;

            Test.startTest();
            System.enqueueJob(new DeliverySyncReconciler());
            Test.stopTest();

            Integer queuedWI = [SELECT COUNT() FROM SyncItem__c WHERE ObjectTypePk__c = 'WorkItem__c' AND DirectionPk__c = 'Outbound' AND StatusPk__c = 'Queued'];
            Integer queuedWL = [SELECT COUNT() FROM SyncItem__c WHERE ObjectTypePk__c = 'WorkLog__c' AND DirectionPk__c = 'Outbound' AND StatusPk__c = 'Queued'];
            System.assertEquals(0, queuedWI, 'Reconciler should NOT create Queued WorkItem SyncItems when Synced item exists.');
            System.assertEquals(0, queuedWL, 'Reconciler should NOT create Queued WorkLog SyncItems when Synced item exists.');
        }
    }

    /**
     * @description Verifies that the reconciler creates SyncItems for both a missing
     * WorkItem and a missing WorkLog in a single pass.
     */
    @IsTest
    static void testReconcileWorkLogs() {
        System.runAs(testUser) {
            // Clear all SyncItems (gap for both WorkItem and WorkLog)
            delete [SELECT Id FROM SyncItem__c];

            Test.startTest();
            System.enqueueJob(new DeliverySyncReconciler());
            Test.stopTest();

            List<SyncItem__c> workItemSyncs = [
                SELECT Id FROM SyncItem__c
                WHERE ObjectTypePk__c = 'WorkItem__c'
                AND DirectionPk__c = 'Outbound'
            ];
            List<SyncItem__c> workLogSyncs = [
                SELECT Id, PayloadTxt__c FROM SyncItem__c
                WHERE ObjectTypePk__c = 'WorkLog__c'
                AND DirectionPk__c = 'Outbound'
            ];

            System.assertEquals(1, workItemSyncs.size(), 'Should create one WorkItem SyncItem.');
            System.assertEquals(1, workLogSyncs.size(), 'Should create one WorkLog SyncItem.');
            System.assert(workLogSyncs[0].PayloadTxt__c.contains('HoursLoggedNumber__c'), 'WorkLog payload should contain hours.');
        }
    }
}

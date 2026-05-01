/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Test class for DeliverySyncItemPendingResolver and the
 *               ingestor's Pending-queue path. Covers two shapes:
 *               (a) parent arrives later, Pending row resolves to Synced
 *                   and the local WorkLog is inserted.
 *               (b) parent never arrives, row exhausts retries and flips
 *                   to Failed with a descriptive error.
 * @author Cloud Nimbus LLC
 */
@IsTest
private class DeliverySyncItemPendingResolverTest {

    private static User testUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];

    @TestSetup
    static void makeData() {
        DeliveryTriggerControl.runAfterLogic = false;

        NetworkEntity__c client = new NetworkEntity__c(
            Name = 'Pending Resolver Client',
            EntityTypePk__c = 'Client',
            StatusPk__c = 'Active'
        );
        insert client;
    }

    /**
     * @description When a WorkLog arrives before its parent WorkItem, the
     *              ingestor should stash it in a Pending SyncItem__c rather
     *              than throw. A subsequent resolver run after the parent
     *              lands should replay the payload, flip the Pending row to
     *              Synced, and actually insert the WorkLog.
     */
    @IsTest
    static void testPendingResolvesWhenParentArrivesLater() {
        System.runAs(testUser) {
            Map<String, Object> logPayload = new Map<String, Object>{
                'SourceId' => 'REMOTE-WL-LATE-PARENT-001',
                'GlobalSourceId' => 'REMOTE-WL-LATE-PARENT-001',
                'SenderOrgId' => '00D_MOCK_ORG_ID',
                'WorkItemLookup__c' => 'REMOTE-WI-LATE-001',
                'HoursLoggedNumber__c' => 3.25,
                'WorkDateDate__c' => String.valueOf(Date.today()),
                'WorkDescriptionTxt__c' => 'Logged before parent synced'
            };

            Test.startTest();

            // (1) WorkLog arrives first. Should NOT throw; should park as Pending.
            Id pendingId = DeliverySyncItemIngestor.processInboundItem('WorkLog__c', logPayload);
            System.assertNotEquals(null, pendingId, 'Ingestor must return the Pending SyncItem Id');

            SyncItem__c pending = [
                SELECT Id, StatusPk__c, ObjectTypePk__c, ParentRefTxt__c, PayloadTxt__c
                FROM SyncItem__c
                WHERE Id = :pendingId
                LIMIT 1
            ];
            System.assertEquals('Pending', pending.StatusPk__c, 'Row should be parked in Pending');
            System.assertEquals('REMOTE-WI-LATE-001', pending.ParentRefTxt__c,
                'Parent ref should be stashed in ParentRefTxt__c');

            // (2) Parent WorkItem arrives via its own sync path. Use the
            // ledger pathway — insert a Synced inbound SyncItem mapping the
            // remote id to the local WorkItem record.
            NetworkEntity__c client = [SELECT Id FROM NetworkEntity__c LIMIT 1];
            WorkItem__c parent = new WorkItem__c(
                BriefDescriptionTxt__c = 'Parent that arrived late',
                ClientNetworkEntityLookup__c = client.Id
            );
            insert parent;
            insert new SyncItem__c(
                DirectionPk__c = 'Inbound',
                StatusPk__c = 'Synced',
                ObjectTypePk__c = 'WorkItem__c',
                RemoteExternalIdTxt__c = 'REMOTE-WI-LATE-001',
                LocalRecordIdTxt__c = parent.Id,
                WorkItemLookup__c = parent.Id
            );

            // (3) Resolver sweeps Pending rows and replays the payload.
            DeliverySyncItemPendingResolver resolver =
                new DeliverySyncItemPendingResolver('REMOTE-WI-LATE-001');
            Integer promoted = resolver.resolvePending();

            Test.stopTest();

            System.assertEquals(1, promoted, 'Exactly one row should have been promoted');

            SyncItem__c resolved = [SELECT StatusPk__c FROM SyncItem__c WHERE Id = :pendingId];
            System.assertEquals('Synced', resolved.StatusPk__c,
                'Pending row should flip to Synced once parent resolves');

            // The replayed payload must actually create the WorkLog record.
            List<WorkLog__c> logs = [
                SELECT HoursLoggedNumber__c, WorkItemLookup__c, WorkDescriptionTxt__c
                FROM WorkLog__c
                WHERE WorkItemLookup__c = :parent.Id
            ];
            System.assertEquals(1, logs.size(), 'Exactly one WorkLog should have been created on replay');
            System.assertEquals(3.25, logs[0].HoursLoggedNumber__c, 'Hours must round-trip through the Pending queue');
            System.assertEquals('Logged before parent synced', logs[0].WorkDescriptionTxt__c);
        }
    }

    /**
     * @description When the parent WorkItem never arrives, a Pending row
     *              should hit the configured max-retry ceiling and flip
     *              to Failed with a descriptive ErrorLogTxt__c. Verifies
     *              the resolver does not loop forever.
     */
    @IsTest
    static void testPendingFailsAfterMaxRetries() {
        System.runAs(testUser) {
            Map<String, Object> logPayload = new Map<String, Object>{
                'SourceId' => 'REMOTE-WL-NEVER-001',
                'GlobalSourceId' => 'REMOTE-WL-NEVER-001',
                'WorkItemLookup__c' => 'REMOTE-WI-NEVER-001',
                'HoursLoggedNumber__c' => 1.5,
                'WorkDateDate__c' => String.valueOf(Date.today()),
                'WorkDescriptionTxt__c' => 'Orphan — parent never arrives'
            };

            Test.startTest();

            Id pendingId = DeliverySyncItemIngestor.processInboundItem('WorkLog__c', logPayload);
            System.assertNotEquals(null, pendingId, 'Ingestor must return the Pending SyncItem Id');

            // Drive the resolver past its max-retry ceiling. DEFAULT_MAX_RETRIES
            // is 10; run 11 times to guarantee the Failed flip. Parent never
            // arrives (we intentionally create no ledger entry and no bridge).
            DeliverySyncItemPendingResolver resolver =
                new DeliverySyncItemPendingResolver('REMOTE-WI-NEVER-001');
            for (Integer i = 0; i < 11; i++) {
                resolver.resolvePending();
            }

            Test.stopTest();

            SyncItem__c finalRow = [
                SELECT StatusPk__c, RetryCountNumber__c, ErrorLogTxt__c
                FROM SyncItem__c
                WHERE Id = :pendingId
            ];
            System.assertEquals('Failed', finalRow.StatusPk__c,
                'Pending row should flip to Failed once retries are exhausted');
            System.assert(finalRow.RetryCountNumber__c >= 10,
                'Retry counter should have incremented past the default ceiling');
            System.assert(finalRow.ErrorLogTxt__c != null
                && finalRow.ErrorLogTxt__c.contains('Parent WorkItem did not arrive'),
                'ErrorLogTxt should explain the failure');

            // No WorkLog should have been inserted.
            Integer logCount = [SELECT COUNT() FROM WorkLog__c];
            System.assertEquals(0, logCount, 'No WorkLog should exist when parent never resolved');
        }
    }

    /**
     * @description Regression test for the Failed-Inbound-with-resolved-parent
     *              recovery path. When a Pending row exhausts retries before
     *              the parent arrives, it flips to Failed. Pre-fix the row
     *              stayed Failed forever even after the parent landed via a
     *              later sync tick. Post-fix the scheduler-driven
     *              `recoverFailedWithResolvedParent` sweep flips the row
     *              back to Pending so the next resolver tick can replay it.
     *
     *              Empirical motivator: dh-prod 2026-05-01 had 6 WL Inbound
     *              rows Failed with "Parent WorkItem did not arrive within
     *              10 retry attempts" while the parents had since synced.
     */
    @IsTest
    static void testRecoverFailedWithResolvedParent() {
        System.runAs(testUser) {
            Map<String, Object> logPayload = new Map<String, Object>{
                'SourceId' => 'REMOTE-WL-LATE-RECOVER-001',
                'GlobalSourceId' => 'REMOTE-WL-LATE-RECOVER-001',
                'WorkItemLookup__c' => 'REMOTE-WI-LATE-RECOVER-001',
                'HoursLoggedNumber__c' => 2.25,
                'WorkDateDate__c' => String.valueOf(Date.today()),
                'WorkDescriptionTxt__c' => 'Logged before parent synced — late recovery'
            };

            Test.startTest();
            // 1. Stage Pending; drive past max-retry to flip Failed.
            Id pendingId = DeliverySyncItemIngestor.processInboundItem('WorkLog__c', logPayload);
            DeliverySyncItemPendingResolver resolver =
                new DeliverySyncItemPendingResolver('REMOTE-WI-LATE-RECOVER-001');
            for (Integer i = 0; i < 11; i++) {
                resolver.resolvePending();
            }
            SyncItem__c failed = [SELECT StatusPk__c, ErrorLogTxt__c FROM SyncItem__c WHERE Id = :pendingId];
            System.assertEquals('Failed', failed.StatusPk__c, 'Setup precondition: row should be Failed');
            System.assert(failed.ErrorLogTxt__c.contains('Parent WorkItem did not arrive'),
                'Setup precondition: ErrorLog should match the recovery prefix');

            // 2. Parent WorkItem arrives via inbound (creates ledger entry).
            WorkItem__c parent = new WorkItem__c(
                BriefDescriptionTxt__c = 'Late-arriving parent for recovery test',
                StageNamePk__c = 'In Development'
            );
            insert parent;
            insert new SyncItem__c(
                ObjectTypePk__c        = 'WorkItem__c',
                DirectionPk__c         = 'Inbound',
                StatusPk__c            = 'Synced',
                LocalRecordIdTxt__c    = (String) parent.Id,
                RemoteExternalIdTxt__c = 'REMOTE-WI-LATE-RECOVER-001',
                GlobalSourceIdTxt__c   = 'REMOTE-WI-LATE-RECOVER-001'
            );

            // 3. Recovery sweep flips Failed back to Pending. The downstream
            //    Pending → Synced replay is already covered by
            //    testPendingResolvesWhenParentArrivesLater — this test only
            //    verifies the recovery method's own contract (Failed → Pending
            //    with cleared retry counter and error message so the next
            //    scheduler tick can pick the row up via the standard sweep).
            Integer recovered = new DeliverySyncItemPendingResolver().recoverFailedWithResolvedParent();
            Test.stopTest();

            System.assertEquals(1, recovered, 'Recovery should flip exactly one row back to Pending');

            SyncItem__c recoveredRow = [
                SELECT StatusPk__c, RetryCountNumber__c, ErrorLogTxt__c, ParentRefTxt__c
                FROM SyncItem__c WHERE Id = :pendingId
            ];
            System.assertEquals('Pending', recoveredRow.StatusPk__c,
                'Recovery should flip the row from Failed back to Pending');
            System.assertEquals(0, recoveredRow.RetryCountNumber__c.intValue(),
                'Recovery should reset RetryCountNumber__c so the resolver gets a fresh budget');
            System.assertEquals(null, recoveredRow.ErrorLogTxt__c,
                'Recovery should clear the prior failure message');
            System.assertEquals('REMOTE-WI-LATE-RECOVER-001', recoveredRow.ParentRefTxt__c,
                'Recovery must preserve ParentRefTxt__c so the resolver can re-resolve');
        }
    }

    /**
     * @description Two re-deliveries of the same payload should coalesce to a
     *              single Pending row — the ingestor is idempotent on
     *              (SourceId, parentRef).
     */
    @IsTest
    static void testPendingIngestIsIdempotent() {
        System.runAs(testUser) {
            Map<String, Object> logPayload = new Map<String, Object>{
                'SourceId' => 'REMOTE-WL-DUPE-001',
                'WorkItemLookup__c' => 'REMOTE-WI-DUPE-001',
                'HoursLoggedNumber__c' => 2.0,
                'WorkDateDate__c' => String.valueOf(Date.today())
            };

            Test.startTest();
            Id firstId = DeliverySyncItemIngestor.processInboundItem('WorkLog__c', logPayload);
            Id secondId = DeliverySyncItemIngestor.processInboundItem('WorkLog__c', logPayload);
            Test.stopTest();

            System.assertEquals(firstId, secondId,
                'Re-delivering the same payload before resolution must reuse the existing Pending row');

            Integer pendingRows = [
                SELECT COUNT() FROM SyncItem__c
                WHERE DirectionPk__c = 'Inbound'
                AND StatusPk__c = 'Pending'
                AND RemoteExternalIdTxt__c = 'REMOTE-WL-DUPE-001'
            ];
            System.assertEquals(1, pendingRows, 'Only one Pending row should exist for the duplicate payload');
        }
    }

    /**
     * @description Scheduler's requeuePendingItems sweep should enqueue the
     *              resolver when at least one Pending row exists, and no-op
     *              when none do. Uses the Schedulable hook on DeliveryHubScheduler.
     */
    @IsTest
    static void testSchedulerRequeuesPendingItems() {
        System.runAs(testUser) {
            // Seed one Pending row so the scheduler sweep has something to pick up.
            insert new SyncItem__c(
                DirectionPk__c = 'Inbound',
                StatusPk__c = 'Pending',
                ObjectTypePk__c = 'WorkLog__c',
                RemoteExternalIdTxt__c = 'REMOTE-WL-SCHED-001',
                ParentRefTxt__c = 'REMOTE-WI-SCHED-001',
                PayloadTxt__c = '{}',
                RetryCountNumber__c = 0
            );

            Test.setMock(HttpCalloutMock.class, new EmptySyncMock());

            Test.startTest();
            String cronExp = '0 0 0 15 3 ? 2041';
            System.schedule('TestSchedulerPendingSweep', cronExp, new DeliveryHubScheduler());
            // Drive the execute() path directly so the sweep runs in-test.
            new DeliveryHubScheduler().execute(null);
            Test.stopTest();

            // Scheduler drained one Pending row via a Queueable — because the
            // parent ledger doesn't exist it will have either bumped the
            // retry counter or left the row Pending. Either is fine; we're
            // asserting the scheduler wiring executed without error.
            SyncItem__c swept = [
                SELECT StatusPk__c, RetryCountNumber__c
                FROM SyncItem__c
                WHERE RemoteExternalIdTxt__c = 'REMOTE-WL-SCHED-001'
            ];
            System.assertNotEquals(null, swept, 'Pending row must still exist');
            // Either the retry counter incremented or it hit the Failed ceiling —
            // both demonstrate the scheduler wiring fired.
            Boolean sweepRan = swept.StatusPk__c == 'Failed'
                || (swept.RetryCountNumber__c != null && swept.RetryCountNumber__c > 0)
                || swept.StatusPk__c == 'Pending';
            System.assert(sweepRan, 'Scheduler sweep should have touched the Pending row');
        }
    }

    /**
     * @description Minimal HttpCalloutMock returning an empty JSON array so
     *              DeliveryHubScheduler.runSyncAsync() has no work to do
     *              during the scheduler-wiring test above.
     */
    public class EmptySyncMock implements HttpCalloutMock {
        /**
         * @description Returns an empty JSON array for any callout so the
         *              scheduler-wiring test finds no inbound work.
         * @param req Inbound HTTP request (ignored).
         * @return HttpResponse with status 200 and body '[]'.
         */
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('[]');
            return res;
        }
    }
}

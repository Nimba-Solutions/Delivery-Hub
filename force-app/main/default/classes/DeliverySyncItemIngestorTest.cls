/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Verifies inbound ingestion logic with namespace awareness.
 * V2 Architecture: Tests both Downstream (Request) and Upstream (Ledger) DAG traversal.
 * @author Cloud Nimbus LLC
 */
@IsTest
private class DeliverySyncItemIngestorTest {

    private static User testUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];

    @TestSetup
    static void makeData() {
        // 1. Create Upstream Client Entity
        NetworkEntity__c client = new NetworkEntity__c(
            Name = 'Upstream Client', 
            EntityTypePk__c = 'Client', 
            StatusPk__c = 'Active'
        );
        insert client;

        // 2. Create Work Item linked to Upstream Client
        WorkItem__c t = new WorkItem__c(
            BriefDescriptionTxt__c = 'Base Work Item',
            ClientNetworkEntityLookup__c = client.Id
        );
        insert t;

        // 3. Create Downstream Request Bridge
        insert new WorkRequest__c(
            WorkItemId__c = t.Id,
            RemoteWorkItemIdTxt__c = 'REMOTE-123',
            StatusPk__c = 'Active'
        );
        
        // 4. Create an Upstream Ledger Entry (Simulating a workItem that came from the Client)
        insert new SyncItem__c(
            DirectionPk__c = 'Inbound',
            StatusPk__c = 'Synced',
            ObjectTypePk__c = 'WorkItem__c',
            RemoteExternalIdTxt__c = 'REMOTE-CLIENT-WORKITEM-1',
            LocalRecordIdTxt__c = t.Id,
            WorkItemLookup__c = t.Id
        );
    }

    @IsTest
    static void testProcessInboundWorkItemUpdateDownstreamEdge() {
        System.runAs(testUser) {
            Map<String, Object> payload = new Map<String, Object>{
                'SourceId' => 'REMOTE-123',
                'BriefDescriptionTxt__c' => 'Updated via Inbound Sync'
            };

            Test.startTest();
            DeliverySyncItemIngestor.processInboundItem('WorkItem__c', payload);
            Test.stopTest();

            WorkItem__c updated = [SELECT BriefDescriptionTxt__c FROM WorkItem__c LIMIT 1];
            System.assertEquals('Updated via Inbound Sync', updated.BriefDescriptionTxt__c, 'Work item description should be updated via robust field mapping');

            // V2 Verification: Engine memory should have captured the Request ID to block echoes
            System.assert(DeliverySyncEngine.blockedOrigins.size() > 0, 'Origin edge should be blocked for echo suppression');
        }
    }

    @IsTest
    static void testProcessInboundCommentInsertDownstreamEdge() {
        System.runAs(testUser) {
            Map<String, Object> payload = new Map<String, Object>{
                'SourceId' => 'REMOTE-COMM-456',
                'TargetId' => 'REMOTE-123', // Matches the Request Bridge
                'BodyTxt__c' => 'New Inbound Comment',
                'AuthorTxt__c' => 'Vendor'
            };

            Test.startTest();
            DeliverySyncItemIngestor.processInboundItem('WorkItemComment__c', payload);
            Test.stopTest();

            // Verify insertion
            WorkItemComment__c comm = [SELECT BodyTxt__c FROM WorkItemComment__c WHERE AuthorTxt__c = 'Vendor' LIMIT 1];
            System.assertNotEquals(null, comm, 'Comment should be inserted');

            // Verify V2 Ledger Routing
            SyncItem__c ledger = [SELECT ObjectTypePk__c, RequestLookup__c FROM SyncItem__c WHERE RemoteExternalIdTxt__c = 'REMOTE-COMM-456' LIMIT 1];
            System.assert(ledger.ObjectTypePk__c.contains('WorkItemComment__c'), 'Ledger must have valid ObjectTypePk__c value');
            System.assertNotEquals(null, ledger.RequestLookup__c, 'V2 DAG Rule: RequestId__c MUST be stamped on the inbound ledger item to log the routing edge.');
        }
    }
    
    @IsTest
    static void testProcessInboundCommentInsertUpstreamEdge() {
        System.runAs(testUser) {
            // TargetId points to the Client's remote ID stored in the Ledger (no WorkRequest__c bridge exists for this)
            Map<String, Object> payload = new Map<String, Object>{
                'SourceId' => 'REMOTE-COMM-789',
                'TargetId' => 'REMOTE-CLIENT-WORKITEM-1', 
                'BodyTxt__c' => 'Upstream Client Comment',
                'AuthorTxt__c' => 'Client'
            };

            Test.startTest();
            DeliverySyncItemIngestor.processInboundItem('WorkItemComment__c', payload);
            Test.stopTest();

            // Verify insertion
            WorkItemComment__c comm = [SELECT BodyTxt__c FROM WorkItemComment__c WHERE AuthorTxt__c = 'Client' LIMIT 1];
            System.assertNotEquals(null, comm, 'Comment should be inserted');

            // Verify V2 Ledger Routing & Upstream Echo Suppression
            SyncItem__c ledger = [SELECT ObjectTypePk__c, RequestLookup__c FROM SyncItem__c WHERE RemoteExternalIdTxt__c = 'REMOTE-COMM-789' LIMIT 1];
            System.assertEquals(null, ledger.RequestLookup__c, 'V2 DAG Rule: RequestId__c must be NULL since this came from an upstream Client Ledger translation.');
            System.assert(DeliverySyncEngine.blockedOrigins.size() > 0, 'The ClientNetworkEntityLookup__c must have been passed to memory to block upstream echoes.');
        }
    }

    @IsTest
    static void testProcessInboundWorkLogResolvesParentViaLedger() {
        System.runAs(testUser) {
            // Simulates a WorkLog arriving from a client org where:
            // - The parent WorkItem already exists locally (via prior sync)
            // - The payload references the remote WorkItem ID
            // - Cross-org lookup IDs in payload must be stripped before insert
            WorkItem__c localItem = [SELECT Id FROM WorkItem__c LIMIT 1];
            WorkRequest__c localReq = [SELECT Id FROM WorkRequest__c WHERE WorkItemId__c = :localItem.Id LIMIT 1];

            Map<String, Object> payload = new Map<String, Object>{
                'SourceId' => 'REMOTE-WORKLOG-001',
                'SenderOrgId' => '00D_MOCK_ORG_ID',
                'GlobalSourceId' => 'REMOTE-WORKLOG-001',
                'WorkItemLookup__c' => 'REMOTE-CLIENT-WORKITEM-1',  // remote ID — resolved via Ledger
                'RequestId__c' => 'REMOTE-REQUEST-INVALID',      // cross-org ID — must be stripped
                'HoursLoggedNumber__c' => 4.5,
                'WorkDateDate__c' => String.valueOf(Date.today()),
                'WorkDescriptionTxt__c' => 'Inbound work log test'
            };

            Test.startTest();
            Id resultId = DeliverySyncItemIngestor.processInboundItem('WorkLog__c', payload);
            Test.stopTest();

            System.assertNotEquals(null, resultId, 'WorkLog should have been created');

            WorkLog__c wl = [SELECT HoursLoggedNumber__c, WorkItemLookup__c, RequestId__c, WorkDescriptionTxt__c FROM WorkLog__c WHERE Id = :resultId];
            System.assertEquals(4.5, wl.HoursLoggedNumber__c, 'Hours should be mapped from payload');
            System.assertEquals(localItem.Id, wl.WorkItemLookup__c, 'Parent WorkItem should resolve to local ID via Ledger');
            System.assertEquals(localReq.Id, wl.RequestId__c, 'RequestId should resolve to local WorkRequest, not the remote ID');
            System.assertEquals('Inbound work log test', wl.WorkDescriptionTxt__c, 'Description should be mapped');

            // Verify ledger entry was created
            SyncItem__c ledger = [SELECT RemoteExternalIdTxt__c, ObjectTypePk__c FROM SyncItem__c WHERE RemoteExternalIdTxt__c = 'REMOTE-WORKLOG-001' LIMIT 1];
            System.assert(ledger.ObjectTypePk__c.contains('WorkLog__c'), 'Ledger entry should be created for the WorkLog');
        }
    }

    @IsTest
    static void testFindLocalIdIgnoresNullSourceId() {
        System.runAs(testUser) {
            // When SourceId is null (e.g., from older payloads missing routing metadata),
            // findLocalId must return null — NOT match ledger entries with null RemoteExternalIdTxt__c
            Map<String, Object> payload = new Map<String, Object>{
                'WorkItemLookup__c' => 'REMOTE-CLIENT-WORKITEM-1',
                'HoursLoggedNumber__c' => 2.0,
                'WorkDateDate__c' => String.valueOf(Date.today()),
                'WorkDescriptionTxt__c' => 'First log without SourceId'
            };

            Test.startTest();
            Id firstId = DeliverySyncItemIngestor.processInboundItem('WorkLog__c', payload);

            // Second call with a different payload but also no SourceId
            Map<String, Object> payload2 = new Map<String, Object>{
                'WorkItemLookup__c' => 'REMOTE-CLIENT-WORKITEM-1',
                'HoursLoggedNumber__c' => 3.0,
                'WorkDateDate__c' => String.valueOf(Date.today().addDays(-1)),
                'WorkDescriptionTxt__c' => 'Second log without SourceId'
            };
            Id secondId = DeliverySyncItemIngestor.processInboundItem('WorkLog__c', payload2);
            Test.stopTest();

            System.assertNotEquals(null, firstId, 'First WorkLog should be created');
            System.assertNotEquals(null, secondId, 'Second WorkLog should be created');
            System.assertNotEquals(firstId, secondId, 'Each call must create a SEPARATE WorkLog — null SourceId must not match existing ledger entries');

            Integer logCount = [SELECT COUNT() FROM WorkLog__c];
            System.assertEquals(2, logCount, 'Two distinct WorkLogs must exist');
        }
    }

    @IsTest
    static void testTargetIdPointingAtDeletedRecordFallsThroughToInsert() {
        System.runAs(testUser) {
            // Simulate the production drift scenario: a sender's bridge points
            // at a local record that we've since deleted. Without this fix the
            // receiver would Database.update on the deleted Id, get silent
            // success, and the real record would never receive the change.
            WorkItem__c stale = new WorkItem__c(BriefDescriptionTxt__c = 'Will be deleted');
            insert stale;
            Id staleId = stale.Id;
            delete stale;

            Map<String, Object> payload = new Map<String, Object>{
                'SourceId' => 'REMOTE-STALE-TARGET-001',
                'TargetId' => (String) staleId,
                'BriefDescriptionTxt__c' => 'Should create new record, not silently no-op on the deleted one'
            };

            Test.startTest();
            Id resultId = DeliverySyncItemIngestor.processInboundItem('WorkItem__c', payload);
            Test.stopTest();

            System.assertNotEquals(null, resultId, 'Result should be a freshly inserted record Id');
            System.assertNotEquals(staleId, resultId, 'Result must NOT be the stale deleted Id — that path is the bug we are fixing');

            WorkItem__c created = [SELECT Id, BriefDescriptionTxt__c FROM WorkItem__c WHERE Id = :resultId];
            System.assertEquals('Should create new record, not silently no-op on the deleted one', created.BriefDescriptionTxt__c);

            // The insert path also creates a ledger entry — verifying that ensures
            // future syncs for this SourceId will resolve to the freshly created record.
            SyncItem__c ledger = [SELECT LocalRecordIdTxt__c FROM SyncItem__c WHERE RemoteExternalIdTxt__c = 'REMOTE-STALE-TARGET-001' AND DirectionPk__c = 'Inbound' LIMIT 1];
            System.assertEquals((String) resultId, ledger.LocalRecordIdTxt__c, 'Ledger entry must record the new local Id so subsequent syncs auto-resolve');
        }
    }

    @IsTest
    static void testStaleLedgerEntrySkippedFavorsActiveRecord() {
        System.runAs(testUser) {
            // Older inbound created a local record that has since been deleted —
            // but a newer inbound (correctly) created a fresh active record. Both
            // ledger entries share the same RemoteExternalIdTxt__c. The resolver
            // must skip the deleted-target entry and pick the active one.
            WorkItem__c stale = new WorkItem__c(BriefDescriptionTxt__c = 'Stale duplicate');
            insert stale;
            Id staleId = stale.Id;

            WorkItem__c active = new WorkItem__c(BriefDescriptionTxt__c = 'Active canonical');
            insert active;

            // Older entry pointing at the doomed record
            insert new SyncItem__c(
                DirectionPk__c = 'Inbound',
                StatusPk__c = 'Synced',
                ObjectTypePk__c = 'WorkItem__c',
                RemoteExternalIdTxt__c = 'REMOTE-DUPE-WORKITEM',
                LocalRecordIdTxt__c = (String) staleId,
                WorkItemLookup__c = staleId
            );
            // Newer entry pointing at the canonical record
            insert new SyncItem__c(
                DirectionPk__c = 'Inbound',
                StatusPk__c = 'Synced',
                ObjectTypePk__c = 'WorkItem__c',
                RemoteExternalIdTxt__c = 'REMOTE-DUPE-WORKITEM',
                LocalRecordIdTxt__c = (String) active.Id,
                WorkItemLookup__c = active.Id
            );

            // Delete the stale record — its ledger entry remains but is now stale
            delete stale;

            Map<String, Object> payload = new Map<String, Object>{
                'SourceId' => 'REMOTE-DUPE-WORKITEM',
                'BriefDescriptionTxt__c' => 'Updated via ledger fallback'
            };

            Test.startTest();
            Id resultId = DeliverySyncItemIngestor.processInboundItem('WorkItem__c', payload);
            Test.stopTest();

            System.assertEquals(active.Id, resultId, 'Resolver must skip the stale-target ledger entry and find the active record');
            WorkItem__c updated = [SELECT BriefDescriptionTxt__c FROM WorkItem__c WHERE Id = :active.Id];
            System.assertEquals('Updated via ledger fallback', updated.BriefDescriptionTxt__c);
        }
    }

    @IsTest
    static void testProcessInboundWorkItemAutoParentsClient() {
        System.runAs(testUser) {
            // 1. Setup a Client Network Entity with a simulated Org ID
            String simulatedOrgId = '00D_MOCK_ORG_ID';
            NetworkEntity__c clientEntity = new NetworkEntity__c(
                Name = 'Simulated Upstream Client',
                EntityTypePk__c = 'Client',
                StatusPk__c = 'Active',
                RemoteExternalIdTxt__c = simulatedOrgId // This is what the Ingestor will look for
            );
            insert clientEntity;

            // 2. Create an inbound payload simulating a brand new workItem pushed from the Client
            Map<String, Object> payload = new Map<String, Object>{
                'SourceId' => 'REMOTE-WORKITEM-999',
                'BriefDescriptionTxt__c' => 'Testing Auto-Parenting',
                'SenderOrgId' => simulatedOrgId // The new Identity Injection!
            };

            Test.startTest();
            // 3. Process the inbound item
            DeliverySyncItemIngestor.processInboundItem('WorkItem__c', payload);
            Test.stopTest();

            // 4. Verify the Work Item was inserted AND automatically parented to the Client
            WorkItem__c insertedWorkItem = [
                SELECT Id, BriefDescriptionTxt__c, ClientNetworkEntityLookup__c 
                FROM WorkItem__c 
                WHERE BriefDescriptionTxt__c = 'Testing Auto-Parenting' 
                LIMIT 1
            ];

            System.assertNotEquals(null, insertedWorkItem, 'Work item should have been created successfully.');
            System.assertEquals(clientEntity.Id, insertedWorkItem.ClientNetworkEntityLookup__c, 'The Ingestor should have automatically stamped the ClientNetworkEntityLookup__c based on the SenderOrgId in the payload.');
        }
    }

    /**
     * @description Verifies the pull-callout ContentVersion branch: an inbound
     *              metadata-only payload should create a Queued inbound ledger
     *              row keyed to the local WorkItem — no ContentVersion insert
     *              attempted in-band. The DeliveryFileBytesFetcher Queueable
     *              takes it from there (covered by its own test).
     */
    @IsTest
    static void testInboundContentVersionPullCalloutCreatesLedger() {
        System.runAs(testUser) {
            WorkItem__c wi = [SELECT Id FROM WorkItem__c LIMIT 1];

            Map<String, Object> payload = new Map<String, Object>{
                'SourceId' => '068999000000001',
                'TargetId' => 'REMOTE-123', // matches WorkRequest.RemoteWorkItemIdTxt__c
                'GlobalSourceId' => 'GSID-ABC',
                'SenderOrgId' => '00D000000000002',
                'ContentDocumentId' => '069999000000001AAA',
                'Title' => 'Pulled file',
                'PathOnClient' => 'pulled.txt',
                'FileTransport' => 'pull-callout',
                'Sha256' => '0'.repeat(64)
            };

            // Set a mock so the enqueued DeliveryFileBytesFetcher (if it runs)
            // doesn't crash the test. We're only validating ingestor behaviour
            // here; the fetcher is covered by its own test class.
            Test.setMock(HttpCalloutMock.class, new MockBytesQuiet(500, 'noop'));

            Test.startTest();
            Id resultId = DeliverySyncItemIngestor.processInboundItem('ContentVersion', payload);
            Test.stopTest();

            System.assertNotEquals(null, resultId, 'Should return the ledger row Id');

            SyncItem__c ledger = [
                SELECT Id, DirectionPk__c, StatusPk__c, ObjectTypePk__c,
                       WorkItemLookup__c, GlobalSourceIdTxt__c
                FROM SyncItem__c
                WHERE Id = :resultId
            ];
            System.assertEquals('Inbound', ledger.DirectionPk__c, 'Should be inbound');
            System.assertEquals('Queued', ledger.StatusPk__c, 'Should be Queued awaiting the fetcher');
            System.assertEquals('ContentVersion', ledger.ObjectTypePk__c, 'Object type should be ContentVersion');
            System.assertEquals(wi.Id, ledger.WorkItemLookup__c, 'Ledger should point at the resolved local WorkItem');
            System.assertEquals('GSID-ABC', ledger.GlobalSourceIdTxt__c, 'GlobalSourceId should be recorded for idempotency');

            // No ContentVersion should have been inserted in-band — the fetcher does that
            Integer cvCount = [SELECT COUNT() FROM ContentVersion WHERE Title = 'Pulled file'];
            System.assertEquals(0, cvCount, 'Ingestor must not insert ContentVersion directly in the pull-callout path');
        }
    }

    /**
     * @description Second pull-callout inbound with the same GlobalSourceId
     *              should NOT create a duplicate ledger row (idempotency).
     */
    @IsTest
    static void testInboundContentVersionPullCalloutIdempotent() {
        System.runAs(testUser) {
            Map<String, Object> payload = new Map<String, Object>{
                'SourceId' => '068999000000002',
                'TargetId' => 'REMOTE-123',
                'GlobalSourceId' => 'GSID-DUPE',
                'SenderOrgId' => '00D000000000002',
                'ContentDocumentId' => '069999000000002AAA',
                'Title' => 'Dup file',
                'PathOnClient' => 'dup.txt',
                'FileTransport' => 'pull-callout',
                'Sha256' => null
            };

            Test.setMock(HttpCalloutMock.class, new MockBytesQuiet(500, 'noop'));

            Test.startTest();
            Id first = DeliverySyncItemIngestor.processInboundItem('ContentVersion', payload);
            Id second = DeliverySyncItemIngestor.processInboundItem('ContentVersion', payload);
            Test.stopTest();

            System.assertEquals(first, second, 'Duplicate inbound should return existing ledger Id');
            Integer count = [SELECT COUNT() FROM SyncItem__c WHERE GlobalSourceIdTxt__c = 'GSID-DUPE'];
            System.assertEquals(1, count, 'Only one ledger row should exist for a given GlobalSourceId');
        }
    }

    /**
     * @description Minimal HttpCalloutMock for the pull-callout path —
     *              tests that exercise the ingestor enqueue a fetcher
     *              Queueable; this mock lets that Queueable fail cleanly
     *              instead of crashing the test harness.
     */
    private class MockBytesQuiet implements HttpCalloutMock {
        /** @description HTTP status to return. */
        private final Integer status;
        /** @description Response body to return. */
        private final String body;
        /**
         * @description Builds a quiet mock with the given status and body.
         * @param status HTTP status code.
         * @param body Response body as a string.
         */
        public MockBytesQuiet(Integer status, String body) {
            this.status = status;
            this.body = body;
        }
        /**
         * @description Returns the pre-configured mock HttpResponse.
         * @param req Ignored.
         * @return Mock HttpResponse.
         */
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(status);
            res.setBodyAsBlob(Blob.valueOf(body));
            return res;
        }
    }
}
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
            WorkItemLookup__c = t.Id,
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
            System.assertNotEquals(null, ledger.RequestLookup__c, 'V2 DAG Rule: RequestLookup__c MUST be stamped on the inbound ledger item to log the routing edge.');
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
            System.assertEquals(null, ledger.RequestLookup__c, 'V2 DAG Rule: RequestLookup__c must be NULL since this came from an upstream Client Ledger translation.');
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
            WorkRequest__c localReq = [SELECT Id FROM WorkRequest__c WHERE WorkItemLookup__c = :localItem.Id LIMIT 1];

            Map<String, Object> payload = new Map<String, Object>{
                'SourceId' => 'REMOTE-WORKLOG-001',
                'SenderOrgId' => '00D_MOCK_ORG_ID',
                'GlobalSourceId' => 'REMOTE-WORKLOG-001',
                'WorkItemLookup__c' => 'REMOTE-CLIENT-WORKITEM-1',  // remote ID — resolved via Ledger
                'RequestLookup__c' => 'REMOTE-REQUEST-INVALID',      // cross-org ID — must be stripped
                'HoursLoggedNumber__c' => 4.5,
                'WorkDateDate__c' => String.valueOf(Date.today()),
                'WorkDescriptionTxt__c' => 'Inbound work log test'
            };

            Test.startTest();
            Id resultId = DeliverySyncItemIngestor.processInboundItem('WorkLog__c', payload);
            Test.stopTest();

            System.assertNotEquals(null, resultId, 'WorkLog should have been created');

            WorkLog__c wl = [SELECT HoursLoggedNumber__c, WorkItemLookup__c, RequestLookup__c, WorkDescriptionTxt__c FROM WorkLog__c WHERE Id = :resultId];
            System.assertEquals(4.5, wl.HoursLoggedNumber__c, 'Hours should be mapped from payload');
            System.assertEquals(localItem.Id, wl.WorkItemLookup__c, 'Parent WorkItem should resolve to local ID via Ledger');
            System.assertEquals(localReq.Id, wl.RequestLookup__c, 'RequestId should resolve to local WorkRequest, not the remote ID');
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
}
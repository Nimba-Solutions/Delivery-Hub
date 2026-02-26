/**
 * @description Verifies inbound ingestion logic with namespace awareness.
 * V2 Architecture: Tests both Downstream (Request) and Upstream (Ledger) DAG traversal.
 * @author Cloud Nimbus LLC
 */
@IsTest
private class DeliverySyncItemIngestorTest {

    @TestSetup
    static void makeData() {
        // 1. Create Upstream Client Entity
        Network_Entity__c client = new Network_Entity__c(
            Name = 'Upstream Client', 
            EntityTypePk__c = 'Client', 
            StatusPk__c = 'Active'
        );
        insert client;

        // 2. Create Work Item linked to Upstream Client
        WorkItem__c t = new WorkItem__c(
            BriefDescriptionTxt__c = 'Base Work Item',
            ClientNetworkEntityId__c = client.Id
        );
        insert t;

        // 3. Create Downstream Request Bridge
        insert new WorkRequest__c(
            WorkItemId__c = t.Id,
            RemoteWorkItemIdTxt__c = 'REMOTE-123',
            StatusPk__c = 'Active'
        );
        
        // 4. Create an Upstream Ledger Entry (Simulating a workItem that came from the Client)
        insert new Sync_Item__c(
            DirectionPk__c = 'Inbound',
            StatusPk__c = 'Synced',
            ObjectTypePk__c = 'WorkItem__c',
            RemoteExternalIdTxt__c = 'REMOTE-CLIENT-WORKITEM-1',
            LocalRecordIdTxt__c = t.Id,
            WorkItemId__c = t.Id
        );
    }

    @IsTest
    static void testProcessInboundWorkItemUpdateDownstreamEdge() {
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

    @IsTest
    static void testProcessInboundCommentInsertDownstreamEdge() {
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
        Sync_Item__c ledger = [SELECT ObjectTypePk__c, RequestId__c FROM Sync_Item__c WHERE RemoteExternalIdTxt__c = 'REMOTE-COMM-456' LIMIT 1];
        System.assert(ledger.ObjectTypePk__c.contains('WorkItemComment__c'), 'Ledger must have valid ObjectTypePk__c value');
        System.assertNotEquals(null, ledger.RequestId__c, 'V2 DAG Rule: RequestId__c MUST be stamped on the inbound ledger item to log the routing edge.');
    }
    
    @IsTest
    static void testProcessInboundCommentInsertUpstreamEdge() {
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
        Sync_Item__c ledger = [SELECT ObjectTypePk__c, RequestId__c FROM Sync_Item__c WHERE RemoteExternalIdTxt__c = 'REMOTE-COMM-789' LIMIT 1];
        System.assertEquals(null, ledger.RequestId__c, 'V2 DAG Rule: RequestId__c must be NULL since this came from an upstream Client Ledger translation.');
        System.assert(DeliverySyncEngine.blockedOrigins.size() > 0, 'The ClientNetworkEntityId__c must have been passed to memory to block upstream echoes.');
    }

    @IsTest
    static void testProcessInboundWorkItemAutoParentsClient() {
        // 1. Setup a Client Network Entity with a simulated Org ID
        String simulatedOrgId = '00D_MOCK_ORG_ID';
        Network_Entity__c clientEntity = new Network_Entity__c(
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
            SELECT Id, BriefDescriptionTxt__c, ClientNetworkEntityId__c 
            FROM WorkItem__c 
            WHERE BriefDescriptionTxt__c = 'Testing Auto-Parenting' 
            LIMIT 1
        ];
        
        System.assertNotEquals(null, insertedWorkItem, 'Work item should have been created successfully.');
        System.assertEquals(clientEntity.Id, insertedWorkItem.ClientNetworkEntityId__c, 'The Ingestor should have automatically stamped the ClientNetworkEntityId__c based on the SenderOrgId in the payload.');
    }
}
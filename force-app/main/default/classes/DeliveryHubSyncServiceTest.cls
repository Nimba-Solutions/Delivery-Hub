/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Test class for DeliveryHubSyncService.
 * Verifies the REST entry point for both Push (POST) and Pull (GET) flows,
 * ensuring namespace awareness and strict V2 multi-tenant data segregation.
 * @author Cloud Nimbus LLC
 */
@IsTest
private class DeliveryHubSyncServiceTest {

    @TestSetup
    static void makeData() {
        // 1. Setup Settings
        insert new DeliveryHubSettings__c(
            AutoCreateWorkRequestBool__c = false,
            AutoSyncNetworkEntityBool__c = false
        );

        // 2. Create Network Entities (Vendor & Client)
        NetworkEntity__c vendor = new NetworkEntity__c(
            Name = 'Test Vendor',
            StatusPk__c = 'Active',
            EntityTypePk__c = 'Vendor'
        );
        NetworkEntity__c client = new NetworkEntity__c(
            Name = 'Test Client',
            StatusPk__c = 'Active',
            EntityTypePk__c = 'Client'
        );
        insert new List<NetworkEntity__c>{vendor, client};

        // 3. Create Work Item (Explicitly linked to the Client)
        WorkItem__c t = new WorkItem__c(
            BriefDescriptionTxt__c = 'Original Name',
            StageNamePk__c = 'Backlog',
            ClientNetworkEntityId__c = client.Id
        );
        insert t;

        // 4. Create Request (The Ledger bridge linking Work Item to Remote ID)
        insert new WorkRequest__c(
            WorkItemId__c = t.Id,
            DeliveryEntityId__c = vendor.Id,
            RemoteWorkItemIdTxt__c = 'REMOTE-WORKITEM-123',
            StatusPk__c = 'Active'
        );
        
        // 5. V2 ARCHITECTURE: Stage an Outbound Hub Item for the GET tests
        insert new SyncItem__c(
            DirectionPk__c = 'Outbound',
            StatusPk__c = 'Queued',
            RequestId__c = null, // Null indicates Hub Mode
            WorkItemId__c = t.Id,  // Mandatory for routing
            ObjectTypePk__c = 'WorkItem__c',
            PayloadTxt__c = '{"Test":"Payload"}'
        );
    }

    // ==========================================
    // INBOUND PUSH TESTS (POST)
    // ==========================================

    @IsTest
    static void testHttpPostInvalidObject() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        req.requestURI = '/services/apexrest/deliveryhub/v1/sync/Invalid_Object__c';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(JSON.serialize(new Map<String, Object>{'SourceId' => '123'}));
        
        RestContext.request = req;
        RestContext.response = res; 

        Test.startTest();
        DeliveryHubSyncService.handleIncomingSync();
        Test.stopTest();

        System.assertEquals(500, res.statusCode, 'Should return 500 for invalid object types');
    }

    @IsTest
    static void testWorkItemUpdateViaService() {
        String remoteId = 'REMOTE-WORKITEM-123';
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        req.requestURI = '/services/apexrest/deliveryhub/v1/sync/WorkItem__c';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(JSON.serialize(new Map<String, Object>{
            'SourceId' => remoteId,
            'BriefDescriptionTxt__c' => 'Updated Description'
        }));
        
        RestContext.request = req;
        RestContext.response = res; 

        Test.startTest();
        DeliveryHubSyncService.handleIncomingSync();
        Test.stopTest();

        System.assertEquals(200, res.statusCode, 'Should return 200 Success');
        
        WorkItem__c updatedT = [SELECT BriefDescriptionTxt__c FROM WorkItem__c LIMIT 1];
        System.assertEquals('Updated Description', updatedT.BriefDescriptionTxt__c, 'Work item should be updated via ledger lookup');
    }

    @IsTest
    static void testCommentInsertWithIdempotency() {
        String remoteWorkItemId = 'REMOTE-WORKITEM-123'; 
        String sourceId = 'REMOTE-COMMENT-999';
        String uniqueAuthor = 'REST_TEST_AUTHOR';

        Map<String, Object> payload = new Map<String, Object>{
            'TargetId' => remoteWorkItemId, 
            'SourceId' => sourceId,
            'AuthorTxt__c' => uniqueAuthor,
            'BodyTxt__c' => 'Service Tester Comment'
        };

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        req.requestURI = '/services/apexrest/deliveryhub/v1/sync/WorkItemComment__c';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(JSON.serialize(payload));
        
        RestContext.request = req;
        RestContext.response = res; 

        Test.startTest();
        // 1. First Sync: Should Insert
        DeliveryHubSyncService.handleIncomingSync();
        
        // 2. Second Sync (Duplicate): Should Update existing based on Ledger
        DeliveryHubSyncService.handleIncomingSync();
        Test.stopTest();

        List<WorkItemComment__c> comments = [SELECT Id FROM WorkItemComment__c WHERE AuthorTxt__c = :uniqueAuthor];
        System.assertEquals(1, comments.size(), 'Should have inserted exactly 1 comment due to ledger idempotency.');
    }

    // ==========================================
    // OUTBOUND PULL TESTS (GET) - V2 MULTI-TENANCY
    // ==========================================

    @IsTest
    static void testHttpGetChangesSuccess() {
        NetworkEntity__c client = [SELECT Id FROM NetworkEntity__c WHERE EntityTypePk__c = 'Client' LIMIT 1];
        
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        req.requestURI = '/services/apexrest/deliveryhub/v1/sync/changes';
        req.httpMethod = 'GET';
        req.addParameter('clientId', client.Id); 
        req.addParameter('since', '2000-01-01T00:00:00Z');
        
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        DeliveryHubSyncService.handleOutgoingSync();
        Test.stopTest();

        System.assertEquals(200, res.statusCode, 'Should return 200 OK');
        // FIX: Broadened the assertion to ignore JSON escaping slashes
        System.assert(res.responseBody.toString().contains('Payload'), 'Should successfully retrieve the isolated payload');
    }

    @IsTest
    static void testHttpGetChangesMissingClientId() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        req.requestURI = '/services/apexrest/deliveryhub/v1/sync/changes';
        req.httpMethod = 'GET';
        
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        DeliveryHubSyncService.handleOutgoingSync();
        Test.stopTest();

        System.assertEquals(400, res.statusCode, 'Should return 400 Bad Request if clientId is missing');
        System.assert(res.responseBody.toString().contains('Missing required parameter'), 'Response should state the missing parameter');
    }

    @IsTest
    static void testHttpGetChangesWrongEndpoint() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        req.requestURI = '/services/apexrest/deliveryhub/v1/sync/invalid_path';
        req.httpMethod = 'GET';
        
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        DeliveryHubSyncService.handleOutgoingSync();
        Test.stopTest();

        System.assertEquals(404, res.statusCode, 'Should return 404 Not Found for incorrect GET paths');
    }
}
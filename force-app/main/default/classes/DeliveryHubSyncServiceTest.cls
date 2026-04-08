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

    private static User testUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];

    @TestSetup
    static void makeData() {
        // 1. Setup Settings
        insert new DeliveryHubSettings__c(
            EnableAutoCreateWorkRequestDateTime__c = null,
            EnableAutoSyncNetworkEntityDateTime__c = null
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
            ClientNetworkEntityLookup__c = client.Id
        );
        insert t;

        // 4. Create Request (The Ledger bridge linking Work Item to Remote ID)
        insert new WorkRequest__c(
            WorkItemId__c = t.Id,
            DeliveryEntityLookup__c = vendor.Id,
            RemoteWorkItemIdTxt__c = 'REMOTE-WORKITEM-123',
            StatusPk__c = 'Active'
        );
        
        // 5. V2 ARCHITECTURE: Stage an Outbound Hub Item for the GET tests
        // StatusPk__c = 'Staged' means this item is waiting for a client poll
        insert new SyncItem__c(
            DirectionPk__c = 'Outbound',
            StatusPk__c = 'Staged',
            RequestLookup__c = null, // Null indicates Hub Mode
            WorkItemLookup__c = t.Id,  // Mandatory for routing
            ObjectTypePk__c = 'WorkItem__c',
            PayloadTxt__c = '{"Test":"Payload"}'
        );
    }

    // ==========================================
    // INBOUND PUSH TESTS (POST)
    // ==========================================

    @IsTest
    static void testHttpPostInvalidObject() {
        System.runAs(testUser) {
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
    }

    @IsTest
    static void testWorkItemUpdateViaService() {
        System.runAs(testUser) {
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
    }

    @IsTest
    static void testCommentInsertWithIdempotency() {
        System.runAs(testUser) {
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
    }

    // ==========================================
    // OUTBOUND PULL TESTS (GET) - V2 MULTI-TENANCY
    // ==========================================

    @IsTest
    static void testHttpGetChangesSuccess() {
        System.runAs(testUser) {
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
    }

    @IsTest
    static void testHttpGetChangesMissingClientId() {
        System.runAs(testUser) {
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
    }

    @IsTest
    static void testHttpGetChangesWrongEndpoint() {
        System.runAs(testUser) {
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

    // ==========================================
    // CONNECTION APPROVAL TESTS
    // ==========================================

    @IsTest
    static void testPostRejectedForPendingApprovalEntity() {
        System.runAs(testUser) {
            NetworkEntity__c pendingEntity = new NetworkEntity__c(
                Name = 'Pending Client',
                StatusPk__c = 'Active',
                EntityTypePk__c = 'Client',
                OrgIdTxt__c = '00DPENDING12345',
                ConnectionStatusPk__c = 'Pending Approval'
            );
            insert pendingEntity;

            RestRequest req = new RestRequest();
            RestResponse res = new RestResponse();

            req.requestURI = '/services/apexrest/deliveryhub/v1/sync/WorkItem__c';
            req.httpMethod = 'POST';
            req.requestBody = Blob.valueOf(JSON.serialize(new Map<String, Object>{
                'SourceId' => 'REMOTE-999',
                'BriefDescriptionTxt__c' => 'Should Be Blocked',
                'SenderOrgId' => '00DPENDING12345'
            }));

            RestContext.request = req;
            RestContext.response = res;

            Test.startTest();
            DeliveryHubSyncService.handleIncomingSync();
            Test.stopTest();

            System.assertEquals(403, res.statusCode, 'Should return 403 for Pending Approval entity');
            System.assert(res.responseBody.toString().contains('pending approval'), 'Response should mention pending approval');
        }
    }

    @IsTest
    static void testNetworkEntitySyncAllowedDuringHandshake() {
        System.runAs(testUser) {
            RestRequest req = new RestRequest();
            RestResponse res = new RestResponse();

            req.requestURI = '/services/apexrest/deliveryhub/v1/sync/NetworkEntity__c';
            req.httpMethod = 'POST';
            req.requestBody = Blob.valueOf(JSON.serialize(new Map<String, Object>{
                'SourceId' => 'REMOTE-ENTITY-1',
                'Name' => 'New Client Org',
                'EntityTypePk__c' => 'Client',
                'StatusPk__c' => 'Active',
                'SenderOrgId' => '00DNEWCLIENT123'
            }));

            RestContext.request = req;
            RestContext.response = res;

            Test.startTest();
            DeliveryHubSyncService.handleIncomingSync();
            Test.stopTest();

            System.assertEquals(200, res.statusCode, 'NetworkEntity sync (handshake) should be allowed');

            List<NetworkEntity__c> created = [
                SELECT ConnectionStatusPk__c FROM NetworkEntity__c
                WHERE Name = 'New Client Org' LIMIT 1
            ];
            System.assertEquals(1, created.size(), 'NetworkEntity should be created');
            System.assertEquals('Pending Approval', created[0].ConnectionStatusPk__c, 'New entity should be Pending Approval');
        }
    }

    // ==========================================
    // API KEY AUTHENTICATION TESTS
    // ==========================================

    @IsTest
    static void testPostWithValidApiKey() {
        System.runAs(testUser) {
            // Set up an entity with an API key
            NetworkEntity__c authedEntity = new NetworkEntity__c(
                Name = 'Authed Partner',
                StatusPk__c = 'Active',
                EntityTypePk__c = 'Vendor',
                ApiKeyTxt__c = 'valid-sync-key-12345',
                ConnectionStatusPk__c = 'Connected'
            );
            insert authedEntity;

            String remoteId = 'REMOTE-WORKITEM-123';
            RestRequest req = new RestRequest();
            RestResponse res = new RestResponse();

            req.requestURI = '/services/apexrest/deliveryhub/v1/sync/WorkItem__c';
            req.httpMethod = 'POST';
            req.addHeader('X-Api-Key', 'valid-sync-key-12345');
            req.requestBody = Blob.valueOf(JSON.serialize(new Map<String, Object>{
                'SourceId' => remoteId,
                'BriefDescriptionTxt__c' => 'Authed Update'
            }));

            RestContext.request = req;
            RestContext.response = res;

            Test.startTest();
            DeliveryHubSyncService.handleIncomingSync();
            Test.stopTest();

            System.assertEquals(200, res.statusCode, 'Valid API key should be accepted');
        }
    }

    @IsTest
    static void testPostWithInvalidApiKey() {
        System.runAs(testUser) {
            RestRequest req = new RestRequest();
            RestResponse res = new RestResponse();

            req.requestURI = '/services/apexrest/deliveryhub/v1/sync/WorkItem__c';
            req.httpMethod = 'POST';
            req.addHeader('X-Api-Key', 'totally-wrong-key');
            req.requestBody = Blob.valueOf(JSON.serialize(new Map<String, Object>{
                'SourceId' => '123',
                'BriefDescriptionTxt__c' => 'Should Not Work'
            }));

            RestContext.request = req;
            RestContext.response = res;

            Test.startTest();
            DeliveryHubSyncService.handleIncomingSync();
            Test.stopTest();

            System.assertEquals(401, res.statusCode, 'Invalid API key should return 401');
        }
    }

    @IsTest
    static void testPostWithNoApiKeyBackwardCompatible() {
        System.runAs(testUser) {
            // No X-Api-Key header = legacy connection, should still work
            String remoteId = 'REMOTE-WORKITEM-123';
            RestRequest req = new RestRequest();
            RestResponse res = new RestResponse();

            req.requestURI = '/services/apexrest/deliveryhub/v1/sync/WorkItem__c';
            req.httpMethod = 'POST';
            // No X-Api-Key header
            req.requestBody = Blob.valueOf(JSON.serialize(new Map<String, Object>{
                'SourceId' => remoteId,
                'BriefDescriptionTxt__c' => 'Legacy Update'
            }));

            RestContext.request = req;
            RestContext.response = res;

            Test.startTest();
            DeliveryHubSyncService.handleIncomingSync();
            Test.stopTest();

            System.assertEquals(200, res.statusCode, 'No API key should be backward compatible (200)');
        }
    }

    @IsTest
    static void testGatewayEchoSuppressionRecentOutboundStillBlocks() {
        System.runAs(testUser) {
            // Simulates an in-flight round-trip: this org sent an outbound for
            // GLOBAL-SRC-RECENT moments ago and the same payload is bouncing back.
            // The recent outbound should still be classified as an echo and
            // the inbound should be silently dropped before the ingestor runs.
            String globalSourceId = 'GLOBAL-SRC-RECENT';
            WorkItem__c wi = [SELECT Id FROM WorkItem__c LIMIT 1];

            insert new SyncItem__c(
                DirectionPk__c = 'Outbound',
                StatusPk__c = 'Synced',
                ObjectTypePk__c = 'WorkItem__c',
                GlobalSourceIdTxt__c = globalSourceId,
                LocalRecordIdTxt__c = (String) wi.Id,
                WorkItemLookup__c = wi.Id,
                PayloadTxt__c = '{"placeholder":true}'
            );

            RestRequest req = new RestRequest();
            RestResponse res = new RestResponse();
            req.requestURI = '/services/apexrest/deliveryhub/v1/sync/WorkItem__c';
            req.httpMethod = 'POST';
            req.addHeader('X-Global-Source-Id', globalSourceId);
            req.requestBody = Blob.valueOf(JSON.serialize(new Map<String, Object>{
                'SourceId' => 'REMOTE-WORKITEM-123',
                'BriefDescriptionTxt__c' => 'Should NOT be applied — this is an echo'
            }));
            RestContext.request = req;
            RestContext.response = res;

            Test.startTest();
            DeliveryHubSyncService.handleIncomingSync();
            Test.stopTest();

            System.assertEquals(200, res.statusCode, 'Echo suppression returns 200 with a status body');
            String body = res.responseBody.toString();
            System.assert(body.contains('Echo suppressed'), 'Body should explicitly say Echo suppressed: ' + body);

            // The inbound payload must NOT have been applied
            WorkItem__c after = [SELECT BriefDescriptionTxt__c FROM WorkItem__c WHERE Id = :wi.Id];
            System.assertNotEquals('Should NOT be applied — this is an echo', after.BriefDescriptionTxt__c, 'Recent outbound must still suppress the echo');
        }
    }

    @IsTest
    static void testGatewayEchoSuppressionStaleOutboundDoesNotBlock() {
        System.runAs(testUser) {
            // Simulates the production drift scenario: this org has an outbound
            // for GLOBAL-SRC-STALE from days ago (long-since synced), then the
            // peer org sends a legitimate later update for the same record.
            // The stale outbound must NOT be treated as evidence of an echo —
            // otherwise the inbound would be silently dropped and the records
            // would diverge permanently.
            String globalSourceId = 'GLOBAL-SRC-STALE';
            WorkItem__c wi = [SELECT Id FROM WorkItem__c LIMIT 1];

            SyncItem__c stale = new SyncItem__c(
                DirectionPk__c = 'Outbound',
                StatusPk__c = 'Synced',
                ObjectTypePk__c = 'WorkItem__c',
                GlobalSourceIdTxt__c = globalSourceId,
                LocalRecordIdTxt__c = (String) wi.Id,
                WorkItemLookup__c = wi.Id,
                PayloadTxt__c = '{"placeholder":true}'
            );
            insert stale;
            // Force CreatedDate to outside the suppression window so the gateway treats it as stale
            Test.setCreatedDate(stale.Id, Datetime.now().addSeconds(-(DeliveryHubSyncService.ECHO_SUPPRESSION_WINDOW_SECONDS + 60)));

            RestRequest req = new RestRequest();
            RestResponse res = new RestResponse();
            req.requestURI = '/services/apexrest/deliveryhub/v1/sync/WorkItem__c';
            req.httpMethod = 'POST';
            req.addHeader('X-Global-Source-Id', globalSourceId);
            req.requestBody = Blob.valueOf(JSON.serialize(new Map<String, Object>{
                'SourceId' => 'REMOTE-WORKITEM-123',
                'BriefDescriptionTxt__c' => 'Legitimate later update — must be applied'
            }));
            RestContext.request = req;
            RestContext.response = res;

            Test.startTest();
            DeliveryHubSyncService.handleIncomingSync();
            Test.stopTest();

            System.assertEquals(200, res.statusCode, 'Inbound should succeed, not be suppressed');
            String body = res.responseBody.toString();
            System.assert(!body.contains('Echo suppressed'), 'Stale outbound must NOT trigger echo suppression: ' + body);

            WorkItem__c after = [SELECT BriefDescriptionTxt__c FROM WorkItem__c WHERE Id = :wi.Id];
            System.assertEquals('Legitimate later update — must be applied', after.BriefDescriptionTxt__c, 'Stale-outbound case must allow the inbound through to the ingestor');
        }
    }

    @IsTest
    static void testGetWithInvalidApiKey() {
        System.runAs(testUser) {
            NetworkEntity__c client = [SELECT Id FROM NetworkEntity__c WHERE EntityTypePk__c = 'Client' LIMIT 1];

            RestRequest req = new RestRequest();
            RestResponse res = new RestResponse();

            req.requestURI = '/services/apexrest/deliveryhub/v1/sync/changes';
            req.httpMethod = 'GET';
            req.addHeader('X-Api-Key', 'wrong-key-for-get');
            req.addParameter('clientId', client.Id);
            req.addParameter('since', '2000-01-01T00:00:00Z');

            RestContext.request = req;
            RestContext.response = res;

            Test.startTest();
            DeliveryHubSyncService.handleOutgoingSync();
            Test.stopTest();

            System.assertEquals(401, res.statusCode, 'Invalid API key on GET should return 401');
        }
    }
}
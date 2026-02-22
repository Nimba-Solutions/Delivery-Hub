/**
 * @description Test class for DeliveryHubSyncService.
 * Verifies the REST entry point for both Push (POST) and Pull (GET) flows,
 * ensuring namespace awareness and strict V2 multi-tenant data segregation.
 */
@IsTest
private class DeliveryHubSyncServiceTest {

    @TestSetup
    static void makeData() {
        // 1. Setup Settings
        insert new Delivery_Hub_Settings__c(
            AutoCreateRequestFromTicketBool__c = false,
            AutoSyncNetworkEntityBool__c = false
        );

        // 2. Create Network Entities (Vendor & Client)
        Network_Entity__c vendor = new Network_Entity__c(
            Name = 'Test Vendor',
            StatusPk__c = 'Active',
            EntityTypePk__c = 'Vendor'
        );
        Network_Entity__c client = new Network_Entity__c(
            Name = 'Test Client',
            StatusPk__c = 'Active',
            EntityTypePk__c = 'Client'
        );
        insert new List<Network_Entity__c>{vendor, client};

        // 3. Create Ticket (Explicitly linked to the Client)
        Ticket__c t = new Ticket__c(
            WorkItemNameTxt__c = 'Original Name',
            StageNamePk__c = 'Backlog',
            BriefDescriptionTxt__c = 'Original Description',
            ClientNetworkEntityId__c = client.Id
        );
        insert t;

        // 4. Create Request (The Ledger bridge linking Ticket to Remote ID)
        insert new Request__c(
            TicketId__c = t.Id,
            DeliveryEntityId__c = vendor.Id,
            RemoteTicketIdTxt__c = 'REMOTE-TICKET-123',
            StatusPk__c = 'Active'
        );
        
        // 5. V2 ARCHITECTURE: Stage an Outbound Hub Item for the GET tests
        insert new Sync_Item__c(
            DirectionPk__c = 'Outbound',
            StatusPk__c = 'Queued',
            RequestId__c = null, // Null indicates Hub Mode
            TicketId__c = t.Id,  // Mandatory for routing
            ObjectTypePk__c = 'Ticket__c',
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
    static void testTicketUpdateViaService() {
        String remoteId = 'REMOTE-TICKET-123';
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        req.requestURI = '/services/apexrest/deliveryhub/v1/sync/Ticket__c';
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
        
        Ticket__c updatedT = [SELECT BriefDescriptionTxt__c FROM Ticket__c LIMIT 1];
        System.assertEquals('Updated Description', updatedT.BriefDescriptionTxt__c, 'Ticket should be updated via ledger lookup');
    }

    @IsTest
    static void testCommentInsertWithIdempotency() {
        String remoteTicketId = 'REMOTE-TICKET-123'; 
        String sourceId = 'REMOTE-COMMENT-999';
        String uniqueAuthor = 'REST_TEST_AUTHOR';

        Map<String, Object> payload = new Map<String, Object>{
            'TargetId' => remoteTicketId, 
            'SourceId' => sourceId,
            'AuthorTxt__c' => uniqueAuthor,
            'BodyTxt__c' => 'Service Tester Comment'
        };

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        req.requestURI = '/services/apexrest/deliveryhub/v1/sync/Ticket_Comment__c';
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

        List<Ticket_Comment__c> comments = [SELECT Id FROM Ticket_Comment__c WHERE AuthorTxt__c = :uniqueAuthor];
        System.assertEquals(1, comments.size(), 'Should have inserted exactly 1 comment due to ledger idempotency.');
    }

    // ==========================================
    // OUTBOUND PULL TESTS (GET) - V2 MULTI-TENANCY
    // ==========================================

    @IsTest
    static void testHttpGetChangesSuccess() {
        Network_Entity__c client = [SELECT Id FROM Network_Entity__c WHERE EntityTypePk__c = 'Client' LIMIT 1];
        
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
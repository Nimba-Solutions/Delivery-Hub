@IsTest
private class DeliveryHubSyncResourceTest {

    @TestSetup
    static void makeData() {
        // 1. Setup a local record to update
        Ticket__c t = new Ticket__c(
            WorkItemNameTxt__c = 'Original Name',
            StageNamePk__c = 'Backlog',
            BriefDescriptionTxt__c = 'Original Description'
        );
        insert t;

        // 2. Setup Network Entity (Vendor)
        Network_Entity__c vendor = new Network_Entity__c(
            Name = 'Mothership',
            EntityTypePk__c = 'Vendor',
            StatusPk__c = 'Active'
        );
        insert vendor;

        // 3. Setup the Bridge (Request) linking Local ID to a Remote ID
        // The Ledger Pattern requires this to find the local ticket
        insert new Request__c(
            TicketId__c = t.Id,
            DeliveryEntityId__c = vendor.Id,
            StatusPk__c = 'Active',
            RemoteTicketIdTxt__c = 'REMOTE-TKT-777'
        );
    }

    /**
     * @description Happy Path: Verifies that a valid JSON request updates the record 
     * using the SourceId (Remote ID) lookup.
     */
    @IsTest
    static void testHandleIncomingSyncSuccess() {
        // 1. Prepare JSON Payload using SourceId
        Map<String, Object> jsonMap = new Map<String, Object>{
            'SourceId' => 'REMOTE-TKT-777',
            'BriefDescriptionTxt__c' => 'Updated via Sync Resource',
            'StageNamePk__c' => 'In Development'
        };
        
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.requestURI = '/services/apexrest/deliveryhub/v1/sync/Ticket__c'; 
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(JSON.serialize(jsonMap));
        
        RestContext.request = req;
        RestContext.response = res;

        // 2. Execute
        Test.startTest();
        DeliveryHubSyncResource.handleIncomingSync();
        Test.stopTest();

        // 3. Verify Response
        System.assertEquals(200, res.statusCode, 'Should return 200 OK');
        System.assert(res.responseBody.toString().contains('Success'), 'Response should mention Success');

        // 4. Verify Database Update
        Ticket__c updatedTicket = [SELECT BriefDescriptionTxt__c, StageNamePk__c FROM Ticket__c LIMIT 1];
        System.assertEquals('Updated via Sync Resource', updatedTicket.BriefDescriptionTxt__c, 'Field should be updated via Ledger lookup');
        System.assertEquals('In Development', updatedTicket.StageNamePk__c, 'Stage should be updated');
    }

    /**
     * @description Error Path: Verifies 400 Bad Request when body is empty.
     */
    @IsTest
    static void testHandleIncomingSyncEmptyBody() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.requestURI = '/services/apexrest/deliveryhub/v1/sync/Ticket__c';
        req.httpMethod = 'POST';
        req.requestBody = null; 

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        DeliveryHubSyncResource.handleIncomingSync();
        Test.stopTest();

        System.assertEquals(400, res.statusCode, 'Should return 400 for empty body');
        System.assert(res.responseBody.toString().contains('Empty Request Body'));
    }

    /**
     * @description Error Path: Verifies 400 Bad Request when SourceId is missing.
     */
    @IsTest
    static void testHandleIncomingSyncMissingSourceId() {
        Map<String, Object> jsonMap = new Map<String, Object>{
            'BriefDescriptionTxt__c' => 'No ID provided'
        };
        
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.requestURI = '/services/apexrest/deliveryhub/v1/sync/Ticket__c';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(JSON.serialize(jsonMap));

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        DeliveryHubSyncResource.handleIncomingSync();
        Test.stopTest();

        System.assertEquals(400, res.statusCode, 'Should return 400 for missing SourceId');
        System.assert(res.responseBody.toString().contains('Missing SourceId'), 'Should mention missing remote ID');
    }

    /**
     * @description Error Path: Verifies 500 Server Error when Object Type is invalid.
     */
    @IsTest
    static void testHandleIncomingSyncInvalidObjectType() {
        Map<String, Object> jsonMap = new Map<String, Object>{ 'SourceId' => 'REMOTE-TKT-777' };

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.requestURI = '/services/apexrest/deliveryhub/v1/sync/NonExistentObject__c'; 
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(JSON.serialize(jsonMap));

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        DeliveryHubSyncResource.handleIncomingSync();
        Test.stopTest();

        System.assertEquals(500, res.statusCode, 'Should return 500 for invalid object type');
        System.assert(res.responseBody.toString().contains('Invalid Object Type'), 'Error should explain invalid object');
    }

    /**
     * @description Error Path: Verifies 500 Server Error on malformed JSON.
     */
    @IsTest
    static void testHandleIncomingSyncMalformedJson() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.requestURI = '/services/apexrest/deliveryhub/v1/sync/Ticket__c';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf('{ "SourceId": "123", "Bad Json: }'); 

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        DeliveryHubSyncResource.handleIncomingSync();
        Test.stopTest();

        System.assertEquals(500, res.statusCode, 'Should return 500 for JSON parsing error');
    }
}
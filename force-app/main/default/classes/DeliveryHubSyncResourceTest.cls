@IsTest
private class DeliveryHubSyncResourceTest {

    @TestSetup
    static void makeData() {
        // Setup a record to update (Target)
        // We use Ticket__c as the standard object for these tests
        Ticket__c t = new Ticket__c(
            WorkItemNameTxt__c = 'Original Name',
            StageNamePk__c = 'Backlog',
            BriefDescriptionTxt__c = 'Original Description'
        );
        insert t;
    }

    /**
     * @description Happy Path: Verifies that a valid JSON request updates the record.
     */
    @IsTest
    static void testHandleIncomingSyncSuccess() {
        // 1. Get Target ID
        Ticket__c target = [SELECT Id FROM Ticket__c LIMIT 1];
        
        // 2. Prepare JSON Payload
        Map<String, Object> jsonMap = new Map<String, Object>();
        jsonMap.put('TargetId', target.Id);
        jsonMap.put('BriefDescriptionTxt__c', 'Updated via Sync');
        jsonMap.put('StageNamePk__c', 'In Development');
        
        String jsonBody = JSON.serialize(jsonMap);

        // 3. Setup RestContext
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        // Note: The URL logic handles namespaces dynamically in the main class
        req.requestURI = '/services/apexrest/v1/sync/Ticket__c'; 
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(jsonBody);
        
        RestContext.request = req;
        RestContext.response = res;

        // 4. Execute
        Test.startTest();
        DeliveryHubSyncResource.handleIncomingSync();
        Test.stopTest();

        // 5. Verify Response
        System.assertEquals(200, res.statusCode, 'Should return 200 OK');
        System.assert(res.responseBody.toString().contains('Success'), 'Response should mention Success');

        // 6. Verify Database Update
        Ticket__c updatedTicket = [SELECT BriefDescriptionTxt__c, StageNamePk__c FROM Ticket__c WHERE Id = :target.Id];
        System.assertEquals('Updated via Sync', updatedTicket.BriefDescriptionTxt__c, 'Field should be updated');
        System.assertEquals('In Development', updatedTicket.StageNamePk__c, 'Stage should be updated');
    }

    /**
     * @description Error Path: Verifies 400 Bad Request when body is empty.
     */
    @IsTest
    static void testHandleIncomingSyncEmptyBody() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.requestURI = '/services/apexrest/v1/sync/Ticket__c';
        req.httpMethod = 'POST';
        req.requestBody = null; // Empty

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        DeliveryHubSyncResource.handleIncomingSync();
        Test.stopTest();

        System.assertEquals(400, res.statusCode, 'Should return 400 for empty body');
        System.assertEquals('Empty Request Body', res.responseBody.toString());
    }

    /**
     * @description Error Path: Verifies 400 Bad Request when TargetId is missing.
     */
    @IsTest
    static void testHandleIncomingSyncMissingTargetId() {
        Map<String, Object> jsonMap = new Map<String, Object>();
        jsonMap.put('BriefDescriptionTxt__c', 'No ID provided');
        
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.requestURI = '/services/apexrest/v1/sync/Ticket__c';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(JSON.serialize(jsonMap));

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        DeliveryHubSyncResource.handleIncomingSync();
        Test.stopTest();

        System.assertEquals(400, res.statusCode, 'Should return 400 for missing TargetId');
        System.assert(res.responseBody.toString().contains('Missing TargetId'), 'Should mention missing ID');
    }

    /**
     * @description Error Path: Verifies 500 Server Error when Object Type is invalid.
     */
    @IsTest
    static void testHandleIncomingSyncInvalidObjectType() {
        Ticket__c target = [SELECT Id FROM Ticket__c LIMIT 1];
        
        Map<String, Object> jsonMap = new Map<String, Object>();
        jsonMap.put('TargetId', target.Id);

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        // INVALID Object Name in URL
        req.requestURI = '/services/apexrest/v1/sync/NonExistentObject__c'; 
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

        req.requestURI = '/services/apexrest/v1/sync/Ticket__c';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf('{ "TargetId": "123", "Bad Json: }'); // Syntax error

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        DeliveryHubSyncResource.handleIncomingSync();
        Test.stopTest();

        System.assertEquals(500, res.statusCode, 'Should return 500 for JSON parsing error');
    }
}
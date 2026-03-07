/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Test class for DeliveryPublicApiService.
 * Validates API key authentication, entity scoping, and all REST endpoints.
 * @author Cloud Nimbus LLC
 */
@IsTest
private class DeliveryPublicApiServiceTest {

    private static final String TEST_API_KEY = 'test-api-key-abc123def456';

    @TestSetup
    static void setupData() {
        // Connected entity with API key
        NetworkEntity__c entityA = new NetworkEntity__c(
            Name = 'API Client Corp',
            EntityTypePk__c = 'Client',
            StatusPk__c = 'Active',
            ApiKeyTxt__c = TEST_API_KEY,
            ConnectionStatusPk__c = 'Connected'
        );
        // Second entity (for isolation tests)
        NetworkEntity__c entityB = new NetworkEntity__c(
            Name = 'Other Corp',
            EntityTypePk__c = 'Client',
            StatusPk__c = 'Active',
            ApiKeyTxt__c = 'other-api-key-xyz789',
            ConnectionStatusPk__c = 'Connected'
        );
        // Disabled entity
        NetworkEntity__c entityC = new NetworkEntity__c(
            Name = 'Disabled Corp',
            EntityTypePk__c = 'Client',
            StatusPk__c = 'Active',
            ApiKeyTxt__c = 'disabled-key-999',
            ConnectionStatusPk__c = 'Disabled'
        );
        insert new List<NetworkEntity__c>{ entityA, entityB, entityC };

        // Work items for Entity A
        List<WorkItem__c> items = new List<WorkItem__c>{
            new WorkItem__c(
                BriefDescriptionTxt__c = 'API Active Item',
                StageNamePk__c = 'In Development',
                PriorityPk__c = 'High',
                IsActiveBool__c = true,
                StatusPk__c = 'New',
                ClientNetworkEntityId__c = entityA.Id,
                DetailsTxt__c = 'Active item for API testing'
            ),
            new WorkItem__c(
                BriefDescriptionTxt__c = 'API Done Item',
                StageNamePk__c = 'Done',
                PriorityPk__c = 'Low',
                IsActiveBool__c = false,
                StatusPk__c = 'Closed',
                ClientNetworkEntityId__c = entityA.Id
            ),
            // Entity B item (isolation)
            new WorkItem__c(
                BriefDescriptionTxt__c = 'Other Corp Item',
                StageNamePk__c = 'Backlog',
                PriorityPk__c = 'Medium',
                IsActiveBool__c = true,
                StatusPk__c = 'New',
                ClientNetworkEntityId__c = entityB.Id
            )
        };
        insert items;

        // Comment on first item
        insert new WorkItemComment__c(
            WorkItemId__c = items[0].Id,
            BodyTxt__c = 'Existing API test comment',
            AuthorTxt__c = 'Developer',
            SourcePk__c = 'Salesforce'
        );
    }

    // ==========================================
    // AUTHENTICATION TESTS
    // ==========================================

    @IsTest
    static void testMissingApiKey() {
        RestRequest req = buildGetRequest('/services/apexrest/delivery/deliveryhub/v1/api/dashboard');
        RestResponse res = new RestResponse();
        // No X-Api-Key header
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        DeliveryPublicApiService.handleGet();
        Test.stopTest();

        System.assertEquals(401, res.statusCode, 'Should return 401 for missing API key');
        assertErrorResponse(res, 'Missing X-Api-Key');
    }

    @IsTest
    static void testInvalidApiKey() {
        RestRequest req = buildGetRequest('/services/apexrest/delivery/deliveryhub/v1/api/dashboard');
        req.addHeader('X-Api-Key', 'totally-wrong-key');
        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        DeliveryPublicApiService.handleGet();
        Test.stopTest();

        System.assertEquals(401, res.statusCode, 'Should return 401 for invalid API key');
        assertErrorResponse(res, 'Invalid API key');
    }

    @IsTest
    static void testDisabledEntityApiKey() {
        RestRequest req = buildGetRequest('/services/apexrest/delivery/deliveryhub/v1/api/dashboard');
        req.addHeader('X-Api-Key', 'disabled-key-999');
        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        DeliveryPublicApiService.handleGet();
        Test.stopTest();

        System.assertEquals(401, res.statusCode, 'Should return 401 for disabled entity');
    }

    // ==========================================
    // GET DASHBOARD
    // ==========================================

    @IsTest
    static void testGetDashboard() {
        RestRequest req = buildGetRequest('/services/apexrest/delivery/deliveryhub/v1/api/dashboard');
        req.addHeader('X-Api-Key', TEST_API_KEY);
        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        DeliveryPublicApiService.handleGet();
        Test.stopTest();

        System.assertEquals(200, res.statusCode, 'Should return 200');
        Map<String, Object> body = parseResponse(res);
        System.assertEquals(true, body.get('success'), 'Should be successful');

        Map<String, Object> data = (Map<String, Object>) body.get('data');
        System.assertEquals('API Client Corp', data.get('entityName'), 'Entity name should match');
    }

    // ==========================================
    // GET WORK ITEMS
    // ==========================================

    @IsTest
    static void testGetWorkItems() {
        RestRequest req = buildGetRequest('/services/apexrest/delivery/deliveryhub/v1/api/work-items');
        req.addHeader('X-Api-Key', TEST_API_KEY);
        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        DeliveryPublicApiService.handleGet();
        Test.stopTest();

        System.assertEquals(200, res.statusCode, 'Should return 200');
        Map<String, Object> body = parseResponse(res);
        List<Object> data = (List<Object>) body.get('data');
        System.assertEquals(2, data.size(), 'Should return 2 items for this entity');
    }

    @IsTest
    static void testGetWorkItemsWithFilter() {
        RestRequest req = buildGetRequest('/services/apexrest/delivery/deliveryhub/v1/api/work-items');
        req.addHeader('X-Api-Key', TEST_API_KEY);
        req.addParameter('status', 'active');
        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        DeliveryPublicApiService.handleGet();
        Test.stopTest();

        System.assertEquals(200, res.statusCode, 'Should return 200');
        Map<String, Object> body = parseResponse(res);
        List<Object> data = (List<Object>) body.get('data');
        System.assertEquals(1, data.size(), 'Should return only 1 active item');
    }

    // ==========================================
    // GET WORK ITEM DETAIL
    // ==========================================

    @IsTest
    static void testGetWorkItemDetail() {
        WorkItem__c item = [SELECT Id FROM WorkItem__c WHERE BriefDescriptionTxt__c = 'API Active Item' LIMIT 1];

        RestRequest req = buildGetRequest('/services/apexrest/delivery/deliveryhub/v1/api/work-items/' + item.Id);
        req.addHeader('X-Api-Key', TEST_API_KEY);
        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        DeliveryPublicApiService.handleGet();
        Test.stopTest();

        System.assertEquals(200, res.statusCode, 'Should return 200');
        Map<String, Object> body = parseResponse(res);
        Map<String, Object> data = (Map<String, Object>) body.get('data');
        System.assertEquals('API Active Item', data.get('title'), 'Title should match');

        List<Object> comments = (List<Object>) data.get('comments');
        System.assertEquals(1, comments.size(), 'Should have 1 comment');
    }

    @IsTest
    static void testGetWorkItemDetailCrossEntityBlocked() {
        // Entity A's key trying to access Entity B's work item
        WorkItem__c otherItem = [SELECT Id FROM WorkItem__c WHERE BriefDescriptionTxt__c = 'Other Corp Item' LIMIT 1];

        RestRequest req = buildGetRequest('/services/apexrest/delivery/deliveryhub/v1/api/work-items/' + otherItem.Id);
        req.addHeader('X-Api-Key', TEST_API_KEY);
        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        DeliveryPublicApiService.handleGet();
        Test.stopTest();

        System.assertEquals(403, res.statusCode, 'Should return 403 for cross-entity access');
        assertErrorResponse(res, 'Access denied');
    }

    // ==========================================
    // GET UNKNOWN RESOURCE
    // ==========================================

    @IsTest
    static void testGetUnknownResource() {
        RestRequest req = buildGetRequest('/services/apexrest/delivery/deliveryhub/v1/api/unknown');
        req.addHeader('X-Api-Key', TEST_API_KEY);
        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        DeliveryPublicApiService.handleGet();
        Test.stopTest();

        System.assertEquals(404, res.statusCode, 'Should return 404 for unknown resource');
    }

    // ==========================================
    // POST WORK ITEM (SUBMIT REQUEST)
    // ==========================================

    @IsTest
    static void testPostWorkItem() {
        Map<String, Object> body = new Map<String, Object>{
            'title' => 'New API Request',
            'description' => 'Please build this feature.',
            'priority' => 'High',
            'type' => 'Internal'
        };

        RestRequest req = buildPostRequest(
            '/services/apexrest/delivery/deliveryhub/v1/api/work-items',
            body
        );
        req.addHeader('X-Api-Key', TEST_API_KEY);
        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        DeliveryPublicApiService.handlePost();
        Test.stopTest();

        System.assertEquals(201, res.statusCode, 'Should return 201 Created');
        Map<String, Object> responseBody = parseResponse(res);
        Map<String, Object> data = (Map<String, Object>) responseBody.get('data');
        System.assertNotEquals(null, data.get('id'), 'Should return the new item Id');

        // Verify entity was auto-linked
        WorkItem__c created = [
            SELECT ClientNetworkEntityId__c, BriefDescriptionTxt__c
            FROM WorkItem__c
            WHERE BriefDescriptionTxt__c = '[Portal] New API Request'
            LIMIT 1
        ];
        NetworkEntity__c entityA = [SELECT Id FROM NetworkEntity__c WHERE Name = 'API Client Corp' LIMIT 1];
        System.assertEquals(entityA.Id, created.ClientNetworkEntityId__c, 'Should auto-link to authenticated entity');
    }

    @IsTest
    static void testPostWorkItemEmptyBody() {
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/delivery/deliveryhub/v1/api/work-items';
        req.httpMethod = 'POST';
        req.addHeader('X-Api-Key', TEST_API_KEY);
        // No request body
        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        DeliveryPublicApiService.handlePost();
        Test.stopTest();

        System.assertEquals(400, res.statusCode, 'Should return 400 for empty body');
    }

    // ==========================================
    // POST COMMENT
    // ==========================================

    @IsTest
    static void testPostComment() {
        WorkItem__c item = [SELECT Id FROM WorkItem__c WHERE BriefDescriptionTxt__c = 'API Active Item' LIMIT 1];

        Map<String, Object> body = new Map<String, Object>{
            'body' => 'Comment via API'
        };

        RestRequest req = buildPostRequest(
            '/services/apexrest/delivery/deliveryhub/v1/api/work-items/' + item.Id + '/comments',
            body
        );
        req.addHeader('X-Api-Key', TEST_API_KEY);
        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        DeliveryPublicApiService.handlePost();
        Test.stopTest();

        System.assertEquals(201, res.statusCode, 'Should return 201 Created');

        Map<String, Object> responseBody = parseResponse(res);
        Map<String, Object> data = (Map<String, Object>) responseBody.get('data');
        Id commentId = (Id) data.get('id');

        WorkItemComment__c comment = [
            SELECT BodyTxt__c, AuthorTxt__c FROM WorkItemComment__c
            WHERE Id = :commentId LIMIT 1
        ];
        System.assertEquals('Comment via API', comment.BodyTxt__c, 'Comment body should match');
        System.assertEquals('Portal User', comment.AuthorTxt__c, 'Author should be Portal User');
    }

    @IsTest
    static void testPostCommentCrossEntityBlocked() {
        WorkItem__c otherItem = [SELECT Id FROM WorkItem__c WHERE BriefDescriptionTxt__c = 'Other Corp Item' LIMIT 1];

        Map<String, Object> body = new Map<String, Object>{
            'body' => 'Sneaky cross-entity comment'
        };

        RestRequest req = buildPostRequest(
            '/services/apexrest/delivery/deliveryhub/v1/api/work-items/' + otherItem.Id + '/comments',
            body
        );
        req.addHeader('X-Api-Key', TEST_API_KEY);
        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        DeliveryPublicApiService.handlePost();
        Test.stopTest();

        System.assertEquals(403, res.statusCode, 'Should return 403 for cross-entity comment');
    }

    // ==========================================
    // POST UNKNOWN RESOURCE
    // ==========================================

    @IsTest
    static void testPostUnknownResource() {
        RestRequest req = buildPostRequest(
            '/services/apexrest/delivery/deliveryhub/v1/api/unknown',
            new Map<String, Object>{ 'data' => 'test' }
        );
        req.addHeader('X-Api-Key', TEST_API_KEY);
        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        DeliveryPublicApiService.handlePost();
        Test.stopTest();

        System.assertEquals(404, res.statusCode, 'Should return 404 for unknown POST resource');
    }

    // ==========================================
    // API KEY GENERATION
    // ==========================================

    @IsTest
    static void testGenerateApiKey() {
        Test.startTest();
        String key1 = DeliveryPublicApiService.generateApiKey();
        String key2 = DeliveryPublicApiService.generateApiKey();
        Test.stopTest();

        System.assertEquals(64, key1.length(), 'API key should be 64 hex characters');
        System.assertNotEquals(key1, key2, 'Generated keys should be unique');
    }

    // ==========================================
    // HELPERS
    // ==========================================

    private static RestRequest buildGetRequest(String uri) {
        RestRequest req = new RestRequest();
        req.requestURI = uri;
        req.httpMethod = 'GET';
        return req;
    }

    private static RestRequest buildPostRequest(String uri, Map<String, Object> body) {
        RestRequest req = new RestRequest();
        req.requestURI = uri;
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(JSON.serialize(body));
        return req;
    }

    private static Map<String, Object> parseResponse(RestResponse res) {
        return (Map<String, Object>) JSON.deserializeUntyped(res.responseBody.toString());
    }

    private static void assertErrorResponse(RestResponse res, String expectedMessage) {
        Map<String, Object> body = parseResponse(res);
        System.assertEquals(false, body.get('success'), 'Should not be successful');
        String error = (String) body.get('error');
        System.assert(error.contains(expectedMessage), 'Error should contain: ' + expectedMessage + ', got: ' + error);
    }
}

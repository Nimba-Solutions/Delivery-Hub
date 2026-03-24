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

        // Portal access records for multi-tenant testing
        List<PortalAccess__c> portalAccessRecords = new List<PortalAccess__c>{
            new PortalAccess__c(
                NetworkEntityId__c = entityA.Id,
                EmailTxt__c = 'portal@example.com',
                RolePk__c = 'Admin'
            ),
            new PortalAccess__c(
                NetworkEntityId__c = entityB.Id,
                EmailTxt__c = 'portal@example.com',
                RolePk__c = 'Member'
            )
        };
        insert portalAccessRecords;

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

        // Work request for first item (needed for WorkLog master-detail)
        NetworkEntity__c vendorForReq = new NetworkEntity__c(
            Name = 'API Test Vendor', EntityTypePk__c = 'Vendor', StatusPk__c = 'Active'
        );
        insert vendorForReq;

        WorkRequest__c req = new WorkRequest__c(
            WorkItemId__c = items[0].Id,
            DeliveryEntityId__c = vendorForReq.Id,
            QuotedHoursNumber__c = 20,
            HourlyRateCurrency__c = 100,
            StatusPk__c = 'Accepted'
        );
        insert req;

        // Comment on first item
        insert new WorkItemComment__c(
            WorkItemId__c = items[0].Id,
            BodyTxt__c = 'Existing API test comment',
            AuthorTxt__c = 'Developer',
            SourcePk__c = 'Salesforce'
        );

        // Draft work log on first item (for pending-approvals / approve / reject tests)
        insert new WorkLog__c(
            RequestId__c = req.Id,
            WorkItemId__c = items[0].Id,
            HoursLoggedNumber__c = 2.5,
            WorkDateDate__c = Date.today(),
            WorkDescriptionTxt__c = 'Draft work log for API test',
            StatusPk__c = 'Draft'
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
    // GET ACTIVITY FEED
    // ==========================================

    @IsTest
    static void testGetActivityFeed() {
        RestRequest req = buildGetRequest('/services/apexrest/delivery/deliveryhub/v1/api/activity-feed');
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
        System.assert(data.containsKey('events'), 'Response should contain events');
        System.assert(data.containsKey('totalCount'), 'Response should contain totalCount');
        System.assert(data.containsKey('hasMore'), 'Response should contain hasMore');
    }

    @IsTest
    static void testGetActivityFeedWithParams() {
        RestRequest req = buildGetRequest('/services/apexrest/delivery/deliveryhub/v1/api/activity-feed');
        req.addHeader('X-Api-Key', TEST_API_KEY);
        req.addParameter('filterType', 'comments');
        req.addParameter('pageOffset', '0');
        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        DeliveryPublicApiService.handleGet();
        Test.stopTest();

        System.assertEquals(200, res.statusCode, 'Should return 200');
        Map<String, Object> body = parseResponse(res);
        System.assertEquals(true, body.get('success'), 'Should be successful');
    }

    // ==========================================
    // GET CONVERSATIONS
    // ==========================================

    @IsTest
    static void testGetConversations() {
        RestRequest req = buildGetRequest('/services/apexrest/delivery/deliveryhub/v1/api/conversations');
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
    }

    // ==========================================
    // GET PENDING APPROVALS
    // ==========================================

    @IsTest
    static void testGetPendingApprovals() {
        RestRequest req = buildGetRequest('/services/apexrest/delivery/deliveryhub/v1/api/pending-approvals');
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
        System.assert(data.containsKey('approvals'), 'Response should contain approvals');
        System.assert(data.containsKey('totalCount'), 'Response should contain totalCount');
    }

    // ==========================================
    // POST APPROVE WORKLOGS
    // ==========================================

    @IsTest
    static void testPostApproveWorkLogs() {
        WorkLog__c wl = [SELECT Id FROM WorkLog__c WHERE StatusPk__c = 'Draft' LIMIT 1];

        Map<String, Object> body = new Map<String, Object>{
            'workLogIds' => new List<String>{ wl.Id }
        };

        RestRequest req = buildPostRequest(
            '/services/apexrest/delivery/deliveryhub/v1/api/approve-worklogs',
            body
        );
        req.addHeader('X-Api-Key', TEST_API_KEY);
        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        DeliveryPublicApiService.handlePost();
        Test.stopTest();

        System.assertEquals(200, res.statusCode, 'Should return 200');
        Map<String, Object> responseBody = parseResponse(res);
        Map<String, Object> data = (Map<String, Object>) responseBody.get('data');
        System.assertEquals('Approved', data.get('status'), 'Status should be Approved');
    }

    // ==========================================
    // POST REJECT WORKLOGS
    // ==========================================

    @IsTest
    static void testPostRejectWorkLogs() {
        WorkLog__c wl = [SELECT Id FROM WorkLog__c WHERE StatusPk__c = 'Draft' LIMIT 1];

        Map<String, Object> body = new Map<String, Object>{
            'workLogIds' => new List<String>{ wl.Id }
        };

        RestRequest req = buildPostRequest(
            '/services/apexrest/delivery/deliveryhub/v1/api/reject-worklogs',
            body
        );
        req.addHeader('X-Api-Key', TEST_API_KEY);
        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        DeliveryPublicApiService.handlePost();
        Test.stopTest();

        System.assertEquals(200, res.statusCode, 'Should return 200');
        Map<String, Object> responseBody = parseResponse(res);
        Map<String, Object> data = (Map<String, Object>) responseBody.get('data');
        System.assertEquals('Rejected', data.get('status'), 'Status should be Rejected');
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
    // PORTAL ACCESS — MY ENTITIES
    // ==========================================

    @IsTest
    static void testGetMyEntities() {
        RestRequest req = buildGetRequest('/services/apexrest/delivery/deliveryhub/v1/api/my-entities');
        req.addHeader('X-Api-Key', TEST_API_KEY);
        req.addHeader('X-Portal-User', 'portal@example.com');
        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        DeliveryPublicApiService.handleGet();
        Test.stopTest();

        System.assertEquals(200, res.statusCode, 'Should return 200');
        Map<String, Object> body = parseResponse(res);
        System.assertEquals(true, body.get('success'), 'Should be successful');

        List<Object> data = (List<Object>) body.get('data');
        System.assertEquals(2, data.size(), 'portal@example.com should have access to 2 entities');
    }

    @IsTest
    static void testGetMyEntitiesMissingHeader() {
        RestRequest req = buildGetRequest('/services/apexrest/delivery/deliveryhub/v1/api/my-entities');
        req.addHeader('X-Api-Key', TEST_API_KEY);
        // No X-Portal-User header
        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        DeliveryPublicApiService.handleGet();
        Test.stopTest();

        System.assertEquals(400, res.statusCode, 'Should return 400 when X-Portal-User is missing');
        assertErrorResponse(res, 'X-Portal-User header is required');
    }

    // ==========================================
    // PORTAL ACCESS — ENTITY SWITCHING
    // ==========================================

    @IsTest
    static void testGetDashboardWithEntityId() {
        NetworkEntity__c entityB = [SELECT Id FROM NetworkEntity__c WHERE Name = 'Other Corp' LIMIT 1];

        RestRequest req = buildGetRequest('/services/apexrest/delivery/deliveryhub/v1/api/dashboard');
        req.addHeader('X-Api-Key', TEST_API_KEY);
        req.addHeader('X-Portal-User', 'portal@example.com');
        req.addParameter('entityId', entityB.Id);
        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        DeliveryPublicApiService.handleGet();
        Test.stopTest();

        System.assertEquals(200, res.statusCode, 'Should return 200 for authorized portal user');
        Map<String, Object> body = parseResponse(res);
        System.assertEquals(true, body.get('success'), 'Should be successful');

        Map<String, Object> data = (Map<String, Object>) body.get('data');
        System.assertEquals('Other Corp', data.get('entityName'), 'Should show Other Corp dashboard');
    }

    @IsTest
    static void testGetDashboardUnauthorizedEntity() {
        // Create an entity that portal@example.com does NOT have access to
        NetworkEntity__c noAccessEntity = new NetworkEntity__c(
            Name = 'No Access Corp',
            EntityTypePk__c = 'Client',
            StatusPk__c = 'Active',
            ApiKeyTxt__c = 'no-access-key-111',
            ConnectionStatusPk__c = 'Connected'
        );
        insert noAccessEntity;

        RestRequest req = buildGetRequest('/services/apexrest/delivery/deliveryhub/v1/api/dashboard');
        req.addHeader('X-Api-Key', TEST_API_KEY);
        req.addHeader('X-Portal-User', 'portal@example.com');
        req.addParameter('entityId', noAccessEntity.Id);
        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        DeliveryPublicApiService.handleGet();
        Test.stopTest();

        System.assertEquals(403, res.statusCode, 'Should return 403 for unauthorized entity access');
        assertErrorResponse(res, 'Portal user does not have access');
    }

    @IsTest
    static void testGetDashboardBackwardCompatible() {
        // Without X-Portal-User and entityId, should fall back to API key entity
        RestRequest req = buildGetRequest('/services/apexrest/delivery/deliveryhub/v1/api/dashboard');
        req.addHeader('X-Api-Key', TEST_API_KEY);
        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        DeliveryPublicApiService.handleGet();
        Test.stopTest();

        System.assertEquals(200, res.statusCode, 'Should return 200 with backward-compatible behavior');
        Map<String, Object> body = parseResponse(res);
        Map<String, Object> data = (Map<String, Object>) body.get('data');
        System.assertEquals('API Client Corp', data.get('entityName'), 'Should fall back to authenticated entity');
    }

    // ==========================================
    // GET WORK-LOGS
    // ==========================================

    @IsTest
    static void testGetWorkLogs() {
        RestRequest req = buildGetRequest('/services/apexrest/delivery/deliveryhub/v1/api/work-logs');
        req.addHeader('X-Api-Key', TEST_API_KEY);
        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        DeliveryPublicApiService.handleGet();
        Test.stopTest();

        System.assertEquals(200, res.statusCode);
        Map<String, Object> body = parseResponse(res);
        System.assertEquals(true, body.get('success'));
    }

    // ==========================================
    // GET FILES
    // ==========================================

    @IsTest
    static void testGetFiles() {
        RestRequest req = buildGetRequest('/services/apexrest/delivery/deliveryhub/v1/api/files');
        req.addHeader('X-Api-Key', TEST_API_KEY);
        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        DeliveryPublicApiService.handleGet();
        Test.stopTest();

        System.assertEquals(200, res.statusCode);
        Map<String, Object> body = parseResponse(res);
        System.assertEquals(true, body.get('success'));
    }

    // ==========================================
    // GET BOARD-SUMMARY
    // ==========================================

    @IsTest
    static void testGetBoardSummary() {
        RestRequest req = buildGetRequest('/services/apexrest/delivery/deliveryhub/v1/api/board-summary');
        req.addHeader('X-Api-Key', TEST_API_KEY);
        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        DeliveryPublicApiService.handleGet();
        Test.stopTest();

        // Board summary may return null summary if AI is not configured — that's OK
        System.assertEquals(200, res.statusCode);
        Map<String, Object> body = parseResponse(res);
        System.assertEquals(true, body.get('success'));
    }

    // ==========================================
    // GET DOCUMENTS
    // ==========================================

    @IsTest
    static void testGetDocuments() {
        RestRequest req = buildGetRequest('/services/apexrest/delivery/deliveryhub/v1/api/documents');
        req.addHeader('X-Api-Key', TEST_API_KEY);
        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        DeliveryPublicApiService.handleGet();
        Test.stopTest();

        System.assertEquals(200, res.statusCode);
        Map<String, Object> body = parseResponse(res);
        System.assertEquals(true, body.get('success'));
    }

    // ==========================================
    // POST LOG-HOURS
    // ==========================================

    @IsTest
    static void testPostLogHours() {
        WorkItem__c item = [SELECT Id FROM WorkItem__c WHERE BriefDescriptionTxt__c = 'API Active Item' LIMIT 1];

        Map<String, Object> body = new Map<String, Object>{
            'workItemId' => item.Id,
            'hours' => 2.5,
            'workNotes' => 'Portal time entry',
            'workDate' => String.valueOf(Date.today())
        };

        RestRequest req = buildPostRequest(
            '/services/apexrest/delivery/deliveryhub/v1/api/log-hours',
            body
        );
        req.addHeader('X-Api-Key', TEST_API_KEY);
        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        DeliveryPublicApiService.handlePost();
        Test.stopTest();

        System.assertEquals(201, res.statusCode);
        Map<String, Object> responseBody = parseResponse(res);
        Map<String, Object> data = (Map<String, Object>) responseBody.get('data');
        System.assertEquals('Logged', data.get('status'));
    }

    @IsTest
    static void testPostLogHoursMissingFields() {
        Map<String, Object> body = new Map<String, Object>{
            'workItemId' => null,
            'hours' => null
        };

        RestRequest req = buildPostRequest(
            '/services/apexrest/delivery/deliveryhub/v1/api/log-hours',
            body
        );
        req.addHeader('X-Api-Key', TEST_API_KEY);
        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        DeliveryPublicApiService.handlePost();
        Test.stopTest();

        System.assertEquals(400, res.statusCode);
    }

    @IsTest
    static void testPostLogHoursCrossEntityBlocked() {
        WorkItem__c otherItem = [SELECT Id FROM WorkItem__c WHERE BriefDescriptionTxt__c = 'Other Corp Item' LIMIT 1];

        Map<String, Object> body = new Map<String, Object>{
            'workItemId' => otherItem.Id,
            'hours' => 1.5,
            'workNotes' => 'Cross-entity attempt',
            'workDate' => String.valueOf(Date.today())
        };

        RestRequest req = buildPostRequest(
            '/services/apexrest/delivery/deliveryhub/v1/api/log-hours',
            body
        );
        req.addHeader('X-Api-Key', TEST_API_KEY);
        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        DeliveryPublicApiService.handlePost();
        Test.stopTest();

        System.assertEquals(403, res.statusCode, 'Should block cross-entity hour logging');
        assertErrorResponse(res, 'access denied');
    }

    @IsTest
    static void testPostLogHoursCreatesActivityLog() {
        WorkItem__c item = [SELECT Id FROM WorkItem__c WHERE BriefDescriptionTxt__c = 'API Active Item' LIMIT 1];

        Map<String, Object> body = new Map<String, Object>{
            'workItemId' => item.Id,
            'hours' => 3.0,
            'workNotes' => 'Activity log test',
            'workDate' => String.valueOf(Date.today())
        };

        RestRequest req = buildPostRequest(
            '/services/apexrest/delivery/deliveryhub/v1/api/log-hours',
            body
        );
        req.addHeader('X-Api-Key', TEST_API_KEY);
        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        DeliveryPublicApiService.handlePost();
        Test.stopTest();

        System.assertEquals(201, res.statusCode);

        List<ActivityLog__c> logs = [
            SELECT ActionTypePk__c, RecordIdTxt__c, ComponentNameTxt__c
            FROM ActivityLog__c WHERE ActionTypePk__c = 'Portal_Hours_Logged'
        ];
        System.assertEquals(1, logs.size(), 'Should create an ActivityLog record');
        System.assertEquals(item.Id, logs[0].RecordIdTxt__c, 'ActivityLog should reference the work item');
        System.assertEquals('PortalTimeEntry', logs[0].ComponentNameTxt__c, 'ComponentName should be PortalTimeEntry');
    }

    // ==========================================
    // GET WORK-LOGS WITH WORK ITEM FILTER
    // ==========================================

    @IsTest
    static void testGetWorkLogsFilteredByWorkItem() {
        WorkItem__c item = [SELECT Id FROM WorkItem__c WHERE BriefDescriptionTxt__c = 'API Active Item' LIMIT 1];

        RestRequest req = buildGetRequest('/services/apexrest/delivery/deliveryhub/v1/api/work-logs');
        req.addHeader('X-Api-Key', TEST_API_KEY);
        req.addParameter('workItemId', item.Id);
        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        DeliveryPublicApiService.handleGet();
        Test.stopTest();

        System.assertEquals(200, res.statusCode);
        Map<String, Object> body = parseResponse(res);
        System.assertEquals(true, body.get('success'));

        List<Object> data = (List<Object>) body.get('data');
        for (Object entry : data) {
            Map<String, Object> log = (Map<String, Object>) entry;
            System.assertEquals(item.Id, log.get('workItemId'), 'All logs should belong to filtered work item');
        }
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

/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Test class for DeliveryPublicApiService.
 * Validates API key authentication, entity scoping, and all REST endpoints.
 * @author Cloud Nimbus LLC
 */
@IsTest
@SuppressWarnings('PMD.CyclomaticComplexity')
private class DeliveryPublicApiServiceTest {

    private static User testUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];

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
                ActivatedDateTime__c = Datetime.now(),
                StatusPk__c = 'New',
                ClientNetworkEntityLookup__c = entityA.Id,
                DetailsTxt__c = 'Active item for API testing'
            ),
            new WorkItem__c(
                BriefDescriptionTxt__c = 'API Done Item',
                StageNamePk__c = 'Done',
                PriorityPk__c = 'Low',
                ActivatedDateTime__c = null,
                StatusPk__c = 'Closed',
                ClientNetworkEntityLookup__c = entityA.Id
            ),
            // Entity B item (isolation)
            new WorkItem__c(
                BriefDescriptionTxt__c = 'Other Corp Item',
                StageNamePk__c = 'Backlog',
                PriorityPk__c = 'Medium',
                ActivatedDateTime__c = Datetime.now(),
                StatusPk__c = 'New',
                ClientNetworkEntityLookup__c = entityB.Id
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
            DeliveryEntityLookup__c = vendorForReq.Id,
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
            WorkItemLookup__c = items[0].Id,
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
        System.runAs(testUser) {
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
    }

    @IsTest
    static void testInvalidApiKey() {
        System.runAs(testUser) {
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
    }

    @IsTest
    static void testDisabledEntityApiKey() {
        System.runAs(testUser) {
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
    }

    // ==========================================
    // GET DASHBOARD
    // ==========================================

    @IsTest
    static void testGetDashboard() {
        System.runAs(testUser) {
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
    }

    // ==========================================
    // GET WORK ITEMS
    // ==========================================

    @IsTest
    static void testGetWorkItems() {
        System.runAs(testUser) {
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
    }

    @IsTest
    static void testGetWorkItemsWithFilter() {
        System.runAs(testUser) {
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
    }

    // ==========================================
    // GET WORK ITEM DETAIL
    // ==========================================

    @IsTest
    static void testGetWorkItemDetail() {
        System.runAs(testUser) {
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
    }

    @IsTest
    static void testGetWorkItemDetailCrossEntityBlocked() {
        System.runAs(testUser) {
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
    }

    // ==========================================
    // GET UNKNOWN RESOURCE
    // ==========================================

    @IsTest
    static void testGetUnknownResource() {
        System.runAs(testUser) {
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
    }

    // ==========================================
    // POST WORK ITEM (SUBMIT REQUEST)
    // ==========================================

    @IsTest
    static void testPostWorkItem() {
        System.runAs(testUser) {
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
                SELECT ClientNetworkEntityLookup__c, BriefDescriptionTxt__c
                FROM WorkItem__c
                WHERE BriefDescriptionTxt__c = '[Portal] New API Request'
                LIMIT 1
            ];
            NetworkEntity__c entityA = [SELECT Id FROM NetworkEntity__c WHERE Name = 'API Client Corp' LIMIT 1];
            System.assertEquals(entityA.Id, created.ClientNetworkEntityLookup__c, 'Should auto-link to authenticated entity');
        }
    }

    @IsTest
    static void testPostWorkItemEmptyBody() {
        System.runAs(testUser) {
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
    }

    /**
     * @description v0.200 defense-in-depth: blank-payload WorkItem creates
     *              should be rejected at the REST ingestor with a 400, not
     *              create a row with a [Portal] null title. Background: the
     *              cloudnimbus Slack approval handler once POSTed empty
     *              suggestedWorkRequest objects and dh-prod accepted them,
     *              creating 40 blank WorkItems before the client-side fix.
     */
    @IsTest
    static void testPostWorkItemBlankPayloadRejected() {
        System.runAs(testUser) {
            Map<String, Object> body = new Map<String, Object>{
                'priority' => 'High',
                'type' => 'Internal'
                // Intentionally omit title AND description — must be rejected.
            };
            RestRequest req = buildPostRequest(
                '/services/apexrest/delivery/deliveryhub/v1/api/work-items',
                body
            );
            req.addHeader('X-Api-Key', TEST_API_KEY);
            RestResponse res = new RestResponse();
            RestContext.request = req;
            RestContext.response = res;

            Integer beforeCount = [SELECT COUNT() FROM WorkItem__c];

            Test.startTest();
            DeliveryPublicApiService.handlePost();
            Test.stopTest();

            System.assertEquals(400, res.statusCode,
                'Blank payload must be rejected with HTTP 400');
            assertErrorResponse(res, 'Blank payloads are rejected');

            Integer afterCount = [SELECT COUNT() FROM WorkItem__c];
            System.assertEquals(beforeCount, afterCount,
                'No WorkItem should have been created for the blank payload');
        }
    }

    /**
     * @description Same blank-payload scenario, but with empty-string values
     *              instead of missing keys — e.g., `{"title":"","description":""}`.
     *              Still must be rejected (String.isBlank covers both).
     */
    @IsTest
    static void testPostWorkItemEmptyStringsRejected() {
        System.runAs(testUser) {
            Map<String, Object> body = new Map<String, Object>{
                'title' => '',
                'description' => '   ',
                'priority' => 'High'
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

            System.assertEquals(400, res.statusCode,
                'Empty/whitespace title+description must be rejected with HTTP 400');
        }
    }

    // ==========================================
    // POST COMMENT
    // ==========================================

    @IsTest
    static void testPostComment() {
        System.runAs(testUser) {
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
    }

    @IsTest
    static void testPostCommentCrossEntityBlocked() {
        System.runAs(testUser) {
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
    }

    // ==========================================
    // POST UNKNOWN RESOURCE
    // ==========================================

    @IsTest
    static void testPostUnknownResource() {
        System.runAs(testUser) {
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
    }

    // ==========================================
    // GET ACTIVITY FEED
    // ==========================================

    @IsTest
    static void testGetActivityFeed() {
        System.runAs(testUser) {
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
    }

    @IsTest
    static void testGetActivityFeedWithParams() {
        System.runAs(testUser) {
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
    }

    // ==========================================
    // GET CONVERSATIONS
    // ==========================================

    @IsTest
    static void testGetConversations() {
        System.runAs(testUser) {
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
    }

    // ==========================================
    // GET PENDING APPROVALS
    // ==========================================

    @IsTest
    static void testGetPendingApprovals() {
        System.runAs(testUser) {
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
    }

    // ==========================================
    // POST APPROVE WORKLOGS
    // ==========================================

    @IsTest
    static void testPostApproveWorkLogs() {
        System.runAs(testUser) {
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
    }

    // ==========================================
    // POST REJECT WORKLOGS
    // ==========================================

    @IsTest
    static void testPostRejectWorkLogs() {
        System.runAs(testUser) {
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
    }

    // ==========================================
    // API KEY GENERATION
    // ==========================================

    @IsTest
    static void testGenerateApiKey() {
        System.runAs(testUser) {
            Test.startTest();
            String key1 = DeliveryPublicApiService.generateApiKey();
            String key2 = DeliveryPublicApiService.generateApiKey();
            Test.stopTest();

            System.assertEquals(64, key1.length(), 'API key should be 64 hex characters');
            System.assertNotEquals(key1, key2, 'Generated keys should be unique');
        }
    }

    // ==========================================
    // PORTAL ACCESS — MY ENTITIES
    // ==========================================

    @IsTest
    static void testGetMyEntities() {
        System.runAs(testUser) {
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
    }

    @IsTest
    static void testGetMyEntitiesMissingHeader() {
        System.runAs(testUser) {
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
    }

    // ==========================================
    // PORTAL ACCESS — ENTITY SWITCHING
    // ==========================================

    @IsTest
    static void testGetDashboardWithEntityId() {
        System.runAs(testUser) {
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
    }

    @IsTest
    static void testGetDashboardUnauthorizedEntity() {
        System.runAs(testUser) {
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
    }

    @IsTest
    static void testGetDashboardBackwardCompatible() {
        System.runAs(testUser) {
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
    }

    // ==========================================
    // GET WORK-LOGS
    // ==========================================

    @IsTest
    static void testGetWorkLogs() {
        System.runAs(testUser) {
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
    }

    // ==========================================
    // GET FILES
    // ==========================================

    @IsTest
    static void testGetFiles() {
        System.runAs(testUser) {
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
    }

    // ==========================================
    // GET BOARD-SUMMARY
    // ==========================================

    @IsTest
    static void testGetBoardSummary() {
        System.runAs(testUser) {
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
    }

    // ==========================================
    // GET DOCUMENTS
    // ==========================================

    @IsTest
    static void testGetDocuments() {
        System.runAs(testUser) {
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
    }

    // ==========================================
    // POST LOG-HOURS
    // ==========================================

    @IsTest
    static void testPostLogHours() {
        System.runAs(testUser) {
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
    }

    @IsTest
    static void testPostLogHoursMissingFields() {
        System.runAs(testUser) {
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
    }

    @IsTest
    static void testPostLogHoursCrossEntityBlocked() {
        System.runAs(testUser) {
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
    }

    @IsTest
    static void testPostLogHoursCreatesActivityLog() {
        System.runAs(testUser) {
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
    }

    // ==========================================
    // GET WORK-LOGS WITH WORK ITEM FILTER
    // ==========================================

    @IsTest
    static void testGetWorkLogsFilteredByWorkItem() {
        System.runAs(testUser) {
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
    }

    // ==========================================
    // DOCUMENT APPROVAL TESTS
    // ==========================================

    @IsTest
    static void testPostDocumentApprove() {
        System.runAs(testUser) {
            NetworkEntity__c entity = [SELECT Id FROM NetworkEntity__c WHERE Name = 'API Client Corp' LIMIT 1];
            DeliveryTriggerControl.runAfterLogic = false;
            Id docId = DeliveryDocumentController.generateDocument(
                entity.Id, 'Invoice',
                Date.newInstance(2026, 3, 1), Date.newInstance(2026, 3, 31), null
            );
            DeliveryDocumentController.updateDocumentStatus(docId, 'Sent');
            DeliveryDocument__c doc = [SELECT PublicTokenTxt__c FROM DeliveryDocument__c WHERE Id = :docId];

            Map<String, Object> body = new Map<String, Object>{ 'token' => doc.PublicTokenTxt__c };
            RestRequest req = buildPostRequest('/services/apexrest/delivery/deliveryhub/v1/api/document-approve', body);
            req.addHeader('X-Api-Key', TEST_API_KEY);
            RestResponse res = new RestResponse();
            RestContext.request = req;
            RestContext.response = res;

            Test.startTest();
            DeliveryPublicApiService.handlePost();
            Test.stopTest();

            System.assertEquals(200, res.statusCode, 'Should return 200');
            Map<String, Object> result = parseResponse(res);
            System.assertEquals(true, result.get('success'), 'Should be successful');
            Map<String, Object> data = (Map<String, Object>) result.get('data');
            System.assertEquals('Approved', data.get('status'), 'Document should be Approved');
        }
    }

    @IsTest
    static void testPostDocumentDispute() {
        System.runAs(testUser) {
            NetworkEntity__c entity = [SELECT Id FROM NetworkEntity__c WHERE Name = 'API Client Corp' LIMIT 1];
            DeliveryTriggerControl.runAfterLogic = false;
            Id docId = DeliveryDocumentController.generateDocument(
                entity.Id, 'Invoice',
                Date.newInstance(2026, 3, 1), Date.newInstance(2026, 3, 31), null
            );
            DeliveryDocumentController.updateDocumentStatus(docId, 'Sent');
            DeliveryDocument__c doc = [SELECT PublicTokenTxt__c FROM DeliveryDocument__c WHERE Id = :docId];

            Map<String, Object> body = new Map<String, Object>{
                'token' => doc.PublicTokenTxt__c, 'reason' => 'Hours are incorrect'
            };
            RestRequest req = buildPostRequest('/services/apexrest/delivery/deliveryhub/v1/api/document-dispute', body);
            req.addHeader('X-Api-Key', TEST_API_KEY);
            RestResponse res = new RestResponse();
            RestContext.request = req;
            RestContext.response = res;

            Test.startTest();
            DeliveryPublicApiService.handlePost();
            Test.stopTest();

            System.assertEquals(200, res.statusCode, 'Should return 200');
            Map<String, Object> result = parseResponse(res);
            Map<String, Object> data = (Map<String, Object>) result.get('data');
            System.assertEquals('Disputed', data.get('status'), 'Document should be Disputed');
        }
    }

    @IsTest
    static void testPostDocumentApproveMissingToken() {
        System.runAs(testUser) {
            Map<String, Object> body = new Map<String, Object>{ 'action' => 'approve' };
            RestRequest req = buildPostRequest('/services/apexrest/delivery/deliveryhub/v1/api/document-approve', body);
            req.addHeader('X-Api-Key', TEST_API_KEY);
            RestResponse res = new RestResponse();
            RestContext.request = req;
            RestContext.response = res;

            Test.startTest();
            DeliveryPublicApiService.handlePost();
            Test.stopTest();

            System.assertEquals(400, res.statusCode, 'Should return 400 for missing token');
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

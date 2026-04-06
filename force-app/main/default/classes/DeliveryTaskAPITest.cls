/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Test class for DeliveryTaskAPI REST resource.
 *               Validates GET listing, GET with filters, PATCH updates,
 *               and POST comment creation.
 * @author Cloud Nimbus LLC
 */
@IsTest
private class DeliveryTaskAPITest {

    private static User testUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];

    private static final String TEST_API_KEY = 'test-api-key-12345';

    @TestSetup
    static void setupData() {
        // Create an active network entity with API key for auth
        NetworkEntity__c entity = new NetworkEntity__c(
            Name = 'Test API Client',
            EntityTypePk__c = 'Client',
            StatusPk__c = 'Active',
            ApiKeyTxt__c = TEST_API_KEY
        );
        insert entity;

        // Work items with different stages and priorities
        List<WorkItem__c> items = new List<WorkItem__c>{
            new WorkItem__c(
                BriefDescriptionTxt__c = 'API Task Alpha',
                StageNamePk__c        = 'In Development',
                PriorityPk__c         = 'High',
                ActivatedDateTime__c       = Datetime.now(),
                StatusPk__c           = 'New',
                DetailsTxt__c         = 'Details for alpha task',
                WorkflowTypeTxt__c    = 'Software_Delivery',
                DeveloperLookupId__c          = UserInfo.getUserId()
            ),
            new WorkItem__c(
                BriefDescriptionTxt__c = 'API Task Beta',
                StageNamePk__c        = 'Backlog',
                PriorityPk__c         = 'Medium',
                ActivatedDateTime__c       = Datetime.now(),
                StatusPk__c           = 'New',
                WorkflowTypeTxt__c    = 'Software_Delivery'
            ),
            new WorkItem__c(
                BriefDescriptionTxt__c = 'API Task Gamma',
                StageNamePk__c        = 'Code Review',
                PriorityPk__c         = 'Low',
                ActivatedDateTime__c       = Datetime.now(),
                StatusPk__c           = 'New',
                WorkflowTypeTxt__c    = 'Loan_Approval'
            )
        };
        insert items;
    }

    // ==========================================
    // GET — list all work items
    // ==========================================

    @IsTest
    static void testGetAllTasks() {
        System.runAs(testUser) {
            RestRequest req = buildGetRequest('/services/apexrest/delivery/deliveryhub/v1/tasks');
            RestResponse res = new RestResponse();
            RestContext.request = req;
            RestContext.response = res;

            Test.startTest();
            DeliveryTaskAPI.handleGet();
            Test.stopTest();

            System.assertEquals(200, res.statusCode, 'Should return 200');
            Map<String, Object> body = parseResponse(res);
            System.assertEquals(true, body.get('success'), 'Should be successful');
            List<Object> data = (List<Object>) body.get('data');
            System.assertEquals(3, data.size(), 'Should return all 3 work items');
        }
    }

    // ==========================================
    // GET — filter by assignee
    // ==========================================

    @IsTest
    static void testGetTasksByAssignee() {
        System.runAs(testUser) {
            RestRequest req = buildGetRequest('/services/apexrest/delivery/deliveryhub/v1/tasks');
            req.addParameter('assignee', 'ai');
            RestResponse res = new RestResponse();
            RestContext.request = req;
            RestContext.response = res;

            Test.startTest();
            DeliveryTaskAPI.handleGet();
            Test.stopTest();

            System.assertEquals(200, res.statusCode, 'Should return 200');
            Map<String, Object> body = parseResponse(res);
            List<Object> data = (List<Object>) body.get('data');
            System.assertEquals(1, data.size(), 'Should return only 1 item with Developer assigned');
        }
    }

    // ==========================================
    // GET — filter by status (stage)
    // ==========================================

    @IsTest
    static void testGetTasksByStatus() {
        System.runAs(testUser) {
            RestRequest req = buildGetRequest('/services/apexrest/delivery/deliveryhub/v1/tasks');
            req.addParameter('status', 'Backlog');
            RestResponse res = new RestResponse();
            RestContext.request = req;
            RestContext.response = res;

            Test.startTest();
            DeliveryTaskAPI.handleGet();
            Test.stopTest();

            System.assertEquals(200, res.statusCode, 'Should return 200');
            Map<String, Object> body = parseResponse(res);
            List<Object> data = (List<Object>) body.get('data');
            System.assertEquals(1, data.size(), 'Should return only Backlog items');
        }
    }

    // ==========================================
    // GET — filter by workflow type
    // ==========================================

    @IsTest
    static void testGetTasksByWorkflowType() {
        System.runAs(testUser) {
            RestRequest req = buildGetRequest('/services/apexrest/delivery/deliveryhub/v1/tasks');
            req.addParameter('workflowType', 'Loan_Approval');
            RestResponse res = new RestResponse();
            RestContext.request = req;
            RestContext.response = res;

            Test.startTest();
            DeliveryTaskAPI.handleGet();
            Test.stopTest();

            System.assertEquals(200, res.statusCode, 'Should return 200');
            Map<String, Object> body = parseResponse(res);
            List<Object> data = (List<Object>) body.get('data');
            System.assertEquals(1, data.size(), 'Should return only Loan_Approval items');
        }
    }

    // ==========================================
    // PATCH — update stage
    // ==========================================

    @IsTest
    static void testPatchUpdateStage() {
        System.runAs(testUser) {
            WorkItem__c item = [
                SELECT Id FROM WorkItem__c
                WHERE BriefDescriptionTxt__c = 'API Task Alpha' LIMIT 1
            ];

            Map<String, Object> body = new Map<String, Object>{
                'stage' => 'Code Review'
            };

            RestRequest req = buildPatchRequest(
                '/services/apexrest/delivery/deliveryhub/v1/tasks/' + item.Id,
                body
            );
            RestResponse res = new RestResponse();
            RestContext.request = req;
            RestContext.response = res;

            Test.startTest();
            DeliveryTaskAPI.handlePatch();
            Test.stopTest();

            System.assertEquals(200, res.statusCode, 'Should return 200');
            Map<String, Object> responseBody = parseResponse(res);
            System.assertEquals(true, responseBody.get('success'), 'Should be successful');

            Map<String, Object> data = (Map<String, Object>) responseBody.get('data');
            System.assertEquals('Code Review', data.get('stage'), 'Stage should be updated');

            // Verify in database
            WorkItem__c updated = [
                SELECT StageNamePk__c FROM WorkItem__c WHERE Id = :item.Id
            ];
            System.assertEquals('Code Review', updated.StageNamePk__c, 'DB stage should match');
        }
    }

    // ==========================================
    // PATCH — update priority
    // ==========================================

    @IsTest
    static void testPatchUpdatePriority() {
        System.runAs(testUser) {
            WorkItem__c item = [
                SELECT Id FROM WorkItem__c
                WHERE BriefDescriptionTxt__c = 'API Task Beta' LIMIT 1
            ];

            Map<String, Object> body = new Map<String, Object>{
                'priority' => 'Critical'
            };

            RestRequest req = buildPatchRequest(
                '/services/apexrest/delivery/deliveryhub/v1/tasks/' + item.Id,
                body
            );
            RestResponse res = new RestResponse();
            RestContext.request = req;
            RestContext.response = res;

            Test.startTest();
            DeliveryTaskAPI.handlePatch();
            Test.stopTest();

            System.assertEquals(200, res.statusCode, 'Should return 200');

            WorkItem__c updated = [
                SELECT PriorityPk__c FROM WorkItem__c WHERE Id = :item.Id
            ];
            System.assertEquals('Critical', updated.PriorityPk__c, 'Priority should be updated');
        }
    }

    // ==========================================
    // PATCH — missing ID
    // ==========================================

    @IsTest
    static void testPatchMissingId() {
        System.runAs(testUser) {
            RestRequest req = buildPatchRequest(
                '/services/apexrest/delivery/deliveryhub/v1/tasks/',
                new Map<String, Object>{ 'stage' => 'Done' }
            );
            RestResponse res = new RestResponse();
            RestContext.request = req;
            RestContext.response = res;

            Test.startTest();
            DeliveryTaskAPI.handlePatch();
            Test.stopTest();

            System.assertEquals(400, res.statusCode, 'Should return 400 for missing ID');
        }
    }

    // ==========================================
    // PATCH — empty body
    // ==========================================

    @IsTest
    static void testPatchEmptyBody() {
        System.runAs(testUser) {
            WorkItem__c item = [
                SELECT Id FROM WorkItem__c
                WHERE BriefDescriptionTxt__c = 'API Task Alpha' LIMIT 1
            ];

            RestRequest req = new RestRequest();
            req.requestURI = '/services/apexrest/delivery/deliveryhub/v1/tasks/' + item.Id;
            req.httpMethod = 'PATCH';
            req.headers.put('X-Api-Key', TEST_API_KEY);
            RestResponse res = new RestResponse();
            RestContext.request = req;
            RestContext.response = res;

            Test.startTest();
            DeliveryTaskAPI.handlePatch();
            Test.stopTest();

            System.assertEquals(400, res.statusCode, 'Should return 400 for empty body');
        }
    }

    // ==========================================
    // POST — create comment
    // ==========================================

    @IsTest
    static void testPostComment() {
        System.runAs(testUser) {
            WorkItem__c item = [
                SELECT Id FROM WorkItem__c
                WHERE BriefDescriptionTxt__c = 'API Task Alpha' LIMIT 1
            ];

            Map<String, Object> body = new Map<String, Object>{
                'body'   => 'This is a comment from the API',
                'author' => 'CI Pipeline'
            };

            RestRequest req = buildPostRequest(
                '/services/apexrest/delivery/deliveryhub/v1/tasks/' + item.Id + '/comments',
                body
            );
            RestResponse res = new RestResponse();
            RestContext.request = req;
            RestContext.response = res;

            Test.startTest();
            DeliveryTaskAPI.handlePost();
            Test.stopTest();

            System.assertEquals(201, res.statusCode, 'Should return 201 Created');
            Map<String, Object> responseBody = parseResponse(res);
            System.assertEquals(true, responseBody.get('success'), 'Should be successful');

            Map<String, Object> data = (Map<String, Object>) responseBody.get('data');
            System.assertNotEquals(null, data.get('id'), 'Should return comment Id');

            // Verify in database
            WorkItemComment__c comment = [
                SELECT BodyTxt__c, AuthorTxt__c, SourcePk__c
                FROM WorkItemComment__c
                WHERE WorkItemId__c = :item.Id
                LIMIT 1
            ];
            System.assertEquals('This is a comment from the API', comment.BodyTxt__c, 'Comment body should match');
            System.assertEquals('CI Pipeline', comment.AuthorTxt__c, 'Author should match');
            System.assertEquals('API', comment.SourcePk__c, 'Source should be API');
        }
    }

    // ==========================================
    // POST — comment with default author
    // ==========================================

    @IsTest
    static void testPostCommentDefaultAuthor() {
        System.runAs(testUser) {
            WorkItem__c item = [
                SELECT Id FROM WorkItem__c
                WHERE BriefDescriptionTxt__c = 'API Task Beta' LIMIT 1
            ];

            Map<String, Object> body = new Map<String, Object>{
                'body' => 'Auto-generated comment'
            };

            RestRequest req = buildPostRequest(
                '/services/apexrest/delivery/deliveryhub/v1/tasks/' + item.Id + '/comments',
                body
            );
            RestResponse res = new RestResponse();
            RestContext.request = req;
            RestContext.response = res;

            Test.startTest();
            DeliveryTaskAPI.handlePost();
            Test.stopTest();

            System.assertEquals(201, res.statusCode, 'Should return 201');

            WorkItemComment__c comment = [
                SELECT AuthorTxt__c FROM WorkItemComment__c
                WHERE WorkItemId__c = :item.Id LIMIT 1
            ];
            System.assertEquals('API', comment.AuthorTxt__c, 'Default author should be API');
        }
    }

    // ==========================================
    // POST — missing work item ID
    // ==========================================

    @IsTest
    static void testPostCommentMissingId() {
        System.runAs(testUser) {
            RestRequest req = buildPostRequest(
                '/services/apexrest/delivery/deliveryhub/v1/tasks/',
                new Map<String, Object>{ 'body' => 'orphan comment' }
            );
            RestResponse res = new RestResponse();
            RestContext.request = req;
            RestContext.response = res;

            Test.startTest();
            DeliveryTaskAPI.handlePost();
            Test.stopTest();

            System.assertEquals(400, res.statusCode, 'Should return 400 for missing work item ID');
        }
    }

    // ==========================================
    // POST — empty comment body
    // ==========================================

    @IsTest
    static void testPostCommentEmptyBody() {
        System.runAs(testUser) {
            WorkItem__c item = [
                SELECT Id FROM WorkItem__c
                WHERE BriefDescriptionTxt__c = 'API Task Alpha' LIMIT 1
            ];

            RestRequest req = buildPostRequest(
                '/services/apexrest/delivery/deliveryhub/v1/tasks/' + item.Id + '/comments',
                new Map<String, Object>{ 'body' => '' }
            );
            RestResponse res = new RestResponse();
            RestContext.request = req;
            RestContext.response = res;

            Test.startTest();
            DeliveryTaskAPI.handlePost();
            Test.stopTest();

            System.assertEquals(400, res.statusCode, 'Should return 400 for empty comment body');
        }
    }

    // ==========================================
    // HELPERS
    // ==========================================

    // ==========================================
    // Auth — missing API key returns 401
    // ==========================================

    @IsTest
    static void testGetMissingApiKey() {
        System.runAs(testUser) {
            RestRequest req = new RestRequest();
            req.requestURI = '/services/apexrest/delivery/deliveryhub/v1/tasks';
            req.httpMethod = 'GET';
            // No X-Api-Key header
            RestResponse res = new RestResponse();
            RestContext.request = req;
            RestContext.response = res;

            Test.startTest();
            DeliveryTaskAPI.handleGet();
            Test.stopTest();

            System.assertEquals(401, res.statusCode, 'Should return 401 for missing API key');
        }
    }

    // ==========================================
    // PATCH — non-existent work item returns 404
    // ==========================================

    @IsTest
    static void testPatchNonExistentWorkItem() {
        System.runAs(testUser) {
            // Use a valid ID format that doesn't exist in DB
            String fakeId = WorkItem__c.SObjectType.getDescribe().getKeyPrefix() + '000000000099';
            RestRequest req = buildPatchRequest(
                '/services/apexrest/delivery/deliveryhub/v1/tasks/' + fakeId,
                new Map<String, Object>{ 'stage' => 'Done' }
            );
            RestResponse res = new RestResponse();
            RestContext.request = req;
            RestContext.response = res;

            Test.startTest();
            DeliveryTaskAPI.handlePatch();
            Test.stopTest();

            System.assertEquals(404, res.statusCode, 'Should return 404 for non-existent work item');
        }
    }

    // ==========================================
    // PATCH — no valid update fields returns 400
    // ==========================================

    @IsTest
    static void testPatchNoValidFields() {
        System.runAs(testUser) {
            WorkItem__c item = [
                SELECT Id FROM WorkItem__c
                WHERE BriefDescriptionTxt__c = 'API Task Alpha' LIMIT 1
            ];

            RestRequest req = buildPatchRequest(
                '/services/apexrest/delivery/deliveryhub/v1/tasks/' + item.Id,
                new Map<String, Object>{ 'someUnknownField' => 'value' }
            );
            RestResponse res = new RestResponse();
            RestContext.request = req;
            RestContext.response = res;

            Test.startTest();
            DeliveryTaskAPI.handlePatch();
            Test.stopTest();

            System.assertEquals(400, res.statusCode, 'Should return 400 when no valid fields provided');
        }
    }

    // ==========================================
    // POST — non-existent work item returns 404
    // ==========================================

    @IsTest
    static void testPostCommentNonExistentWorkItem() {
        System.runAs(testUser) {
            String fakeId = WorkItem__c.SObjectType.getDescribe().getKeyPrefix() + '000000000099';
            RestRequest req = buildPostRequest(
                '/services/apexrest/delivery/deliveryhub/v1/tasks/' + fakeId + '/comments',
                new Map<String, Object>{ 'body' => 'orphan comment' }
            );
            RestResponse res = new RestResponse();
            RestContext.request = req;
            RestContext.response = res;

            Test.startTest();
            DeliveryTaskAPI.handlePost();
            Test.stopTest();

            System.assertEquals(404, res.statusCode, 'Should return 404 for non-existent work item');
        }
    }

    // ==========================================
    // HELPERS
    // ==========================================

    private static RestRequest buildGetRequest(String uri) {
        RestRequest req = new RestRequest();
        req.requestURI = uri;
        req.httpMethod = 'GET';
        req.headers.put('X-Api-Key', TEST_API_KEY);
        return req;
    }

    private static RestRequest buildPatchRequest(String uri, Map<String, Object> body) {
        RestRequest req = new RestRequest();
        req.requestURI = uri;
        req.httpMethod = 'PATCH';
        req.requestBody = Blob.valueOf(JSON.serialize(body));
        req.headers.put('X-Api-Key', TEST_API_KEY);
        return req;
    }

    private static RestRequest buildPostRequest(String uri, Map<String, Object> body) {
        RestRequest req = new RestRequest();
        req.requestURI = uri;
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(JSON.serialize(body));
        req.headers.put('X-Api-Key', TEST_API_KEY);
        return req;
    }

    private static Map<String, Object> parseResponse(RestResponse res) {
        return (Map<String, Object>) JSON.deserializeUntyped(res.responseBody.toString());
    }
}

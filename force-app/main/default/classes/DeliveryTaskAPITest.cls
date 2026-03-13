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

    @TestSetup
    static void setupData() {
        // Work items with different stages and priorities
        List<WorkItem__c> items = new List<WorkItem__c>{
            new WorkItem__c(
                BriefDescriptionTxt__c = 'API Task Alpha',
                StageNamePk__c        = 'In Development',
                PriorityPk__c         = 'High',
                IsActiveBool__c       = true,
                StatusPk__c           = 'New',
                DetailsTxt__c         = 'Details for alpha task',
                WorkflowTypeTxt__c    = 'Software_Delivery',
                Developer__c          = UserInfo.getUserId()
            ),
            new WorkItem__c(
                BriefDescriptionTxt__c = 'API Task Beta',
                StageNamePk__c        = 'Backlog',
                PriorityPk__c         = 'Medium',
                IsActiveBool__c       = true,
                StatusPk__c           = 'New',
                WorkflowTypeTxt__c    = 'Software_Delivery'
            ),
            new WorkItem__c(
                BriefDescriptionTxt__c = 'API Task Gamma',
                StageNamePk__c        = 'Code Review',
                PriorityPk__c         = 'Low',
                IsActiveBool__c       = true,
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
        RestRequest req = buildGetRequest('/services/apexrest/delivery/delivery/tasks');
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

    // ==========================================
    // GET — filter by assignee
    // ==========================================

    @IsTest
    static void testGetTasksByAssignee() {
        RestRequest req = buildGetRequest('/services/apexrest/delivery/delivery/tasks');
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

    // ==========================================
    // GET — filter by status (stage)
    // ==========================================

    @IsTest
    static void testGetTasksByStatus() {
        RestRequest req = buildGetRequest('/services/apexrest/delivery/delivery/tasks');
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

    // ==========================================
    // GET — filter by workflow type
    // ==========================================

    @IsTest
    static void testGetTasksByWorkflowType() {
        RestRequest req = buildGetRequest('/services/apexrest/delivery/delivery/tasks');
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

    // ==========================================
    // PATCH — update stage
    // ==========================================

    @IsTest
    static void testPatchUpdateStage() {
        WorkItem__c item = [
            SELECT Id FROM WorkItem__c
            WHERE BriefDescriptionTxt__c = 'API Task Alpha' LIMIT 1
        ];

        Map<String, Object> body = new Map<String, Object>{
            'stage' => 'Code Review'
        };

        RestRequest req = buildPatchRequest(
            '/services/apexrest/delivery/delivery/tasks/' + item.Id,
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

    // ==========================================
    // PATCH — update priority
    // ==========================================

    @IsTest
    static void testPatchUpdatePriority() {
        WorkItem__c item = [
            SELECT Id FROM WorkItem__c
            WHERE BriefDescriptionTxt__c = 'API Task Beta' LIMIT 1
        ];

        Map<String, Object> body = new Map<String, Object>{
            'priority' => 'Critical'
        };

        RestRequest req = buildPatchRequest(
            '/services/apexrest/delivery/delivery/tasks/' + item.Id,
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

    // ==========================================
    // PATCH — missing ID
    // ==========================================

    @IsTest
    static void testPatchMissingId() {
        RestRequest req = buildPatchRequest(
            '/services/apexrest/delivery/delivery/tasks/',
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

    // ==========================================
    // PATCH — empty body
    // ==========================================

    @IsTest
    static void testPatchEmptyBody() {
        WorkItem__c item = [
            SELECT Id FROM WorkItem__c
            WHERE BriefDescriptionTxt__c = 'API Task Alpha' LIMIT 1
        ];

        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/delivery/delivery/tasks/' + item.Id;
        req.httpMethod = 'PATCH';
        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        DeliveryTaskAPI.handlePatch();
        Test.stopTest();

        System.assertEquals(400, res.statusCode, 'Should return 400 for empty body');
    }

    // ==========================================
    // POST — create comment
    // ==========================================

    @IsTest
    static void testPostComment() {
        WorkItem__c item = [
            SELECT Id FROM WorkItem__c
            WHERE BriefDescriptionTxt__c = 'API Task Alpha' LIMIT 1
        ];

        Map<String, Object> body = new Map<String, Object>{
            'body'   => 'This is a comment from the API',
            'author' => 'CI Pipeline'
        };

        RestRequest req = buildPostRequest(
            '/services/apexrest/delivery/delivery/tasks/' + item.Id + '/comments',
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

    // ==========================================
    // POST — comment with default author
    // ==========================================

    @IsTest
    static void testPostCommentDefaultAuthor() {
        WorkItem__c item = [
            SELECT Id FROM WorkItem__c
            WHERE BriefDescriptionTxt__c = 'API Task Beta' LIMIT 1
        ];

        Map<String, Object> body = new Map<String, Object>{
            'body' => 'Auto-generated comment'
        };

        RestRequest req = buildPostRequest(
            '/services/apexrest/delivery/delivery/tasks/' + item.Id + '/comments',
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

    // ==========================================
    // POST — missing work item ID
    // ==========================================

    @IsTest
    static void testPostCommentMissingId() {
        RestRequest req = buildPostRequest(
            '/services/apexrest/delivery/delivery/tasks/',
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

    // ==========================================
    // POST — empty comment body
    // ==========================================

    @IsTest
    static void testPostCommentEmptyBody() {
        WorkItem__c item = [
            SELECT Id FROM WorkItem__c
            WHERE BriefDescriptionTxt__c = 'API Task Alpha' LIMIT 1
        ];

        RestRequest req = buildPostRequest(
            '/services/apexrest/delivery/delivery/tasks/' + item.Id + '/comments',
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

    // ==========================================
    // HELPERS
    // ==========================================

    private static RestRequest buildGetRequest(String uri) {
        RestRequest req = new RestRequest();
        req.requestURI = uri;
        req.httpMethod = 'GET';
        return req;
    }

    private static RestRequest buildPatchRequest(String uri, Map<String, Object> body) {
        RestRequest req = new RestRequest();
        req.requestURI = uri;
        req.httpMethod = 'PATCH';
        req.requestBody = Blob.valueOf(JSON.serialize(body));
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
}

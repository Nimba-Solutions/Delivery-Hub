/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Test class for DeliveryPublicSubmissionService.
 * Validates successful submission, required field enforcement, rate limiting,
 * entity resolution, and input sanitization for unauthenticated work item creation.
 * @author Cloud Nimbus LLC
 */
@IsTest
private class DeliveryPublicSubmissionServiceTest {

    @TestSetup
    static void setupData() {
        NetworkEntity__c clientEntity = new NetworkEntity__c(
            Name = 'Public Submissions Client',
            EntityTypePk__c = 'Client',
            StatusPk__c = 'Active'
        );
        NetworkEntity__c vendorEntity = new NetworkEntity__c(
            Name = 'Vendor Only',
            EntityTypePk__c = 'Vendor',
            StatusPk__c = 'Active'
        );
        insert new List<NetworkEntity__c>{ clientEntity, vendorEntity };
    }

    // -------------------------------------------------------------------------
    // Helper: builds a RestRequest with the given JSON body
    // -------------------------------------------------------------------------

    private static void setupRestContext(Map<String, Object> body) {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.requestURI = '/services/apexrest/delivery/deliveryhub/v1/submit';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(JSON.serialize(body));

        RestContext.request = req;
        RestContext.response = res;
    }

    private static void setupRestContextRaw(String rawBody) {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.requestURI = '/services/apexrest/delivery/deliveryhub/v1/submit';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(rawBody);

        RestContext.request = req;
        RestContext.response = res;
    }

    // -------------------------------------------------------------------------
    // Success scenarios
    // -------------------------------------------------------------------------

    @IsTest
    static void testSuccessfulSubmission() {
        NetworkEntity__c entity = [SELECT Id FROM NetworkEntity__c WHERE Name = 'Public Submissions Client' LIMIT 1];

        Map<String, Object> body = new Map<String, Object>{
            'title' => 'I need help with deployment',
            'description' => '<p>My deployment is failing.</p>',
            'email' => 'john@example.com',
            'name' => 'John Doe',
            'priority' => 'High',
            'requestType' => 'Feature',
            'tags' => 'portal,urgent',
            'entityId' => entity.Id
        };
        setupRestContext(body);

        Test.startTest();
        Map<String, Object> result = DeliveryPublicSubmissionService.submitWorkItem();
        Test.stopTest();

        System.assertEquals(true, result.get('success'), 'Should succeed');
        System.assertNotEquals(null, result.get('workItemId'), 'Should return a work item Id');
        System.assertNotEquals(null, result.get('workItemNumber'), 'Should return the auto-number');

        WorkItem__c created = [
            SELECT BriefDescriptionTxt__c, DetailsTxt__c, ExternalRequesterEmailTxt__c,
                   StageNamePk__c, PriorityPk__c, RequestTypePk__c, Tags__c,
                   IsActiveBool__c, StatusPk__c, ClientNetworkEntityId__c
            FROM WorkItem__c
            WHERE Id = :(Id) result.get('workItemId')
            LIMIT 1
        ];

        System.assertEquals('[Public] I need help with deployment', created.BriefDescriptionTxt__c, 'Title should have [Public] prefix');
        System.assertEquals('john@example.com', created.ExternalRequesterEmailTxt__c, 'Email should be stored');
        System.assertEquals('Backlog', created.StageNamePk__c, 'Should start in Backlog');
        System.assertEquals('High', created.PriorityPk__c, 'Priority should match');
        System.assertEquals('Feature', created.RequestTypePk__c, 'Request type should match');
        System.assertEquals('portal,urgent', created.Tags__c, 'Tags should match');
        System.assertEquals(true, created.IsActiveBool__c, 'Should be active');
        System.assertEquals('New', created.StatusPk__c, 'Status should be New');
        System.assertEquals(entity.Id, created.ClientNetworkEntityId__c, 'Should be linked to the entity');
        System.assert(created.DetailsTxt__c.contains('John Doe'), 'Description should contain submitter name');
        System.assert(created.DetailsTxt__c.contains('john@example.com'), 'Description should contain submitter email');
        System.assert(created.DetailsTxt__c.contains('deployment is failing'), 'Description should contain user description');
    }

    @IsTest
    static void testSuccessfulSubmissionMinimalFields() {
        Map<String, Object> body = new Map<String, Object>{
            'title' => 'Minimal request',
            'email' => 'minimal@example.com'
        };
        setupRestContext(body);

        Test.startTest();
        Map<String, Object> result = DeliveryPublicSubmissionService.submitWorkItem();
        Test.stopTest();

        System.assertEquals(true, result.get('success'), 'Should succeed with minimal fields');

        WorkItem__c created = [
            SELECT PriorityPk__c, RequestTypePk__c, ClientNetworkEntityId__c
            FROM WorkItem__c
            WHERE Id = :(Id) result.get('workItemId')
            LIMIT 1
        ];

        System.assertEquals('Medium', created.PriorityPk__c, 'Default priority should be Medium');
        System.assertEquals('Public Lead', created.RequestTypePk__c, 'Default request type should be Public Lead');
        // Should resolve to the first active Client entity
        NetworkEntity__c clientEntity = [SELECT Id FROM NetworkEntity__c WHERE Name = 'Public Submissions Client' LIMIT 1];
        System.assertEquals(clientEntity.Id, created.ClientNetworkEntityId__c, 'Should fall back to default Client entity');
    }

    @IsTest
    static void testSubmissionWithNameNoDescription() {
        Map<String, Object> body = new Map<String, Object>{
            'title' => 'Question about pricing',
            'email' => 'asker@example.com',
            'name' => 'Jane Smith'
        };
        setupRestContext(body);

        Test.startTest();
        Map<String, Object> result = DeliveryPublicSubmissionService.submitWorkItem();
        Test.stopTest();

        System.assertEquals(true, result.get('success'), 'Should succeed');

        WorkItem__c created = [
            SELECT DetailsTxt__c
            FROM WorkItem__c
            WHERE Id = :(Id) result.get('workItemId')
            LIMIT 1
        ];

        System.assert(created.DetailsTxt__c.contains('Jane Smith'), 'Should contain submitter name');
        System.assert(created.DetailsTxt__c.contains('asker@example.com'), 'Should contain submitter email');
    }

    // -------------------------------------------------------------------------
    // Validation errors
    // -------------------------------------------------------------------------

    @IsTest
    static void testMissingTitle() {
        Map<String, Object> body = new Map<String, Object>{
            'email' => 'test@example.com'
        };
        setupRestContext(body);

        Test.startTest();
        Map<String, Object> result = DeliveryPublicSubmissionService.submitWorkItem();
        Test.stopTest();

        System.assertEquals(false, result.get('success'), 'Should fail without title');
        System.assertEquals('Title is required.', result.get('error'), 'Should return title required error');
        System.assertEquals(400, RestContext.response.statusCode, 'Should return 400');
    }

    @IsTest
    static void testMissingEmail() {
        Map<String, Object> body = new Map<String, Object>{
            'title' => 'A valid title'
        };
        setupRestContext(body);

        Test.startTest();
        Map<String, Object> result = DeliveryPublicSubmissionService.submitWorkItem();
        Test.stopTest();

        System.assertEquals(false, result.get('success'), 'Should fail without email');
        System.assertEquals('Email is required.', result.get('error'), 'Should return email required error');
        System.assertEquals(400, RestContext.response.statusCode, 'Should return 400');
    }

    @IsTest
    static void testInvalidEmail() {
        Map<String, Object> body = new Map<String, Object>{
            'title' => 'A valid title',
            'email' => 'not-an-email'
        };
        setupRestContext(body);

        Test.startTest();
        Map<String, Object> result = DeliveryPublicSubmissionService.submitWorkItem();
        Test.stopTest();

        System.assertEquals(false, result.get('success'), 'Should fail with invalid email');
        System.assertEquals('A valid email address is required.', result.get('error'), 'Should return email validation error');
        System.assertEquals(400, RestContext.response.statusCode, 'Should return 400');
    }

    @IsTest
    static void testEmptyBody() {
        setupRestContextRaw('');

        Test.startTest();
        Map<String, Object> result = DeliveryPublicSubmissionService.submitWorkItem();
        Test.stopTest();

        System.assertEquals(false, result.get('success'), 'Should fail with empty body');
        System.assertEquals(400, RestContext.response.statusCode, 'Should return 400');
    }

    // -------------------------------------------------------------------------
    // Rate limiting
    // -------------------------------------------------------------------------

    @IsTest
    static void testRateLimiting() {
        String rateLimitEmail = 'spammer@example.com';

        // Pre-create 5 recent work items from this email to simulate hitting the limit
        List<WorkItem__c> existingItems = new List<WorkItem__c>();
        for (Integer i = 0; i < 5; i++) {
            existingItems.add(new WorkItem__c(
                BriefDescriptionTxt__c = '[Public] Existing ' + i,
                StageNamePk__c = 'Backlog',
                ExternalRequesterEmailTxt__c = rateLimitEmail,
                IsActiveBool__c = true,
                StatusPk__c = 'New'
            ));
        }
        Database.insert(existingItems, AccessLevel.SYSTEM_MODE);

        // Now attempt a 6th submission via the REST endpoint
        Map<String, Object> body = new Map<String, Object>{
            'title' => 'One more request',
            'email' => rateLimitEmail
        };
        setupRestContext(body);

        Test.startTest();
        Map<String, Object> result = DeliveryPublicSubmissionService.submitWorkItem();
        Test.stopTest();

        System.assertEquals(false, result.get('success'), 'Should fail due to rate limiting');
        System.assertEquals('Rate limit exceeded. Please try again later.', result.get('error'), 'Should return rate limit error');
        System.assertEquals(429, RestContext.response.statusCode, 'Should return 429');
    }

    @IsTest
    static void testRateLimitAllowsUnderThreshold() {
        String legitimateEmail = 'legitimate@example.com';

        // Pre-create 4 recent work items (under the limit of 5)
        List<WorkItem__c> existingItems = new List<WorkItem__c>();
        for (Integer i = 0; i < 4; i++) {
            existingItems.add(new WorkItem__c(
                BriefDescriptionTxt__c = '[Public] Existing ' + i,
                StageNamePk__c = 'Backlog',
                ExternalRequesterEmailTxt__c = legitimateEmail,
                IsActiveBool__c = true,
                StatusPk__c = 'New'
            ));
        }
        Database.insert(existingItems, AccessLevel.SYSTEM_MODE);

        // 5th submission should still be allowed
        Map<String, Object> body = new Map<String, Object>{
            'title' => 'Fifth request',
            'email' => legitimateEmail
        };
        setupRestContext(body);

        Test.startTest();
        Map<String, Object> result = DeliveryPublicSubmissionService.submitWorkItem();
        Test.stopTest();

        System.assertEquals(true, result.get('success'), 'Should succeed at 5th submission (limit not yet exceeded)');
    }

    // -------------------------------------------------------------------------
    // Entity resolution
    // -------------------------------------------------------------------------

    @IsTest
    static void testWithExplicitEntityId() {
        NetworkEntity__c entity = [SELECT Id FROM NetworkEntity__c WHERE Name = 'Public Submissions Client' LIMIT 1];

        Map<String, Object> body = new Map<String, Object>{
            'title' => 'Linked to entity',
            'email' => 'linked@example.com',
            'entityId' => entity.Id
        };
        setupRestContext(body);

        Test.startTest();
        Map<String, Object> result = DeliveryPublicSubmissionService.submitWorkItem();
        Test.stopTest();

        System.assertEquals(true, result.get('success'), 'Should succeed');

        WorkItem__c created = [
            SELECT ClientNetworkEntityId__c
            FROM WorkItem__c
            WHERE Id = :(Id) result.get('workItemId')
            LIMIT 1
        ];
        System.assertEquals(entity.Id, created.ClientNetworkEntityId__c, 'Should be linked to the specified entity');
    }

    @IsTest
    static void testWithVendorEntityIdFallsBack() {
        // Vendor entity should not be accepted; should fall back to default Client entity
        NetworkEntity__c vendorEntity = [SELECT Id FROM NetworkEntity__c WHERE Name = 'Vendor Only' LIMIT 1];
        NetworkEntity__c clientEntity = [SELECT Id FROM NetworkEntity__c WHERE Name = 'Public Submissions Client' LIMIT 1];

        Map<String, Object> body = new Map<String, Object>{
            'title' => 'Vendor entity test',
            'email' => 'vendor@example.com',
            'entityId' => vendorEntity.Id
        };
        setupRestContext(body);

        Test.startTest();
        Map<String, Object> result = DeliveryPublicSubmissionService.submitWorkItem();
        Test.stopTest();

        System.assertEquals(true, result.get('success'), 'Should succeed');

        WorkItem__c created = [
            SELECT ClientNetworkEntityId__c
            FROM WorkItem__c
            WHERE Id = :(Id) result.get('workItemId')
            LIMIT 1
        ];
        System.assertEquals(clientEntity.Id, created.ClientNetworkEntityId__c, 'Should fall back to the Client entity');
    }

    @IsTest
    static void testWithInvalidEntityIdFallsBack() {
        NetworkEntity__c clientEntity = [SELECT Id FROM NetworkEntity__c WHERE Name = 'Public Submissions Client' LIMIT 1];

        Map<String, Object> body = new Map<String, Object>{
            'title' => 'Bad entity test',
            'email' => 'badentity@example.com',
            'entityId' => 'not-a-real-id'
        };
        setupRestContext(body);

        Test.startTest();
        Map<String, Object> result = DeliveryPublicSubmissionService.submitWorkItem();
        Test.stopTest();

        System.assertEquals(true, result.get('success'), 'Should succeed with fallback entity');

        WorkItem__c created = [
            SELECT ClientNetworkEntityId__c
            FROM WorkItem__c
            WHERE Id = :(Id) result.get('workItemId')
            LIMIT 1
        ];
        System.assertEquals(clientEntity.Id, created.ClientNetworkEntityId__c, 'Should fall back to default Client entity');
    }

    @IsTest
    static void testWithoutEntityIdUsesDefault() {
        NetworkEntity__c clientEntity = [SELECT Id FROM NetworkEntity__c WHERE Name = 'Public Submissions Client' LIMIT 1];

        Map<String, Object> body = new Map<String, Object>{
            'title' => 'No entity specified',
            'email' => 'noentity@example.com'
        };
        setupRestContext(body);

        Test.startTest();
        Map<String, Object> result = DeliveryPublicSubmissionService.submitWorkItem();
        Test.stopTest();

        System.assertEquals(true, result.get('success'), 'Should succeed');

        WorkItem__c created = [
            SELECT ClientNetworkEntityId__c
            FROM WorkItem__c
            WHERE Id = :(Id) result.get('workItemId')
            LIMIT 1
        ];
        System.assertEquals(clientEntity.Id, created.ClientNetworkEntityId__c, 'Should auto-resolve to the first active Client entity');
    }

    // -------------------------------------------------------------------------
    // Input sanitization
    // -------------------------------------------------------------------------

    @IsTest
    static void testHtmlStrippedFromTitle() {
        Map<String, Object> body = new Map<String, Object>{
            'title' => '<script>alert("xss")</script>Help me',
            'email' => 'clean@example.com'
        };
        setupRestContext(body);

        Test.startTest();
        Map<String, Object> result = DeliveryPublicSubmissionService.submitWorkItem();
        Test.stopTest();

        System.assertEquals(true, result.get('success'), 'Should succeed');

        WorkItem__c created = [
            SELECT BriefDescriptionTxt__c
            FROM WorkItem__c
            WHERE Id = :(Id) result.get('workItemId')
            LIMIT 1
        ];
        System.assert(!created.BriefDescriptionTxt__c.contains('<script>'), 'HTML should be stripped from title');
        System.assert(created.BriefDescriptionTxt__c.contains('Help me'), 'Plain text should remain');
    }

    @IsTest
    static void testInvalidPriorityDefaultsToMedium() {
        Map<String, Object> body = new Map<String, Object>{
            'title' => 'Priority test',
            'email' => 'priority@example.com',
            'priority' => 'Critical'
        };
        setupRestContext(body);

        Test.startTest();
        Map<String, Object> result = DeliveryPublicSubmissionService.submitWorkItem();
        Test.stopTest();

        System.assertEquals(true, result.get('success'), 'Should succeed');

        WorkItem__c created = [
            SELECT PriorityPk__c
            FROM WorkItem__c
            WHERE Id = :(Id) result.get('workItemId')
            LIMIT 1
        ];
        System.assertEquals('Medium', created.PriorityPk__c, 'Invalid priority should default to Medium');
    }

    @IsTest
    static void testHttpStatusCodeOnSuccess() {
        Map<String, Object> body = new Map<String, Object>{
            'title' => 'Status code test',
            'email' => 'status@example.com'
        };
        setupRestContext(body);

        Test.startTest();
        DeliveryPublicSubmissionService.submitWorkItem();
        Test.stopTest();

        System.assertEquals(201, RestContext.response.statusCode, 'Successful creation should return 201');
    }
}

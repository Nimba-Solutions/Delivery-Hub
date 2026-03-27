/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Test class for DeliveryBountyApiService REST endpoints.
 *               Validates public GET access, authenticated POST actions, and error handling.
 * @author       Cloud Nimbus LLC
 */
@IsTest
private class DeliveryBountyApiServiceTest {

    private static final String TEST_API_KEY = 'bounty-api-test-key-xyz';

    @TestSetup
    static void setupData() {
        NetworkEntity__c entity = new NetworkEntity__c(
            Name = 'Bounty Platform',
            EntityTypePk__c = 'Vendor',
            StatusPk__c = 'Active',
            ApiKeyTxt__c = TEST_API_KEY,
            ConnectionStatusPk__c = 'Connected',
            ContactEmailTxt__c = 'platform@example.com'
        );
        insert entity;

        WorkItem__c bounty = new WorkItem__c(
            BriefDescriptionTxt__c = 'API Test Bounty',
            DetailsTxt__c = 'Test bounty for API endpoint testing',
            AcceptanceCriteriaTxt__c = '1. Tests pass\n2. Coverage > 80%',
            StageNamePk__c = 'Backlog',
            PriorityPk__c = 'High',
            ActivatedDateTime__c = Datetime.now(),
            BountyEnabledDateTime__c = Datetime.now(),
            BountyAmountCurrency__c = 300.00,
            BountyDeadlineDate__c = Date.today().addDays(30),
            BountyStatusPk__c = 'Open',
            BountyTokenTxt__c = 'api-test-token-001',
            BountyDifficultyPk__c = 'Intermediate',
            BountySkillsTxt__c = 'Apex;LWC',
            BountyMaxClaimsNumber__c = 5,
            ClientNetworkEntityId__c = entity.Id
        );
        insert bounty;
    }

    // ── GET: List Bounties (Public) ──────────────────────────────────────

    @IsTest
    static void testGetListBounties() {
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/deliveryhub/v1/bounties';
        req.httpMethod = 'GET';
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        DeliveryBountyApiService.handleGet();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode);
        Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(
            RestContext.response.responseBody.toString()
        );
        System.assertEquals(true, result.get('success'));
        List<Object> data = (List<Object>) result.get('data');
        System.assertEquals(1, data.size(), 'Should return the one open bounty');
    }

    @IsTest
    static void testGetListBountiesWithFilters() {
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/deliveryhub/v1/bounties';
        req.httpMethod = 'GET';
        req.params.put('difficulty', 'Expert');
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        DeliveryBountyApiService.handleGet();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode);
        Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(
            RestContext.response.responseBody.toString()
        );
        List<Object> data = (List<Object>) result.get('data');
        System.assertEquals(0, data.size(), 'No Expert bounties should exist');
    }

    // ── GET: Bounty Detail (Public) ──────────────────────────────────────

    @IsTest
    static void testGetBountyDetail() {
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/deliveryhub/v1/bounties/api-test-token-001';
        req.httpMethod = 'GET';
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        DeliveryBountyApiService.handleGet();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode);
        Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(
            RestContext.response.responseBody.toString()
        );
        System.assertEquals(true, result.get('success'));
        Map<String, Object> data = (Map<String, Object>) result.get('data');
        System.assertEquals('API Test Bounty', data.get('title'));
    }

    @IsTest
    static void testGetBountyDetailNotFound() {
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/deliveryhub/v1/bounties/nonexistent';
        req.httpMethod = 'GET';
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        DeliveryBountyApiService.handleGet();
        Test.stopTest();

        System.assertEquals(404, RestContext.response.statusCode);
    }

    // ── POST: Claim Bounty (Authenticated) ───────────────────────────────

    @IsTest
    static void testPostClaimBountySuccess() {
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/deliveryhub/v1/bounties/api-test-token-001/claim';
        req.httpMethod = 'POST';
        req.addHeader('X-Api-Key', TEST_API_KEY);
        req.requestBody = Blob.valueOf(JSON.serialize(new Map<String, String>{
            'email' => 'claimer@example.com',
            'name' => 'Test Claimer',
            'note' => 'Excited to work on this!'
        }));
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        DeliveryBountyApiService.handlePost();
        Test.stopTest();

        System.assertEquals(201, RestContext.response.statusCode);
        Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(
            RestContext.response.responseBody.toString()
        );
        System.assertEquals(true, result.get('success'));
        Map<String, Object> data = (Map<String, Object>) result.get('data');
        System.assertEquals('Active', data.get('status'));
        System.assertNotEquals(null, data.get('claimId'));
    }

    @IsTest
    static void testPostClaimBountyNoAuth() {
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/deliveryhub/v1/bounties/api-test-token-001/claim';
        req.httpMethod = 'POST';
        // No X-Api-Key header
        req.requestBody = Blob.valueOf('{"email":"test@example.com"}');
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        DeliveryBountyApiService.handlePost();
        Test.stopTest();

        System.assertEquals(401, RestContext.response.statusCode);
    }

    @IsTest
    static void testPostClaimBountyInvalidKey() {
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/deliveryhub/v1/bounties/api-test-token-001/claim';
        req.httpMethod = 'POST';
        req.addHeader('X-Api-Key', 'bad-key');
        req.requestBody = Blob.valueOf('{"email":"test@example.com"}');
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        DeliveryBountyApiService.handlePost();
        Test.stopTest();

        System.assertEquals(401, RestContext.response.statusCode);
    }

    @IsTest
    static void testPostClaimBountyMissingEmail() {
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/deliveryhub/v1/bounties/api-test-token-001/claim';
        req.httpMethod = 'POST';
        req.addHeader('X-Api-Key', TEST_API_KEY);
        req.requestBody = Blob.valueOf('{"name":"No Email"}');
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        DeliveryBountyApiService.handlePost();
        Test.stopTest();

        System.assertEquals(400, RestContext.response.statusCode);
    }

    // ── POST: Submit Work (Authenticated) ────────────────────────────────

    @IsTest
    static void testPostSubmitWorkSuccess() {
        // First create a claim
        DeliveryBountyService.claimBounty('api-test-token-001', 'dev@example.com', 'Dev', null);

        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/deliveryhub/v1/bounties/api-test-token-001/submit';
        req.httpMethod = 'POST';
        req.addHeader('X-Api-Key', TEST_API_KEY);
        req.requestBody = Blob.valueOf(JSON.serialize(new Map<String, String>{
            'email' => 'dev@example.com',
            'workProofUrl' => 'https://github.com/example/pr/42',
            'note' => 'Done!'
        }));
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        DeliveryBountyApiService.handlePost();
        Test.stopTest();

        System.assertEquals(201, RestContext.response.statusCode);
    }

    @IsTest
    static void testPostSubmitWorkMissingProofUrl() {
        DeliveryBountyService.claimBounty('api-test-token-001', 'dev@example.com', 'Dev', null);

        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/deliveryhub/v1/bounties/api-test-token-001/submit';
        req.httpMethod = 'POST';
        req.addHeader('X-Api-Key', TEST_API_KEY);
        req.requestBody = Blob.valueOf('{"email":"dev@example.com"}');
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        DeliveryBountyApiService.handlePost();
        Test.stopTest();

        System.assertEquals(400, RestContext.response.statusCode);
    }

    // ── POST: Withdraw Claim (Authenticated) ─────────────────────────────

    @IsTest
    static void testPostWithdrawClaimSuccess() {
        DeliveryBountyService.claimBounty('api-test-token-001', 'dev@example.com', 'Dev', null);

        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/deliveryhub/v1/bounties/api-test-token-001/withdraw';
        req.httpMethod = 'POST';
        req.addHeader('X-Api-Key', TEST_API_KEY);
        req.requestBody = Blob.valueOf('{"email":"dev@example.com"}');
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        DeliveryBountyApiService.handlePost();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode);
    }

    // ── POST: Unknown Action ─────────────────────────────────────────────

    @IsTest
    static void testPostUnknownAction() {
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/deliveryhub/v1/bounties/api-test-token-001/foobar';
        req.httpMethod = 'POST';
        req.addHeader('X-Api-Key', TEST_API_KEY);
        req.requestBody = Blob.valueOf('{}');
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        DeliveryBountyApiService.handlePost();
        Test.stopTest();

        System.assertEquals(404, RestContext.response.statusCode);
    }
}

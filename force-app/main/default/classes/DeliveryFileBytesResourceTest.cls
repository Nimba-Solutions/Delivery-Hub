/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Tests for DeliveryFileBytesResource — verifies HMAC auth,
 *              timestamp skew rejection, 404 for unknown ContentDocumentIds,
 *              and happy-path bytes delivery.
 * @author Cloud Nimbus LLC
 */
@IsTest
private class DeliveryFileBytesResourceTest {

    private static final String TEST_API_KEY = 'test-api-key-12345';
    private static final String TEST_HMAC_SECRET = 'shhh-test-secret';

    @TestSetup
    static void makeData() {
        NetworkEntity__c peer = new NetworkEntity__c(
            Name = 'Peer Org',
            EntityTypePk__c = 'Client',
            StatusPk__c = 'Active',
            ConnectionStatusPk__c = 'Connected',
            ApiKeyTxt__c = TEST_API_KEY,
            HmacSecretTxt__c = TEST_HMAC_SECRET,
            IntegrationEndpointUrlTxt__c = 'https://peer.example.com'
        );
        insert peer;

        ContentVersion cv = new ContentVersion(
            Title = 'Asset',
            PathOnClient = 'asset.bin',
            VersionData = Blob.valueOf('hello bytes')
        );
        insert cv;
    }

    private static String firstContentDocumentId() {
        return [SELECT ContentDocumentId FROM ContentVersion LIMIT 1].ContentDocumentId;
    }

    private static RestRequest buildRequest(String contentDocumentId, String apiKey, String timestamp, String signature) {
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/delivery/fileBytes/' + (contentDocumentId == null ? '' : contentDocumentId);
        req.httpMethod = 'GET';
        if (apiKey != null) {
            req.headers.put('X-Api-Key', apiKey);
        }
        if (timestamp != null) {
            req.headers.put('X-Timestamp', timestamp);
        }
        if (signature != null) {
            req.headers.put('X-Signature', signature);
        }
        return req;
    }

    private static String signFor(String contentDocumentId, String timestamp) {
        return DeliveryCryptoService.computeHMAC(TEST_HMAC_SECRET, contentDocumentId + '|' + timestamp);
    }

    @IsTest
    static void testHappyPathReturnsBytes() {
        String cdId = firstContentDocumentId();
        String ts = String.valueOf(Datetime.now().getTime() / 1000L);
        String sig = signFor(cdId, ts);

        RestContext.request = buildRequest(cdId, TEST_API_KEY, ts, sig);
        RestContext.response = new RestResponse();

        Test.startTest();
        DeliveryFileBytesResource.handleGet();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode,
            'Valid HMAC + known ContentDocumentId should return 200');
        System.assertNotEquals(null, RestContext.response.responseBody,
            'Response body should carry the bytes');
        System.assertEquals('hello bytes', RestContext.response.responseBody.toString(),
            'Response body should match the original VersionData');
    }

    @IsTest
    static void testMissingApiKeyReturns401() {
        String cdId = firstContentDocumentId();
        String ts = String.valueOf(Datetime.now().getTime() / 1000L);
        String sig = signFor(cdId, ts);

        RestContext.request = buildRequest(cdId, null, ts, sig);
        RestContext.response = new RestResponse();

        Test.startTest();
        DeliveryFileBytesResource.handleGet();
        Test.stopTest();

        System.assertEquals(401, RestContext.response.statusCode,
            'Missing X-Api-Key should reject with 401');
    }

    @IsTest
    static void testInvalidApiKeyReturns401() {
        String cdId = firstContentDocumentId();
        String ts = String.valueOf(Datetime.now().getTime() / 1000L);
        String sig = signFor(cdId, ts);

        RestContext.request = buildRequest(cdId, 'wrong-key', ts, sig);
        RestContext.response = new RestResponse();

        Test.startTest();
        DeliveryFileBytesResource.handleGet();
        Test.stopTest();

        System.assertEquals(401, RestContext.response.statusCode,
            'Unknown API key should be rejected with 401');
    }

    @IsTest
    static void testBadHmacReturns401() {
        String cdId = firstContentDocumentId();
        String ts = String.valueOf(Datetime.now().getTime() / 1000L);

        RestContext.request = buildRequest(cdId, TEST_API_KEY, ts, 'nonsense-signature');
        RestContext.response = new RestResponse();

        Test.startTest();
        DeliveryFileBytesResource.handleGet();
        Test.stopTest();

        System.assertEquals(401, RestContext.response.statusCode,
            'Bad HMAC should be rejected with 401');
    }

    @IsTest
    static void testStaleTimestampReturns401() {
        String cdId = firstContentDocumentId();
        // One hour in the past — well beyond the 300s skew window
        String staleTs = String.valueOf((Datetime.now().getTime() / 1000L) - 3600L);
        String sig = signFor(cdId, staleTs);

        RestContext.request = buildRequest(cdId, TEST_API_KEY, staleTs, sig);
        RestContext.response = new RestResponse();

        Test.startTest();
        DeliveryFileBytesResource.handleGet();
        Test.stopTest();

        System.assertEquals(401, RestContext.response.statusCode,
            'Stale timestamp should fail replay-protection check');
    }

    @IsTest
    static void testUnknownContentDocumentIdReturns404() {
        // SOQL `WHERE ContentDocumentId = :x` requires valid Id format, so
        // build one dynamically from the ContentDocument key prefix rather
        // than hardcoding '069...' — same pattern used in
        // DeliveryHubBoardControllerTest.
        String fakeCdId = ContentDocument.SObjectType.getDescribe().getKeyPrefix() + '000000000001';
        String ts = String.valueOf(Datetime.now().getTime() / 1000L);
        String sig = signFor(fakeCdId, ts);

        RestContext.request = buildRequest(fakeCdId, TEST_API_KEY, ts, sig);
        RestContext.response = new RestResponse();

        Test.startTest();
        DeliveryFileBytesResource.handleGet();
        Test.stopTest();

        System.assertEquals(404, RestContext.response.statusCode,
            'Unknown ContentDocumentId should return 404');
    }

    @IsTest
    static void testPeerWithoutHmacSecretIsRefused() {
        NetworkEntity__c peer = [SELECT Id FROM NetworkEntity__c LIMIT 1];
        peer.HmacSecretTxt__c = null;
        update peer;

        String cdId = firstContentDocumentId();
        String ts = String.valueOf(Datetime.now().getTime() / 1000L);

        RestContext.request = buildRequest(cdId, TEST_API_KEY, ts, 'whatever');
        RestContext.response = new RestResponse();

        Test.startTest();
        DeliveryFileBytesResource.handleGet();
        Test.stopTest();

        System.assertEquals(401, RestContext.response.statusCode,
            'Binary transfer must require HMAC — peer without secret should be refused');
    }

    @IsTest
    static void testMissingContentDocumentIdReturns400() {
        String ts = String.valueOf(Datetime.now().getTime() / 1000L);
        String sig = signFor('', ts);

        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/delivery/fileBytes';
        req.httpMethod = 'GET';
        req.headers.put('X-Api-Key', TEST_API_KEY);
        req.headers.put('X-Timestamp', ts);
        req.headers.put('X-Signature', sig);
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        DeliveryFileBytesResource.handleGet();
        Test.stopTest();

        System.assertEquals(400, RestContext.response.statusCode,
            'Missing ContentDocumentId should return 400');
    }
}

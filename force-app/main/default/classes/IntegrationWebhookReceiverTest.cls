/**
 * @name         Delivery Hub · Integration Framework
 * @license      BSL 1.1 — See LICENSE.md
 * @description Tests for IntegrationWebhookReceiver. Constructs RestRequest /
 *              RestResponse via RestContext mocking pattern and validates the
 *              receiver's URL parsing, header collection, response codes.
 *              Cannot insert IntegrationProvider__mdt records in test; uses
 *              the @TestVisible private methods directly to exercise the
 *              non-IO logic.
 *
 * @author       Cloud Nimbus LLC
 * @since        2026-04-26
 */
@IsTest
@SuppressWarnings('PMD.ApexDoc')
private class IntegrationWebhookReceiverTest {

    private static RestRequest buildRequest(String uri, String body, Map<String, String> headers) {
        RestRequest req = new RestRequest();
        req.requestURI = uri;
        req.requestBody = body == null ? null : Blob.valueOf(body);
        req.httpMethod = 'POST';
        if (headers != null) {
            for (String k : headers.keySet()) {
                req.headers.put(k, headers.get(k));
            }
        }
        return req;
    }

    @IsTest
    static void extractProviderKeySimple() {
        String key = IntegrationWebhookReceiver.extractProviderKey(
            '/services/apexrest/integration/v1/webhook/Slack_Webhook');
        System.assertEquals('Slack_Webhook', key);
    }

    @IsTest
    static void extractProviderKeyTrailingSlash() {
        String key = IntegrationWebhookReceiver.extractProviderKey(
            '/services/apexrest/integration/v1/webhook/Active_Collab/');
        System.assertEquals('Active_Collab', key);
    }

    @IsTest
    static void extractProviderKeyWithQueryString() {
        String key = IntegrationWebhookReceiver.extractProviderKey(
            '/services/apexrest/integration/v1/webhook/MyProvider?source=test');
        System.assertEquals('MyProvider', key);
    }

    @IsTest
    static void extractProviderKeyMissingMarkerReturnsNull() {
        String key = IntegrationWebhookReceiver.extractProviderKey(
            '/services/apexrest/integration/v1/something-else/X');
        System.assertEquals(null, key);
    }

    @IsTest
    static void extractProviderKeyBlankReturnsNull() {
        System.assertEquals(null, IntegrationWebhookReceiver.extractProviderKey(null));
        System.assertEquals(null, IntegrationWebhookReceiver.extractProviderKey(''));
    }

    @IsTest
    static void collectHeadersLowerCasesKeys() {
        RestRequest req = buildRequest('/x', 'body', new Map<String, String>{
            'X-Signature' => 'abc',
            'Content-Type' => 'application/json'
        });
        Map<String, String> out = IntegrationWebhookReceiver.collectHeaders(req);
        System.assertEquals('abc', out.get('x-signature'));
        System.assertEquals('application/json', out.get('content-type'));
    }

    @IsTest
    static void validateTimestampFreshTimestampReturnsTrue() {
        Long now = Datetime.now().getTime() / 1000;
        Map<String, String> h = new Map<String, String>{ 'x-timestamp' => String.valueOf(now) };
        System.assertEquals(true, IntegrationWebhookReceiver.validateTimestamp(h));
    }

    @IsTest
    static void validateTimestampStaleTimestampReturnsFalse() {
        Long staleSec = (Datetime.now().getTime() / 1000) - 1000; // 16+ min ago
        Map<String, String> h = new Map<String, String>{ 'x-timestamp' => String.valueOf(staleSec) };
        System.assertEquals(false, IntegrationWebhookReceiver.validateTimestamp(h));
    }

    @IsTest
    static void validateTimestampMissingHeaderReturnsTrueStub() {
        // Stub policy during bring-up: tolerate missing timestamp.
        System.assertEquals(true,
            IntegrationWebhookReceiver.validateTimestamp(new Map<String, String>()));
    }

    @IsTest
    static void validateTimestampInvalidFormatReturnsFalse() {
        Map<String, String> h = new Map<String, String>{ 'x-timestamp' => 'not-a-number' };
        System.assertEquals(false, IntegrationWebhookReceiver.validateTimestamp(h));
    }

    @IsTest
    static void doPostMissingProviderKeyReturns400() {
        RestContext.request = buildRequest(
            '/services/apexrest/integration/v1/webhook/', '{}', null);
        RestContext.response = new RestResponse();
        Test.startTest();
        IntegrationWebhookReceiver.doPost();
        Test.stopTest();
        System.assertEquals(400, RestContext.response.statusCode);
    }

    @IsTest
    static void doPostUnknownProviderReturns404() {
        RestContext.request = buildRequest(
            '/services/apexrest/integration/v1/webhook/NonexistentProvider_99999',
            '{}', null);
        RestContext.response = new RestResponse();
        Test.startTest();
        IntegrationWebhookReceiver.doPost();
        Test.stopTest();
        System.assertEquals(404, RestContext.response.statusCode);
    }

    @IsTest
    static void writeResponseSetsCodeAndBody() {
        RestResponse res = new RestResponse();
        IntegrationWebhookReceiver.writeResponse(res, 418, '{"teapot":true}');
        System.assertEquals(418, res.statusCode);
        System.assertEquals('{"teapot":true}', res.responseBody.toString());
    }

    @IsTest
    static void validateSignatureStubReturnsTrue() {
        // Stub state: validateSignature returns true unconditionally during
        // bring-up. When secret-resolution lands in Phase 4 follow-up, this
        // test gets replaced with positive + negative HMAC cases.
        IntegrationProvider__mdt cfg = new IntegrationProvider__mdt();
        Boolean ok = IntegrationWebhookReceiver.validateSignature(
            cfg, new Map<String, String>(), 'body');
        System.assertEquals(true, ok);
    }
}

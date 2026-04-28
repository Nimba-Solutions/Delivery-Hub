/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Tests for DeliveryWebhookReceiverApi — slug extraction,
 *               JSON parsing, error responses. Provider lookup needs real
 *               CMT rows so it's exercised via DeliveryWebhookEventRouterTest
 *               where the router is invoked with in-memory provider stubs.
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.ApexDoc')
@IsTest
private class DeliveryWebhookReceiverApiTest {

    @IsTest
    static void extractSlugReturnsLastPathSegment() {
        System.assertEquals('Stripe_Webhook',
            DeliveryWebhookReceiverApi.extractSlug('/services/apexrest/delivery/deliveryhub/v1/webhook/Stripe_Webhook'));
    }

    @IsTest
    static void extractSlugStripsQueryString() {
        System.assertEquals('GitHub',
            DeliveryWebhookReceiverApi.extractSlug('/services/apexrest/delivery/deliveryhub/v1/webhook/GitHub?source=test'));
    }

    @IsTest
    static void extractSlugReturnsBlankWhenMissing() {
        System.assertEquals('',
            DeliveryWebhookReceiverApi.extractSlug('/services/apexrest/delivery/other/route'));
    }

    @IsTest
    static void parseBodyAcceptsObject() {
        Map<String, Object> parsed = DeliveryWebhookReceiverApi.parseBody('{"a":1}');
        System.assertEquals(1, parsed.get('a'));
    }

    @IsTest
    static void parseBodyEmptyReturnsEmptyMap() {
        System.assertEquals(0, DeliveryWebhookReceiverApi.parseBody('').size());
    }

    @IsTest
    static void parseBodyArrayThrows() {
        Boolean threw = false;
        try {
            DeliveryWebhookReceiverApi.parseBody('[1,2,3]');
        } catch (Exception e) {
            threw = true;
        }
        System.assertEquals(true, threw,
            'Webhook bodies must be JSON objects, not arrays');
    }

    @IsTest
    static void postWithMissingSlugReturns400() {
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/delivery/deliveryhub/v1/webhook/';
        req.requestBody = Blob.valueOf('{}');
        req.httpMethod = 'POST';
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        DeliveryWebhookReceiverApi.handlePost();
        Test.stopTest();

        System.assertEquals(400, RestContext.response.statusCode,
            'Missing provider slug should return 400');
    }

    @IsTest
    static void postWithUnknownSlugReturns404() {
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/delivery/deliveryhub/v1/webhook/Nonexistent_Provider_99999';
        req.requestBody = Blob.valueOf('{"type":"x"}');
        req.httpMethod = 'POST';
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        DeliveryWebhookReceiverApi.handlePost();
        Test.stopTest();

        System.assertEquals(404, RestContext.response.statusCode,
            'Unknown provider slug should return 404');
    }
}

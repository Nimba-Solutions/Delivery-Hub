/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Tests for WebhookSignatureVerifier — HmacSha256, HmacSha1,
 *               None, Stripe-style compound headers, header-missing failures.
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.ApexDoc')
@IsTest
private class WebhookSignatureVerifierTest {

    private static final String SECRET = 'whsec_test_12345';
    private static final String BODY = '{"type":"charge.succeeded"}';

    private static IntegrationProvider__mdt baseConfig() {
        IntegrationProvider__mdt p = new IntegrationProvider__mdt();
        p.DeveloperName = 'Test_Inbound';
        p.SignatureAlgorithmTxt__c = 'HmacSha256';
        p.SignatureHeaderTxt__c = 'X-Test-Signature';
        p.SignatureSecretTxt__c = SECRET;
        return p;
    }

    private static String hmac(String algo, String body, String secret) {
        return EncodingUtil.convertToHex(
            Crypto.generateMac(algo, Blob.valueOf(body), Blob.valueOf(secret)));
    }

    private static RestRequest reqWithHeader(String name, String value) {
        RestRequest r = new RestRequest();
        r.headers.put(name, value);
        return r;
    }

    @IsTest
    static void noneAlgorithmAlwaysPasses() {
        IntegrationProvider__mdt p = baseConfig();
        p.SignatureAlgorithmTxt__c = 'None';
        WebhookSignatureVerifier.Outcome o = WebhookSignatureVerifier.verify(
            p, new RestRequest(), 'anything');
        System.assertEquals(true, o.passed,
            'None disables verification');
    }

    @IsTest
    static void hmacSha256BareDigestPasses() {
        IntegrationProvider__mdt p = baseConfig();
        String sig = hmac('HmacSHA256', BODY, SECRET);
        WebhookSignatureVerifier.Outcome o = WebhookSignatureVerifier.verify(
            p, reqWithHeader('X-Test-Signature', sig), BODY);
        System.assertEquals(true, o.passed, 'Matching HMAC-SHA256 should pass');
    }

    @IsTest
    static void hmacSha256StripeCompoundHeaderPasses() {
        IntegrationProvider__mdt p = baseConfig();
        String sig = hmac('HmacSHA256', BODY, SECRET);
        WebhookSignatureVerifier.Outcome o = WebhookSignatureVerifier.verify(
            p, reqWithHeader('X-Test-Signature', 't=1234567890,v1=' + sig), BODY);
        System.assertEquals(true, o.passed,
            'Stripe-style "t=...,v1=..." compound header should pass when v1 matches');
    }

    @IsTest
    static void hmacSha1Works() {
        IntegrationProvider__mdt p = baseConfig();
        p.SignatureAlgorithmTxt__c = 'HmacSha1';
        String sig = hmac('HmacSHA1', BODY, SECRET);
        WebhookSignatureVerifier.Outcome o = WebhookSignatureVerifier.verify(
            p, reqWithHeader('X-Test-Signature', sig), BODY);
        System.assertEquals(true, o.passed);
    }

    @IsTest
    static void wrongSignatureFails() {
        IntegrationProvider__mdt p = baseConfig();
        WebhookSignatureVerifier.Outcome o = WebhookSignatureVerifier.verify(
            p, reqWithHeader('X-Test-Signature', 'deadbeef'), BODY);
        System.assertEquals(false, o.passed);
    }

    @IsTest
    static void missingHeaderFails() {
        IntegrationProvider__mdt p = baseConfig();
        WebhookSignatureVerifier.Outcome o = WebhookSignatureVerifier.verify(
            p, new RestRequest(), BODY);
        System.assertEquals(false, o.passed);
        System.assert(o.reason.contains('Missing header'));
    }

    @IsTest
    static void missingSecretFails() {
        IntegrationProvider__mdt p = baseConfig();
        p.SignatureSecretTxt__c = null;
        WebhookSignatureVerifier.Outcome o = WebhookSignatureVerifier.verify(
            p, reqWithHeader('X-Test-Signature', 'anything'), BODY);
        System.assertEquals(false, o.passed);
    }

    @IsTest
    static void unknownAlgorithmFails() {
        IntegrationProvider__mdt p = baseConfig();
        p.SignatureAlgorithmTxt__c = 'NotAnAlgo';
        WebhookSignatureVerifier.Outcome o = WebhookSignatureVerifier.verify(
            p, reqWithHeader('X-Test-Signature', 'x'), BODY);
        System.assertEquals(false, o.passed);
    }

    @IsTest
    static void constantTimeEqualsCoverage() {
        System.assertEquals(true,
            WebhookSignatureVerifier.constantTimeEquals('abc', 'abc'));
        System.assertEquals(false,
            WebhookSignatureVerifier.constantTimeEquals('abc', 'xyz'));
        System.assertEquals(false,
            WebhookSignatureVerifier.constantTimeEquals('abc', 'abcd'));
        System.assertEquals(false,
            WebhookSignatureVerifier.constantTimeEquals(null, 'abc'));
    }
}

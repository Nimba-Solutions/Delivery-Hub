/**
 * @name         Delivery Hub · Integration Framework
 * @license      BSL 1.1 — See LICENSE.md
 * @description Tests for SlackWebhookProvider using HttpCalloutMock pattern.
 *              Mock URL = test://slack — Test.setMock intercepts before any
 *              real network call. Covers:
 *                - Successful 200 response
 *                - 400 Slack validation error → terminal
 *                - 503 Slack outage → retryable
 *                - Missing 'text' key → terminal (no callout made)
 *                - Missing Named Credential → terminal (no callout made)
 *                - CalloutException → retryable
 *                - validateConnection paths
 *
 * @author       Cloud Nimbus LLC
 * @since        2026-04-26
 */
@IsTest
@SuppressWarnings('PMD.ApexDoc')
private class SlackWebhookProviderTest {

    /**
     * @description Configurable HTTP mock — return any status code/body for
     *              the test scenario. The Slack incoming-webhook spec is well
     *              documented (https://api.slack.com/messaging/webhooks), so
     *              this mock matches the real shape.
     */
    public class SlackMock implements HttpCalloutMock {
        public Integer statusCode;
        public String responseBody;
        public Boolean throwException = false;

        public HttpResponse respond(HttpRequest req) {
            if (this.throwException) {
                throw new CalloutException('mock callout exception');
            }
            HttpResponse res = new HttpResponse();
            res.setStatusCode(this.statusCode);
            res.setBody(this.responseBody == null ? '' : this.responseBody);
            return res;
        }
    }

    private static IntegrationProvider__mdt testConfig() {
        IntegrationProvider__mdt cfg = new IntegrationProvider__mdt();
        cfg.DeveloperName = 'Test_Slack';
        cfg.ApexClassNameTxt__c = 'SlackWebhookProvider';
        cfg.NamedCredentialDevNameTxt__c = 'TestSlackNC';
        cfg.TypePk__c = 'Sink';
        cfg.EnabledDateTime__c = Datetime.now();
        return cfg;
    }

    /**
     * @description Happy path: 200 response → Sent.
     */
    @IsTest
    static void sendSuccessReturnsSent() {
        SlackMock mock = new SlackMock();
        mock.statusCode = 200;
        mock.responseBody = 'ok';
        Test.setMock(HttpCalloutMock.class, mock);

        SlackWebhookProvider p = new SlackWebhookProvider();
        Test.startTest();
        IntegrationSinkResult r = p.send(new Map<String, Object>{ 'text' => 'hello' }, testConfig());
        Test.stopTest();

        System.assertEquals('Sent', r.statusCode, 'expected Sent');
    }

    /**
     * @description 400 from Slack (e.g. invalid_payload) → terminal failure.
     *              Don't retry; the payload is the problem.
     */
    @IsTest
    static void send400ReturnsTerminal() {
        SlackMock mock = new SlackMock();
        mock.statusCode = 400;
        mock.responseBody = 'invalid_payload';
        Test.setMock(HttpCalloutMock.class, mock);

        SlackWebhookProvider p = new SlackWebhookProvider();
        Test.startTest();
        IntegrationSinkResult r = p.send(new Map<String, Object>{ 'text' => 'hi' }, testConfig());
        Test.stopTest();

        System.assertEquals('TerminalFailure', r.statusCode, 'expected TerminalFailure');
        System.assert(r.statusMessage.contains('400'), 'should mention HTTP code');
    }

    /**
     * @description 503 from Slack (outage) → retryable. Backoff handles it.
     */
    @IsTest
    static void send503ReturnsRetryable() {
        SlackMock mock = new SlackMock();
        mock.statusCode = 503;
        mock.responseBody = 'slack outage';
        Test.setMock(HttpCalloutMock.class, mock);

        SlackWebhookProvider p = new SlackWebhookProvider();
        Test.startTest();
        IntegrationSinkResult r = p.send(new Map<String, Object>{ 'text' => 'hi' }, testConfig());
        Test.stopTest();

        System.assertEquals('RetryableFailure', r.statusCode, 'expected RetryableFailure');
    }

    /**
     * @description Missing 'text' key → terminal failure, NO callout attempted.
     *              Don't waste an outbound call on a known-bad payload.
     */
    @IsTest
    static void sendMissingTextReturnsTerminalNoCallout() {
        // No mock set — would throw if a callout were attempted.
        SlackWebhookProvider p = new SlackWebhookProvider();
        IntegrationSinkResult r = p.send(new Map<String, Object>{ 'wrong' => 'key' }, testConfig());

        System.assertEquals('TerminalFailure', r.statusCode);
        System.assert(r.statusMessage.contains('text'), 'message should reference the missing key');
    }

    /**
     * @description Missing Named Credential → terminal, NO callout.
     */
    @IsTest
    static void sendMissingNamedCredentialReturnsTerminalNoCallout() {
        IntegrationProvider__mdt cfg = testConfig();
        cfg.NamedCredentialDevNameTxt__c = null;

        SlackWebhookProvider p = new SlackWebhookProvider();
        IntegrationSinkResult r = p.send(new Map<String, Object>{ 'text' => 'hi' }, cfg);

        System.assertEquals('TerminalFailure', r.statusCode);
        System.assert(r.statusMessage.contains('Named Credential'), 'message should reference NC');
    }

    /**
     * @description CalloutException (network unreachable) → retryable.
     */
    @IsTest
    static void sendCalloutExceptionReturnsRetryable() {
        SlackMock mock = new SlackMock();
        mock.throwException = true;
        Test.setMock(HttpCalloutMock.class, mock);

        SlackWebhookProvider p = new SlackWebhookProvider();
        Test.startTest();
        IntegrationSinkResult r = p.send(new Map<String, Object>{ 'text' => 'hi' }, testConfig());
        Test.stopTest();

        System.assertEquals('RetryableFailure', r.statusCode);
    }

    /**
     * @description validateConnection: 200 from Slack → live.
     */
    @IsTest
    static void validateConnection200ReturnsTrue() {
        SlackMock mock = new SlackMock();
        mock.statusCode = 200;
        Test.setMock(HttpCalloutMock.class, mock);

        SlackWebhookProvider p = new SlackWebhookProvider();
        Test.startTest();
        Boolean ok = p.validateConnection(testConfig());
        Test.stopTest();
        System.assertEquals(true, ok);
    }

    /**
     * @description validateConnection: 400 → still live (Slack rejected empty
     *              body but the URL routed). Counts as healthy.
     */
    @IsTest
    static void validateConnection400ReturnsTrue() {
        SlackMock mock = new SlackMock();
        mock.statusCode = 400;
        Test.setMock(HttpCalloutMock.class, mock);

        SlackWebhookProvider p = new SlackWebhookProvider();
        Test.startTest();
        Boolean ok = p.validateConnection(testConfig());
        Test.stopTest();
        System.assertEquals(true, ok, '400 from Slack indicates live URL');
    }

    /**
     * @description validateConnection: 404 → URL is dead.
     */
    @IsTest
    static void validateConnection404ReturnsFalse() {
        SlackMock mock = new SlackMock();
        mock.statusCode = 404;
        Test.setMock(HttpCalloutMock.class, mock);

        SlackWebhookProvider p = new SlackWebhookProvider();
        Test.startTest();
        Boolean ok = p.validateConnection(testConfig());
        Test.stopTest();
        System.assertEquals(false, ok);
    }

    /**
     * @description validateConnection with no NC → false, no callout.
     */
    @IsTest
    static void validateConnectionMissingNCReturnsFalseNoCallout() {
        IntegrationProvider__mdt cfg = testConfig();
        cfg.NamedCredentialDevNameTxt__c = null;

        SlackWebhookProvider p = new SlackWebhookProvider();
        Boolean ok = p.validateConnection(cfg);
        System.assertEquals(false, ok);
    }
}

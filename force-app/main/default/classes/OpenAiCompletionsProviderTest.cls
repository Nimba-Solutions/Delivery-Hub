/**
 * @name         Delivery Hub · Integration Framework
 * @license      BSL 1.1 — See LICENSE.md
 * @description Tests for OpenAiCompletionsProvider using HttpCalloutMock.
 *              Covers success path with parsed completion content, 4xx → terminal,
 *              5xx → retryable, missing payload key, missing Named Credential,
 *              CalloutException, validateConnection variations.
 *
 * @author       Cloud Nimbus LLC
 * @since        2026-04-26
 */
@IsTest
@SuppressWarnings('PMD.ApexDoc')
private class OpenAiCompletionsProviderTest {

    public class OpenAiMock implements HttpCalloutMock {
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
        cfg.DeveloperName = 'Test_OpenAI';
        cfg.ApexClassNameTxt__c = 'OpenAiCompletionsProvider';
        cfg.NamedCredentialDevNameTxt__c = 'TestOpenAiNC';
        cfg.EndpointPathTxt__c = '/v1/chat/completions';
        cfg.TypePk__c = 'Sink';
        cfg.EnabledDateTime__c = Datetime.now();
        return cfg;
    }

    private static String successBody() {
        return '{"choices":[{"message":{"role":"assistant","content":"hello world"}}]}';
    }

    @IsTest
    static void sendSuccessReturnsSentWithContent() {
        OpenAiMock mock = new OpenAiMock();
        mock.statusCode = 200;
        mock.responseBody = successBody();
        Test.setMock(HttpCalloutMock.class, mock);

        OpenAiCompletionsProvider p = new OpenAiCompletionsProvider();
        Test.startTest();
        IntegrationSinkResult r = p.send(
            new Map<String, Object>{ 'prompt' => 'say hello' }, testConfig());
        Test.stopTest();

        System.assertEquals('Sent', r.statusCode);
        System.assertEquals('hello world', r.responseBodySnippet);
    }

    @IsTest
    static void send400ReturnsTerminal() {
        OpenAiMock mock = new OpenAiMock();
        mock.statusCode = 400;
        mock.responseBody = '{"error":{"message":"bad model"}}';
        Test.setMock(HttpCalloutMock.class, mock);

        OpenAiCompletionsProvider p = new OpenAiCompletionsProvider();
        Test.startTest();
        IntegrationSinkResult r = p.send(
            new Map<String, Object>{ 'prompt' => 'x' }, testConfig());
        Test.stopTest();

        System.assertEquals('TerminalFailure', r.statusCode);
    }

    @IsTest
    static void send503ReturnsRetryable() {
        OpenAiMock mock = new OpenAiMock();
        mock.statusCode = 503;
        Test.setMock(HttpCalloutMock.class, mock);

        OpenAiCompletionsProvider p = new OpenAiCompletionsProvider();
        Test.startTest();
        IntegrationSinkResult r = p.send(
            new Map<String, Object>{ 'prompt' => 'x' }, testConfig());
        Test.stopTest();

        System.assertEquals('RetryableFailure', r.statusCode);
    }

    @IsTest
    static void sendMissingPromptReturnsTerminalNoCallout() {
        OpenAiCompletionsProvider p = new OpenAiCompletionsProvider();
        IntegrationSinkResult r = p.send(
            new Map<String, Object>{ 'model' => 'gpt-3.5-turbo' }, testConfig());
        System.assertEquals('TerminalFailure', r.statusCode);
        System.assert(r.statusMessage.contains('prompt'),
            'message should reference missing prompt key');
    }

    @IsTest
    static void sendMissingNamedCredentialReturnsTerminal() {
        IntegrationProvider__mdt cfg = testConfig();
        cfg.NamedCredentialDevNameTxt__c = null;

        OpenAiCompletionsProvider p = new OpenAiCompletionsProvider();
        IntegrationSinkResult r = p.send(
            new Map<String, Object>{ 'prompt' => 'x' }, cfg);
        System.assertEquals('TerminalFailure', r.statusCode);
    }

    @IsTest
    static void sendCalloutExceptionReturnsRetryable() {
        OpenAiMock mock = new OpenAiMock();
        mock.throwException = true;
        Test.setMock(HttpCalloutMock.class, mock);

        OpenAiCompletionsProvider p = new OpenAiCompletionsProvider();
        Test.startTest();
        IntegrationSinkResult r = p.send(
            new Map<String, Object>{ 'prompt' => 'x' }, testConfig());
        Test.stopTest();

        System.assertEquals('RetryableFailure', r.statusCode);
    }

    @IsTest
    static void sendEmptyChoicesReturnsRetryable() {
        OpenAiMock mock = new OpenAiMock();
        mock.statusCode = 200;
        mock.responseBody = '{"choices":[]}';
        Test.setMock(HttpCalloutMock.class, mock);

        OpenAiCompletionsProvider p = new OpenAiCompletionsProvider();
        Test.startTest();
        IntegrationSinkResult r = p.send(
            new Map<String, Object>{ 'prompt' => 'x' }, testConfig());
        Test.stopTest();

        System.assertEquals('RetryableFailure', r.statusCode);
    }

    @IsTest
    static void sendMalformedBodyReturnsRetryable() {
        OpenAiMock mock = new OpenAiMock();
        mock.statusCode = 200;
        mock.responseBody = 'not-json';
        Test.setMock(HttpCalloutMock.class, mock);

        OpenAiCompletionsProvider p = new OpenAiCompletionsProvider();
        Test.startTest();
        IntegrationSinkResult r = p.send(
            new Map<String, Object>{ 'prompt' => 'x' }, testConfig());
        Test.stopTest();

        System.assertEquals('RetryableFailure', r.statusCode);
    }

    @IsTest
    static void sendAcceptsAllOptionalParams() {
        OpenAiMock mock = new OpenAiMock();
        mock.statusCode = 200;
        mock.responseBody = successBody();
        Test.setMock(HttpCalloutMock.class, mock);

        OpenAiCompletionsProvider p = new OpenAiCompletionsProvider();
        Test.startTest();
        IntegrationSinkResult r = p.send(new Map<String, Object>{
            'prompt'      => 'x',
            'model'       => 'gpt-4o',
            'maxTokens'   => 100,
            'temperature' => 0.2
        }, testConfig());
        Test.stopTest();

        System.assertEquals('Sent', r.statusCode);
    }

    @IsTest
    static void validateConnection200ReturnsTrue() {
        OpenAiMock mock = new OpenAiMock();
        mock.statusCode = 200;
        Test.setMock(HttpCalloutMock.class, mock);

        OpenAiCompletionsProvider p = new OpenAiCompletionsProvider();
        Test.startTest();
        Boolean ok = p.validateConnection(testConfig());
        Test.stopTest();
        System.assertEquals(true, ok);
    }

    @IsTest
    static void validateConnection401ReturnsTrue() {
        // 401 = bad creds but endpoint live. Counts as healthy connection.
        OpenAiMock mock = new OpenAiMock();
        mock.statusCode = 401;
        Test.setMock(HttpCalloutMock.class, mock);

        OpenAiCompletionsProvider p = new OpenAiCompletionsProvider();
        Test.startTest();
        Boolean ok = p.validateConnection(testConfig());
        Test.stopTest();
        System.assertEquals(true, ok);
    }

    @IsTest
    static void validateConnection500ReturnsFalse() {
        OpenAiMock mock = new OpenAiMock();
        mock.statusCode = 500;
        Test.setMock(HttpCalloutMock.class, mock);

        OpenAiCompletionsProvider p = new OpenAiCompletionsProvider();
        Test.startTest();
        Boolean ok = p.validateConnection(testConfig());
        Test.stopTest();
        System.assertEquals(false, ok);
    }

    @IsTest
    static void validateConnectionMissingNCReturnsFalseNoCallout() {
        IntegrationProvider__mdt cfg = testConfig();
        cfg.NamedCredentialDevNameTxt__c = null;

        OpenAiCompletionsProvider p = new OpenAiCompletionsProvider();
        Boolean ok = p.validateConnection(cfg);
        System.assertEquals(false, ok);
    }
}

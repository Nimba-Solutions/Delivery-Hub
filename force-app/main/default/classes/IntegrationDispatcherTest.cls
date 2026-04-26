/**
 * @name         Delivery Hub · Integration Framework
 * @license      BSL 1.1 — See LICENSE.md
 * @description Tests for IntegrationDispatcher · resolution, validation,
 *              request building, header merge, extension resolution.
 *              CMT records cannot be inserted in tests; tests focus on the
 *              public API + private helpers via @TestVisible.
 * @author       Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.ApexDoc')
@IsTest
private class IntegrationDispatcherTest {

    public class StubExtension implements IIntegrationTemplateExtension {
        public Boolean called = false;
        public void applyTo(HttpRequest req, Map<String, Object> payload, IntegrationProvider__mdt cfg) {
            this.called = true;
            req.setHeader('X-Stub-Applied', 'true');
        }
    }

    private static IntegrationProvider__mdt baseCfg() {
        IntegrationProvider__mdt cfg = new IntegrationProvider__mdt();
        cfg.DeveloperName = 'Test_Provider';
        cfg.NamedCredentialDevNameTxt__c = 'Test_NC';
        cfg.HttpMethodPk__c = 'POST';
        cfg.EndpointPathTxt__c = '/v1/items';
        cfg.RequestBodyTemplateTxt__c = '{"text":"{{message}}"}';
        cfg.HeadersJsonTxt__c = null;
        cfg.ResponseRulesJsonTxt__c = null;
        cfg.SuccessParseExprTxt__c = null;
        cfg.SignerExtensionTxt__c = null;
        cfg.EnabledDateTime__c = Datetime.now();
        return cfg;
    }

    @IsTest
    static void sendBlankNameReturnsTerminal() {
        IntegrationDispatcherResult r = IntegrationDispatcher.send('', new Map<String, Object>());
        System.assertEquals('TerminalFailure', r.statusCode);
    }

    @IsTest
    static void sendUnknownProviderReturnsTerminal() {
        IntegrationDispatcherResult r = IntegrationDispatcher.send(
            'Nonexistent_Provider_99999', new Map<String, Object>());
        System.assertEquals('TerminalFailure', r.statusCode);
        System.assert(r.statusMessage.contains('No IntegrationProvider__mdt found'));
    }

    @IsTest
    static void buildRequestRendersTemplateAndPath() {
        IntegrationProvider__mdt cfg = baseCfg();
        cfg.EndpointPathTxt__c = '/v1/projects/{{projectId}}/items';
        HttpRequest req = IntegrationDispatcher.buildRequest(
            cfg, new Map<String, Object>{
                'projectId' => 'p99',
                'message' => 'hi'
            });
        System.assertEquals('callout:Test_NC/v1/projects/p99/items', req.getEndpoint());
        System.assertEquals('POST', req.getMethod());
        System.assertEquals('{"text":"hi"}', req.getBody());
    }

    @IsTest
    static void buildRequestMissingNCThrows() {
        IntegrationProvider__mdt cfg = baseCfg();
        cfg.NamedCredentialDevNameTxt__c = null;
        Boolean threw = false;
        try {
            IntegrationDispatcher.buildRequest(cfg, new Map<String, Object>());
        } catch (IntegrationDispatcher.IntegrationDispatcherException e) {
            threw = true;
        }
        System.assertEquals(true, threw);
    }

    @IsTest
    static void buildRequestUsesPostWhenMethodBlank() {
        IntegrationProvider__mdt cfg = baseCfg();
        cfg.HttpMethodPk__c = null;
        HttpRequest req = IntegrationDispatcher.buildRequest(cfg, new Map<String, Object>());
        System.assertEquals('POST', req.getMethod());
    }

    @IsTest
    static void buildRequestSkipsBodyWhenTemplateBlank() {
        IntegrationProvider__mdt cfg = baseCfg();
        cfg.RequestBodyTemplateTxt__c = null;
        HttpRequest req = IntegrationDispatcher.buildRequest(cfg, new Map<String, Object>());
        System.assertEquals(null, req.getBody());
    }

    @IsTest
    static void applyHeadersMergesCustomHeaders() {
        IntegrationProvider__mdt cfg = baseCfg();
        cfg.HeadersJsonTxt__c = '{"X-Api-Version":"2024-01","X-Client":"DH"}';
        HttpRequest req = new HttpRequest();
        IntegrationDispatcher.applyHeaders(req, cfg);
        System.assertEquals('application/json', req.getHeader('Content-Type'));
        System.assertEquals('application/json', req.getHeader('Accept'));
        System.assertEquals('2024-01', req.getHeader('X-Api-Version'));
        System.assertEquals('DH', req.getHeader('X-Client'));
    }

    @IsTest
    static void applyHeadersIgnoresMalformedJson() {
        IntegrationProvider__mdt cfg = baseCfg();
        cfg.HeadersJsonTxt__c = 'this is not json';
        HttpRequest req = new HttpRequest();
        IntegrationDispatcher.applyHeaders(req, cfg);
        // Defaults still applied
        System.assertEquals('application/json', req.getHeader('Content-Type'));
    }

    @IsTest
    static void applyHeadersOverridesContentType() {
        IntegrationProvider__mdt cfg = baseCfg();
        cfg.HeadersJsonTxt__c = '{"Content-Type":"text/plain"}';
        HttpRequest req = new HttpRequest();
        IntegrationDispatcher.applyHeaders(req, cfg);
        System.assertEquals('text/plain', req.getHeader('Content-Type'));
    }

    @IsTest
    static void applyExtensionResolvesAndCallsClass() {
        IntegrationProvider__mdt cfg = baseCfg();
        cfg.SignerExtensionTxt__c = 'IntegrationDispatcherTest.StubExtension';
        HttpRequest req = new HttpRequest();
        IntegrationDispatcher.applyExtension(cfg, req, new Map<String, Object>());
        System.assertEquals('true', req.getHeader('X-Stub-Applied'),
            'extension should have run and set its marker header');
    }

    @IsTest
    static void applyExtensionUnknownClassThrows() {
        IntegrationProvider__mdt cfg = baseCfg();
        cfg.SignerExtensionTxt__c = 'NonexistentClass_99999';
        HttpRequest req = new HttpRequest();
        Boolean threw = false;
        try {
            IntegrationDispatcher.applyExtension(cfg, req, new Map<String, Object>());
        } catch (IntegrationDispatcher.IntegrationDispatcherException e) {
            threw = true;
        }
        System.assertEquals(true, threw);
    }

    @IsTest
    static void applyExtensionWrongInterfaceThrows() {
        IntegrationProvider__mdt cfg = baseCfg();
        // Reference a class that doesn't implement the interface
        cfg.SignerExtensionTxt__c = 'IntegrationDispatcherTest';
        HttpRequest req = new HttpRequest();
        Boolean threw = false;
        try {
            IntegrationDispatcher.applyExtension(cfg, req, new Map<String, Object>());
        } catch (IntegrationDispatcher.IntegrationDispatcherException e) {
            threw = true;
        }
        System.assertEquals(true, threw);
    }

    @IsTest
    static void applyExtensionBlankIsNoop() {
        IntegrationProvider__mdt cfg = baseCfg();
        cfg.SignerExtensionTxt__c = null;
        HttpRequest req = new HttpRequest();
        IntegrationDispatcher.applyExtension(cfg, req, new Map<String, Object>());
        System.assertEquals(null, req.getHeader('X-Stub-Applied'));
    }

    @IsTest
    static void resolveProviderUnknownThrows() {
        Boolean threw = false;
        try {
            IntegrationDispatcher.resolveProvider('Definitely_Missing_99999');
        } catch (IntegrationDispatcher.IntegrationDispatcherException e) {
            threw = true;
        }
        System.assertEquals(true, threw);
    }
}

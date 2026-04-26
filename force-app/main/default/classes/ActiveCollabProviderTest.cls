/**
 * @name         Delivery Hub · Integration Framework
 * @license      BSL 1.1 — See LICENSE.md
 * @description Tests for ActiveCollabProvider scaffold. Validates the provider
 *              is framework-compliant (implements both interfaces, returns
 *              structured results) without requiring real AC API.
 *
 *              When the provider gets a real implementation post-Danny
 *              hand-off, these tests evolve to mock AC's API via
 *              HttpCalloutMock with realistic response bodies.
 *
 * @author       Cloud Nimbus LLC
 * @since        2026-04-26
 */
@IsTest
private class ActiveCollabProviderTest {

    private static IntegrationProvider__mdt configWithoutNC() {
        IntegrationProvider__mdt cfg = new IntegrationProvider__mdt();
        cfg.DeveloperName = 'Test_AC';
        cfg.ApexClassNameTxt__c = 'ActiveCollabProvider';
        cfg.NamedCredentialDevNameTxt__c = null;
        cfg.TypePk__c = 'Bidirectional';
        cfg.EnabledDateTime__c = Datetime.now();
        return cfg;
    }

    private static IntegrationProvider__mdt configWithNC() {
        IntegrationProvider__mdt cfg = configWithoutNC();
        cfg.NamedCredentialDevNameTxt__c = 'TestAcNC';
        return cfg;
    }

    @IsTest
    static void send_withoutNC_returnsTerminal() {
        ActiveCollabProvider p = new ActiveCollabProvider();
        IntegrationSinkResult r = p.send(new Map<String, Object>{ 'hours' => 1 }, configWithoutNC());
        System.assertEquals('TerminalFailure', r.statusCode);
        System.assert(r.statusMessage.contains('Named Credential'));
    }

    @IsTest
    static void send_nullPayload_returnsTerminal() {
        ActiveCollabProvider p = new ActiveCollabProvider();
        IntegrationSinkResult r = p.send(null, configWithoutNC());
        System.assertEquals('TerminalFailure', r.statusCode);
    }

    @IsTest
    static void send_scaffoldStub_returnsTerminalWithExplanation() {
        ActiveCollabProvider p = new ActiveCollabProvider();
        IntegrationSinkResult r = p.send(
            new Map<String, Object>{ 'hours' => 2 }, configWithNC());
        System.assertEquals('TerminalFailure', r.statusCode);
        System.assert(r.statusMessage.contains('not yet implemented'),
            'scaffold should self-identify as pending impl');
    }

    @IsTest
    static void fetch_withoutNC_returnsRetryable() {
        ActiveCollabProvider p = new ActiveCollabProvider();
        IntegrationPullResult r = p.fetch(null, configWithoutNC());
        System.assertEquals('RetryableFailure', r.statusCode);
    }

    @IsTest
    static void fetch_withNC_returnsNoNewData() {
        ActiveCollabProvider p = new ActiveCollabProvider();
        IntegrationPullResult r = p.fetch(null, configWithNC());
        System.assertEquals('NoNewData', r.statusCode);
        System.assertEquals(0, r.records.size());
    }

    @IsTest
    static void acceptWebhook_returnsAcknowledged() {
        ActiveCollabProvider p = new ActiveCollabProvider();
        IntegrationWebhookResult r = p.acceptWebhook(
            new Map<String, String>(),
            '{"event":"time-entry.created"}',
            configWithNC()
        );
        System.assertEquals(200, r.responseStatusCode);
    }

    @IsTest
    static void validateConnection_alwaysFalseInScaffold() {
        ActiveCollabProvider p = new ActiveCollabProvider();
        System.assertEquals(false, p.validateConnection(configWithNC()));
        System.assertEquals(false, p.validateConnection(configWithoutNC()));
    }

    @IsTest
    static void implementsBothInterfaces() {
        ActiveCollabProvider p = new ActiveCollabProvider();
        System.assert(p instanceof IIntegrationSink, 'must implement Sink');
        System.assert(p instanceof IIntegrationSource, 'must implement Source');
    }
}

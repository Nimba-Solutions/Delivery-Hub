/**
 * @name         Delivery Hub · Integration Framework
 * @license      BSL 1.1 — See LICENSE.md
 * @description Tests for QuickBooksProvider scaffold. Validates framework
 *              compliance (interface implementation, structured returns).
 *              When real impl lands, these tests evolve to mock QB API
 *              with realistic response bodies and OAuth2 token refresh.
 *
 * @author       Cloud Nimbus LLC
 * @since        2026-04-26
 */
@IsTest
@SuppressWarnings('PMD.ApexDoc')
private class QuickBooksProviderTest {

    private static IntegrationProvider__mdt configWithoutNC() {
        IntegrationProvider__mdt cfg = new IntegrationProvider__mdt();
        cfg.DeveloperName = 'Test_QB';
        cfg.ApexClassNameTxt__c = 'QuickBooksProvider';
        cfg.NamedCredentialDevNameTxt__c = null;
        cfg.TypePk__c = 'Sink';
        cfg.EnabledDateTime__c = Datetime.now();
        return cfg;
    }

    private static IntegrationProvider__mdt configWithNC() {
        IntegrationProvider__mdt cfg = configWithoutNC();
        cfg.NamedCredentialDevNameTxt__c = 'TestQbNC';
        return cfg;
    }

    @IsTest
    static void sendMissingOperationReturnsTerminal() {
        QuickBooksProvider p = new QuickBooksProvider();
        IntegrationSinkResult r = p.send(
            new Map<String, Object>{ 'amount' => 100 }, configWithNC());
        System.assertEquals('TerminalFailure', r.statusCode);
        System.assert(r.statusMessage.contains('operation'));
    }

    @IsTest
    static void sendNullPayloadReturnsTerminal() {
        QuickBooksProvider p = new QuickBooksProvider();
        IntegrationSinkResult r = p.send(null, configWithNC());
        System.assertEquals('TerminalFailure', r.statusCode);
    }

    @IsTest
    static void sendMissingNCReturnsTerminalWithOAuthHint() {
        QuickBooksProvider p = new QuickBooksProvider();
        IntegrationSinkResult r = p.send(
            new Map<String, Object>{ 'operation' => 'CreateJournalEntry' },
            configWithoutNC()
        );
        System.assertEquals('TerminalFailure', r.statusCode);
        System.assert(r.statusMessage.contains('OAuth'),
            'should hint at OAuth2 / External Credential setup');
    }

    @IsTest
    static void sendScaffoldStubReturnsTerminalWithMigrationHint() {
        QuickBooksProvider p = new QuickBooksProvider();
        IntegrationSinkResult r = p.send(
            new Map<String, Object>{ 'operation' => 'CreateInvoice' },
            configWithNC()
        );
        System.assertEquals('TerminalFailure', r.statusCode);
        System.assert(r.statusMessage.contains('scaffold'),
            'scaffold stub should self-identify');
        System.assert(r.statusMessage.contains('CreateInvoice'),
            'should echo the requested operation');
    }

    @IsTest
    static void validateConnectionAlwaysFalseInScaffold() {
        QuickBooksProvider p = new QuickBooksProvider();
        System.assertEquals(false, p.validateConnection(configWithNC()));
        System.assertEquals(false, p.validateConnection(configWithoutNC()));
    }

    @IsTest
    static void implementsSinkInterface() {
        QuickBooksProvider p = new QuickBooksProvider();
        System.assert(p instanceof IIntegrationSink);
    }
}

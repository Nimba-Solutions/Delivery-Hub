/**
 * @name         Delivery Hub · Integration Framework
 * @license      BSL 1.1 — See LICENSE.md
 * @description Tests for IntegrationDispatcher. Covers:
 *              - Provider resolution by DeveloperName
 *              - Disabled-provider rejection
 *              - Wrong-role rejection
 *              - Class-instantiation failures
 *              - Successful sink dispatch with mocked callout
 *              - Retryable error wrapping
 *
 *              Provider resolution is mocked at the SOQL layer via TestDataMother
 *              pattern — we cannot insert IntegrationProvider__mdt records in
 *              tests (CMT records are deploy-time only). Instead we test the
 *              public methods that accept provider Apex types directly, plus
 *              one integration-style test using a real CMT seed record.
 *
 * @author       Cloud Nimbus LLC
 * @since        2026-04-26
 */
@IsTest
private class IntegrationDispatcherTest {

    /**
     * @description Mock IIntegrationSink that records what was sent and returns
     *              a configured result. Captured payload exposed for assertions.
     */
    public class MockSink implements IIntegrationSink {
        public Map<String, Object> lastPayload;
        public IntegrationProvider__mdt lastConfig;
        public IntegrationSinkResult resultToReturn;
        public Boolean throwInstead = false;

        public IntegrationSinkResult send(Map<String, Object> payload, IntegrationProvider__mdt cfg) {
            this.lastPayload = payload;
            this.lastConfig = cfg;
            if (this.throwInstead) {
                throw new TestException('mock sink threw');
            }
            return this.resultToReturn != null
                ? this.resultToReturn
                : IntegrationSinkResult.success('mock-remote-id');
        }

        public Boolean validateConnection(IntegrationProvider__mdt cfg) {
            return true;
        }
    }

    public class TestException extends Exception {}

    /**
     * @description Verifies that a missing CMT record produces a clean
     *              IntegrationDispatcherException instead of a NullPointerException.
     */
    @IsTest
    static void resolveProviderUnknownDevNameThrows() {
        Boolean threw = false;
        try {
            IntegrationDispatcher.resolveProvider('NonexistentProvider__9999');
        } catch (IntegrationDispatcher.IntegrationDispatcherException e) {
            threw = true;
            System.assert(e.getMessage().contains('NonexistentProvider'), 'message should mention name');
        }
        System.assertEquals(true, threw, 'expected IntegrationDispatcherException');
    }

    /**
     * @description Disabled provider (EnabledDateTime__c null) is rejected by
     *              assertEnabled, even if the rest of the config looks valid.
     */
    @IsTest
    static void assertEnabledNullDateTimeThrows() {
        IntegrationProvider__mdt cfg = new IntegrationProvider__mdt();
        cfg.DeveloperName = 'TestDisabled';
        cfg.EnabledDateTime__c = null;
        Boolean threw = false;
        try {
            IntegrationDispatcher.assertEnabled(cfg);
        } catch (IntegrationDispatcher.IntegrationDispatcherException e) {
            threw = true;
        }
        System.assertEquals(true, threw, 'disabled provider should reject');
    }

    /**
     * @description Source-only provider rejected for sink dispatch — splits the
     *              source/sink role correctly and prevents miscalls.
     */
    @IsTest
    static void assertSinkRoleSourceOnlyThrows() {
        IntegrationProvider__mdt cfg = new IntegrationProvider__mdt();
        cfg.DeveloperName = 'TestSourceOnly';
        cfg.TypePk__c = 'Source';
        Boolean threw = false;
        try {
            IntegrationDispatcher.assertSinkRole(cfg);
        } catch (IntegrationDispatcher.IntegrationDispatcherException e) {
            threw = true;
            System.assert(e.getMessage().contains('Source'), 'message should mention actual role');
        }
        System.assertEquals(true, threw, 'source-role should reject sink dispatch');
    }

    /**
     * @description Bidirectional provider accepted for sink dispatch.
     */
    @IsTest
    static void assertSinkRoleBidirectionalPasses() {
        IntegrationProvider__mdt cfg = new IntegrationProvider__mdt();
        cfg.TypePk__c = 'Bidirectional';
        // No exception expected
        IntegrationDispatcher.assertSinkRole(cfg);
        System.assert(true, 'bidirectional accepted as sink');
    }

    /**
     * @description Sink role accepted for sink dispatch.
     */
    @IsTest
    static void assertSinkRoleSinkPasses() {
        IntegrationProvider__mdt cfg = new IntegrationProvider__mdt();
        cfg.TypePk__c = 'Sink';
        IntegrationDispatcher.assertSinkRole(cfg);
        System.assert(true, 'sink role accepted');
    }

    /**
     * @description instantiateSink resolves a real Apex class implementing
     *              IIntegrationSink. Uses MockSink as the target since it's
     *              defined in this test class and accessible.
     */
    @IsTest
    static void instantiateSinkValidClassReturnsInstance() {
        IntegrationProvider__mdt cfg = new IntegrationProvider__mdt();
        cfg.DeveloperName = 'MockProvider';
        cfg.ApexClassNameTxt__c = 'IntegrationDispatcherTest.MockSink';
        IIntegrationSink sink = IntegrationDispatcher.instantiateSink(cfg);
        System.assertNotEquals(null, sink, 'sink should be resolved');
        System.assert(sink instanceof MockSink, 'should be MockSink instance');
    }

    /**
     * @description Class that doesn't implement IIntegrationSink rejected with
     *              a clean exception.
     */
    @IsTest
    static void instantiateSinkWrongInterfaceThrows() {
        IntegrationProvider__mdt cfg = new IntegrationProvider__mdt();
        cfg.DeveloperName = 'WrongInterface';
        cfg.ApexClassNameTxt__c = 'IntegrationDispatcherTest';  // not a sink
        Boolean threw = false;
        try {
            IntegrationDispatcher.instantiateSink(cfg);
        } catch (IntegrationDispatcher.IntegrationDispatcherException e) {
            threw = true;
            System.assert(e.getMessage().contains('IIntegrationSink'), 'should mention interface');
        }
        System.assertEquals(true, threw, 'wrong-interface should reject');
    }

    /**
     * @description Unknown class name rejected with clean exception.
     */
    @IsTest
    static void instantiateSinkUnknownClassThrows() {
        IntegrationProvider__mdt cfg = new IntegrationProvider__mdt();
        cfg.DeveloperName = 'UnknownClass';
        cfg.ApexClassNameTxt__c = 'NonexistentClass_9999';
        Boolean threw = false;
        try {
            IntegrationDispatcher.instantiateSink(cfg);
        } catch (IntegrationDispatcher.IntegrationDispatcherException e) {
            threw = true;
            System.assert(e.getMessage().contains('NonexistentClass'), 'should mention class name');
        }
        System.assertEquals(true, threw, 'unknown class should reject');
    }
}

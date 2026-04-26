/**
 * @name         Delivery Hub · Integration Framework
 * @license      BSL 1.1 — See LICENSE.md
 * @description Dispatches outbound payloads to the right IIntegrationSink based
 *              on declarative IntegrationProvider__mdt config. Handles:
 *                - Provider resolution by DeveloperName
 *                - Apex class instantiation via Type.forName (namespace-aware)
 *                - Enabled-flag check (skips silently if provider disabled)
 *                - Single-call dispatch (callers wrap in their own retry/queue)
 *
 *              EXPLICITLY OUT OF SCOPE for this spike:
 *                - Retry policy execution (will live in IntegrationItem__c
 *                  processor · separate class · separate PR)
 *                - Inbound source pulling (cron + Source provider type)
 *                - Webhook receiver (Apex REST resource · separate PR)
 *                - Field mapping (delegated to provider implementation today;
 *                  IntegrationFieldMap__c custom object arrives in next PR)
 *                - Platform Event seam (IntegrationEvent__e arrives Phase 4)
 *
 *              This is the spike. It proves the registry+dispatch pattern works
 *              against a real refactor (DeliverySlackProvider). Subsequent PRs
 *              add retry, source-side, webhooks, mapping, and PE.
 *
 * @author       Cloud Nimbus LLC
 * @since        2026-04-26
 */
public with sharing class IntegrationDispatcher {

    /** @description Throws when a provider lookup fails — dispatcher's only checked exception. */
    public class IntegrationDispatcherException extends Exception {}

    /**
     * @description Sends a payload to the named provider. Provider must be
     *              configured as Type=Sink or Bidirectional with Enabled set.
     * @param providerDeveloperName DeveloperName of an IntegrationProvider__mdt record.
     * @param payload Provider-shaped payload map.
     * @return IntegrationSinkResult from the provider implementation.
     */
    public static IntegrationSinkResult dispatchSink(String providerDeveloperName, Map<String, Object> payload) {
        if (String.isBlank(providerDeveloperName)) {
            throw new IntegrationDispatcherException('providerDeveloperName is required');
        }
        IntegrationProvider__mdt config = resolveProvider(providerDeveloperName);
        assertEnabled(config);
        assertSinkRole(config);
        IIntegrationSink sink = instantiateSink(config);
        try {
            return sink.send(payload, config);
        } catch (Exception e) {
            // Provider impl threw without producing a structured result — treat
            // as retryable; processor can decide. Don't swallow — surface to caller.
            return IntegrationSinkResult.retryable(
                e.getTypeName() + ': ' + e.getMessage(),
                String.valueOf(e.getStackTraceString()).left(4000)
            );
        }
    }

    /**
     * @description Health-check probe. Used by scheduled "Connection Health"
     *              jobs to detect silent-token-expiry on OAuth integrations.
     * @param providerDeveloperName DeveloperName of the provider to probe.
     * @return Result of the provider's validateConnection() call.
     */
    public static Boolean probeConnection(String providerDeveloperName) {
        IntegrationProvider__mdt config = resolveProvider(providerDeveloperName);
        if (config.EnabledDateTime__c == null) {
            return false;
        }
        IIntegrationSink sink;
        try {
            sink = instantiateSink(config);
        } catch (Exception e) {
            return false;
        }
        try {
            return sink.validateConnection(config);
        } catch (Exception e) {
            return false;
        }
    }

    @TestVisible
    private static IntegrationProvider__mdt resolveProvider(String developerName) {
        List<IntegrationProvider__mdt> hits = [
            SELECT Id, DeveloperName, ApexClassNameTxt__c, NamedCredentialDevNameTxt__c,
                   EndpointPathTxt__c, TypePk__c, EnabledDateTime__c, RetryPolicyJsonTxt__c
            FROM IntegrationProvider__mdt
            WHERE DeveloperName = :developerName
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        if (hits.isEmpty()) {
            throw new IntegrationDispatcherException(
                'No IntegrationProvider__mdt record found for DeveloperName: ' + developerName
            );
        }
        return hits[0];
    }

    @TestVisible
    private static void assertEnabled(IntegrationProvider__mdt config) {
        if (config.EnabledDateTime__c == null) {
            throw new IntegrationDispatcherException(
                'Provider ' + config.DeveloperName + ' is disabled (EnabledDateTime__c is null). Set the field to enable.'
            );
        }
    }

    @TestVisible
    private static void assertSinkRole(IntegrationProvider__mdt config) {
        if (config.TypePk__c != 'Sink' && config.TypePk__c != 'Bidirectional') {
            throw new IntegrationDispatcherException(
                'Provider ' + config.DeveloperName + ' is configured as ' + config.TypePk__c
                + ' — dispatchSink requires Sink or Bidirectional.'
            );
        }
    }

    @TestVisible
    private static IIntegrationSink instantiateSink(IntegrationProvider__mdt config) {
        if (String.isBlank(config.ApexClassNameTxt__c)) {
            throw new IntegrationDispatcherException(
                'Provider ' + config.DeveloperName + ' has no ApexClassNameTxt__c.'
            );
        }
        // Namespace-aware Type.forName per Salesforce platform docs:
        // when ApexClassNameTxt__c contains a dot, we split namespace and class.
        // Otherwise use the local namespace context.
        Type t;
        if (config.ApexClassNameTxt__c.contains('.')) {
            List<String> parts = config.ApexClassNameTxt__c.split('\\.');
            t = Type.forName(parts[0], parts[1]);
        } else {
            t = Type.forName(config.ApexClassNameTxt__c);
        }
        if (t == null) {
            throw new IntegrationDispatcherException(
                'Cannot resolve Apex class: ' + config.ApexClassNameTxt__c
            );
        }
        Object instance = t.newInstance();
        if (!(instance instanceof IIntegrationSink)) {
            throw new IntegrationDispatcherException(
                'Class ' + config.ApexClassNameTxt__c + ' does not implement IIntegrationSink.'
            );
        }
        return (IIntegrationSink) instance;
    }
}

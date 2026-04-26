/**
 * @name         Delivery Hub · Integration Framework
 * @license      BSL 1.1 — See LICENSE.md
 * @description Outbound-only provider interface for the Integration Framework.
 *              Implementations push payload data to an external system. Inbound
 *              providers (pull or webhook) implement IIntegrationSource separately
 *              — splitting them prevents the source/sink-conflation antipattern
 *              that plagues homegrown integration frameworks.
 *
 *              Reference: Kafka Connect's SinkConnector, Camel's Producer.
 *
 *              Each concrete sink is registered via IntegrationProvider__mdt
 *              with TypePk__c = 'Sink' and ApexClassNameTxt__c = '<className>'.
 *              The IntegrationDispatcher resolves and instantiates via
 *              Type.forName(namespace, className).
 *
 * @author       Cloud Nimbus LLC
 * @since        2026-04-26
 */
// global modifier is required: subscriber-namespace Apex classes implement this
// interface and need cross-namespace visibility (per Salesforce managed-package
// platform docs). Public doesn't satisfy that constraint.
@SuppressWarnings('PMD.AvoidGlobalModifier')
global interface IIntegrationSink {

    /**
     * @description Push a single payload to the external system. Implementations
     *              should NOT retry internally — the dispatcher owns retry policy
     *              via IntegrationItem__c.RetryCountNumber__c. Throw on failure;
     *              the dispatcher captures the exception, increments retry count,
     *              and reschedules per the provider's RetryPolicyJson__c.
     * @param payload Provider-shaped payload map. Keys/types are provider-specific
     *                — the dispatcher serializes IntegrationItem__c.PayloadTxt__c
     *                into this Map<String, Object> before invocation.
     * @param providerConfig Resolved IntegrationProvider__mdt record for this sink.
     *                       Implementations read endpoint paths, feature flags,
     *                       transformer hints from here.
     * @return IntegrationSinkResult — capture remote ID, status, response body
     *         summary. Used to update the IntegrationItem__c on success.
     */
    IntegrationSinkResult send(Map<String, Object> payload, IntegrationProvider__mdt providerConfig);

    /**
     * @description Health-check the external connection without side effects.
     *              Used by the framework's scheduled "Connection Health" job
     *              (per Spring '23 External Credentials best practice — refresh
     *              tokens that rotate silently break after 30-90 days; weekly
     *              probe surfaces this before customers hit it).
     * @param providerConfig Resolved provider config.
     * @return true when the connection is usable. False = surface in admin UI;
     *         the dispatcher will mark inflight items as Pending until restored.
     */
    Boolean validateConnection(IntegrationProvider__mdt providerConfig);
}

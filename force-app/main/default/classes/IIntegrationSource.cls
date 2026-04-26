/**
 * @name         Delivery Hub · Integration Framework
 * @license      BSL 1.1 — See LICENSE.md
 * @description Inbound-only provider interface. Two flavors:
 *              - PULL: framework cron invokes fetch(cursor) periodically
 *              - PUSH: external system POSTs to /services/apexrest/integration/v1/webhook/{providerKey},
 *                framework's IntegrationWebhookReceiver routes the body to
 *                acceptWebhook(headers, body) on the matched source.
 *
 *              An adapter MAY implement both interfaces (Active Collab will).
 *              Splitting at the interface level lets a registry expose just the
 *              capabilities each provider supports, and prevents the
 *              source/sink-conflation antipattern.
 *
 *              Reference: Kafka Connect's SourceConnector + push-pull split,
 *              Camel's Consumer with Polling vs EventDriven flavors.
 *
 * @author       Cloud Nimbus LLC
 * @since        2026-04-26
 */
global interface IIntegrationSource {

    /**
     * @description Pull-mode fetch. Framework's hourly cron (or LWC-triggered
     *              manual sync) invokes this with the last-successful cursor.
     *              Implementations return a list of normalized records; the
     *              dispatcher converts each to an IntegrationItem__c (inbound,
     *              status = Pending) and an IntegrationEvent__e Platform Event
     *              that wakes the processor.
     * @param cursor Provider-specific cursor token (timestamp, offset, etc.).
     *               Null on first fetch — implementations should fall back to
     *               their provider's "since" semantics (e.g. last-modified-after-X).
     * @param providerConfig Resolved IntegrationProvider__mdt record.
     * @return IntegrationPullResult — list of records + new cursor + sourceId
     *         pairs for idempotency.
     */
    IntegrationPullResult fetch(String cursor, IntegrationProvider__mdt providerConfig);

    /**
     * @description Push-mode webhook handler. Called by the framework's REST
     *              receiver AFTER HMAC validation, timestamp-skew check, and
     *              nonce de-dupe. Implementations parse provider-specific
     *              payload shape and return normalized record list.
     *
     *              CRITICAL: do not perform DML in this method — it runs in
     *              the REST request context with strict CPU limits. The
     *              framework dispatcher persists the records via Platform Event
     *              + Queueable on a separate transaction.
     *
     * @param headers Pre-validated HTTP headers (signature already verified).
     * @param body Raw request body string.
     * @param providerConfig Resolved provider config.
     * @return IntegrationWebhookResult — list of records + acknowledgment HTTP
     *         status to return to the calling system.
     */
    IntegrationWebhookResult acceptWebhook(Map<String, String> headers, String body, IntegrationProvider__mdt providerConfig);
}

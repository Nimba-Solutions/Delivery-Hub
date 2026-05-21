/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Stub C — Watcher signal that will eventually detect edge
 *              cases the AR-aging signal doesn't cover — payment-in-progress
 *              states (e.g. DeliveryTransaction__c for Stripe webhook,
 *              dispute reasons surfacing, refund windows opening). Cross-
 *              references DeliveryTransaction__c (which already exists)
 *              with invoice status.
 *
 *              Deferred because: Stripe-style transaction object isn't fully
 *              wired across all orgs yet (per memory the CN portal side is
 *              mid-build).
 *
 *              v1 shim: empty class + EnableWatcherPaymentOpsDateTime__c
 *              flag. Returns empty SignalResultDTO.
 * @author Cloud Nimbus LLC
 */
public with sharing class WatcherPaymentOpsQueryService {

    /** @description Stable signal identifier surfaced into WatcherDigest__c.SignalCountsTxt__c. */
    public static final String SIGNAL_NAME = 'PaymentOps';

    /**
     * @description Stub implementation. Always returns an empty result.
     *              Real implementation lands once DeliveryTransaction__c
     *              ingest is fully cross-org.
     * @return Empty SignalResultDTO with signalName populated.
     */
    public static SignalResultDTO query() {
        System.debug(LoggingLevel.INFO,
            '[WatcherPaymentOpsQueryService] stub — empty result');
        return SignalResultDTO.emptyResult(SIGNAL_NAME);
    }
}

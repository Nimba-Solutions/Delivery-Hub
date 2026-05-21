/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Stub B — Watcher signal that will eventually detect
 *              DeliveryDocuments in Awaiting_Signatures status whose
 *              RequireSigningDateTime__c is past + signer hasn't viewed
 *              (ViewedDateTime__c=null) in N days; OR WIs entering a stage
 *              that requires signoff per a CMT-defined gate.
 *
 *              Deferred because: the signoff workflow
 *              (DeliveryAdminSigningController etc.) is mid-feature — the
 *              data shape isn't stable yet.
 *
 *              v1 shim: empty class + EnableWatcherSignoffDateTime__c flag.
 *              Returns empty SignalResultDTO.
 * @author Cloud Nimbus LLC
 */
public with sharing class WatcherUpcomingSignoffQueryService {

    /** @description Stable signal identifier surfaced into WatcherDigest__c.SignalCountsTxt__c. */
    public static final String SIGNAL_NAME = 'UpcomingSignoff';

    /**
     * @description Stub implementation. Always returns an empty result.
     *              Real implementation lands after the Awaiting_Signatures /
     *              gated-stage signoff workflow stabilises.
     * @return Empty SignalResultDTO with signalName populated.
     */
    public static SignalResultDTO query() {
        System.debug(LoggingLevel.INFO,
            '[WatcherUpcomingSignoffQueryService] stub — empty result');
        return SignalResultDTO.emptyResult(SIGNAL_NAME);
    }
}

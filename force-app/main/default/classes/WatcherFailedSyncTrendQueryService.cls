/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Stub D — Watcher signal that will eventually detect a
 *              rolling 7-day count of SyncItem__c.StatusPk__c='Failed' rows
 *              that did NOT auto-recover (i.e. survived
 *              FailedSyncAutoDismissDaysNumber__c window or were dismissed
 *              manually) — trended against the prior 7 days. Alerts on
 *              delta, not on Failed count itself (the existing self-healers
 *              handle individual failures fine).
 *
 *              Deferred because: needs 14-21 days of post-Watcher-install
 *              reconciler data to baseline what "normal" failure rate looks
 *              like per org. Without a baseline this is a noise generator.
 *              This is the strongest stub — it pairs with the 14-day Watcher
 *              stabilization gate that already gates Phase 3.
 *
 *              v1 shim: empty class + EnableWatcherSyncTrendDateTime__c
 *              flag. Returns empty SignalResultDTO.
 * @author Cloud Nimbus LLC
 */
public with sharing class WatcherFailedSyncTrendQueryService {

    /** @description Stable signal identifier surfaced into WatcherDigest__c.SignalCountsTxt__c. */
    public static final String SIGNAL_NAME = 'FailedSyncTrend';

    /**
     * @description Stub implementation. Always returns an empty result.
     *              Real implementation lands once Watcher has 14+ days of
     *              baseline data to compute deltas against.
     * @return Empty SignalResultDTO with signalName populated.
     */
    public static SignalResultDTO query() {
        System.debug(LoggingLevel.INFO,
            '[WatcherFailedSyncTrendQueryService] stub — empty result');
        return SignalResultDTO.emptyResult(SIGNAL_NAME);
    }
}

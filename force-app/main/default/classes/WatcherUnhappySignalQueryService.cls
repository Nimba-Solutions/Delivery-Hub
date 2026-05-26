/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Stub A — Watcher signal that will eventually detect WIs whose
 *              sentiment trend on WorkItemComment__c.BodyTxt__c has tipped
 *              negative (frustrated reply patterns, repeated "still broken",
 *              customer escalation language). Likely OpenAI-classified.
 *
 *              Deferred because: requires NLP / signal-design + customer-
 *              language baseline. Easy to get wrong (false-positive flags
 *              Glen ignores → erodes signal-to-noise). Wait until we've
 *              baselined what an "unhappy" comment looks like.
 *
 *              v1 shim: empty class + EnableWatcherUnhappySignalDateTime__c
 *              flag. Returns empty SignalResultDTO so the orchestrator can
 *              merge cleanly without special-casing stubs.
 * @author Cloud Nimbus LLC
 */
public with sharing class WatcherUnhappySignalQueryService {

    /** @description Stable signal identifier surfaced into WatcherDigest__c.SignalCountsTxt__c. */
    public static final String SIGNAL_NAME = 'UnhappySignal';

    /**
     * @description Stub implementation. Always returns an empty result.
     *              Real implementation lands once we have a comment-sentiment
     *              baseline and OpenAI classifier wired.
     * @return Empty SignalResultDTO with signalName populated.
     */
    public static SignalResultDTO query() {
        System.debug(LoggingLevel.INFO,
            '[WatcherUnhappySignalQueryService] stub — empty result');
        return SignalResultDTO.emptyResult(SIGNAL_NAME);
    }
}

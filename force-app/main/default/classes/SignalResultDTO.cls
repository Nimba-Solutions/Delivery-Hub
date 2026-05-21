/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Shared payload returned by every Watcher *QueryService.query()
 *              method. The orchestrator (DeliveryWatcherService) merges these
 *              into a WatcherRunResultDTO and persists a WatcherDigest__c row
 *              + posts to Slack. Held as a top-level class so individual
 *              signal services don't have to import each other's inner types.
 *
 *              All fields are @AuraEnabled — they bubble through the
 *              orchestrator's WatcherRunResultDTO into LWC manual-run UX
 *              that PR-C+ may add.
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.AvoidGlobalModifier')
global virtual class SignalResultDTO {

    /** @description Stable identifier of the signal that produced this result (e.g. 'SLABreach', 'StuckStage'). */
    @AuraEnabled public String signalName;

    /** @description Primary headline count (e.g. Breached WI count for SLA, Stuck WI count for stuck-stage). */
    @AuraEnabled public Integer primaryCount;

    /** @description Secondary count (e.g. AtRisk for SLA). Nullable — signals that have no secondary leave this null. */
    @AuraEnabled public Integer secondaryCount;

    /** @description Up to 5 representative entries for the digest body. May be empty even when counts are non-zero (signal opted out of body lines). */
    @AuraEnabled public List<SignalEntryDTO> topEntries;

    /** @description Populated when the query method threw; the orchestrator captures it into WatcherDigest__c.ErrorMessageTxt__c and downgrades StatusPk__c to Partial. */
    @AuraEnabled public String errorMessage;

    /**
     * @description Default constructor. Initialises topEntries to an empty
     *              list so callers never NPE when iterating.
     */
    global SignalResultDTO() {
        this.primaryCount = 0;
        this.secondaryCount = 0;
        this.topEntries = new List<SignalEntryDTO>();
    }

    /**
     * @description Convenience factory for an empty / no-op result.
     * @param name Stable signal identifier.
     * @return Empty SignalResultDTO with signalName set + counts at 0.
     */
    global static SignalResultDTO emptyResult(String name) {
        SignalResultDTO r = new SignalResultDTO();
        r.signalName = name;
        return r;
    }
}

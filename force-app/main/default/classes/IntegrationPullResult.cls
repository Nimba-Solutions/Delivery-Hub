/**
 * @name         Delivery Hub · Integration Framework
 * @license      BSL 1.1 — See LICENSE.md
 * @description DTO returned by IIntegrationSource.fetch. Carries the list of
 *              records pulled from the external system plus the new cursor
 *              token to use for the NEXT pull. Records are normalized
 *              shapes — provider implementations are responsible for
 *              translating their wire format into these maps. The framework
 *              dispatcher converts each map into an IntegrationItem__c
 *              (inbound) and fires an IntegrationEvent__e Platform Event to
 *              wake the processor (Phase 4).
 *
 * @author       Cloud Nimbus LLC
 * @since        2026-04-26
 */
global class IntegrationPullResult {
    /** @description Records pulled this fetch — each is a provider-shaped
     *  map. Empty list = no new records since cursor (still a success). */
    @AuraEnabled global List<Map<String, Object>> records { get; set; }
    /** @description Updated cursor token for the next fetch (null = use
     *  provider default). Persisted on IntegrationProvider__mdt or a
     *  per-provider state record (TBD Phase 4). */
    @AuraEnabled global String nextCursor { get; set; }
    /** @description Optional ack message (e.g. "fetched 12 records"). */
    @AuraEnabled global String statusMessage { get; set; }
    /** @description Per-call status: Fetched | NoNewData | RetryableFailure | TerminalFailure. */
    @AuraEnabled global String statusCode { get; set; }

    /**
     * @description Constructs a successful fetch result.
     * @param records List of normalized records.
     * @param nextCursor New cursor token to persist.
     * @return Configured IntegrationPullResult with statusCode='Fetched'.
     */
    global static IntegrationPullResult fetched(List<Map<String, Object>> records, String nextCursor) {
        IntegrationPullResult r = new IntegrationPullResult();
        r.records = records == null ? new List<Map<String, Object>>() : records;
        r.nextCursor = nextCursor;
        r.statusCode = 'Fetched';
        return r;
    }

    /**
     * @description Constructs a no-new-data result. Cursor unchanged.
     * @return Configured IntegrationPullResult with statusCode='NoNewData'.
     */
    global static IntegrationPullResult noNewData() {
        IntegrationPullResult r = new IntegrationPullResult();
        r.records = new List<Map<String, Object>>();
        r.statusCode = 'NoNewData';
        return r;
    }

    /**
     * @description Constructs a retryable-failure result.
     * @param message Short error description.
     * @return Configured IntegrationPullResult with statusCode='RetryableFailure'.
     */
    global static IntegrationPullResult retryable(String message) {
        IntegrationPullResult r = new IntegrationPullResult();
        r.records = new List<Map<String, Object>>();
        r.statusCode = 'RetryableFailure';
        r.statusMessage = message;
        return r;
    }
}

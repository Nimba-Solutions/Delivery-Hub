/**
 * @name         Delivery Hub · Integration Framework
 * @license      BSL 1.1 — See LICENSE.md
 * @description DTO returned by IIntegrationSink.send. Captures the outcome of a
 *              single outbound dispatch so the framework can update the
 *              IntegrationItem__c row with remote ID, status, and error context.
 * @author       Cloud Nimbus LLC
 */
// global is required: subscriber-namespace IIntegrationSink implementations
// return / consume this DTO across namespace boundaries.
@SuppressWarnings('PMD.AvoidGlobalModifier')
global class IntegrationSinkResult {
    /** @description Remote system's identifier for the record (idempotency key). */
    @AuraEnabled global String remoteId { get; set; }
    /** @description Per-call status: Sent | PartialSuccess | RetryableFailure | TerminalFailure. */
    @AuraEnabled global String statusCode { get; set; }
    /** @description Short human-readable status (one line, surfaces in admin UI). */
    @AuraEnabled global String statusMessage { get; set; }
    /** @description Truncated response body (max 4000 chars) for diagnostics. */
    @AuraEnabled global String responseBodySnippet { get; set; }
    /** @description When set, dispatcher schedules retry at this time instead of
     *  the default exponential backoff. Honors provider-specified Retry-After. */
    @AuraEnabled global Datetime retryAfter { get; set; }

    /**
     * @description Constructs a successful result. Convenience for the common path.
     * @param remoteId Remote system's identifier.
     * @return Configured IntegrationSinkResult with statusCode='Sent'.
     */
    global static IntegrationSinkResult success(String remoteId) {
        IntegrationSinkResult r = new IntegrationSinkResult();
        r.remoteId = remoteId;
        r.statusCode = 'Sent';
        r.statusMessage = 'OK';
        return r;
    }

    /**
     * @description Constructs a retryable-failure result. Dispatcher will
     *              increment RetryCountNumber__c and schedule next attempt
     *              per the provider's RetryPolicyJson__c.
     * @param message Short error description.
     * @param body Optional response body for diagnostics (truncated).
     * @return Configured IntegrationSinkResult with statusCode='RetryableFailure'.
     */
    global static IntegrationSinkResult retryable(String message, String body) {
        IntegrationSinkResult r = new IntegrationSinkResult();
        r.statusCode = 'RetryableFailure';
        r.statusMessage = message;
        r.responseBodySnippet = body == null ? null : body.left(4000);
        return r;
    }

    /**
     * @description Constructs a terminal-failure result. Dispatcher will move
     *              the IntegrationItem__c to Status='DLQ' and stop retrying.
     *              Use for 4xx client errors that won't succeed on retry
     *              (auth failure, malformed payload, missing remote record).
     * @param message Short error description.
     * @param body Optional response body for diagnostics.
     * @return Configured IntegrationSinkResult with statusCode='TerminalFailure'.
     */
    global static IntegrationSinkResult terminal(String message, String body) {
        IntegrationSinkResult r = new IntegrationSinkResult();
        r.statusCode = 'TerminalFailure';
        r.statusMessage = message;
        r.responseBodySnippet = body == null ? null : body.left(4000);
        return r;
    }
}

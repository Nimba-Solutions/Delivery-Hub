/**
 * @name         Delivery Hub · Integration Framework
 * @license      BSL 1.1 — See LICENSE.md
 * @description Outcome of a single IntegrationDispatcher.send call. Captures
 *              the dispatcher's interpretation of the HTTP response per the
 *              provider's ResponseRulesJsonTxt__c rules.
 *
 *              statusCode values:
 *                - "Sent"             — provider rules matched a success state
 *                - "RetryableFailure" — transient failure (e.g. 5xx, network)
 *                - "TerminalFailure"  — permanent failure (e.g. 4xx, bad config)
 *
 *              Also carries the raw response status + body snippet (truncated
 *              4000 chars) for diagnostics, plus an optional "remoteId" or
 *              "responseValue" extracted via SuccessParseExprTxt__c.
 *
 * @author       Cloud Nimbus LLC
 * @since        2026-04-26
 */
public with sharing class IntegrationDispatcherResult {
    /** @description Dispatcher's interpretation: Sent / RetryableFailure / TerminalFailure. */
    public String statusCode { get; set; }
    /** @description Short human-readable status (one line, surfaces in admin UI / logs). */
    public String statusMessage { get; set; }
    /** @description Raw HTTP status code from the callout (when one was made). */
    public Integer httpStatusCode { get; set; }
    /** @description Truncated response body (4000 chars max) for diagnostics. */
    public String responseBodySnippet { get; set; }
    /** @description Value extracted via SuccessParseExprTxt__c, when configured. */
    public String responseValue { get; set; }

    /**
     * @description Constructs a successful result.
     * @param httpCode The actual HTTP status returned.
     * @param body The response body (will be truncated for snippet).
     * @return Configured result with statusCode='Sent'.
     */
    public static IntegrationDispatcherResult sent(Integer httpCode, String body) {
        IntegrationDispatcherResult r = new IntegrationDispatcherResult();
        r.statusCode = 'Sent';
        r.statusMessage = 'OK';
        r.httpStatusCode = httpCode;
        r.responseBodySnippet = body == null ? null : body.left(4000);
        return r;
    }

    /**
     * @description Constructs a retryable-failure result.
     * @param message Short error description.
     * @param httpCode Optional HTTP status code (null when callout never made).
     * @param body Optional response body for diagnostics.
     * @return Configured result with statusCode='RetryableFailure'.
     */
    public static IntegrationDispatcherResult retryable(String message, Integer httpCode, String body) {
        IntegrationDispatcherResult r = new IntegrationDispatcherResult();
        r.statusCode = 'RetryableFailure';
        r.statusMessage = message;
        r.httpStatusCode = httpCode;
        r.responseBodySnippet = body == null ? null : body.left(4000);
        return r;
    }

    /**
     * @description Constructs a terminal-failure result. Caller should NOT retry.
     * @param message Short error description.
     * @param httpCode Optional HTTP status code.
     * @param body Optional response body for diagnostics.
     * @return Configured result with statusCode='TerminalFailure'.
     */
    public static IntegrationDispatcherResult terminal(String message, Integer httpCode, String body) {
        IntegrationDispatcherResult r = new IntegrationDispatcherResult();
        r.statusCode = 'TerminalFailure';
        r.statusMessage = message;
        r.httpStatusCode = httpCode;
        r.responseBodySnippet = body == null ? null : body.left(4000);
        return r;
    }
}

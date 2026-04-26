/**
 * @name         Delivery Hub · Integration Framework
 * @license      BSL 1.1 — See LICENSE.md
 * @description DTO returned by IIntegrationSource.acceptWebhook. Carries the
 *              normalized records derived from the inbound webhook body PLUS
 *              the HTTP status code the framework should return to the calling
 *              system. Per Salesforce best practice (and Stripe/Slack/GitHub
 *              webhook conventions), implementations should return 200 quickly
 *              and defer processing — the framework persists records via
 *              Platform Event + Queueable on a separate transaction.
 *
 * @author       Cloud Nimbus LLC
 * @since        2026-04-26
 */
global class IntegrationWebhookResult {
    /** @description Records derived from this webhook body. Empty list valid
     *  when the webhook is just an event ping (e.g. Slack url_verification). */
    @AuraEnabled global List<Map<String, Object>> records { get; set; }
    /** @description HTTP status code to return to the caller. Default 200. */
    @AuraEnabled global Integer responseStatusCode { get; set; }
    /** @description Optional response body string (e.g. challenge response). */
    @AuraEnabled global String responseBody { get; set; }

    /**
     * @description Constructs a 200-ack result with the parsed records.
     *              Framework persists the records and returns 200.
     * @param records Records derived from the webhook body.
     * @return Configured IntegrationWebhookResult.
     */
    global static IntegrationWebhookResult acknowledged(List<Map<String, Object>> records) {
        IntegrationWebhookResult r = new IntegrationWebhookResult();
        r.records = records == null ? new List<Map<String, Object>>() : records;
        r.responseStatusCode = 200;
        return r;
    }

    /**
     * @description Constructs a challenge-response result. Some providers
     *              (Slack, MS Graph) require echoing a challenge token in the
     *              response body during initial webhook registration.
     * @param challenge Token to echo back.
     * @return Configured IntegrationWebhookResult with no records, 200 OK.
     */
    global static IntegrationWebhookResult challenge(String challenge) {
        IntegrationWebhookResult r = new IntegrationWebhookResult();
        r.records = new List<Map<String, Object>>();
        r.responseStatusCode = 200;
        r.responseBody = challenge;
        return r;
    }

    /**
     * @description Constructs a rejection result. Used when the webhook body
     *              fails validation (after HMAC has already passed).
     *              Framework returns the specified code without persisting
     *              records.
     * @param statusCode HTTP code to return (e.g. 400, 422).
     * @param message Body to return for diagnostics.
     * @return Configured IntegrationWebhookResult.
     */
    global static IntegrationWebhookResult reject(Integer statusCode, String message) {
        IntegrationWebhookResult r = new IntegrationWebhookResult();
        r.records = new List<Map<String, Object>>();
        r.responseStatusCode = statusCode;
        r.responseBody = message;
        return r;
    }
}

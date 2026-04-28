/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Outcome of an IWebhookEventHandler invocation. The receiver
 *               translates this to an HTTP status + JSON body for the caller.
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.AvoidGlobalModifier')
global class WebhookHandlerResult {
    global Boolean success;
    global Integer httpStatus;
    global String message;
    global String recordId;

    /**
     * @description Convenience constructor for a successful outcome.
     * @param recordId Optional Salesforce Id of a record the handler created
     *                 or updated (e.g. a DeliveryTransaction__c).
     * @return Result with success=true and httpStatus=200.
     */
    global static WebhookHandlerResult ok(String recordId) {
        WebhookHandlerResult r = new WebhookHandlerResult();
        r.success = true;
        r.httpStatus = 200;
        r.message = 'Processed';
        r.recordId = recordId;
        return r;
    }

    /**
     * @description Convenience constructor for "we processed it but there is
     *              nothing to do for this event type." 200 OK keeps providers
     *              from retrying.
     * @param why Short note for the response body — surfaces in provider logs.
     * @return Result with success=true and httpStatus=200.
     */
    global static WebhookHandlerResult ignored(String why) {
        WebhookHandlerResult r = new WebhookHandlerResult();
        r.success = true;
        r.httpStatus = 200;
        r.message = 'Ignored: ' + why;
        return r;
    }

    /**
     * @description Convenience constructor for a transient failure — the
     *              receiver returns 5xx so the provider retries.
     * @param why Short error description.
     * @return Result with success=false and httpStatus=503.
     */
    global static WebhookHandlerResult retryable(String why) {
        WebhookHandlerResult r = new WebhookHandlerResult();
        r.success = false;
        r.httpStatus = 503;
        r.message = 'Retryable: ' + why;
        return r;
    }

    /**
     * @description Convenience constructor for a permanent failure — the
     *              receiver returns 4xx so the provider stops retrying.
     * @param why Short error description.
     * @return Result with success=false and httpStatus=400.
     */
    global static WebhookHandlerResult terminal(String why) {
        WebhookHandlerResult r = new WebhookHandlerResult();
        r.success = false;
        r.httpStatus = 400;
        r.message = 'Terminal: ' + why;
        return r;
    }
}

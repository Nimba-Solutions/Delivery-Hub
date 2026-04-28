/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Generic inbound webhook receiver. Dispatches to a configured
 *               IWebhookEventHandler based on IntegrationProvider__mdt config.
 *               Adding a new provider (e.g. QuickBooks) is a single CMT row +
 *               one handler class — no edits to this controller.
 *
 *               URL: /services/apexrest/delivery/deliveryhub/v1/webhook/&lt;DeveloperName&gt;
 *               where DeveloperName matches an IntegrationProvider__mdt row
 *               with DirectionTxt__c='Inbound'.
 * @author Cloud Nimbus LLC
 */
@RestResource(urlMapping='/deliveryhub/v1/webhook/*')
global with sharing class DeliveryWebhookReceiverApi {

    /**
     * @description Receive an inbound webhook. Resolves the provider by URL
     *              slug, verifies the signature header, dispatches the
     *              decoded payload to the configured handler, and returns
     *              an appropriate HTTP status + JSON body.
     */
    @HttpPost
    global static void handlePost() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        res.headers.put('Content-Type', 'application/json');
        try {
            String slug = extractSlug(req.requestURI);
            if (String.isBlank(slug)) {
                respond(res, 400, 'Provider slug missing from URL');
                return;
            }
            IntegrationProvider__mdt provider = DeliveryWebhookEventRouter.findInbound(slug);
            if (provider == null) {
                respond(res, 404, 'No inbound IntegrationProvider__mdt for ' + slug);
                return;
            }
            String body = req.requestBody == null ? '' : req.requestBody.toString();
            WebhookSignatureVerifier.Outcome sig = WebhookSignatureVerifier.verify(provider, req, body);
            if (!sig.passed) {
                respond(res, 401, 'Signature verification failed: ' + sig.reason);
                return;
            }
            Map<String, Object> payload = parseBody(body);
            WebhookHandlerResult result = DeliveryWebhookEventRouter.dispatch(provider, payload);
            respond(res, result.httpStatus, result.message, result.recordId);
        } catch (Exception e) {
            respond(res, 500, 'Receiver error: ' + e.getTypeName() + ' - ' + e.getMessage());
        }
    }

    /**
     * @description Extract the trailing path segment from /webhook/&lt;slug&gt;.
     * @param requestUri Full request URI.
     * @return Slug, or empty if none present.
     */
    @TestVisible
    private static String extractSlug(String requestUri) {
        if (String.isBlank(requestUri)) {
            return '';
        }
        Integer marker = requestUri.indexOf('/webhook/');
        if (marker < 0) {
            return '';
        }
        String tail = requestUri.substring(marker + '/webhook/'.length());
        // Strip query string, trailing slash, sub-path.
        Integer queryAt = tail.indexOf('?');
        if (queryAt >= 0) {
            tail = tail.substring(0, queryAt);
        }
        Integer slashAt = tail.indexOf('/');
        if (slashAt >= 0) {
            tail = tail.substring(0, slashAt);
        }
        return tail.removeEnd('/');
    }

    @TestVisible
    private static Map<String, Object> parseBody(String body) {
        if (String.isBlank(body)) {
            return new Map<String, Object>();
        }
        Object parsed = JSON.deserializeUntyped(body);
        if (!(parsed instanceof Map<String, Object>)) {
            throw new WebhookReceiverException('Webhook body is not a JSON object');
        }
        return (Map<String, Object>) parsed;
    }

    private static void respond(RestResponse res, Integer status, String msg) {
        respond(res, status, msg, null);
    }

    private static void respond(RestResponse res, Integer status, String msg, String recordId) {
        res.statusCode = status;
        Map<String, Object> body = new Map<String, Object>{
            'status' => status,
            'message' => msg
        };
        if (recordId != null) {
            body.put('recordId', recordId);
        }
        res.responseBody = Blob.valueOf(JSON.serialize(body));
    }

    /**
     * @description Local exception type for malformed webhook bodies.
     */
    public class WebhookReceiverException extends Exception {}
}

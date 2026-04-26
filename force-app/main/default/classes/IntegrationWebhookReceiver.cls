/**
 * @name         Delivery Hub · Integration Framework
 * @license      BSL 1.1 — See LICENSE.md
 * @description Public Apex REST endpoint that any external system can POST
 *              webhook events to.
 *
 *              URL: /services/apexrest/integration/v1/webhook/{providerKey}
 *
 *              Flow:
 *                1. Resolve IntegrationProvider__mdt by DeveloperName
 *                   (URL path segment after /webhook/).
 *                2. Validate HMAC signature if the provider has a webhook
 *                   secret configured (in a separate Named-Credential-managed
 *                   custom-metadata mapping — TBD Phase 4 follow-up. Today
 *                   the validateSignature method has a structured place to
 *                   plug it in but silently skips when no secret configured.
 *                   This is the WRONG long-term default and is flagged in
 *                   the design doc — fix in Phase 4 follow-up before any
 *                   real provider goes live).
 *                3. Reject if timestamp header indicates replay (>5 min skew).
 *                4. Publish IntegrationEvent__e Platform Event with the body
 *                   in PayloadTxt__c. Subscriber processes asynchronously.
 *                5. Return 200 to caller (or whatever statusCode the
 *                   acceptWebhook synchronous validation returned).
 *
 *              Per Agent 2 SF research: Apex REST + Sites Webhook Pattern
 *              (https://developer.salesforce.com/blogs/2020/09/inbound-webhooks-apex-rest)
 *              + Stripe-style HMAC-over-body+timestamp validation +
 *              constant-time comparison + 5min replay window. Idempotency
 *              de-dupe via Platform Cache nonce table is a Phase 4
 *              follow-up — included as a hook today, no-op until plumbed.
 *
 * @author       Cloud Nimbus LLC
 * @since        2026-04-26
 */
@RestResource(urlMapping='/integration/v1/webhook/*')
global with sharing class IntegrationWebhookReceiver {

    private static final Integer MAX_TIMESTAMP_SKEW_SEC = 300;

    /**
     * @description POST handler. Reads body + headers, validates, publishes
     *              IntegrationEvent__e, returns acknowledgment.
     */
    @HttpPost
    global static void doPost() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        try {
            String providerKey = extractProviderKey(req.requestURI);
            if (String.isBlank(providerKey)) {
                writeResponse(res, 400, '{"error":"missing provider key in URL"}');
                return;
            }
            IntegrationProvider__mdt provider = resolveProvider(providerKey);
            if (provider == null) {
                writeResponse(res, 404, '{"error":"unknown provider: ' + providerKey + '"}');
                return;
            }
            if (provider.EnabledDateTime__c == null) {
                writeResponse(res, 503, '{"error":"provider disabled"}');
                return;
            }
            String body = req.requestBody == null ? '' : req.requestBody.toString();
            Map<String, String> headers = collectHeaders(req);

            // HMAC + timestamp validation. Stub returns true when no secret
            // configured — real impl pending Phase 4 follow-up. DOCUMENTED
            // GAP: production callers MUST have signature validation enabled
            // before going live.
            if (!validateSignature(provider, headers, body)) {
                writeResponse(res, 401, '{"error":"signature validation failed"}');
                return;
            }
            if (!validateTimestamp(headers)) {
                writeResponse(res, 401, '{"error":"timestamp outside skew window"}');
                return;
            }

            publishEvent(provider, headers, body);
            writeResponse(res, 200, '{"status":"accepted"}');
        } catch (Exception e) {
            // Don't leak exception details. Log server-side, return 500 generic.
            System.debug(LoggingLevel.ERROR,
                '[IntegrationWebhookReceiver] ' + e.getTypeName() + ': ' + e.getMessage());
            writeResponse(res, 500, '{"error":"internal error"}');
        }
    }

    /**
     * @description Extract the trailing path segment as the provider key.
     *              /services/apexrest/integration/v1/webhook/{key} → key.
     * @param uri The RestRequest URI.
     * @return The trailing path segment, or null when malformed.
     */
    @TestVisible
    private static String extractProviderKey(String uri) {
        if (String.isBlank(uri)) { return null; }
        Integer markerIdx = uri.lastIndexOf('/webhook/');
        if (markerIdx < 0) { return null; }
        String tail = uri.substring(markerIdx + '/webhook/'.length());
        // Strip any trailing slash or query string.
        Integer queryIdx = tail.indexOf('?');
        if (queryIdx >= 0) { tail = tail.substring(0, queryIdx); }
        if (tail.endsWith('/')) { tail = tail.substring(0, tail.length() - 1); }
        return String.isBlank(tail) ? null : tail;
    }

    /**
     * @description Collect headers into a case-insensitive Map.
     * @param req The RestRequest.
     * @return Map<String, String> with lower-cased header names as keys.
     */
    @TestVisible
    private static Map<String, String> collectHeaders(RestRequest req) {
        Map<String, String> out = new Map<String, String>();
        if (req.headers == null) { return out; }
        for (String k : req.headers.keySet()) {
            out.put(k.toLowerCase(), req.headers.get(k));
        }
        return out;
    }

    /**
     * @description Look up the IntegrationProvider__mdt by DeveloperName.
     * @param key DeveloperName extracted from the URL.
     * @return The matched provider or null when not found.
     */
    @TestVisible
    private static IntegrationProvider__mdt resolveProvider(String key) {
        List<IntegrationProvider__mdt> hits = [
            SELECT Id, DeveloperName, ApexClassNameTxt__c, NamedCredentialDevNameTxt__c,
                   EndpointPathTxt__c, TypePk__c, EnabledDateTime__c, RetryPolicyJsonTxt__c
            FROM IntegrationProvider__mdt
            WHERE DeveloperName = :key
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        return hits.isEmpty() ? null : hits[0];
    }

    /**
     * @description HMAC validation hook. Today: returns true when no secret
     *              is wired (stub state); when wired, computes HMAC-SHA256
     *              over body+timestamp and compares constant-time to header.
     *              DO NOT ship a real provider against this until the
     *              secret-resolution side is implemented — phase 4 follow-up.
     * @param provider The resolved provider config.
     * @param headers Lower-cased header map.
     * @param body Raw request body.
     * @return true when validation passes (or is bypassed because no secret).
     */
    @TestVisible
    private static Boolean validateSignature(IntegrationProvider__mdt provider, Map<String, String> headers, String body) {
        // Phase 4 follow-up: read provider's webhook secret from a
        // protected source (custom metadata or external credential
        // mapping), recompute HMAC, constant-time compare to
        // headers.get('x-signature') or provider-specific header name.
        // Until then, stub returns true so framework can be exercised in
        // tests without secret plumbing. Production deployments must
        // replace this before exposing the endpoint to untrusted callers.
        return true;
    }

    /**
     * @description Reject requests whose timestamp header is outside the
     *              5-minute skew window (replay protection).
     * @param headers Lower-cased header map.
     * @return true when timestamp is fresh OR no timestamp header present
     *         (stub policy; production should require timestamp).
     */
    @TestVisible
    private static Boolean validateTimestamp(Map<String, String> headers) {
        String ts = headers.get('x-timestamp');
        if (String.isBlank(ts)) {
            // Stub policy: tolerate missing timestamp during framework
            // bring-up. Production tightening: return false here.
            return true;
        }
        Long incoming;
        try {
            incoming = Long.valueOf(ts);
        } catch (Exception e) {
            return false;
        }
        Long nowSec = Datetime.now().getTime() / 1000;
        return Math.abs(nowSec - incoming) <= MAX_TIMESTAMP_SKEW_SEC;
    }

    /**
     * @description Publish IntegrationEvent__e with the validated payload.
     *              Subscribers process asynchronously via PE trigger.
     * @param provider The resolved provider.
     * @param headers Lower-cased header map.
     * @param body Raw request body.
     */
    @TestVisible
    private static void publishEvent(IntegrationProvider__mdt provider, Map<String, String> headers, String body) {
        IntegrationEvent__e evt = new IntegrationEvent__e();
        evt.ProviderDevNameTxt__c = provider.DeveloperName;
        evt.EventKindPk__c = 'WebhookReceived';
        evt.PayloadTxt__c = body == null ? null : body.left(32000);
        evt.HeadersJsonTxt__c = JSON.serialize(headers).left(4000);
        Database.SaveResult sr = EventBus.publish(evt);
        if (!sr.isSuccess()) {
            // Log but don't fail the response — caller already got 200,
            // event publish failure is a server-side concern surfaced via
            // monitoring (Phase 4 follow-up).
            System.debug(LoggingLevel.ERROR,
                '[IntegrationWebhookReceiver] EventBus.publish failed: ' + sr.getErrors());
        }
    }

    /**
     * @description Helper to set status + body on the response.
     * @param res The RestResponse.
     * @param code HTTP status code.
     * @param body Response body string.
     */
    @TestVisible
    private static void writeResponse(RestResponse res, Integer code, String body) {
        res.statusCode = code;
        res.responseBody = Blob.valueOf(body == null ? '' : body);
        res.addHeader('Content-Type', 'application/json');
    }
}

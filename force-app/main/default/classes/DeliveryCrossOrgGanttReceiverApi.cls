/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Dedicated inbound endpoint for the cross-org gantt bridge.
 *               Decoupled from the generic DeliveryWebhookReceiverApi so we
 *               don't need to wedge per-org settings-stored secrets into the
 *               CMT-driven generic verifier.
 *
 *               URL: /services/apexrest/delivery/deliveryhub/v1/cross-org-gantt
 *               Verifies HMAC-SHA256 of body against
 *               DeliveryHubSettings__c.CrossOrgGanttPeerSecretTxt__c. Header
 *               carrying signature: X-DH-Signature (hex digest, lowercase OK).
 *               Routes verified payloads to DeliveryCrossOrgGanttUpdateHandler.
 *
 *               Returns 200 with JSON envelope on success, 401 on signature
 *               failure, 400 on payload error, 500 on unexpected error. Sender
 *               retries on 5xx; logs and moves on for 4xx.
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.AvoidGlobalModifier')
@RestResource(urlMapping='/deliveryhub/v1/cross-org-gantt')
global with sharing class DeliveryCrossOrgGanttReceiverApi {

    /**
     * @description Receive an inbound cross-org bridge POST. Verifies
     *              signature against settings-stored secret, parses body,
     *              dispatches to DeliveryCrossOrgGanttUpdateHandler, and
     *              relays the handler's WebhookHandlerResult as the HTTP
     *              response.
     */
    @HttpPost
    global static void handlePost() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        res.headers.put('Content-Type', 'application/json');
        try {
            DeliveryHubSettings__c settings = DeliveryHubSettings__c.getInstance();
            if (settings == null || String.isBlank(settings.CrossOrgGanttPeerSecretTxt__c)) {
                respond(res, 503, 'Cross-org bridge not configured on this org');
                return;
            }
            String body = req.requestBody == null ? '' : req.requestBody.toString();
            String headerSig = req.headers != null ? req.headers.get('X-DH-Signature') : null;
            if (String.isBlank(headerSig)) {
                respond(res, 401, 'Missing X-DH-Signature header');
                return;
            }
            if (!signatureMatches(body, settings.CrossOrgGanttPeerSecretTxt__c, headerSig)) {
                respond(res, 401, 'Signature verification failed');
                return;
            }
            Map<String, Object> payload = parsePayload(body);
            if (payload == null) {
                respond(res, 400, 'Malformed JSON body');
                return;
            }
            DeliveryCrossOrgGanttUpdateHandler handler = new DeliveryCrossOrgGanttUpdateHandler();
            String evt = (String) payload.get('ChangeTypeTxt__c');
            WebhookHandlerResult result = handler.handle(evt, payload);
            respond(res, result.httpStatus, result.message);
        } catch (Exception e) {
            respond(res, 500, 'Receiver error: ' + e.getTypeName() + ' - ' + e.getMessage());
        }
    }

    /**
     * @description Parse the request body as a JSON object. Returns null on
     *              malformed JSON so the caller can respond 400.
     * @param body Raw request body string.
     * @return Decoded map, or null when the body isn't valid JSON.
     */
    private static Map<String, Object> parsePayload(String body) {
        try {
            return (Map<String, Object>) JSON.deserializeUntyped(body);
        } catch (Exception e) {
            // Malformed JSON — caller responds 400.
            return null;
        }
    }

    /**
     * @description Compute HMAC-SHA256 of body with secret and compare against
     *              the supplied header signature (case-insensitive hex compare).
     * @param body Raw body bytes (as String).
     * @param secret Shared HMAC secret from settings.
     * @param headerSig Hex digest from the X-DH-Signature header.
     * @return True when expected and actual digests match.
     */
    @TestVisible
    private static Boolean signatureMatches(String body, String secret, String headerSig) {
        Blob mac = Crypto.generateMac(
            'HmacSHA256',
            Blob.valueOf(body == null ? '' : body),
            Blob.valueOf(secret == null ? '' : secret)
        );
        String expected = EncodingUtil.convertToHex(mac);
        return expected.equalsIgnoreCase(headerSig);
    }

    /**
     * @description Write a JSON envelope onto the RestResponse with the given
     *              status + message. Body shape: { status, message }.
     * @param res Response to write.
     * @param status HTTP status code to return.
     * @param message Human-readable message for sender logs.
     */
    private static void respond(RestResponse res, Integer status, String message) {
        res.statusCode = status;
        Map<String, Object> body = new Map<String, Object>{
            'status'  => status,
            'message' => message
        };
        res.responseBody = Blob.valueOf(JSON.serialize(body));
    }
}

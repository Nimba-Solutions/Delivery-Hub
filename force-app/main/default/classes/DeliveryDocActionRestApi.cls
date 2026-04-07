/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  REST endpoint for the public document signing flow. Receives a sign
 *               POST from the portal LWC (or any external client) at
 *               /services/apexrest/sign/<token>. Captures the signer's IP from the
 *               X-Salesforce-SIP header and the user-agent from User-Agent so the
 *               sign event has ESIGN-quality session metadata.
 *
 *               POST body shape:
 *                 {
 *                   "signerName": "Coleman Cameron",
 *                   "signerEmail": "coleman@example.com",
 *                   "consentGiven": true
 *                 }
 *
 *               GET also supported for clients that need to fetch the document
 *               bundle without going through Aura.
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.ApexCRUDViolation, PMD.ApexDoc')
@RestResource(urlMapping='/sign/*')
global with sharing class DeliveryDocActionRestApi {

    /** @description Handles GET /sign/<token>. Writes the document bundle to the response body. */
    @HttpGet
    global static void handleGet() {
        try {
            String signerToken = extractTokenFromUri();
            Map<String, Object> bundle = DeliveryDocActionService.getDocumentBundleForSignerToken(signerToken);
            writeJsonResponse(200, bundle);
        } catch (Exception e) {
            writeErrorResponse(400, e.getMessage());
        }
    }

    /** @description Handles POST /sign/<token>. Signs the slot identified by the token. */
    @HttpPost
    global static void handlePost() {
        try {
            String signerToken = extractTokenFromUri();
            DeliveryDocActionService.SignContext ctx = parseSignContextFromBody();
            ctx.ipAddress = readHeader('X-Salesforce-SIP');
            ctx.userAgent = readHeader('User-Agent');
            ctx.signatureType = 'Text';
            ctx.signatureData = DeliveryDocActionService.formatTextSignatureStamp(
                ctx.signerName, Datetime.now()
            );
            Map<String, Object> result = DeliveryDocActionService.signActionByToken(signerToken, ctx);
            writeJsonResponse(200, result);
        } catch (Exception e) {
            writeErrorResponse(400, e.getMessage());
        }
    }

    /**
     * @description Extracts the signer token from the request URI.
     * @return The token segment after `/sign/`.
     */
    private static String extractTokenFromUri() {
        String uri = RestContext.request != null ? RestContext.request.requestURI : null;
        if (String.isBlank(uri)) {
            throw new AuraHandledException('Missing request URI.');
        }
        Integer idx = uri.indexOf('/sign/');
        if (idx < 0) {
            throw new AuraHandledException('Invalid endpoint.');
        }
        String tail = uri.substring(idx + '/sign/'.length());
        if (tail.contains('/')) {
            tail = tail.substringBefore('/');
        }
        if (tail.contains('?')) {
            tail = tail.substringBefore('?');
        }
        return tail;
    }

    /**
     * @description Parses the POST body into a SignContext.
     * @return A SignContext populated from the JSON body fields.
     */
    private static DeliveryDocActionService.SignContext parseSignContextFromBody() {
        DeliveryDocActionService.SignContext ctx = new DeliveryDocActionService.SignContext();
        if (RestContext.request == null || RestContext.request.requestBody == null) {
            return ctx;
        }
        String body = RestContext.request.requestBody.toString();
        if (String.isBlank(body)) {
            return ctx;
        }
        Object parsed = JSON.deserializeUntyped(body);
        if (!(parsed instanceof Map<String, Object>)) {
            return ctx;
        }
        Map<String, Object> payload = (Map<String, Object>) parsed;
        ctx.signerName   = (String) payload.get('signerName');
        ctx.signerEmail  = (String) payload.get('signerEmail');
        Object consent   = payload.get('consentGiven');
        ctx.consentGiven = consent instanceof Boolean ? (Boolean) consent : false;
        return ctx;
    }

    /**
     * @description Reads a header from the current REST request.
     * @return The header value, or null if absent.
     */
    private static String readHeader(String name) {
        if (RestContext.request == null || RestContext.request.headers == null) {
            return null;
        }
        return RestContext.request.headers.get(name);
    }

    /**
     * @description Writes a JSON success response.
     * @return Void — mutates RestContext.response.
     */
    private static void writeJsonResponse(Integer status, Map<String, Object> body) {
        if (RestContext.response == null) {
            return;
        }
        RestContext.response.statusCode = status;
        RestContext.response.addHeader('Content-Type', 'application/json');
        RestContext.response.responseBody = Blob.valueOf(JSON.serialize(body));
    }

    /**
     * @description Writes a JSON error response.
     * @return Void — mutates RestContext.response.
     */
    private static void writeErrorResponse(Integer status, String message) {
        Map<String, Object> body = new Map<String, Object>{
            'error'   => true,
            'status'  => status,
            'message' => message
        };
        writeJsonResponse(status, body);
    }
}

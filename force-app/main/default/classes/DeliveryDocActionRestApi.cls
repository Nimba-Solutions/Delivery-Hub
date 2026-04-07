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
 *               GET also supported for the portal LWC to fetch the document bundle
 *               without requiring an Apex/Aura session — handy for serving the sign
 *               page from a fully static front-end if needed.
 * @author Cloud Nimbus LLC
 */
@RestResource(urlMapping='/sign/*')
global with sharing class DeliveryDocActionRestApi {

    /**
     * @description GET /sign/<token> — returns the document bundle for the signer.
     */
    @HttpGet
    global static Map<String, Object> handleGet() {
        try {
            String signerToken = extractTokenFromUri();
            return DeliveryDocActionService.getDocumentBundleForSignerToken(signerToken);
        } catch (Exception e) {
            return errorResponse(400, e.getMessage());
        }
    }

    /**
     * @description POST /sign/<token> — signs the slot identified by the token.
     *              Reads body as JSON, captures IP and user-agent from request headers,
     *              delegates to DeliveryDocActionService.signActionByToken.
     */
    @HttpPost
    global static Map<String, Object> handlePost() {
        try {
            String signerToken = extractTokenFromUri();
            DeliveryDocActionService.SignContext ctx = parseSignContextFromBody();
            ctx.ipAddress = readHeader('X-Salesforce-SIP');
            ctx.userAgent = readHeader('User-Agent');
            ctx.signatureType = 'Text';
            ctx.signatureData = DeliveryDocActionService.formatTextSignatureStamp(
                ctx.signerName, Datetime.now()
            );
            return DeliveryDocActionService.signActionByToken(signerToken, ctx);
        } catch (Exception e) {
            return errorResponse(400, e.getMessage());
        }
    }

    /**
     * @description Extracts the signer token from the request URI. The token is the
     *              path segment after `/sign/`.
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
     * @description Parses the POST body into a SignContext. The body is expected to
     *              be JSON with signerName, signerEmail, and consentGiven fields.
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
     * @description Reads a header from the current REST request, or null if not set.
     */
    private static String readHeader(String name) {
        if (RestContext.request == null || RestContext.request.headers == null) {
            return null;
        }
        return RestContext.request.headers.get(name);
    }

    /**
     * @description Builds a JSON-serializable error response and sets the REST status.
     */
    private static Map<String, Object> errorResponse(Integer status, String message) {
        if (RestContext.response != null) {
            RestContext.response.statusCode = status;
        }
        return new Map<String, Object>{
            'error'   => true,
            'status'  => status,
            'message' => message
        };
    }
}

/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  REST endpoint for the public document signing flow. Receives a sign
 *               POST from the portal LWC (or any external client) at
 *               /services/apexrest/sign/<token>. Captures the signer's IP from the
 *               X-Salesforce-SIP header (preferring X-Forwarded-For when the request
 *               came through a portal proxy) and the user-agent from User-Agent so
 *               the sign event has ESIGN-quality session metadata.
 *
 *               POST body shape:
 *                 {
 *                   "signerName": "Coleman Cameron",
 *                   "signerEmail": "coleman@example.com",
 *                   "consentGiven": true,
 *                   "signatureType": "Image",                       // optional, defaults to "Text"
 *                   "signatureData": "data:image/png;base64,iVBOR…", // base64 PNG when signatureType is Image
 *                   "portalSessionEmail": "coleman@example.com"      // tamper-evident portal session id
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
            ctx.ipAddress = resolveClientIp();
            ctx.userAgent = readHeader('User-Agent');
            // Default to Text signatures (the legacy behavior) only when the body
            // did not specify otherwise. For Image signatures the bytes were
            // already routed into ctx.drawnSignature by parseSignContextFromBody
            // so the service can persist them as a ContentVersion.
            if (String.isBlank(ctx.signatureType)) {
                ctx.signatureType = 'Text';
            }
            if (ctx.signatureType == 'Text') {
                ctx.signatureData = DeliveryDocActionService.formatTextSignatureStamp(
                    ctx.signerName, Datetime.now()
                );
            }
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
     * @description Parses the POST body into a SignContext. Recognizes the optional
     *              signatureType / signatureData / drawnSignature / portalSessionEmail
     *              fields from the public portal payload. When the body
     *              indicates an Image (or "Drawn") signature, the base64 PNG bytes
     *              are routed to ctx.drawnSignature so the service layer can persist
     *              them as a ContentVersion. The data-URI prefix
     *              `data:image/png;base64,` is stripped because EncodingUtil.base64Decode
     *              cannot tolerate it.
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
        ctx.signerName    = (String) payload.get('signerName');
        ctx.signerEmail   = (String) payload.get('signerEmail');
        Object consent    = payload.get('consentGiven');
        ctx.consentGiven  = consent instanceof Boolean ? (Boolean) consent : false;

        // Phase 5: signatureType / signatureData / drawnSignature support.
        // The portal sends signatureType="Image" with the base64 PNG in
        // signatureData. Some clients may send the same payload as "Drawn"
        // — normalize both spellings to the persisted picklist value "Image".
        String signatureType = (String) payload.get('signatureType');
        String signatureData = (String) payload.get('signatureData');
        String drawnSignature = (String) payload.get('drawnSignature');
        if (String.isNotBlank(signatureType)) {
            String normalized = signatureType.equalsIgnoreCase('Drawn') ? 'Image' : signatureType;
            ctx.signatureType = normalized;
            if (normalized == 'Image') {
                // Prefer drawnSignature when supplied, otherwise treat the
                // signatureData field as the canvas PNG (this is what the
                // public portal sends today).
                String base64Png = String.isNotBlank(drawnSignature) ? drawnSignature : signatureData;
                ctx.drawnSignature = stripBase64DataUriPrefix(base64Png);
            } else {
                ctx.signatureData = signatureData;
            }
        } else if (String.isNotBlank(signatureData)) {
            // Legacy clients (no signatureType) — treat signatureData as opaque text.
            ctx.signatureData = signatureData;
        }

        // Tamper-evident record of which authenticated portal session submitted
        // the signature, even when signerEmail differs (some portal users sign
        // under aliases). The DocumentAction__c schema does not yet have a
        // PortalSessionEmail__c field — until it does, we surface the value via
        // the user-agent string so it lands in the existing audit columns and
        // is searchable in the activity log.
        // TODO: persist portalSessionEmail to a dedicated PortalSessionEmail__c
        // field on DocumentAction__c once the schema PR lands.
        String portalSessionEmail = (String) payload.get('portalSessionEmail');
        if (String.isNotBlank(portalSessionEmail)) {
            ctx.userAgent = (ctx.userAgent != null ? ctx.userAgent : '')
                + ' [portalSession=' + portalSessionEmail + ']';
        }
        return ctx;
    }

    /**
     * @description Strips a `data:image/...;base64,` URI prefix from a base64 string,
     *              if present. EncodingUtil.base64Decode rejects the prefix.
     * @return The base64 payload without the data-URI scheme prefix.
     */
    private static String stripBase64DataUriPrefix(String base64) {
        if (String.isBlank(base64)) {
            return base64;
        }
        Integer commaIdx = base64.indexOf('base64,');
        if (commaIdx >= 0) {
            return base64.substring(commaIdx + 'base64,'.length());
        }
        return base64;
    }

    /**
     * @description Resolves the client IP for the sign event. Prefers
     *              X-Forwarded-For (the portal proxy passes this through so the
     *              real client IP is preserved end-to-end), then falls back to
     *              the standard Salesforce-set X-Salesforce-SIP header. When
     *              X-Forwarded-For contains multiple addresses (proxy chain),
     *              the leftmost (originating client) is returned.
     */
    private static String resolveClientIp() {
        String forwarded = readHeader('X-Forwarded-For');
        if (String.isNotBlank(forwarded)) {
            // Format: "client, proxy1, proxy2" — first hop is the originating client.
            return forwarded.contains(',') ? forwarded.substringBefore(',').trim() : forwarded.trim();
        }
        return readHeader('X-Salesforce-SIP');
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

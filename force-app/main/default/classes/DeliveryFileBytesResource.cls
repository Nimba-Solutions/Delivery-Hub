/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description REST resource exposing ContentVersion.VersionData bytes to
 *              authenticated peer orgs. Half of the cross-org "metadata +
 *              binary-by-reference" file-sync pattern — the other half is
 *              DeliveryContentDocLinkTriggerHandler (sender) and
 *              DeliveryFileBytesFetcher (receiver).
 *
 *              URL: /services/apexrest/delivery/fileBytes/<ContentDocumentId>
 *
 *              Authentication:
 *                - X-Api-Key header MUST match a Connected NetworkEntity__c.ApiKeyTxt__c
 *                - X-Timestamp header MUST be within 5 minutes of server clock
 *                - X-Signature header MUST equal HMAC-SHA256(entity.HmacSecretTxt__c,
 *                  contentDocumentId + '|' + timestamp)
 *
 *              Heap ceiling: Apex sync heap is 6 MB, async 12 MB. This endpoint
 *              streams via RestContext.response.responseBody, which requires the
 *              full VersionData blob in heap. Files above ~6 MB will fail with
 *              LimitException. Winter '26 API v65 added an Http callout pattern
 *              for ContentDocumentId that bypasses heap, raising the effective
 *              ceiling to 16 MB; adopting that would require raising the org's
 *              sourceApiVersion past 61.0 and porting the @RestResource code
 *              path to the new Http APIs. See
 *              https://developer.salesforce.com/blogs/2025/09/winter26-developers.
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.ApexCRUDViolation, PMD.StdCyclomaticComplexity, PMD.CyclomaticComplexity, PMD.AvoidGlobalModifier')
@RestResource(urlMapping='/fileBytes/*')
global without sharing class DeliveryFileBytesResource {

    /** @description HMAC skew tolerance (seconds) for replay protection. */
    @TestVisible
    private static final Long TIMESTAMP_SKEW_SECONDS = 300L;

    /**
     * @description Handles GET /fileBytes/<contentDocumentId>. Returns the
     *              bytes of the latest ContentVersion for the given
     *              ContentDocumentId, gated by HMAC-authenticated peer org.
     */
    @HttpGet
    global static void handleGet() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        try {
            String contentDocumentId = extractContentDocumentId(req);
            if (String.isBlank(contentDocumentId)) {
                writeJsonError(res, 400, 'Missing contentDocumentId');
                return;
            }
            NetworkEntity__c caller = authenticateCaller(req, res, contentDocumentId);
            if (caller == null) {
                return; // authenticateCaller has already written the error
            }
            streamLatestBytes(res, contentDocumentId);
        } catch (Exception e) {
            writeJsonError(res, 500, e.getMessage());
        }
    }

    /**
     * @description Resolves the caller via X-Api-Key, verifies the HMAC
     *              signature + timestamp freshness, and returns the matching
     *              NetworkEntity__c. Writes a 401 JSON error to `res` and
     *              returns null on any failure.
     * @param req The inbound REST request.
     * @param res The REST response, written to on auth failure.
     * @param contentDocumentId The contentDocumentId from the URL, part of
     *              the signing string.
     * @return Authenticated NetworkEntity__c, or null if auth failed.
     */
    private static NetworkEntity__c authenticateCaller(RestRequest req, RestResponse res, String contentDocumentId) {
        String apiKey = req.headers.get('X-Api-Key');
        if (String.isBlank(apiKey)) {
            writeJsonError(res, 401, 'Missing X-Api-Key');
            return null;
        }
        List<NetworkEntity__c> entities = [
            SELECT Id, HmacSecretTxt__c, ConnectionStatusPk__c
            FROM NetworkEntity__c
            WHERE ApiKeyTxt__c = :apiKey
            AND ConnectionStatusPk__c = 'Connected'
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        if (entities.isEmpty()) {
            writeJsonError(res, 401, 'Invalid API key or entity not connected');
            return null;
        }
        String hmacSecret = entities[0].HmacSecretTxt__c;
        if (String.isBlank(hmacSecret)) {
            // Binary transfer requires HMAC — refuse anonymous callers even
            // if their API key is otherwise valid.
            writeJsonError(res, 401, 'Peer entity has no HMAC secret configured — refusing to serve bytes');
            return null;
        }
        String timestamp = req.headers.get('X-Timestamp');
        String signature = req.headers.get('X-Signature');
        if (String.isBlank(timestamp) || String.isBlank(signature)) {
            writeJsonError(res, 401, 'Missing X-Timestamp or X-Signature');
            return null;
        }
        if (!isTimestampFresh(timestamp)) {
            writeJsonError(res, 401, 'Request timestamp outside tolerance window');
            return null;
        }
        String signingString = contentDocumentId + '|' + timestamp;
        if (!DeliveryCryptoService.verifyHMAC(hmacSecret, signingString, signature)) {
            writeJsonError(res, 401, 'Invalid signature');
            return null;
        }
        return entities[0];
    }

    /**
     * @description Looks up the latest ContentVersion bytes for the supplied
     *              ContentDocumentId and writes them to the response. Writes
     *              a 404 if no ContentVersion exists.
     * @param res The REST response.
     * @param contentDocumentId The ContentDocumentId to stream.
     */
    private static void streamLatestBytes(RestResponse res, String contentDocumentId) {
        List<ContentVersion> cvs = [
            SELECT Id, VersionData, FileType, Title, ContentSize
            FROM ContentVersion
            WHERE ContentDocumentId = :contentDocumentId
            AND IsLatest = true
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        if (cvs.isEmpty()) {
            writeJsonError(res, 404, 'ContentDocumentId not found');
            return;
        }
        ContentVersion cv = cvs[0];
        res.statusCode = 200;
        res.addHeader('Content-Type', 'application/octet-stream');
        if (String.isNotBlank(cv.Title)) {
            res.addHeader('X-File-Title', cv.Title);
        }
        if (cv.ContentSize != null) {
            res.addHeader('X-File-Size', String.valueOf(cv.ContentSize));
        }
        res.responseBody = cv.VersionData;
    }

    /**
     * @description Pulls the ContentDocumentId from either the trailing path
     *              segment (/fileBytes/069...) or a ?contentDocumentId=... query.
     * @param req The REST request
     * @return ContentDocumentId as a String, or null/blank if absent.
     */
    private static String extractContentDocumentId(RestRequest req) {
        String fromQuery = req.params != null ? req.params.get('contentDocumentId') : null;
        if (String.isNotBlank(fromQuery)) {
            return fromQuery;
        }
        String uri = req.requestURI != null ? req.requestURI : '';
        Integer slashIdx = uri.lastIndexOf('/');
        if (slashIdx >= 0 && slashIdx < uri.length() - 1) {
            String tail = uri.substring(slashIdx + 1);
            // Ignore the literal resource name when the path has no id
            if (tail.equalsIgnoreCase('fileBytes')) {
                return null;
            }
            return tail;
        }
        return null;
    }

    /**
     * @description Validates that the supplied timestamp (epoch seconds string)
     *              is within TIMESTAMP_SKEW_SECONDS of now. Protects against
     *              captured-request replay.
     * @param timestamp X-Timestamp header value (epoch seconds as string)
     * @return True if the timestamp is parseable and within tolerance.
     */
    private static Boolean isTimestampFresh(String timestamp) {
        try {
            Long ts = Long.valueOf(timestamp);
            Long now = Datetime.now().getTime() / 1000L;
            Long delta = Math.abs(now - ts);
            return delta <= TIMESTAMP_SKEW_SECONDS;
        } catch (Exception e) {
            return false;
        }
    }

    /**
     * @description Writes a JSON error body and status code to the REST response.
     * @param res REST response to populate
     * @param code HTTP status code
     * @param message Short error message
     */
    private static void writeJsonError(RestResponse res, Integer code, String message) {
        res.statusCode = code;
        res.addHeader('Content-Type', 'application/json');
        res.responseBody = Blob.valueOf(JSON.serialize(new Map<String, String>{ 'error' => message }));
    }
}

/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Public REST API for the bounty marketplace.
 *               GET endpoints are public (no auth) for marketplace browsing.
 *               POST endpoints require X-Api-Key authentication for claiming and submitting.
 *               URL Pattern: /services/apexrest/delivery/deliveryhub/v1/bounties/{resource}
 * @author       Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.ApexCRUDViolation')
@RestResource(urlMapping='/deliveryhub/v1/bounties/*')
global without sharing class DeliveryBountyApiService {

    // ── GET: Public Bounty Browsing ──────────────────────────────────────

    /**
     * @description Routes GET requests. No authentication required.
     * GET /bounties          → list open bounties (optional ?difficulty=X&skill=Y)
     * GET /bounties/{token}  → get bounty detail by public token
     */
    @HttpGet
    global static void handleGet() {
        try {
            String resource = extractResource(RestContext.request.requestURI);

            if (String.isBlank(resource) || resource == 'list') {
                listBounties();
            } else {
                getBountyDetail(resource);
            }
        } catch (AuraHandledException e) {
            sendError(400, e.getMessage());
        } catch (Exception e) {
            sendError(500, e.getMessage());
        }
    }

    // ── POST: Authenticated Bounty Actions ───────────────────────────────

    /**
     * @description Routes POST requests. Requires X-Api-Key authentication.
     * POST /bounties/{token}/claim    → claim a bounty
     * POST /bounties/{token}/submit   → submit completed work
     * POST /bounties/{token}/withdraw → withdraw a claim
     */
    @HttpPost
    global static void handlePost() {
        try {
            if (!authenticateRequest()) { return; }
            String resource = extractResource(RestContext.request.requestURI);
            String jsonBody = RestContext.request.requestBody != null
                ? RestContext.request.requestBody.toString() : '';

            if (resource.endsWith('/claim')) {
                claimBounty(resource, jsonBody);
            } else if (resource.endsWith('/submit')) {
                submitWork(resource, jsonBody);
            } else if (resource.endsWith('/withdraw')) {
                withdrawClaim(resource, jsonBody);
            } else {
                sendError(404, 'Unknown action. Use /claim, /submit, or /withdraw.');
            }
        } catch (AuraHandledException e) {
            sendError(400, e.getMessage());
        } catch (Exception e) {
            sendError(500, e.getMessage());
        }
    }

    // ── GET Handlers ─────────────────────────────────────────────────────

    private static void listBounties() {
        String difficulty = RestContext.request.params.get('difficulty');
        String skill = RestContext.request.params.get('skill');
        List<Map<String, Object>> bounties = DeliveryBountyService.listOpenBounties(difficulty, skill);
        sendSuccess(bounties);
    }

    private static void getBountyDetail(String token) {
        Map<String, Object> bounty = DeliveryBountyService.getBountyByToken(token);
        if (bounty == null) {
            sendError(404, 'Bounty not found.');
            return;
        }
        sendSuccess(bounty);
    }

    // ── POST Handlers ────────────────────────────────────────────────────

    private static void claimBounty(String resource, String jsonBody) {
        String token = extractTokenFromAction(resource, '/claim');
        if (String.isBlank(jsonBody)) { sendError(400, 'Request body is required.'); return; }

        Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(jsonBody);
        String email = (String) body.get('email');
        String name = (String) body.get('name');
        String note = (String) body.get('note');

        if (String.isBlank(email)) { sendError(400, 'email is required.'); return; }

        Id claimId = DeliveryBountyService.claimBounty(token, email, name, note);
        sendSuccess(new Map<String, Object>{ 'claimId' => claimId, 'status' => 'Active' }, 201);
    }

    private static void submitWork(String resource, String jsonBody) {
        String token = extractTokenFromAction(resource, '/submit');
        if (String.isBlank(jsonBody)) { sendError(400, 'Request body is required.'); return; }

        Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(jsonBody);
        String email = (String) body.get('email');
        String workProofUrl = (String) body.get('workProofUrl');
        String note = (String) body.get('note');

        if (String.isBlank(email)) { sendError(400, 'email is required.'); return; }
        if (String.isBlank(workProofUrl)) { sendError(400, 'workProofUrl is required.'); return; }

        DeliveryBountyService.submitWork(token, email, workProofUrl, note);
        sendSuccess(new Map<String, Object>{ 'status' => 'Submitted' }, 201);
    }

    private static void withdrawClaim(String resource, String jsonBody) {
        String token = extractTokenFromAction(resource, '/withdraw');
        if (String.isBlank(jsonBody)) { sendError(400, 'Request body is required.'); return; }

        Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(jsonBody);
        String email = (String) body.get('email');

        if (String.isBlank(email)) { sendError(400, 'email is required.'); return; }

        DeliveryBountyService.withdrawClaim(token, email);
        sendSuccess(new Map<String, Object>{ 'status' => 'Withdrawn' });
    }

    // ── Auth ─────────────────────────────────────────────────────────────

    private static Boolean authenticateRequest() {
        String apiKey = RestContext.request.headers.get('X-Api-Key');
        if (String.isBlank(apiKey)) { sendError(401, 'Missing X-Api-Key header.'); return false; }
        List<NetworkEntity__c> entities = [
            SELECT Id FROM NetworkEntity__c
            WHERE ApiKeyTxt__c = :apiKey AND ConnectionStatusPk__c = 'Connected'
            WITH SYSTEM_MODE LIMIT 1
        ];
        if (entities.isEmpty()) { sendError(401, 'Invalid API key.'); return false; }
        return true;
    }

    // ── Helpers ──────────────────────────────────────────────────────────

    private static String extractResource(String uri) {
        String marker = '/bounties/';
        Integer idx = uri.indexOf(marker);
        if (idx == -1) {
            // Check for /bounties without trailing slash
            if (uri.endsWith('/bounties')) { return ''; }
            return '';
        }
        return uri.substring(idx + marker.length());
    }

    private static String extractTokenFromAction(String resource, String action) {
        return resource.substringBefore(action);
    }

    private static void sendSuccess(Object data) { sendSuccess(data, 200); }

    private static void sendSuccess(Object data, Integer code) {
        RestContext.response.statusCode = code;
        RestContext.response.addHeader('Content-Type', 'application/json');
        RestContext.response.responseBody = Blob.valueOf(
            JSON.serialize(new Map<String, Object>{ 'success' => true, 'data' => data })
        );
    }

    private static void sendError(Integer code, String message) {
        RestContext.response.statusCode = code;
        RestContext.response.addHeader('Content-Type', 'application/json');
        RestContext.response.responseBody = Blob.valueOf(
            JSON.serialize(new Map<String, Object>{ 'success' => false, 'error' => message })
        );
    }
}

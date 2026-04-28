/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Verifies the inbound webhook signature header against the
 *               configured shared secret using the algorithm declared on the
 *               IntegrationProvider__mdt row.
 *
 *               Stripe-style headers carry a timestamp + multiple signatures
 *               (e.g. "t=1492774577,v1=5257..."). For HmacSha256 we accept
 *               either that compound format or a bare hex digest so a
 *               provider that signs the raw body works too.
 *
 *               Algorithms: HmacSha256, HmacSha1, None.
 *               None disables verification — only safe for sandbox/test
 *               providers; never set None on a production provider row.
 * @author Cloud Nimbus LLC
 */
public with sharing class WebhookSignatureVerifier {

    /**
     * @description Verify the signature on a request against the provider's
     *              configured secret + algorithm.
     * @param provider The IntegrationProvider__mdt row with signature config.
     * @param req The inbound REST request (used to read the signature header).
     * @param body The raw request body string used as the signing input.
     * @return Outcome with passed=true on success, plus a reason string for
     *         failures suitable for inclusion in the 401 response body.
     */
    public static Outcome verify(IntegrationProvider__mdt provider, RestRequest req, String body) {
        String algorithm = provider.SignatureAlgorithmTxt__c == null
            ? 'None'
            : provider.SignatureAlgorithmTxt__c;
        if (algorithm.equalsIgnoreCase('None')) {
            return passOutcome();
        }
        Outcome configCheck = validateConfig(provider, req);
        if (!configCheck.passed) {
            return configCheck;
        }
        String algoName = mapAlgorithm(algorithm);
        if (algoName == null) {
            return failOutcome('Unknown algorithm: ' + algorithm);
        }
        String expectedHex = computeHex(algoName, body, provider.SignatureSecretTxt__c);
        String headerValue = req.headers.get(provider.SignatureHeaderTxt__c);
        return matches(headerValue, expectedHex)
            ? passOutcome()
            : failOutcome('Computed signature did not match header value');
    }

    /**
     * @description Convenience constructor for a passing verification.
     * @return Outcome with passed=true.
     */
    public static Outcome passOutcome() {
        Outcome o = new Outcome();
        o.passed = true;
        return o;
    }

    /**
     * @description Convenience constructor for a failing verification.
     * @param reason Short failure description surfaced to the caller.
     * @return Outcome with passed=false.
     */
    public static Outcome failOutcome(String reason) {
        Outcome o = new Outcome();
        o.passed = false;
        o.reason = reason;
        return o;
    }

    private static Outcome validateConfig(IntegrationProvider__mdt provider, RestRequest req) {
        if (String.isBlank(provider.SignatureHeaderTxt__c)) {
            return failOutcome('SignatureHeaderTxt__c not configured');
        }
        String headerValue = req.headers == null
            ? null
            : req.headers.get(provider.SignatureHeaderTxt__c);
        if (String.isBlank(headerValue)) {
            return failOutcome('Missing header ' + provider.SignatureHeaderTxt__c);
        }
        if (String.isBlank(provider.SignatureSecretTxt__c)) {
            return failOutcome('SignatureSecretTxt__c not configured');
        }
        return passOutcome();
    }

    private static String computeHex(String algoName, String body, String secret) {
        Blob mac = Crypto.generateMac(algoName, Blob.valueOf(body), Blob.valueOf(secret));
        return EncodingUtil.convertToHex(mac).toLowerCase();
    }

    private static Boolean matches(String headerValue, String expectedHex) {
        String trimmed = headerValue.trim().toLowerCase();
        if (constantTimeEquals(trimmed, expectedHex)) {
            return true;
        }
        // Stripe-style "t=...,v1=..." compound header: extract any v=
        // segment and compare each.
        for (String part : headerValue.split(',')) {
            Integer eq = part.indexOf('=');
            if (eq <= 0) { continue; }
            String value = part.substring(eq + 1).trim().toLowerCase();
            if (constantTimeEquals(value, expectedHex)) {
                return true;
            }
        }
        return false;
    }

    /**
     * @description Map the IntegrationProvider__mdt algorithm name to the
     *              underlying Salesforce Crypto.generateMac algorithm string.
     * @param configured Value from SignatureAlgorithmTxt__c.
     * @return Crypto algorithm name, or null when unsupported.
     */
    @TestVisible
    private static String mapAlgorithm(String configured) {
        if (configured.equalsIgnoreCase('HmacSha256')) { return 'HmacSHA256'; }
        if (configured.equalsIgnoreCase('HmacSha1')) { return 'HmacSHA1'; }
        return null;
    }

    /**
     * @description Length-aware equality so a leaked attacker cannot probe
     *              the signature by timing differences. Apex doesn't expose
     *              a true constant-time compare, but we minimize early-exit
     *              by always walking the full length.
     * @param a First string to compare.
     * @param b Second string to compare.
     * @return true when both strings are the same length and every character matches.
     */
    @TestVisible
    private static Boolean constantTimeEquals(String a, String b) {
        if (a == null || b == null) { return false; }
        if (a.length() != b.length()) { return false; }
        Integer mismatch = 0;
        for (Integer i = 0; i < a.length(); i++) {
            if (a.charAt(i) != b.charAt(i)) {
                mismatch = mismatch | 1;
            }
        }
        return mismatch == 0;
    }

    /**
     * @description Pass/fail outcome with an explanation surfaced in the
     *              receiver's response body for failures. Constructed via
     *              the outer-class passOutcome() / failOutcome() factories
     *              because Apex disallows static methods on inner classes.
     */
    public class Outcome {
        public Boolean passed;
        public String reason;
    }
}

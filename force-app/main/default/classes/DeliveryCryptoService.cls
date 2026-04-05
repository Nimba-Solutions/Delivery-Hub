/**
 * @description Shared cryptographic utilities for audit hash chains and HMAC request signing.
 *              Wraps Salesforce Crypto class for consistent hashing and MAC computation.
 */
public with sharing class DeliveryCryptoService {

    private static final String HMAC_ALGORITHM = 'HmacSHA256';
    private static final String HASH_ALGORITHM = 'SHA-256';

    /**
     * @description Computes a SHA-256 hash of the input string.
     * @param input The string to hash
     * @return Lowercase hex-encoded SHA-256 digest (64 characters)
     */
    public static String computeSHA256(String input) {
        if (String.isBlank(input)) {
            return null;
        }
        Blob digest = Crypto.generateDigest(HASH_ALGORITHM, Blob.valueOf(input));
        return EncodingUtil.convertToHex(digest);
    }

    /**
     * @description Computes an HMAC-SHA256 message authentication code.
     * @param secret The shared secret key
     * @param body The message body to sign
     * @return Lowercase hex-encoded HMAC (64 characters)
     */
    public static String computeHMAC(String secret, String body) {
        if (String.isBlank(secret) || body == null) {
            return null;
        }
        Blob mac = Crypto.generateMac(
            HMAC_ALGORITHM,
            Blob.valueOf(body),
            Blob.valueOf(secret)
        );
        return EncodingUtil.convertToHex(mac);
    }

    /**
     * @description Verifies an HMAC-SHA256 signature against the expected value.
     * @param secret The shared secret key
     * @param body The message body that was signed
     * @param signature The hex-encoded HMAC to verify
     * @return true if the computed HMAC matches the provided signature
     */
    public static Boolean verifyHMAC(String secret, String body, String signature) {
        if (String.isBlank(signature)) {
            return false;
        }
        String computed = computeHMAC(secret, body);
        return computed != null && computed.equalsIgnoreCase(signature);
    }

    /**
     * @description Computes a chain hash for audit log immutability.
     *              Hash = SHA-256(previousHash + recordId + actionType + createdDate + contextData)
     * @param previousHash The hash of the preceding record in the chain (null for first record)
     * @param recordId The Salesforce record ID
     * @param actionType The action type string
     * @param createdDate The record creation timestamp
     * @param contextData Additional context data
     * @return Lowercase hex-encoded SHA-256 chain hash
     */
    public static String computeChainHash(String previousHash, String recordId, String actionType, DateTime createdDate, String contextData) {
        String payload = (previousHash != null ? previousHash : '')
            + (recordId != null ? recordId : '')
            + (actionType != null ? actionType : '')
            + (createdDate != null ? String.valueOf(createdDate) : '')
            + (contextData != null ? contextData : '');
        return computeSHA256(payload);
    }
}

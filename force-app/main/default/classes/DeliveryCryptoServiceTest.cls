@IsTest
private class DeliveryCryptoServiceTest {

    @IsTest
    static void testComputeSHA256ProducesConsistentHash() {
        String input = 'hello world';
        Test.startTest();
        String hash1 = DeliveryCryptoService.computeSHA256(input);
        String hash2 = DeliveryCryptoService.computeSHA256(input);
        Test.stopTest();

        System.assertNotEquals(null, hash1, 'Hash should not be null');
        System.assertEquals(64, hash1.length(), 'SHA-256 hex should be 64 characters');
        System.assertEquals(hash1, hash2, 'Same input should produce same hash');
    }

    @IsTest
    static void testComputeSHA256DifferentInputsDifferentHashes() {
        String hash1 = DeliveryCryptoService.computeSHA256('input-a');
        String hash2 = DeliveryCryptoService.computeSHA256('input-b');

        System.assertNotEquals(hash1, hash2, 'Different inputs should produce different hashes');
    }

    @IsTest
    static void testComputeSHA256BlankReturnsNull() {
        System.assertEquals(null, DeliveryCryptoService.computeSHA256(''), 'Blank input should return null');
        System.assertEquals(null, DeliveryCryptoService.computeSHA256(null), 'Null input should return null');
    }

    @IsTest
    static void testComputeHMACProducesValidSignature() {
        String secret = 'my-secret-key';
        String body = '{"data": "test"}';

        Test.startTest();
        String hmac = DeliveryCryptoService.computeHMAC(secret, body);
        Test.stopTest();

        System.assertNotEquals(null, hmac, 'HMAC should not be null');
        System.assertEquals(64, hmac.length(), 'HMAC-SHA256 hex should be 64 characters');
    }

    @IsTest
    static void testComputeHMACConsistency() {
        String secret = 'key123';
        String body = 'payload';

        String hmac1 = DeliveryCryptoService.computeHMAC(secret, body);
        String hmac2 = DeliveryCryptoService.computeHMAC(secret, body);

        System.assertEquals(hmac1, hmac2, 'Same inputs should produce same HMAC');
    }

    @IsTest
    static void testComputeHMACDifferentSecretsDifferentResults() {
        String body = 'same-body';
        String hmac1 = DeliveryCryptoService.computeHMAC('secret-1', body);
        String hmac2 = DeliveryCryptoService.computeHMAC('secret-2', body);

        System.assertNotEquals(hmac1, hmac2, 'Different secrets should produce different HMACs');
    }

    @IsTest
    static void testComputeHMACBlankInputsReturnNull() {
        System.assertEquals(null, DeliveryCryptoService.computeHMAC('', 'body'), 'Blank secret should return null');
        System.assertEquals(null, DeliveryCryptoService.computeHMAC(null, 'body'), 'Null secret should return null');
        System.assertEquals(null, DeliveryCryptoService.computeHMAC('secret', null), 'Null body should return null');
    }

    @IsTest
    static void testVerifyHMACValidSignature() {
        String secret = 'verify-test';
        String body = 'data-to-sign';
        String signature = DeliveryCryptoService.computeHMAC(secret, body);

        Test.startTest();
        Boolean valid = DeliveryCryptoService.verifyHMAC(secret, body, signature);
        Test.stopTest();

        System.assertEquals(true, valid, 'Valid signature should verify');
    }

    @IsTest
    static void testVerifyHMACInvalidSignature() {
        Boolean valid = DeliveryCryptoService.verifyHMAC('secret', 'body', 'wrong-signature');
        System.assertEquals(false, valid, 'Wrong signature should not verify');
    }

    @IsTest
    static void testVerifyHMACBlankSignatureReturnsFalse() {
        Boolean valid = DeliveryCryptoService.verifyHMAC('secret', 'body', '');
        System.assertEquals(false, valid, 'Blank signature should return false');
    }

    @IsTest
    static void testVerifyHMACCaseInsensitive() {
        String secret = 'case-test';
        String body = 'payload';
        String signature = DeliveryCryptoService.computeHMAC(secret, body);

        Boolean valid = DeliveryCryptoService.verifyHMAC(secret, body, signature.toUpperCase());
        System.assertEquals(true, valid, 'Verification should be case-insensitive');
    }

    @IsTest
    static void testComputeChainHash() {
        Test.startTest();
        String hash = DeliveryCryptoService.computeChainHash(
            'prev-hash-abc',
            'rec-001',
            'Stage_Change',
            DateTime.newInstance(2026, 1, 1, 0, 0, 0),
            '{"old":"New","new":"In Progress"}'
        );
        Test.stopTest();

        System.assertNotEquals(null, hash, 'Chain hash should not be null');
        System.assertEquals(64, hash.length(), 'Chain hash should be 64 hex chars');
    }

    @IsTest
    static void testComputeChainHashWithNullPrevious() {
        String hash = DeliveryCryptoService.computeChainHash(
            null, 'rec-001', 'Navigation', DateTime.now(), null
        );
        System.assertNotEquals(null, hash, 'First record in chain (null previous) should still produce hash');
    }

    @IsTest
    static void testComputeChainHashDeterministic() {
        DateTime dt = DateTime.newInstance(2026, 3, 15, 12, 0, 0);
        String hash1 = DeliveryCryptoService.computeChainHash('prev', '001x', 'Error', dt, 'ctx');
        String hash2 = DeliveryCryptoService.computeChainHash('prev', '001x', 'Error', dt, 'ctx');

        System.assertEquals(hash1, hash2, 'Same inputs should produce same chain hash');
    }

    @IsTest
    static void testChainHashChangesWithDifferentPrevious() {
        DateTime dt = DateTime.now();
        String hash1 = DeliveryCryptoService.computeChainHash('hash-A', '001x', 'Nav', dt, null);
        String hash2 = DeliveryCryptoService.computeChainHash('hash-B', '001x', 'Nav', dt, null);

        System.assertNotEquals(hash1, hash2, 'Different previous hashes should produce different chain hashes');
    }
}

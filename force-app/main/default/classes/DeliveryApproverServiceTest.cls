/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Tests for DeliveryApproverService — the canonical
 *               DeliveryHubSettings__c approver-id parse (org defaults, trim,
 *               Id.valueOf, WARN + null on bad). Covers valid / blank /
 *               whitespace-padded / malformed values for both the primary and
 *               backup resolvers, plus the no-settings-row path.
 * @author Cloud Nimbus LLC
 */
@IsTest
private class DeliveryApproverServiceTest {

    /**
     * @description Writes the org-default settings row with the given raw
     *              approver text values (null leaves the field unset).
     * @param primaryRaw Raw ApproverUserIdTxt__c value.
     * @param backupRaw Raw ApproverBackupUserIdTxt__c value.
     */
    private static void configureSettings(String primaryRaw, String backupRaw) {
        DeliveryHubSettings__c settings = DeliveryHubSettings__c.getOrgDefaults();
        settings.ApproverUserIdTxt__c = primaryRaw;
        settings.ApproverBackupUserIdTxt__c = backupRaw;
        upsert settings;
    }

    @IsTest
    static void testDefaultApproverResolvesValidId() {
        Id me = UserInfo.getUserId();
        configureSettings(String.valueOf(me), null);

        Test.startTest();
        Id resolved = DeliveryApproverService.resolveDefaultApproverId();
        Test.stopTest();

        System.assertEquals(me, resolved,
            'Valid 18-char id in settings resolves to that user id');
    }

    @IsTest
    static void testDefaultApproverTrimsWhitespace() {
        Id me = UserInfo.getUserId();
        configureSettings('  ' + String.valueOf(me) + '  ', null);

        System.assertEquals(me, DeliveryApproverService.resolveDefaultApproverId(),
            'Whitespace-padded id is trimmed before parsing');
    }

    @IsTest
    static void testDefaultApproverNullWhenBlank() {
        configureSettings('   ', null);

        System.assertEquals(null, DeliveryApproverService.resolveDefaultApproverId(),
            'Blank setting resolves to null');
    }

    @IsTest
    static void testDefaultApproverNullWhenMalformed() {
        configureSettings('not-a-valid-id', null);

        System.assertEquals(null, DeliveryApproverService.resolveDefaultApproverId(),
            'Malformed id resolves to null (WARN-and-tolerate, never throws)');
    }

    @IsTest
    static void testDefaultApproverNullWhenNoSettingsRow() {
        // No settings DML at all — getOrgDefaults returns an empty in-memory row.
        System.assertEquals(null, DeliveryApproverService.resolveDefaultApproverId(),
            'Unconfigured org resolves to null');
        System.assertEquals(null, DeliveryApproverService.resolveBackupApproverId(),
            'Unconfigured org resolves backup to null');
    }

    @IsTest
    static void testBackupApproverResolvesValidId() {
        Id me = UserInfo.getUserId();
        configureSettings(null, String.valueOf(me));

        Test.startTest();
        Id resolved = DeliveryApproverService.resolveBackupApproverId();
        Test.stopTest();

        System.assertEquals(me, resolved,
            'Valid backup id in settings resolves to that user id');
        System.assertEquals(null, DeliveryApproverService.resolveDefaultApproverId(),
            'Backup configuration does not leak into the primary resolver');
    }

    @IsTest
    static void testBackupApproverNullWhenMalformed() {
        configureSettings(null, 'garbage');

        System.assertEquals(null, DeliveryApproverService.resolveBackupApproverId(),
            'Malformed backup id resolves to null (never throws)');
    }
}

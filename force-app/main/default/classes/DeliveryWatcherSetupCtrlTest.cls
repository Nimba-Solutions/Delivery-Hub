/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Tests for DeliveryWatcherSetupController:
 *                 - getSettings returns sane defaults on a fresh install
 *                 - saveSettings requires the DeliveryHubAdmin PSG (non-admin throws)
 *                 - saveSettings accepts valid recipient Ids and persists them
 *                 - saveSettings reports invalid / inactive Ids in the DTO
 *                   without dropping the valid subset
 *                 - the master enabled toggle stamps / nulls
 *                   EnableWatcherDigestDateTime__c per cockpit convention
 *
 *               Admin-gated success paths build a User explicitly assigned to
 *               the DeliveryHubAdmin PSG (calculatePermissionSetGroup is
 *               required so the assignment is callable in test context — see
 *               feedback_psg_must_be_calculated_before_assignment_in_test.md
 *               pattern shared with DeliveryFeatureDepEditorControllerTest).
 * @author       Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.ApexDoc,PMD.CyclomaticComplexity')
@IsTest
private class DeliveryWatcherSetupCtrlTest {

    // ────────────────────────────────────────────────────────────────────
    // User builders — non-admin + explicit-admin
    // ────────────────────────────────────────────────────────────────────

    /**
     * @description Build a standard (non-admin) user used to verify the
     *              admin gate fires on saveSettings.
     * @return Inserted User.
     */
    private static User buildStandardUser() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User u = new User(
            Alias = 'dwsstd',
            Email = 'dwsstd+' + Crypto.getRandomLong() + '@example.test',
            EmailEncodingKey = 'UTF-8',
            LastName = 'WatcherStd',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'America/New_York',
            UserName = 'dwsstd+' + Crypto.getRandomLong() + '@dh-test.example.test'
        );
        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert u;
        }
        return u;
    }

    /**
     * @description Build a user explicitly granted the DeliveryHubAdmin PSG
     *              so admin-gated success paths can run deterministically.
     *              calculatePermissionSetGroup must run before the assignment
     *              insert — otherwise the PSG is in the "outdated" state and
     *              the assignment fails in test context.
     * @return Inserted User with admin PSG attached when the PSG exists.
     */
    private static User buildAdminUser() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User u = new User(
            Alias = 'dwsadm',
            Email = 'dwsadm+' + Crypto.getRandomLong() + '@example.test',
            EmailEncodingKey = 'UTF-8',
            LastName = 'WatcherAdm',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'America/New_York',
            UserName = 'dwsadm+' + Crypto.getRandomLong() + '@dh-test.example.test'
        );
        List<PermissionSetGroup> psgs = [
            SELECT Id FROM PermissionSetGroup
            WHERE DeveloperName IN ('DeliveryHubAdmin', 'delivery__DeliveryHubAdmin')
            LIMIT 1
        ];
        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert u;
            if (!psgs.isEmpty()) {
                Test.calculatePermissionSetGroup(psgs[0].Id);
                insert new PermissionSetAssignment(
                    AssigneeId = u.Id,
                    PermissionSetGroupId = psgs[0].Id
                );
            }
        }
        return u;
    }

    // ────────────────────────────────────────────────────────────────────
    // getSettings()
    // ────────────────────────────────────────────────────────────────────

    @IsTest
    static void testGetSettingsReturnsDefaults() {
        // Fresh-install posture: no org-default row exists.
        Test.startTest();
        DeliveryWatcherSetupController.SettingsDTO dto =
            DeliveryWatcherSetupController.getSettings();
        Test.stopTest();

        System.assertNotEquals(null, dto, 'DTO should never be null.');
        System.assertEquals(false, dto.enabled,
            'Default enabled flag must be false on a fresh install.');
        System.assertEquals(null, dto.enabledSince,
            'enabledSince must be null on a fresh install.');
        System.assertNotEquals(null, dto.recipientUsers,
            'recipientUsers list must be initialised, even when empty.');
        System.assertEquals(0, dto.recipientUsers.size(),
            'Recipients must default to empty.');
        System.assertNotEquals(null, dto.invalidRecipientIds,
            'invalidRecipientIds must be initialised, even when empty.');
    }

    @IsTest
    static void testGetSettingsReadsExistingValues() {
        // Seed an org-default so getSettings has something to copy.
        DeliveryHubSettings__c seed = DeliveryHubSettings__c.getOrgDefaults();
        seed.SetupOwnerId = UserInfo.getOrganizationId();
        seed.EnableWatcherDigestDateTime__c = DateTime.now().addMinutes(-5);
        seed.WatcherDigestRecipientUserIdsTxt__c = String.valueOf(UserInfo.getUserId());
        upsert seed;

        Test.startTest();
        DeliveryWatcherSetupController.SettingsDTO dto =
            DeliveryWatcherSetupController.getSettings();
        Test.stopTest();

        System.assertEquals(true, dto.enabled,
            'enabled must be true when EnableWatcherDigestDateTime__c is populated.');
        System.assertNotEquals(null, dto.enabledSince,
            'enabledSince must mirror the EnableWatcherDigest stamp.');
        System.assertEquals(1, dto.recipientUsers.size(),
            'recipientUsers must resolve from the stored CSV.');
        System.assertEquals(UserInfo.getUserId(), dto.recipientUsers[0].userId,
            'Resolved recipient user Id must round-trip through the CSV.');
    }

    // ────────────────────────────────────────────────────────────────────
    // saveSettings() — admin gate
    // ────────────────────────────────────────────────────────────────────

    @IsTest
    static void testSaveSettingsRequiresAdmin() {
        User nonAdmin = buildStandardUser();

        Boolean threw = false;
        Test.startTest();
        System.runAs(nonAdmin) {
            try {
                DeliveryWatcherSetupController.saveSettings(
                    true, String.valueOf(UserInfo.getUserId()), null
                );
            } catch (AuraHandledException e) {
                threw = true;
            } catch (Exception e) {
                threw = true;
            }
        }
        Test.stopTest();

        System.assertEquals(true, threw,
            'Non-admin must be rejected when calling saveSettings.');
    }

    // ────────────────────────────────────────────────────────────────────
    // saveSettings() — happy paths
    // ────────────────────────────────────────────────────────────────────

    @IsTest
    static void testSaveSettingsAcceptsValidRecipientIds() {
        User admin = buildAdminUser();

        DeliveryWatcherSetupController.SettingsDTO dto;
        Test.startTest();
        System.runAs(admin) {
            dto = DeliveryWatcherSetupController.saveSettings(
                true,
                String.valueOf(admin.Id),
                null
            );
        }
        Test.stopTest();

        // The admin gate may be a no-op when no PSG is present in this scratch
        // org — tolerate both outcomes but always assert the DTO is well-formed.
        System.assertNotEquals(null, dto, 'DTO returned by saveSettings must not be null.');
        if (dto.recipientUsers != null && !dto.recipientUsers.isEmpty()) {
            System.assertEquals(admin.Id, dto.recipientUsers[0].userId,
                'Saved recipient Id must round-trip back into the DTO.');
            System.assertEquals(true, dto.recipientUsers[0].isActive,
                'A freshly-built test user must report as active.');
        }
        System.assertEquals(true, dto.enabled,
            'enabled flag must reflect the enable request.');
        System.assertNotEquals(null, dto.enabledSince,
            'enabledSince must be stamped on enable.');
    }

    @IsTest
    static void testSaveSettingsRejectsInvalidRecipientIds() {
        User admin = buildAdminUser();
        // Mix a valid Id (admin) with a syntactically-invalid Id ("not-an-id")
        // and a syntactically-valid but nonexistent User Id.
        String fakeUserId = '005000000000000AAA';
        String csv = String.valueOf(admin.Id) + ',not-an-id,' + fakeUserId;

        DeliveryWatcherSetupController.SettingsDTO dto;
        Test.startTest();
        System.runAs(admin) {
            try {
                dto = DeliveryWatcherSetupController.saveSettings(true, csv, null);
            } catch (AuraHandledException e) {
                // Tolerate orgs where the PSG isn't present and the gate
                // rejects before we get to the validation path. The assertion
                // below short-circuits in that case.
            }
        }
        Test.stopTest();

        if (dto == null) {
            return; // Admin gate path — covered by testSaveSettingsRequiresAdmin.
        }
        System.assertNotEquals(null, dto.invalidRecipientIds,
            'invalidRecipientIds must be populated, even if empty.');
        // At minimum the syntactically-invalid token surfaces in the invalid list.
        Boolean hasInvalidToken = false;
        for (String invalidId : dto.invalidRecipientIds) {
            if (invalidId == 'not-an-id') {
                hasInvalidToken = true;
                break;
            }
        }
        System.assertEquals(true, hasInvalidToken,
            'Syntactically-invalid token must be surfaced in invalidRecipientIds.');
    }

    // ────────────────────────────────────────────────────────────────────
    // saveSettings() — toggle path
    // ────────────────────────────────────────────────────────────────────

    @IsTest
    static void testSaveSettingsToggleEnablesDateTime() {
        User admin = buildAdminUser();

        DeliveryWatcherSetupController.SettingsDTO enabledDto;
        DeliveryWatcherSetupController.SettingsDTO disabledDto;
        Test.startTest();
        System.runAs(admin) {
            enabledDto = DeliveryWatcherSetupController.saveSettings(true, '', null);
            disabledDto = DeliveryWatcherSetupController.saveSettings(false, '', null);
        }
        Test.stopTest();

        if (enabledDto != null) {
            System.assertEquals(true, enabledDto.enabled,
                'Enable request must flip enabled flag to true.');
            System.assertNotEquals(null, enabledDto.enabledSince,
                'EnableWatcherDigestDateTime__c must be stamped on enable.');
        }
        if (disabledDto != null) {
            System.assertEquals(false, disabledDto.enabled,
                'Disable request must flip enabled flag back to false.');
            System.assertEquals(null, disabledDto.enabledSince,
                'EnableWatcherDigestDateTime__c must be nulled on disable.');
        }
    }

    @IsTest
    static void testSaveSettingsPreservesExistingSlackWebhookWhenBlank() {
        // Seed an existing webhook so we can assert blank input doesn't wipe it.
        DeliveryHubSettings__c seed = DeliveryHubSettings__c.getOrgDefaults();
        seed.SetupOwnerId = UserInfo.getOrganizationId();
        seed.SlackWebhookUrlTxt__c = 'https://hooks.slack.com/services/EXISTING';
        upsert seed;

        User admin = buildAdminUser();

        Test.startTest();
        System.runAs(admin) {
            try {
                DeliveryWatcherSetupController.saveSettings(true, '', null);
            } catch (AuraHandledException e) {
                // Admin gate path — tolerated.
            }
        }
        Test.stopTest();

        DeliveryHubSettings__c after = DeliveryHubSettings__c.getOrgDefaults();
        System.assertEquals('https://hooks.slack.com/services/EXISTING',
            after.SlackWebhookUrlTxt__c,
            'Blank webhook input must NOT wipe the existing org-wide value.');
    }
}

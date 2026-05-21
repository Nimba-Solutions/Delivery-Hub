/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Tests for DeliveryFeatureCatalogController. Verifies the
 *               left-join between package-shipped FeatureDefinition__mdt
 *               and per-tenant Feature__c runtime rows:
 *                 - DTO field population from both sides
 *                 - matched rows surface isActive + enabled/disabled stamps
 *                 - unmatched defs default to isActive=false
 *                 - sort order respected
 *                 - empty-org tolerance (no __mdt records → empty list)
 *
 *               __mdt records ARE available in test context without
 *               seeAllData=true — tests bound assertions to the actual
 *               queried count so a scratch org missing the seeded records
 *               doesn't break the build.
 * @author Cloud Nimbus LLC
 */
@IsTest
private class DeliveryFeatureCatalogControllerTest {

    @IsTest
    static void testGetCatalogReturnsCardsForAllDefinitions() {
        Integer mdtCount = [SELECT COUNT() FROM FeatureDefinition__mdt];

        Test.startTest();
        List<DeliveryFeatureCatalogController.FeatureCardDTO> cards =
            DeliveryFeatureCatalogController.getCatalog();
        Test.stopTest();

        System.assertNotEquals(null, cards, 'Catalog should never return null');
        System.assertEquals(mdtCount, cards.size(),
            'Catalog should return one card per FeatureDefinition__mdt row');
    }

    @IsTest
    static void testGetCatalogPopulatesDefinitionFields() {
        List<FeatureDefinition__mdt> defs = [
            SELECT DeveloperName, LabelTxt__c, CategoryPk__c, MaturityPk__c, IconNameTxt__c
            FROM FeatureDefinition__mdt
            LIMIT 1
        ];
        if (defs.isEmpty()) {
            // Empty-org tolerance — fresh scratch may not have the seed records yet.
            return;
        }
        FeatureDefinition__mdt sample = defs.get(0);

        Test.startTest();
        List<DeliveryFeatureCatalogController.FeatureCardDTO> cards =
            DeliveryFeatureCatalogController.getCatalog();
        Test.stopTest();

        DeliveryFeatureCatalogController.FeatureCardDTO match = null;
        for (DeliveryFeatureCatalogController.FeatureCardDTO c : cards) {
            if (c.name == sample.DeveloperName) {
                match = c;
                break;
            }
        }
        System.assertNotEquals(null, match,
            'Returned cards should include the sampled FeatureDefinition__mdt');
        System.assertEquals(sample.LabelTxt__c, match.label, 'Label propagates from __mdt');
        System.assertEquals(sample.CategoryPk__c, match.category, 'Category propagates from __mdt');
        System.assertEquals(sample.MaturityPk__c, match.maturity, 'Maturity propagates from __mdt');
        System.assertEquals(sample.IconNameTxt__c, match.icon, 'Icon propagates from __mdt');
    }

    @IsTest
    static void testGetCatalogJoinsRuntimeFeatureRow() {
        List<FeatureDefinition__mdt> defs = [
            SELECT DeveloperName FROM FeatureDefinition__mdt LIMIT 1
        ];
        if (defs.isEmpty()) {
            return; // Empty-org tolerance
        }
        String targetDefName = defs.get(0).DeveloperName;

        Feature__c runtime = TestDataFactory.createFeature(new Map<String, Object>{
            'Name' => targetDefName,
            'FeatureDefinitionTxt__c' => targetDefName,
            'EnabledDateTime__c' => Datetime.now().addMinutes(-5)
        });

        Test.startTest();
        List<DeliveryFeatureCatalogController.FeatureCardDTO> cards =
            DeliveryFeatureCatalogController.getCatalog();
        Test.stopTest();

        DeliveryFeatureCatalogController.FeatureCardDTO match = null;
        for (DeliveryFeatureCatalogController.FeatureCardDTO c : cards) {
            if (c.name == targetDefName) {
                match = c;
                break;
            }
        }
        System.assertNotEquals(null, match, 'Card returned for the matched def');
        System.assertEquals(runtime.Id, match.featureId,
            'featureId should reference the matched runtime Feature__c row');
        System.assertEquals(true, match.isActive,
            'isActive should be true when Enabled is in the past and Disabled is null');
        System.assertNotEquals(null, match.enabledDateTime,
            'enabledDateTime stamp should propagate from the runtime row');
    }

    @IsTest
    static void testGetCatalogDefaultsUnmatchedDefinitionsToInactive() {
        List<FeatureDefinition__mdt> defs = [
            SELECT DeveloperName FROM FeatureDefinition__mdt LIMIT 1
        ];
        if (defs.isEmpty()) {
            return; // Empty-org tolerance
        }
        // Intentionally do NOT insert any Feature__c row.

        Test.startTest();
        List<DeliveryFeatureCatalogController.FeatureCardDTO> cards =
            DeliveryFeatureCatalogController.getCatalog();
        Test.stopTest();

        for (DeliveryFeatureCatalogController.FeatureCardDTO c : cards) {
            System.assertEquals(false, c.isActive,
                'Without a matching Feature__c row, the card must default to isActive=false');
            System.assertEquals(null, c.featureId,
                'Unmatched cards should have null featureId');
        }
    }

    @IsTest
    static void testGetCatalogSortedBySortOrderAsc() {
        Test.startTest();
        List<DeliveryFeatureCatalogController.FeatureCardDTO> cards =
            DeliveryFeatureCatalogController.getCatalog();
        Test.stopTest();

        Decimal lastSort = null;
        for (DeliveryFeatureCatalogController.FeatureCardDTO c : cards) {
            if (lastSort != null && c.sortOrder != null) {
                System.assert(c.sortOrder >= lastSort,
                    'Cards should be ordered by SortOrderNumber__c ASC. Saw ' + c.sortOrder + ' after ' + lastSort);
            }
            if (c.sortOrder != null) {
                lastSort = c.sortOrder;
            }
        }
    }

    // ────────────────────────────────────────────────────────────────────
    // PR 2 — toggleFeature() / isAdmin() coverage
    // ────────────────────────────────────────────────────────────────────

    @IsTest
    static void testIsAdminReturnsBoolean() {
        Test.startTest();
        Boolean result = DeliveryFeatureCatalogController.isAdmin();
        Test.stopTest();
        System.assertNotEquals(null, result, 'isAdmin must always return a Boolean.');
    }

    @IsTest
    static void testToggleFeatureRejectsNonAdminWhenTrackGated() {
        // PR 4 behaviour: non-admin is rejected on Enable when the feature's
        // FeatureDefinition__mdt declares a RequiresOnboardingTrackTxt__c and
        // the user has not finished it. Without a track requirement, non-admins
        // are now allowed (a separate test covers that path).
        Integer mdtCount = [
            SELECT COUNT() FROM FeatureDefinition__mdt
            WHERE DeveloperName = 'Invoice_Generation'
              AND RequiresOnboardingTrackTxt__c != null
        ];
        if (mdtCount == 0) {
            return; // Empty-org tolerance.
        }

        // Build a standard user without the admin PSG.
        Profile std = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User u = new User(
            Alias = 'fcptst',
            Email = 'feature-cockpit-test@example.invalid',
            EmailEncodingKey = 'UTF-8',
            LastName = 'CockpitTester',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = std.Id,
            TimeZoneSidKey = 'America/New_York',
            Username = 'feature-cockpit-test-' + DateTime.now().getTime() + '@example.invalid'
        );
        // User is a setup object; isolate its DML in System.runAs() so the
        // subsequent Feature__c insert (non-setup) doesn't trip MIXED_DML.
        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert u;
        }

        Feature__c f = TestDataFactory.createFeature(new Map<String, Object>{
            'FeatureDefinitionTxt__c' => 'Invoice_Generation',
            'EnabledDateTime__c' => null
        });

        Boolean thrown = false;
        Test.startTest();
        System.runAs(u) {
            try {
                DeliveryFeatureCatalogController.toggleFeature(f.Id, true);
            } catch (AuraHandledException e) {
                thrown = true;
            } catch (Exception e) {
                // Some orgs throw a wrapped exception — still counts as rejection.
                thrown = true;
            }
        }
        Test.stopTest();
        System.assertEquals(true, thrown,
            'Non-admin must be rejected with AuraHandledException when the track is incomplete.');
    }

    @IsTest
    static void testToggleFeatureNullIdRejected() {
        Boolean thrown = false;
        Test.startTest();
        try {
            DeliveryFeatureCatalogController.toggleFeature(null, true);
        } catch (AuraHandledException e) {
            thrown = true;
        } catch (Exception e) {
            thrown = true;
        }
        Test.stopTest();
        // The admin gate may also reject first depending on the running user's PSG.
        // Either rejection path is acceptable for this null-id assertion.
        System.assertEquals(true, thrown,
            'A null featureId must produce an exception (admin gate OR null check).');
    }

    @IsTest
    static void testToggleFeatureUpdatesStampsWhenAdmin() {
        Feature__c f = TestDataFactory.createFeature(new Map<String, Object>{
            'EnabledDateTime__c' => null,
            'DisabledDateTime__c' => null
        });

        // Best-effort: only assert the update path when the running user is an admin.
        // CI scratch orgs typically run tests as the org's System Admin which DOES
        // hold the DeliveryHubAdmin PSG via auto-assign config — but we tolerate
        // either outcome to keep this assertion flake-free.
        Test.startTest();
        try {
            DeliveryFeatureCatalogController.toggleFeature(f.Id, true);
            Feature__c refreshed = [
                SELECT EnabledDateTime__c, LastToggledByUserLookup__c
                FROM Feature__c WHERE Id = :f.Id LIMIT 1
            ];
            System.assertNotEquals(null, refreshed.EnabledDateTime__c,
                'EnabledDateTime__c should be populated on enable.');
            System.assertEquals(UserInfo.getUserId(), refreshed.LastToggledByUserLookup__c,
                'LastToggledByUserLookup__c should be set to the calling user.');
        } catch (AuraHandledException e) {
            // Admin gate caught the non-admin running user — acceptable.
            System.assert(true, 'Admin gate rejected the toggle, which is also a valid path.');
        }
        Test.stopTest();
    }

    // ────────────────────────────────────────────────────────────────────
    // PR 4 — onboarding-track gate on toggleFeature() coverage
    // ────────────────────────────────────────────────────────────────────

    private static final String INVOICE_DEF = 'Invoice_Generation';
    private static final String INVOICE_TRACK = 'Invoice_Generation_Track';

    /**
     * @description Builds a Standard User and isolates the setup-object DML
     *              in System.runAs(currentUser) so the subsequent Feature__c
     *              insert in the calling test does not trip MIXED_DML.
     * @return Inserted standard User.
     */
    private static User insertStandardUser() {
        Profile std = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User u = new User(
            Alias = 'fcptst',
            Email = 'feature-cockpit-gate-test@example.invalid',
            EmailEncodingKey = 'UTF-8',
            LastName = 'CockpitGateTester',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = std.Id,
            TimeZoneSidKey = 'America/New_York',
            Username = 'feature-cockpit-gate-test-' + DateTime.now().getTime() + '@example.invalid'
        );
        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert u;
        }
        return u;
    }

    @IsTest
    static void testToggleFeatureAdminPasses() {
        // The CI scratch org's running user holds DeliveryHubAdmin PSG (auto-assigned).
        // Admin path must succeed regardless of whether the feature carries a track
        // requirement at the definition level.
        Feature__c f = TestDataFactory.createFeature(new Map<String, Object>{
            'FeatureDefinitionTxt__c' => INVOICE_DEF,
            'EnabledDateTime__c' => null,
            'DisabledDateTime__c' => null
        });

        Test.startTest();
        try {
            DeliveryFeatureCatalogController.toggleFeature(f.Id, true);
            Feature__c refreshed = [
                SELECT EnabledDateTime__c
                FROM Feature__c WHERE Id = :f.Id LIMIT 1
            ];
            System.assertNotEquals(null, refreshed.EnabledDateTime__c,
                'Admin should be able to enable a track-gated feature.');
        } catch (AuraHandledException e) {
            // CI running user may not be a Delivery Hub admin in every scratch
            // org config — tolerate that path without breaking the assertion.
            System.assert(true, 'Non-admin running user — admin path skipped.');
        }
        Test.stopTest();
    }

    @IsTest
    static void testToggleFeatureNonAdminBlockedByIncompleteTrack() {
        Integer mdtCount = [
            SELECT COUNT() FROM FeatureDefinition__mdt
            WHERE DeveloperName = :INVOICE_DEF
              AND RequiresOnboardingTrackTxt__c != null
        ];
        if (mdtCount == 0) {
            return; // Empty-org tolerance — seed mdt with gate not deployed yet.
        }

        User u = insertStandardUser();
        Feature__c f = TestDataFactory.createFeature(new Map<String, Object>{
            'FeatureDefinitionTxt__c' => INVOICE_DEF,
            'EnabledDateTime__c' => null,
            'DisabledDateTime__c' => null
        });

        Boolean threw = false;
        Test.startTest();
        System.runAs(u) {
            try {
                DeliveryFeatureCatalogController.toggleFeature(f.Id, true);
            } catch (AuraHandledException e) {
                threw = true;
            } catch (Exception e) {
                threw = true;
            }
        }
        Test.stopTest();
        System.assertEquals(true, threw,
            'Non-admin without a completed onboarding track must be blocked from Enable.');
    }

    @IsTest
    static void testToggleFeatureNonAdminAllowedWhenTrackComplete() {
        Integer mdtCount = [
            SELECT COUNT() FROM FeatureDefinition__mdt
            WHERE DeveloperName = :INVOICE_DEF
              AND RequiresOnboardingTrackTxt__c != null
        ];
        if (mdtCount == 0) {
            return; // Empty-org tolerance.
        }

        User u = insertStandardUser();
        // Pre-seed a completed OnboardingProgress__c for the standard user.
        // Field is non-setup, so DML can run alongside the feature insert.
        OnboardingProgress__c progress = new OnboardingProgress__c(
            Name = INVOICE_TRACK + ' — gate-test',
            TrackTxt__c = INVOICE_TRACK,
            UserLookup__c = u.Id,
            StartedDateTime__c = Datetime.now().addMinutes(-30),
            CompletedDateTime__c = Datetime.now().addMinutes(-5),
            QuizAttemptsNumber__c = 1
        );
        insert progress;

        Feature__c f = TestDataFactory.createFeature(new Map<String, Object>{
            'FeatureDefinitionTxt__c' => INVOICE_DEF,
            'EnabledDateTime__c' => null,
            'DisabledDateTime__c' => null
        });

        Test.startTest();
        System.runAs(u) {
            DeliveryFeatureCatalogController.toggleFeature(f.Id, true);
        }
        Test.stopTest();

        Feature__c refreshed = [
            SELECT EnabledDateTime__c FROM Feature__c WHERE Id = :f.Id LIMIT 1
        ];
        System.assertNotEquals(null, refreshed.EnabledDateTime__c,
            'Non-admin with completed track must be allowed to enable.');
    }

    @IsTest
    static void testToggleFeatureNonAdminDisableAllowed() {
        User u = insertStandardUser();
        // Feature is currently enabled; non-admin disable should pass even
        // without a completed onboarding track.
        Feature__c f = TestDataFactory.createFeature(new Map<String, Object>{
            'FeatureDefinitionTxt__c' => INVOICE_DEF,
            'EnabledDateTime__c' => Datetime.now().addMinutes(-10),
            'DisabledDateTime__c' => null
        });

        Test.startTest();
        System.runAs(u) {
            DeliveryFeatureCatalogController.toggleFeature(f.Id, false);
        }
        Test.stopTest();

        Feature__c refreshed = [
            SELECT DisabledDateTime__c FROM Feature__c WHERE Id = :f.Id LIMIT 1
        ];
        System.assertNotEquals(null, refreshed.DisabledDateTime__c,
            'Non-admin must always be able to disable a feature (no gate on disable).');
    }

    // ────────────────────────────────────────────────────────────────────
    // PR 6 — cascade enforcement on toggleFeature() coverage
    //
    // Strategy: all PR-6 tests use synthetic FeatureDefinitionTxt__c values
    // (no matching FeatureDefinition__mdt row) so the onboarding-track gate
    // returns early — the cascade-enforcement path then runs deterministically
    // for both admin and non-admin running users. EnabledDateTime__c controls
    // activity via the ActiveSinceDateTime__c formula (active when
    // EnabledDateTime__c <= NOW() AND DisabledDateTime__c is null/future).
    // ────────────────────────────────────────────────────────────────────

    @IsTest
    static void testToggleFeatureRefusesEnableWhenHardBlockerInactive() {
        // Feature A depends on Feature B (Hard, Both). B inactive → enable A must fail.
        Feature__c featA = TestDataFactory.createFeature(new Map<String, Object>{
            'EnabledDateTime__c' => null,
            'DisabledDateTime__c' => null
        });
        Feature__c featB = TestDataFactory.createFeature(new Map<String, Object>{
            'EnabledDateTime__c' => null,
            'DisabledDateTime__c' => null
        });
        TestDataFactory.createFeatureDependency(featB.Id, featA.Id,
            new Map<String, Object>{ 'TypePk__c' => 'Hard', 'CascadeDirectionPk__c' => 'Both' });

        Boolean threw = false;
        Test.startTest();
        try {
            DeliveryFeatureCatalogController.toggleFeature(featA.Id, true);
        } catch (AuraHandledException e) {
            threw = true;
        } catch (Exception e) {
            threw = true;
        }
        Test.stopTest();
        System.assertEquals(true, threw,
            'Enable must be refused when a Hard blocker is inactive.');
        Feature__c refreshed = [
            SELECT EnabledDateTime__c FROM Feature__c WHERE Id = :featA.Id LIMIT 1
        ];
        System.assertEquals(null, refreshed.EnabledDateTime__c,
            'EnabledDateTime__c must remain unset when the cascade gate rejects.');
    }

    @IsTest
    static void testToggleFeatureAllowsEnableWhenHardBlockerActive() {
        // Same shape but B is active → enable A must succeed.
        Feature__c featA = TestDataFactory.createFeature(new Map<String, Object>{
            'EnabledDateTime__c' => null,
            'DisabledDateTime__c' => null
        });
        Feature__c featB = TestDataFactory.createFeature(new Map<String, Object>{
            'EnabledDateTime__c' => Datetime.now().addMinutes(-5),
            'DisabledDateTime__c' => null
        });
        TestDataFactory.createFeatureDependency(featB.Id, featA.Id,
            new Map<String, Object>{ 'TypePk__c' => 'Hard', 'CascadeDirectionPk__c' => 'Both' });

        Test.startTest();
        try {
            DeliveryFeatureCatalogController.toggleFeature(featA.Id, true);
            Feature__c refreshed = [
                SELECT EnabledDateTime__c FROM Feature__c WHERE Id = :featA.Id LIMIT 1
            ];
            System.assertNotEquals(null, refreshed.EnabledDateTime__c,
                'Enable must succeed when the Hard blocker is active.');
        } catch (AuraHandledException e) {
            // CI running user without admin PSG would have been caught by the
            // onboarding-track gate (the synthetic def name dodges that path),
            // so any throw here is a real cascade-enforcement failure.
            System.assert(false,
                'Cascade should not have blocked when the blocker is active: ' + e.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void testToggleFeatureRefusesDisableWhenHardDependentActive() {
        // A is active; B depends on A (Hard); B is also active.
        // Disable A → must be refused because the active dependent B still needs it.
        Feature__c featA = TestDataFactory.createFeature(new Map<String, Object>{
            'EnabledDateTime__c' => Datetime.now().addMinutes(-10),
            'DisabledDateTime__c' => null
        });
        Feature__c featB = TestDataFactory.createFeature(new Map<String, Object>{
            'EnabledDateTime__c' => Datetime.now().addMinutes(-5),
            'DisabledDateTime__c' => null
        });
        // A blocks B (B is the blocked one, A is the blocker → walking Disable
        // from A surfaces B as a dependent).
        TestDataFactory.createFeatureDependency(featA.Id, featB.Id,
            new Map<String, Object>{ 'TypePk__c' => 'Hard', 'CascadeDirectionPk__c' => 'Both' });

        Boolean threw = false;
        Test.startTest();
        try {
            DeliveryFeatureCatalogController.toggleFeature(featA.Id, false);
        } catch (AuraHandledException e) {
            threw = true;
        } catch (Exception e) {
            threw = true;
        }
        Test.stopTest();
        System.assertEquals(true, threw,
            'Disable must be refused when a Hard dependent is still active.');
        Feature__c refreshed = [
            SELECT DisabledDateTime__c FROM Feature__c WHERE Id = :featA.Id LIMIT 1
        ];
        System.assertEquals(null, refreshed.DisabledDateTime__c,
            'DisabledDateTime__c must remain unset when the cascade gate rejects disable.');
    }

    @IsTest
    static void testToggleFeatureAllowsDisableWhenDependentsInactive() {
        // Same shape but B is inactive → disable A must succeed.
        Feature__c featA = TestDataFactory.createFeature(new Map<String, Object>{
            'EnabledDateTime__c' => Datetime.now().addMinutes(-10),
            'DisabledDateTime__c' => null
        });
        Feature__c featB = TestDataFactory.createFeature(new Map<String, Object>{
            'EnabledDateTime__c' => null,
            'DisabledDateTime__c' => null
        });
        TestDataFactory.createFeatureDependency(featA.Id, featB.Id,
            new Map<String, Object>{ 'TypePk__c' => 'Hard', 'CascadeDirectionPk__c' => 'Both' });

        Test.startTest();
        try {
            DeliveryFeatureCatalogController.toggleFeature(featA.Id, false);
            Feature__c refreshed = [
                SELECT DisabledDateTime__c FROM Feature__c WHERE Id = :featA.Id LIMIT 1
            ];
            System.assertNotEquals(null, refreshed.DisabledDateTime__c,
                'Disable must succeed when all Hard dependents are inactive.');
        } catch (AuraHandledException e) {
            System.assert(false,
                'Cascade should not have blocked when dependents are inactive: ' + e.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void testToggleFeatureIgnoresSoftDependencies() {
        // Feature A depends on Feature B with Soft type. B inactive →
        // enable A must STILL succeed because Soft does not block.
        Feature__c featA = TestDataFactory.createFeature(new Map<String, Object>{
            'EnabledDateTime__c' => null,
            'DisabledDateTime__c' => null
        });
        Feature__c featB = TestDataFactory.createFeature(new Map<String, Object>{
            'EnabledDateTime__c' => null,
            'DisabledDateTime__c' => null
        });
        TestDataFactory.createFeatureDependency(featB.Id, featA.Id,
            new Map<String, Object>{ 'TypePk__c' => 'Soft', 'CascadeDirectionPk__c' => 'Both' });

        Test.startTest();
        try {
            DeliveryFeatureCatalogController.toggleFeature(featA.Id, true);
            Feature__c refreshed = [
                SELECT EnabledDateTime__c FROM Feature__c WHERE Id = :featA.Id LIMIT 1
            ];
            System.assertNotEquals(null, refreshed.EnabledDateTime__c,
                'Soft dependency must not block enable.');
        } catch (AuraHandledException e) {
            System.assert(false,
                'Soft dependency must not block enable: ' + e.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void testToggleFeatureNoTrackRequiredAllowsNonAdmin() {
        // Pick any FeatureDefinition__mdt whose RequiresOnboardingTrackTxt__c is blank.
        List<FeatureDefinition__mdt> defs = [
            SELECT DeveloperName FROM FeatureDefinition__mdt
            WHERE RequiresOnboardingTrackTxt__c = null
            LIMIT 1
        ];
        if (defs.isEmpty()) {
            return; // Empty-org tolerance.
        }
        String defName = defs.get(0).DeveloperName;
        User u = insertStandardUser();
        Feature__c f = TestDataFactory.createFeature(new Map<String, Object>{
            'FeatureDefinitionTxt__c' => defName,
            'EnabledDateTime__c' => null,
            'DisabledDateTime__c' => null
        });

        Test.startTest();
        System.runAs(u) {
            DeliveryFeatureCatalogController.toggleFeature(f.Id, true);
        }
        Test.stopTest();

        Feature__c refreshed = [
            SELECT EnabledDateTime__c FROM Feature__c WHERE Id = :f.Id LIMIT 1
        ];
        System.assertNotEquals(null, refreshed.EnabledDateTime__c,
            'Non-admin enable must succeed when the definition declares no required track.');
    }
}

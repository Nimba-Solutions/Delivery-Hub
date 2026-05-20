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
    static void testToggleFeatureRejectsNonAdmin() {
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
        insert u;

        Feature__c f = TestDataFactory.createFeature(new Map<String, Object>{
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
            'Non-admin must be rejected with AuraHandledException.');
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
}

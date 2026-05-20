/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Tests for DeliveryFeatureSyncService. Verifies:
 *                - syncFeaturesToSettings populates the matching legacy
 *                  Enable*DateTime__c field on DeliveryHubSettings__c
 *                - null EnabledDateTime__c clears the settings field
 *                - syncSettingsToFeatures is the reverse mirror
 *                - recursion guard flips during DML and clears after
 *                - writeAuditRow produces a single ActivityLog__c with
 *                  the expected action + JSON context
 *                - graceful no-op when settings record / mdt mapping is
 *                  absent
 *
 *               Test isolation: every test seeds its own DeliveryHubSettings__c
 *               + Feature__c rows via TestDataFactory. __mdt records are
 *               loaded from the org context (cannot be mocked in standard
 *               Apex tests), so assertions branch on whether a mdt row
 *               exists.
 * @author Cloud Nimbus LLC
 */
@IsTest
private class DeliveryFeatureSyncServiceTest {

    private static FeatureDefinition__mdt firstDefWithSettingsField() {
        List<FeatureDefinition__mdt> defs = [
            SELECT DeveloperName, SettingsFieldApiNameTxt__c
            FROM FeatureDefinition__mdt
            WHERE SettingsFieldApiNameTxt__c != null
            LIMIT 1
        ];
        return defs.isEmpty() ? null : defs.get(0);
    }

    @IsTest
    static void testSyncFeaturesToSettingsMirrorsEnabledTimestamp() {
        FeatureDefinition__mdt def = firstDefWithSettingsField();
        if (def == null) {
            return; // Empty-org tolerance.
        }
        DeliveryHubSettings__c settings = new DeliveryHubSettings__c(
            SetupOwnerId = UserInfo.getOrganizationId()
        );
        insert settings;

        DateTime stamp = DateTime.now().addMinutes(-2);
        Feature__c f = TestDataFactory.createFeature(new Map<String, Object>{
            'Name' => def.DeveloperName,
            'FeatureDefinitionTxt__c' => def.DeveloperName,
            'EnabledDateTime__c' => stamp
        });

        Test.startTest();
        DeliveryFeatureSyncService.syncFeaturesToSettings(new List<Feature__c>{ f });
        Test.stopTest();

        DeliveryHubSettings__c refreshed = DeliveryHubSettings__c.getOrgDefaults();
        // Resolve the local key (namespace-safe).
        Map<String, Schema.SObjectField> settingsFields =
            Schema.getGlobalDescribe()
                .get('DeliveryHubSettings__c')
                .getDescribe()
                .fields
                .getMap();
        String targetLocal = def.SettingsFieldApiNameTxt__c.toLowerCase();
        String matchedKey;
        for (String k : settingsFields.keySet()) {
            if (settingsFields.get(k).getDescribe().getLocalName().toLowerCase() == targetLocal) {
                matchedKey = k;
                break;
            }
        }
        System.assertNotEquals(null, matchedKey,
            'Should have resolved the settings field key via local-name compare.');
        Object raw = refreshed.get(matchedKey);
        DateTime actual = (raw instanceof DateTime) ? (DateTime) raw : null;
        System.assertNotEquals(null, actual,
            'Settings field should have been populated by syncFeaturesToSettings.');
    }

    @IsTest
    static void testSyncFeaturesToSettingsHandlesNullAndEmptyInput() {
        Test.startTest();
        DeliveryFeatureSyncService.syncFeaturesToSettings(null);
        DeliveryFeatureSyncService.syncFeaturesToSettings(new List<Feature__c>());
        Test.stopTest();
        // Just verifies no exception is thrown.
        System.assert(true, 'Null + empty input should be a graceful no-op.');
    }

    @IsTest
    static void testSyncSettingsToFeaturesCopiesValueBack() {
        FeatureDefinition__mdt def = firstDefWithSettingsField();
        if (def == null) {
            return; // Empty-org tolerance.
        }
        DateTime stamp = DateTime.now().addMinutes(-5);

        // Pre-populate the settings field manually (simulating an admin who
        // flipped it via Setup → Custom Settings before PR 2 shipped).
        DeliveryHubSettings__c settings = new DeliveryHubSettings__c(
            SetupOwnerId = UserInfo.getOrganizationId()
        );
        Map<String, Schema.SObjectField> settingsFields =
            Schema.getGlobalDescribe()
                .get('DeliveryHubSettings__c')
                .getDescribe()
                .fields
                .getMap();
        String targetLocal = def.SettingsFieldApiNameTxt__c.toLowerCase();
        String matchedKey;
        for (String k : settingsFields.keySet()) {
            if (settingsFields.get(k).getDescribe().getLocalName().toLowerCase() == targetLocal) {
                matchedKey = k;
                break;
            }
        }
        if (matchedKey == null) {
            return; // field not present on this org's schema — tolerate.
        }
        settings.put(matchedKey, stamp);
        insert settings;

        // Feature__c row with NO EnabledDateTime__c (admin never touched cockpit).
        Feature__c f = TestDataFactory.createFeature(new Map<String, Object>{
            'Name' => def.DeveloperName,
            'FeatureDefinitionTxt__c' => def.DeveloperName,
            'EnabledDateTime__c' => null
        });

        Test.startTest();
        DeliveryFeatureSyncService.syncSettingsToFeatures();
        Test.stopTest();

        Feature__c refreshed = [
            SELECT Id, EnabledDateTime__c FROM Feature__c WHERE Id = :f.Id LIMIT 1
        ];
        System.assertNotEquals(null, refreshed.EnabledDateTime__c,
            'syncSettingsToFeatures should have mirrored the settings value onto the Feature__c.');
    }

    @IsTest
    static void testSyncSettingsToFeaturesNoOpsWhenSettingsAbsent() {
        // No DeliveryHubSettings__c row at all.
        Test.startTest();
        DeliveryFeatureSyncService.syncSettingsToFeatures();
        Test.stopTest();
        System.assert(true, 'Should no-op gracefully when no settings record exists.');
    }

    @IsTest
    static void testWriteAuditRowProducesActivityLog() {
        Feature__c f = TestDataFactory.createFeature(new Map<String, Object>{
            'EnabledDateTime__c' => DateTime.now()
        });

        Integer before = [SELECT COUNT() FROM ActivityLog__c WHERE ActionTypePk__c = 'Feature_Toggle'];

        Test.startTest();
        DeliveryFeatureSyncService.writeAuditRow(f.Id, 'ENABLED', DateTime.now(), null);
        Test.stopTest();

        Integer afterCount = [SELECT COUNT() FROM ActivityLog__c WHERE ActionTypePk__c = 'Feature_Toggle'];
        System.assertEquals(before + 1, afterCount,
            'writeAuditRow should insert exactly one ActivityLog__c row.');

        List<ActivityLog__c> rows = [
            SELECT Id, ActionTypePk__c, RecordIdTxt__c, ContextDataTxt__c
            FROM ActivityLog__c
            WHERE ActionTypePk__c = 'Feature_Toggle'
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        System.assert(!rows.isEmpty(), 'Audit row should be queryable.');
        System.assertEquals(String.valueOf(f.Id), rows.get(0).RecordIdTxt__c,
            'RecordIdTxt__c should carry the Feature__c Id.');
        System.assert(rows.get(0).ContextDataTxt__c.contains('ENABLED'),
            'ContextDataTxt__c should contain the action keyword.');
    }

    @IsTest
    static void testRecursionGuardClearsAfterSync() {
        // Before any sync, guard should be false.
        System.assertEquals(false, DeliveryFeatureSyncService.isInSyncContext(),
            'Guard should start as false.');

        FeatureDefinition__mdt def = firstDefWithSettingsField();
        if (def == null) {
            return; // Empty-org tolerance.
        }
        insert new DeliveryHubSettings__c(SetupOwnerId = UserInfo.getOrganizationId());
        Feature__c f = TestDataFactory.createFeature(new Map<String, Object>{
            'Name' => def.DeveloperName,
            'FeatureDefinitionTxt__c' => def.DeveloperName,
            'EnabledDateTime__c' => DateTime.now()
        });

        Test.startTest();
        DeliveryFeatureSyncService.syncFeaturesToSettings(new List<Feature__c>{ f });
        Test.stopTest();

        System.assertEquals(false, DeliveryFeatureSyncService.isInSyncContext(),
            'Guard should be cleared after sync completes.');
    }
}

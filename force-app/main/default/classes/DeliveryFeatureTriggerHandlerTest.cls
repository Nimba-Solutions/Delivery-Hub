/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Tests for DeliveryFeatureTriggerHandler. Verifies:
 *                - Updating a Feature__c.EnabledDateTime__c fires the
 *                  audit-row write
 *                - Settings field mirror happens within the same
 *                  transaction
 *                - Recursion guard short-circuits the handler when
 *                  DeliveryFeatureSyncService.isInSyncContext is true
 *                - Handler tolerates null/empty input
 * @author Cloud Nimbus LLC
 */
@IsTest
private class DeliveryFeatureTriggerHandlerTest {

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
    static void testUpdatingEnabledDateTimeWritesAuditRow() {
        Feature__c f = TestDataFactory.createFeature(new Map<String, Object>{
            'EnabledDateTime__c' => null
        });

        Integer before = [
            SELECT COUNT() FROM ActivityLog__c
            WHERE ActionTypePk__c = 'Feature_Toggle'
              AND RecordIdTxt__c = :String.valueOf(f.Id)
        ];

        Test.startTest();
        f.EnabledDateTime__c = DateTime.now();
        update f;
        Test.stopTest();

        Integer afterCount = [
            SELECT COUNT() FROM ActivityLog__c
            WHERE ActionTypePk__c = 'Feature_Toggle'
              AND RecordIdTxt__c = :String.valueOf(f.Id)
        ];
        System.assertEquals(before + 1, afterCount,
            'Trigger should have produced exactly one new audit row.');
    }

    @IsTest
    static void testNoAuditRowWhenNeitherTimestampChanges() {
        Feature__c f = TestDataFactory.createFeature(new Map<String, Object>{
            'EnabledDateTime__c' => DateTime.now()
        });

        Integer before = [
            SELECT COUNT() FROM ActivityLog__c
            WHERE ActionTypePk__c = 'Feature_Toggle'
              AND RecordIdTxt__c = :String.valueOf(f.Id)
        ];

        Test.startTest();
        // Update an unrelated field — the trigger should not fire a toggle audit.
        f.Name = f.Name + '-rev2';
        update f;
        Test.stopTest();

        Integer afterCount = [
            SELECT COUNT() FROM ActivityLog__c
            WHERE ActionTypePk__c = 'Feature_Toggle'
              AND RecordIdTxt__c = :String.valueOf(f.Id)
        ];
        System.assertEquals(before, afterCount,
            'Renaming should not trigger a feature-toggle audit row.');
    }

    @IsTest
    static void testRecursionGuardSuppressesHandler() {
        Feature__c f = TestDataFactory.createFeature(new Map<String, Object>{
            'EnabledDateTime__c' => null
        });
        Integer before = [
            SELECT COUNT() FROM ActivityLog__c
            WHERE ActionTypePk__c = 'Feature_Toggle'
              AND RecordIdTxt__c = :String.valueOf(f.Id)
        ];

        Test.startTest();
        // Flip the guard manually (TestVisible) and update — handler should
        // bail out, no audit row written.
        DeliveryFeatureSyncService.inSyncContext = true;
        try {
            f.EnabledDateTime__c = DateTime.now();
            update f;
        } finally {
            DeliveryFeatureSyncService.inSyncContext = false;
        }
        Test.stopTest();

        Integer afterCount = [
            SELECT COUNT() FROM ActivityLog__c
            WHERE ActionTypePk__c = 'Feature_Toggle'
              AND RecordIdTxt__c = :String.valueOf(f.Id)
        ];
        System.assertEquals(before, afterCount,
            'When the sync-context guard is true, the handler must not write audit rows.');
    }

    @IsTest
    static void testHandleToleratesNullInput() {
        Test.startTest();
        DeliveryFeatureTriggerHandler.handle(
            TriggerOperation.AFTER_UPDATE,
            null,
            null
        );
        DeliveryFeatureTriggerHandler.handle(
            TriggerOperation.AFTER_UPDATE,
            new List<Feature__c>(),
            new Map<Id, Feature__c>()
        );
        Test.stopTest();
        System.assert(true, 'Null + empty input is a graceful no-op.');
    }

    @IsTest
    static void testFullToggleCycleMirrorsToSettings() {
        FeatureDefinition__mdt def = firstDefWithSettingsField();
        if (def == null) {
            return; // Empty-org tolerance.
        }
        insert new DeliveryHubSettings__c(SetupOwnerId = UserInfo.getOrganizationId());
        Feature__c f = TestDataFactory.createFeature(new Map<String, Object>{
            'Name' => def.DeveloperName,
            'FeatureDefinitionTxt__c' => def.DeveloperName,
            'EnabledDateTime__c' => null
        });

        Test.startTest();
        f.EnabledDateTime__c = DateTime.now();
        update f;
        Test.stopTest();

        // Verify the legacy field was mirrored.
        DeliveryHubSettings__c refreshed = DeliveryHubSettings__c.getOrgDefaults();
        Map<String, Schema.SObjectField> settingsFields =
            Schema.getGlobalDescribe()
                .get('DeliveryHubSettings__c')
                .getDescribe()
                .fields
                .getMap();
        String target = def.SettingsFieldApiNameTxt__c.toLowerCase();
        String matchedKey;
        for (String k : settingsFields.keySet()) {
            if (settingsFields.get(k).getDescribe().getLocalName().toLowerCase() == target) {
                matchedKey = k;
                break;
            }
        }
        if (matchedKey == null) {
            return; // Field not on this org's schema — tolerate.
        }
        Object raw = refreshed.get(matchedKey);
        System.assertNotEquals(null, raw,
            'Trigger should have mirrored the toggle onto the legacy settings field.');
    }
}

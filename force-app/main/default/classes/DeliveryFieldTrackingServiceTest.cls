/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Test class for DeliveryFieldTrackingService.
 *               Calls trackChanges() directly with constructed old/new maps
 *               to test the service in isolation from trigger wiring.
 * @author Cloud Nimbus LLC
 */
@IsTest
private class DeliveryFieldTrackingServiceTest {

    @TestSetup
    static void setupData() {
        // Enable both activity logging and field tracking
        DeliveryHubSettings__c settings = DeliveryHubSettings__c.getOrgDefaults();
        settings.EnableActivityLoggingBool__c = true;
        settings.EnableFieldTrackingBool__c = true;
        upsert settings;

        // Disable after-trigger logic to avoid sync engine side effects during setup
        DeliveryTriggerControl.disableAfterLogic();

        WorkItem__c workItem = new WorkItem__c(
            BriefDescriptionTxt__c = 'Field Tracking Test Item',
            StageNamePk__c = 'Backlog',
            PriorityPk__c = 'Medium',
            StatusPk__c = 'New'
        );
        insert workItem;

        DeliveryTriggerControl.enableAfterLogic();
    }

    // ── 1. Tracking enabled: verify ActivityLog created for tracked field ──

    @IsTest
    static void testTrackingEnabledCreatesActivityLog() {
        WorkItem__c workItem = [
            SELECT Id, PriorityPk__c, StageNamePk__c, StatusPk__c, Developer__c
            FROM WorkItem__c
            LIMIT 1
        ];

        // Build old record with original values
        WorkItem__c oldRecord = workItem.clone(true, true, true, true);

        // Simulate field change
        workItem.PriorityPk__c = 'High';

        List<SObject> newRecords = new List<SObject>{ workItem };
        Map<Id, SObject> oldMap = new Map<Id, SObject>{ oldRecord.Id => oldRecord };

        DeliveryFieldTrackingService.clearCache();

        Test.startTest();
        DeliveryFieldTrackingService.trackChanges(newRecords, oldMap);
        Test.stopTest();

        List<ActivityLog__c> logs = [
            SELECT ActionTypePk__c, ComponentNameTxt__c, RecordIdTxt__c, ContextDataTxt__c
            FROM ActivityLog__c
            WHERE ActionTypePk__c = 'Field_Change'
              AND ComponentNameTxt__c = 'PriorityPk__c'
            WITH SYSTEM_MODE
        ];
        System.assert(!logs.isEmpty(), 'At least one Field_Change log should be created for a tracked field');
        System.assertEquals(workItem.Id, logs[0].RecordIdTxt__c, 'Log should reference the updated work item');
        System.assert(logs[0].ContextDataTxt__c.contains('Priority'),
            'Context should contain the field label');
    }

    // ── 2. Tracking disabled: verify no ActivityLog created ──

    @IsTest
    static void testTrackingDisabledNoActivityLog() {
        DeliveryHubSettings__c settings = DeliveryHubSettings__c.getOrgDefaults();
        settings.EnableFieldTrackingBool__c = false;
        upsert settings;

        WorkItem__c workItem = [
            SELECT Id, PriorityPk__c, StageNamePk__c, StatusPk__c, Developer__c
            FROM WorkItem__c
            LIMIT 1
        ];

        WorkItem__c oldRecord = workItem.clone(true, true, true, true);
        workItem.PriorityPk__c = 'High';

        DeliveryFieldTrackingService.clearCache();

        Test.startTest();
        DeliveryFieldTrackingService.trackChanges(
            new List<SObject>{ workItem },
            new Map<Id, SObject>{ oldRecord.Id => oldRecord }
        );
        Test.stopTest();

        List<ActivityLog__c> logs = [
            SELECT Id FROM ActivityLog__c
            WHERE ActionTypePk__c = 'Field_Change'
            WITH SYSTEM_MODE
        ];
        System.assertEquals(0, logs.size(), 'No Field_Change logs should be created when tracking is disabled');
    }

    // ── 3. Untracked field: verify no ActivityLog created ──

    @IsTest
    static void testUntrackedFieldNoActivityLog() {
        WorkItem__c workItem = [
            SELECT Id, BriefDescriptionTxt__c, PriorityPk__c, StageNamePk__c, StatusPk__c, Developer__c
            FROM WorkItem__c
            LIMIT 1
        ];

        WorkItem__c oldRecord = workItem.clone(true, true, true, true);
        workItem.BriefDescriptionTxt__c = 'Updated description not tracked';

        DeliveryFieldTrackingService.clearCache();

        Test.startTest();
        DeliveryFieldTrackingService.trackChanges(
            new List<SObject>{ workItem },
            new Map<Id, SObject>{ oldRecord.Id => oldRecord }
        );
        Test.stopTest();

        List<ActivityLog__c> logs = [
            SELECT Id FROM ActivityLog__c
            WHERE ActionTypePk__c = 'Field_Change'
              AND ComponentNameTxt__c = 'BriefDescriptionTxt__c'
            WITH SYSTEM_MODE
        ];
        System.assertEquals(0, logs.size(),
            'No Field_Change log should be created for an untracked field');
    }

    // ── 4. Multiple field changes in one update ──

    @IsTest
    static void testMultipleFieldChangesCreateMultipleLogs() {
        WorkItem__c workItem = [
            SELECT Id, PriorityPk__c, StatusPk__c, StageNamePk__c, Developer__c
            FROM WorkItem__c
            LIMIT 1
        ];

        WorkItem__c oldRecord = workItem.clone(true, true, true, true);
        workItem.PriorityPk__c = 'Critical';
        workItem.StageNamePk__c = 'In Development';

        DeliveryFieldTrackingService.clearCache();

        Test.startTest();
        DeliveryFieldTrackingService.trackChanges(
            new List<SObject>{ workItem },
            new Map<Id, SObject>{ oldRecord.Id => oldRecord }
        );
        Test.stopTest();

        List<ActivityLog__c> logs = [
            SELECT ComponentNameTxt__c
            FROM ActivityLog__c
            WHERE ActionTypePk__c = 'Field_Change'
              AND RecordIdTxt__c = :workItem.Id
            WITH SYSTEM_MODE
        ];
        System.assert(logs.size() >= 2,
            'At least two Field_Change logs should be created for two tracked field changes, got: ' + logs.size());
    }

    // ── 5. Null inputs handled gracefully ──

    @IsTest
    static void testNullInputsDoNotThrow() {
        Test.startTest();
        DeliveryFieldTrackingService.trackChanges(null, null);
        DeliveryFieldTrackingService.trackChanges(new List<SObject>(), null);
        DeliveryFieldTrackingService.trackChanges(
            new List<SObject>(),
            new Map<Id, SObject>()
        );
        Test.stopTest();

        System.assert(true, 'Null/empty inputs should be handled gracefully');
    }
}

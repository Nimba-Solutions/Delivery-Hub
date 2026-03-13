/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Test class for DeliveryFieldTrackingService.
 *               Verifies trigger-driven field change tracking via TrackedField__mdt,
 *               including enabled/disabled gates, tracked vs untracked fields,
 *               and multi-field change detection.
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

        // Disable after-trigger logic to avoid sync engine side effects
        DeliveryTriggerControl.disableAfterLogic();

        WorkItem__c workItem = new WorkItem__c(
            BriefDescriptionTxt__c = 'Field Tracking Test Item',
            StageNamePk__c = 'Backlog',
            PriorityPk__c = 'Medium',
            StatusPk__c = 'Active'
        );
        insert workItem;

        DeliveryTriggerControl.enableAfterLogic();
    }

    // ── 1. Tracking enabled: update a tracked field, verify ActivityLog created ──

    @IsTest
    static void testTrackingEnabledCreatesActivityLog() {
        WorkItem__c workItem = [
            SELECT Id, PriorityPk__c
            FROM WorkItem__c
            LIMIT 1
        ];

        Test.startTest();
        workItem.PriorityPk__c = 'High';
        update workItem;
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
        // Disable field tracking
        DeliveryHubSettings__c settings = DeliveryHubSettings__c.getOrgDefaults();
        settings.EnableFieldTrackingBool__c = false;
        upsert settings;

        WorkItem__c workItem = [
            SELECT Id, PriorityPk__c
            FROM WorkItem__c
            LIMIT 1
        ];

        // Delete any pre-existing Field_Change logs
        List<ActivityLog__c> existingLogs = [
            SELECT Id FROM ActivityLog__c
            WHERE ActionTypePk__c = 'Field_Change'
            WITH SYSTEM_MODE
        ];
        if (!existingLogs.isEmpty()) {
            delete existingLogs;
        }

        Test.startTest();
        workItem.PriorityPk__c = 'High';
        update workItem;
        Test.stopTest();

        List<ActivityLog__c> logs = [
            SELECT Id FROM ActivityLog__c
            WHERE ActionTypePk__c = 'Field_Change'
              AND ComponentNameTxt__c = 'PriorityPk__c'
            WITH SYSTEM_MODE
        ];
        System.assertEquals(0, logs.size(), 'No Field_Change logs should be created when tracking is disabled');
    }

    // ── 3. Field not tracked: verify no ActivityLog created ──

    @IsTest
    static void testUntrackedFieldNoActivityLog() {
        WorkItem__c workItem = [
            SELECT Id, BriefDescriptionTxt__c
            FROM WorkItem__c
            LIMIT 1
        ];

        // Delete any pre-existing Field_Change logs
        List<ActivityLog__c> existingLogs = [
            SELECT Id FROM ActivityLog__c
            WHERE ActionTypePk__c = 'Field_Change'
            WITH SYSTEM_MODE
        ];
        if (!existingLogs.isEmpty()) {
            delete existingLogs;
        }

        Test.startTest();
        workItem.BriefDescriptionTxt__c = 'Updated description not tracked';
        update workItem;
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
            SELECT Id, PriorityPk__c, StatusPk__c
            FROM WorkItem__c
            LIMIT 1
        ];

        // Delete any pre-existing Field_Change logs
        List<ActivityLog__c> existingLogs = [
            SELECT Id FROM ActivityLog__c
            WHERE ActionTypePk__c = 'Field_Change'
            WITH SYSTEM_MODE
        ];
        if (!existingLogs.isEmpty()) {
            delete existingLogs;
        }

        Test.startTest();
        workItem.PriorityPk__c = 'Critical';
        workItem.StatusPk__c = 'Inactive';
        update workItem;
        Test.stopTest();

        List<ActivityLog__c> logs = [
            SELECT ComponentNameTxt__c
            FROM ActivityLog__c
            WHERE ActionTypePk__c = 'Field_Change'
              AND RecordIdTxt__c = :workItem.Id
              AND ComponentNameTxt__c IN ('PriorityPk__c', 'StatusPk__c')
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

        // If we reach here without exception, the test passes
        System.assert(true, 'Null/empty inputs should be handled gracefully');
    }
}

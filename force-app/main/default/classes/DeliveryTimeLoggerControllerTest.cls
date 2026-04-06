/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Test class for DeliveryTimeLoggerController.
 * @author Cloud Nimbus LLC
 */
@isTest
private class DeliveryTimeLoggerControllerTest {

    private static User testUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];

    /**
     * @description Creates a Work Item and an Accepted Request so the controller
     *              can auto-link WorkLog records.
     */
    @TestSetup
    static void setup() {
        NetworkEntity__c vendor = new NetworkEntity__c(
            Name = 'Test Vendor', EntityTypePk__c = 'Vendor', StatusPk__c = 'Active'
        );
        insert vendor;

        WorkItem__c t = new WorkItem__c(BriefDescriptionTxt__c = 'Logger Work Item', StageNamePk__c = 'In Development');
        insert t;

        insert new WorkRequest__c(
            WorkItemId__c           = t.Id,
            DeliveryEntityId__c   = vendor.Id,
            QuotedHoursNumber__c  = 10,
            HourlyRateCurrency__c = 100,
            StatusPk__c           = 'Accepted'
        );
    }

    /**
     * @description Verifies that logHours inserts a WorkLog__c record linked
     *              to the accepted Request and the workItem.
     */
    @isTest
    static void testLogHoursCreatesWorkLog() {
        System.runAs(testUser) {
            WorkItem__c t = [SELECT Id FROM WorkItem__c LIMIT 1];

            Test.startTest();
            DeliveryTimeLoggerController.logHours(t.Id, 2.5, 'Test work notes', null);
            Test.stopTest();

            List<WorkLog__c> logs = [
                SELECT HoursLoggedNumber__c, WorkItemId__c, WorkDateDate__c, RequestId__c
                FROM WorkLog__c
                WHERE WorkItemId__c = :t.Id
            ];
            System.assertEquals(1, logs.size(), 'Expected one WorkLog record');
            System.assertEquals(2.5, logs[0].HoursLoggedNumber__c, 'Expected 2.5 hours');
            System.assertEquals(Date.today(), logs[0].WorkDateDate__c, 'Expected today\'s date');
            System.assertNotEquals(null, logs[0].RequestId__c, 'WorkLog should be linked to the accepted request');
        }
    }

    /**
     * @description Verifies fractional hour increments are stored correctly.
     */
    @isTest
    static void testLogHoursFractional() {
        System.runAs(testUser) {
            WorkItem__c t = [SELECT Id FROM WorkItem__c LIMIT 1];

            Test.startTest();
            DeliveryTimeLoggerController.logHours(t.Id, 0.25, null, null);
            Test.stopTest();

            List<WorkLog__c> logs = [SELECT HoursLoggedNumber__c FROM WorkLog__c WHERE WorkItemId__c = :t.Id];
            System.assertEquals(1, logs.size(), 'Expected one WorkLog record');
            System.assertEquals(0.25, logs[0].HoursLoggedNumber__c, 'Expected 0.25 hours');
        }
    }

    /**
     * @description Verifies multiple logHours calls each create their own WorkLog__c record.
     */
    @isTest
    static void testLogHoursMultipleEntries() {
        System.runAs(testUser) {
            WorkItem__c t = [SELECT Id FROM WorkItem__c LIMIT 1];

            Test.startTest();
            DeliveryTimeLoggerController.logHours(t.Id, 1.0, 'Morning session', null);
            DeliveryTimeLoggerController.logHours(t.Id, 3.0, 'Afternoon session', null);
            Test.stopTest();

            List<WorkLog__c> logs = [SELECT HoursLoggedNumber__c FROM WorkLog__c WHERE WorkItemId__c = :t.Id];
            System.assertEquals(2, logs.size(), 'Expected two WorkLog records');
        }
    }

    /**
     * @description Verifies that logHours throws when no accepted request exists.
     */
    @isTest
    static void testLogHoursNoRequestThrows() {
        System.runAs(testUser) {
            WorkItem__c noReqWorkItem = new WorkItem__c(BriefDescriptionTxt__c = 'No Request', StageNamePk__c = 'Backlog');
            insert noReqWorkItem;

            // Delete any auto-created WorkRequests (AutoCreateWorkRequest may fire in namespaced context)
            List<WorkRequest__c> autoCreated = [SELECT Id FROM WorkRequest__c WHERE WorkItemId__c = :noReqWorkItem.Id];
            if (!autoCreated.isEmpty()) {
                delete autoCreated;
            }

            Test.startTest();
            try {
                DeliveryTimeLoggerController.logHours(noReqWorkItem.Id, 1.0, 'Should fail', null);
                System.assert(false, 'Should have thrown AuraHandledException');
            } catch (AuraHandledException e) {
                System.assert(true, 'Correctly threw when no accepted request exists');
            }
            Test.stopTest();
        }
    }

    /**
     * @description Verifies that logHours uses an explicit work date when provided.
     */
    @isTest
    static void testLogHoursWithExplicitWorkDate() {
        System.runAs(testUser) {
            WorkItem__c t = [SELECT Id FROM WorkItem__c LIMIT 1];
            Date pastDate = Date.newInstance(2026, 1, 15);

            Test.startTest();
            DeliveryTimeLoggerController.logHours(t.Id, 3.0, 'Past work', pastDate);
            Test.stopTest();

            List<WorkLog__c> logs = [
                SELECT HoursLoggedNumber__c, WorkDateDate__c, WorkDescriptionTxt__c
                FROM WorkLog__c
                WHERE WorkItemId__c = :t.Id
            ];
            System.assertEquals(1, logs.size(), 'Expected one WorkLog record');
            System.assertEquals(pastDate, logs[0].WorkDateDate__c, 'Work date should be the explicit date provided');
            System.assertEquals(3.0, logs[0].HoursLoggedNumber__c, 'Hours should match');
            System.assertEquals('Past work', logs[0].WorkDescriptionTxt__c, 'Notes should match');
        }
    }

    /**
     * @description Verifies that null notes are stored without error.
     */
    @isTest
    static void testLogHoursNullNotesSavedSuccessfully() {
        System.runAs(testUser) {
            WorkItem__c t = [SELECT Id FROM WorkItem__c LIMIT 1];

            Test.startTest();
            DeliveryTimeLoggerController.logHours(t.Id, 1.5, null, null);
            Test.stopTest();

            List<WorkLog__c> logs = [
                SELECT WorkDescriptionTxt__c
                FROM WorkLog__c
                WHERE WorkItemId__c = :t.Id
            ];
            System.assertEquals(1, logs.size(), 'Expected one WorkLog record');
            System.assertEquals(null, logs[0].WorkDescriptionTxt__c, 'Notes should be null when none provided');
        }
    }

    /**
     * @description Verifies isApprovalRequired returns false by default (no setting).
     */
    @isTest
    static void testIsApprovalRequiredDefaultsFalse() {
        System.runAs(testUser) {
            Test.startTest();
            Boolean result = DeliveryTimeLoggerController.isApprovalRequired();
            Test.stopTest();

            System.assertEquals(false, result, 'Approval should not be required by default');
        }
    }

    /**
     * @description Verifies isApprovalRequired returns true when setting is enabled.
     */
    @isTest
    static void testIsApprovalRequiredTrueWhenSet() {
        System.runAs(testUser) {
            DeliveryHubSettings__c settings = DeliveryHubSettings__c.getOrgDefaults();
            settings.RequireWorkLogApprovalDateTime__c = Datetime.now();
            upsert settings;

            Test.startTest();
            Boolean result = DeliveryTimeLoggerController.isApprovalRequired();
            Test.stopTest();

            System.assertEquals(true, result, 'Approval should be required when setting is enabled');
        }
    }

    /**
     * @description Verifies that logHours saves as Draft when approval is required.
     */
    @isTest
    static void testLogHoursDraftWhenApprovalRequired() {
        System.runAs(testUser) {
            DeliveryHubSettings__c settings = DeliveryHubSettings__c.getOrgDefaults();
            settings.RequireWorkLogApprovalDateTime__c = Datetime.now();
            upsert settings;

            WorkItem__c t = [SELECT Id FROM WorkItem__c LIMIT 1];

            Test.startTest();
            DeliveryTimeLoggerController.logHours(t.Id, 2.0, 'Draft entry', null);
            Test.stopTest();

            List<WorkLog__c> logs = [
                SELECT StatusPk__c
                FROM WorkLog__c
                WHERE WorkItemId__c = :t.Id
            ];
            System.assertEquals(1, logs.size(), 'Expected one WorkLog record');
            System.assertEquals('Draft', logs[0].StatusPk__c, 'WorkLog should be Draft when approval is required');
        }
    }

    /**
     * @description Verifies approveWorkLogs transitions Draft logs to Approved.
     */
    @isTest
    static void testApproveWorkLogsDraftToApproved() {
        System.runAs(testUser) {
            DeliveryHubSettings__c settings = DeliveryHubSettings__c.getOrgDefaults();
            settings.RequireWorkLogApprovalDateTime__c = Datetime.now();
            upsert settings;

            WorkItem__c t = [SELECT Id FROM WorkItem__c LIMIT 1];
            DeliveryTimeLoggerController.logHours(t.Id, 1.0, 'To approve', null);

            WorkLog__c log = [SELECT Id, StatusPk__c FROM WorkLog__c WHERE WorkItemId__c = :t.Id LIMIT 1];
            System.assertEquals('Draft', log.StatusPk__c, 'Precondition: should be Draft');

            Test.startTest();
            DeliveryTimeLoggerController.approveWorkLogs(new List<Id>{ log.Id });
            Test.stopTest();

            WorkLog__c updated = [SELECT StatusPk__c FROM WorkLog__c WHERE Id = :log.Id];
            System.assertEquals('Approved', updated.StatusPk__c, 'WorkLog should be Approved after approval');
        }
    }

    /**
     * @description Verifies rejectWorkLogs transitions Draft logs to Rejected.
     */
    @isTest
    static void testRejectWorkLogsDraftToRejected() {
        System.runAs(testUser) {
            DeliveryHubSettings__c settings = DeliveryHubSettings__c.getOrgDefaults();
            settings.RequireWorkLogApprovalDateTime__c = Datetime.now();
            upsert settings;

            WorkItem__c t = [SELECT Id FROM WorkItem__c LIMIT 1];
            DeliveryTimeLoggerController.logHours(t.Id, 1.0, 'To reject', null);

            WorkLog__c log = [SELECT Id, StatusPk__c FROM WorkLog__c WHERE WorkItemId__c = :t.Id LIMIT 1];
            System.assertEquals('Draft', log.StatusPk__c, 'Precondition: should be Draft');

            Test.startTest();
            DeliveryTimeLoggerController.rejectWorkLogs(new List<Id>{ log.Id });
            Test.stopTest();

            WorkLog__c updated = [SELECT StatusPk__c FROM WorkLog__c WHERE Id = :log.Id];
            System.assertEquals('Rejected', updated.StatusPk__c, 'WorkLog should be Rejected after rejection');
        }
    }

    /**
     * @description Verifies approveWorkLogs skips already-approved logs (no DML error).
     */
    @isTest
    static void testApproveWorkLogsSkipsAlreadyApproved() {
        System.runAs(testUser) {
            WorkItem__c t = [SELECT Id FROM WorkItem__c LIMIT 1];
            // Default (no approval required) creates Approved logs
            DeliveryTimeLoggerController.logHours(t.Id, 1.0, 'Already approved', null);

            WorkLog__c log = [SELECT Id, StatusPk__c FROM WorkLog__c WHERE WorkItemId__c = :t.Id LIMIT 1];
            System.assertEquals('Approved', log.StatusPk__c, 'Precondition: should already be Approved');

            Test.startTest();
            // Should not throw — the query filters WHERE StatusPk__c = 'Draft', so 0 records to update
            DeliveryTimeLoggerController.approveWorkLogs(new List<Id>{ log.Id });
            Test.stopTest();

            WorkLog__c unchanged = [SELECT StatusPk__c FROM WorkLog__c WHERE Id = :log.Id];
            System.assertEquals('Approved', unchanged.StatusPk__c, 'Status should remain Approved');
        }
    }

    /**
     * @description Verifies approveWorkLogs handles null input gracefully.
     */
    @isTest
    static void testApproveWorkLogsNullInput() {
        System.runAs(testUser) {
            Test.startTest();
            DeliveryTimeLoggerController.approveWorkLogs(null);
            Test.stopTest();
            // No exception = pass
            System.assert(true, 'Should handle null input without error');
        }
    }

    /**
     * @description Verifies rejectWorkLogs handles empty list gracefully.
     */
    @isTest
    static void testRejectWorkLogsEmptyList() {
        System.runAs(testUser) {
            Test.startTest();
            DeliveryTimeLoggerController.rejectWorkLogs(new List<Id>());
            Test.stopTest();
            // No exception = pass
            System.assert(true, 'Should handle empty list without error');
        }
    }

    /**
     * @description Verifies rejectWorkLogs handles null input gracefully.
     */
    @isTest
    static void testRejectWorkLogsNullInput() {
        System.runAs(testUser) {
            Test.startTest();
            DeliveryTimeLoggerController.rejectWorkLogs(null);
            Test.stopTest();
            // No exception = pass
            System.assert(true, 'Should handle null input without error');
        }
    }
}

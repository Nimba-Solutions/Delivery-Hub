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
            DeliveryEntityLookup__c   = vendor.Id,
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
                SELECT HoursLoggedNumber__c, WorkItemLookup__c, WorkDateDate__c, RequestId__c
                FROM WorkLog__c
                WHERE WorkItemLookup__c = :t.Id
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

            List<WorkLog__c> logs = [SELECT HoursLoggedNumber__c FROM WorkLog__c WHERE WorkItemLookup__c = :t.Id];
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

            List<WorkLog__c> logs = [SELECT HoursLoggedNumber__c FROM WorkLog__c WHERE WorkItemLookup__c = :t.Id];
            System.assertEquals(2, logs.size(), 'Expected two WorkLog records');
        }
    }

    /**
     * @description Soft gate: with no request at all, logHours creates a Draft
     *              request (against the Active Vendor) and saves the hours
     *              instead of refusing.
     */
    @isTest
    static void testLogHoursNoRequestCreatesDraftRequest() {
        System.runAs(testUser) {
            WorkItem__c noReqWorkItem = new WorkItem__c(BriefDescriptionTxt__c = 'No Request', StageNamePk__c = 'Backlog');
            insert noReqWorkItem;
            delete [SELECT Id FROM WorkRequest__c WHERE WorkItemId__c = :noReqWorkItem.Id];

            Test.startTest();
            DeliveryTimeLoggerController.logHours(noReqWorkItem.Id, 1.0, 'Soft gate', null);
            Test.stopTest();

            WorkLog__c log = [
                SELECT HoursLoggedNumber__c, RequestId__r.StatusPk__c, RequestId__r.DeliveryEntityLookup__r.Name
                FROM WorkLog__c WHERE WorkItemLookup__c = :noReqWorkItem.Id
            ];
            System.assertEquals(1.0, log.HoursLoggedNumber__c, 'hours must be saved even with nothing approved');
            System.assertEquals('Draft', log.RequestId__r.StatusPk__c, 'a Draft request is created on demand');
            System.assertEquals('Test Vendor', log.RequestId__r.DeliveryEntityLookup__r.Name,
                'the on-demand request uses the oldest Active Vendor');
        }
    }

    /**
     * @description Request selection: an existing Draft is reused when nothing
     *              is Accepted; once a request is Accepted, new logs go there.
     */
    @isTest
    static void testLogHoursPrefersAcceptedThenDraft() {
        System.runAs(testUser) {
            NetworkEntity__c vendor = [SELECT Id FROM NetworkEntity__c WHERE Name = 'Test Vendor' LIMIT 1];
            WorkItem__c wi = new WorkItem__c(BriefDescriptionTxt__c = 'Pick Request', StageNamePk__c = 'Backlog');
            insert wi;
            delete [SELECT Id FROM WorkRequest__c WHERE WorkItemId__c = :wi.Id];
            WorkRequest__c draft = new WorkRequest__c(
                WorkItemId__c = wi.Id, DeliveryEntityLookup__c = vendor.Id, StatusPk__c = 'Draft'
            );
            insert draft;

            Test.startTest();
            DeliveryTimeLoggerController.logHours(wi.Id, 1.0, 'On the draft', null);
            WorkRequest__c accepted = new WorkRequest__c(
                WorkItemId__c = wi.Id, DeliveryEntityLookup__c = vendor.Id, StatusPk__c = 'Accepted'
            );
            insert accepted;
            DeliveryTimeLoggerController.logHours(wi.Id, 2.0, 'On the accepted', null);
            Test.stopTest();

            System.assertEquals(1, [SELECT COUNT() FROM WorkLog__c WHERE RequestId__c = :draft.Id],
                'with nothing accepted the newest Draft is reused (no new request)');
            System.assertEquals(1, [SELECT COUNT() FROM WorkLog__c WHERE RequestId__c = :accepted.Id],
                'an Accepted request wins once it exists');
            System.assertEquals(2, [SELECT COUNT() FROM WorkRequest__c WHERE WorkItemId__c = :wi.Id],
                'no extra requests were created');
        }
    }

    /**
     * @description Zero, negative and null hours are rejected.
     */
    @isTest
    static void testLogHoursRejectsNonPositiveHours() {
        System.runAs(testUser) {
            WorkItem__c t = [SELECT Id FROM WorkItem__c WHERE BriefDescriptionTxt__c = 'Logger Work Item' LIMIT 1];
            Integer rejected = 0;
            Test.startTest();
            for (Decimal bad : new List<Decimal>{ null, 0, -1 }) {
                try {
                    DeliveryTimeLoggerController.logHours(t.Id, bad, 'bad', null);
                } catch (AuraHandledException e) {
                    rejected++;
                }
            }
            Test.stopTest();
            System.assertEquals(3, rejected, 'null, 0 and negative hours must all be rejected');
            System.assertEquals(0, [SELECT COUNT() FROM WorkLog__c WHERE WorkItemLookup__c = :t.Id],
                'nothing is saved for invalid hours');
        }
    }

    /**
     * @description With no Active Vendor and no client entity there is nothing
     *              to hang a request on: logHours fails with a clear error.
     */
    @isTest
    static void testLogHoursThrowsWhenNoEntityExists() {
        System.runAs(testUser) {
            List<NetworkEntity__c> entities = [SELECT Id FROM NetworkEntity__c];
            for (NetworkEntity__c ne : entities) {
                ne.StatusPk__c = 'Inactive';
            }
            update entities;
            WorkItem__c orphan = new WorkItem__c(BriefDescriptionTxt__c = 'Orphan', StageNamePk__c = 'Backlog');
            insert orphan;
            Boolean threw = false;
            Test.startTest();
            try {
                DeliveryTimeLoggerController.logHours(orphan.Id, 1.0, 'nowhere to go', null);
            } catch (AuraHandledException e) {
                threw = true;
            }
            Test.stopTest();
            System.assertEquals(true, threw, 'no vendor and no client entity must throw');
        }
    }

    /**
     * @description approve/reject are approver-or-admin only.
     */
    @isTest
    static void testApproveAndRejectDeniedForNonApprover() {
        DeliveryAccessService.adminOverride = false;
        Integer denied = 0;
        Test.startTest();
        try {
            DeliveryTimeLoggerController.approveWorkLogs(new List<Id>());
        } catch (AuraHandledException e) {
            denied++;
        }
        try {
            DeliveryTimeLoggerController.rejectWorkLogs(new List<Id>());
        } catch (AuraHandledException e) {
            denied++;
        }
        Test.stopTest();
        System.assertEquals(2, denied, 'a non-approver, non-admin caller must be refused');
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
                WHERE WorkItemLookup__c = :t.Id
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
                WHERE WorkItemLookup__c = :t.Id
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
                WHERE WorkItemLookup__c = :t.Id
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

            WorkLog__c log = [SELECT Id, StatusPk__c FROM WorkLog__c WHERE WorkItemLookup__c = :t.Id LIMIT 1];
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

            WorkLog__c log = [SELECT Id, StatusPk__c FROM WorkLog__c WHERE WorkItemLookup__c = :t.Id LIMIT 1];
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

            WorkLog__c log = [SELECT Id, StatusPk__c FROM WorkLog__c WHERE WorkItemLookup__c = :t.Id LIMIT 1];
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

/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Test class for DeliveryFieldTrackingService.
 *               Calls trackChanges() directly with constructed old/new maps
 *               and asserts on the captured FieldChangeRequest list rather than
 *               querying ActivityLog__c, to avoid silent failures in the
 *               downstream captureFieldChanges insert.
 * @author Cloud Nimbus LLC
 */
@IsTest
private class DeliveryFieldTrackingServiceTest {

    @TestSetup
    static void setupData() {
        DeliveryHubSettings__c settings = DeliveryHubSettings__c.getOrgDefaults();
        settings.EnableActivityLoggingDateTime__c = Datetime.now();
        settings.EnableFieldTrackingDateTime__c = Datetime.now();
        upsert settings;

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

    @IsTest
    static void testTrackingEnabledCreatesChangeRequest() {
        WorkItem__c workItem = [
            SELECT Id, PriorityPk__c, StageNamePk__c, StatusPk__c, Developer__c
            FROM WorkItem__c LIMIT 1
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

        List<DeliveryFieldChangeService.FieldChangeRequest> requests =
            DeliveryFieldTrackingService.lastChangeRequests;

        System.assertNotEquals(null, requests, 'Change requests should be captured');
        System.assert(!requests.isEmpty(), 'At least one change request should exist');

        Boolean foundPriority = false;
        for (DeliveryFieldChangeService.FieldChangeRequest req : requests) {
            if (req.fieldName == 'PriorityPk__c') {
                foundPriority = true;
                System.assertEquals(workItem.Id, req.recordId, 'Record ID should match');
                System.assertEquals('Medium', req.oldValue, 'Old value should be Medium');
                System.assertEquals('High', req.newValue, 'New value should be High');
                System.assertEquals('Priority', req.fieldLabel, 'Field label should be Priority');
            }
        }
        System.assert(foundPriority, 'Should have a change request for PriorityPk__c');
    }

    @IsTest
    static void testTrackingDisabledNoChangeRequest() {
        DeliveryHubSettings__c settings = DeliveryHubSettings__c.getOrgDefaults();
        settings.EnableFieldTrackingDateTime__c = null;
        upsert settings;

        WorkItem__c workItem = [
            SELECT Id, PriorityPk__c, StageNamePk__c, StatusPk__c, Developer__c
            FROM WorkItem__c LIMIT 1
        ];

        WorkItem__c oldRecord = workItem.clone(true, true, true, true);
        workItem.PriorityPk__c = 'High';

        DeliveryFieldTrackingService.clearCache();
        DeliveryFieldTrackingService.lastChangeRequests = null;

        Test.startTest();
        DeliveryFieldTrackingService.trackChanges(
            new List<SObject>{ workItem },
            new Map<Id, SObject>{ oldRecord.Id => oldRecord }
        );
        Test.stopTest();

        System.assertEquals(null, DeliveryFieldTrackingService.lastChangeRequests,
            'No change requests should be generated when tracking is disabled');
    }

    @IsTest
    static void testUntrackedFieldNoChangeRequest() {
        WorkItem__c workItem = [
            SELECT Id, BriefDescriptionTxt__c, PriorityPk__c, StageNamePk__c, StatusPk__c, Developer__c
            FROM WorkItem__c LIMIT 1
        ];

        WorkItem__c oldRecord = workItem.clone(true, true, true, true);
        workItem.BriefDescriptionTxt__c = 'Updated description not tracked';

        DeliveryFieldTrackingService.clearCache();
        DeliveryFieldTrackingService.lastChangeRequests = null;

        Test.startTest();
        DeliveryFieldTrackingService.trackChanges(
            new List<SObject>{ workItem },
            new Map<Id, SObject>{ oldRecord.Id => oldRecord }
        );
        Test.stopTest();

        // lastChangeRequests stays null because only BriefDescriptionTxt__c changed
        // and it's not in TrackedField__mdt
        System.assertEquals(null, DeliveryFieldTrackingService.lastChangeRequests,
            'No change requests should be generated for an untracked field');
    }

    @IsTest
    static void testMultipleFieldChangesCreateMultipleRequests() {
        WorkItem__c workItem = [
            SELECT Id, PriorityPk__c, StageNamePk__c, StatusPk__c, Developer__c
            FROM WorkItem__c LIMIT 1
        ];

        WorkItem__c oldRecord = workItem.clone(true, true, true, true);
        workItem.PriorityPk__c = 'Critical';
        workItem.StatusPk__c = 'Blocked';

        DeliveryFieldTrackingService.clearCache();

        Test.startTest();
        DeliveryFieldTrackingService.trackChanges(
            new List<SObject>{ workItem },
            new Map<Id, SObject>{ oldRecord.Id => oldRecord }
        );
        Test.stopTest();

        List<DeliveryFieldChangeService.FieldChangeRequest> requests =
            DeliveryFieldTrackingService.lastChangeRequests;

        System.assertNotEquals(null, requests, 'Change requests should be captured');
        System.assert(requests.size() >= 2,
            'At least 2 change requests expected, got: ' + requests.size());
    }

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

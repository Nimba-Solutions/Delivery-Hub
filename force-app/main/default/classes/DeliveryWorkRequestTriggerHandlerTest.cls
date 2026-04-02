/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Tests for DeliveryWorkRequestTriggerHandler covering create,
 *               update, and delete field tracking through the trigger.
 * @author Cloud Nimbus LLC
 */
@IsTest
private class DeliveryWorkRequestTriggerHandlerTest {

    private static User testUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];

    @TestSetup
    static void setup() {
        DeliveryTriggerControl.disableAfterLogic();

        DeliveryHubSettings__c settings = DeliveryHubSettings__c.getOrgDefaults();
        settings.EnableActivityLoggingDateTime__c = Datetime.now();
        settings.EnableFieldTrackingDateTime__c = Datetime.now();
        upsert settings;

        NetworkEntity__c vendor = new NetworkEntity__c(
            Name = 'Test Vendor',
            EntityTypePk__c = 'Vendor',
            StatusPk__c = 'Active'
        );
        insert vendor;

        WorkItem__c workItem = new WorkItem__c(
            BriefDescriptionTxt__c = 'WR Tracking Test',
            StageNamePk__c = 'Backlog'
        );
        insert workItem;

        DeliveryTriggerControl.enableAfterLogic();
    }

    @IsTest
    static void testCreateTracking() {
        System.runAs(testUser) {
            WorkItem__c workItem = [SELECT Id FROM WorkItem__c LIMIT 1];
            NetworkEntity__c vendor = [SELECT Id FROM NetworkEntity__c LIMIT 1];
            DeliveryFieldTrackingService.clearCache();

            Test.startTest();
            WorkRequest__c request = new WorkRequest__c(
                WorkItemId__c = workItem.Id,
                DeliveryEntityId__c = vendor.Id,
                StatusPk__c = 'Draft'
            );
            insert request;
            Test.stopTest();

            List<ActivityLog__c> logs = [
                SELECT Id, ContextDataTxt__c FROM ActivityLog__c
                WHERE RecordIdTxt__c = :request.Id AND ActionTypePk__c = 'Field_Change'
            ];
            System.assert(!logs.isEmpty(), 'Create tracking should produce activity logs for work request');
        }
    }

    @IsTest
    static void testUpdateTracking() {
        System.runAs(testUser) {
            WorkItem__c workItem = [SELECT Id FROM WorkItem__c LIMIT 1];
            NetworkEntity__c vendor = [SELECT Id FROM NetworkEntity__c LIMIT 1];

            DeliveryTriggerControl.disableAfterLogic();
            WorkRequest__c request = new WorkRequest__c(
                WorkItemId__c = workItem.Id,
                DeliveryEntityId__c = vendor.Id,
                StatusPk__c = 'Draft'
            );
            insert request;
            DeliveryTriggerControl.enableAfterLogic();
            DeliveryFieldTrackingService.clearCache();

            Test.startTest();
            request.StatusPk__c = 'Accepted';
            update request;
            Test.stopTest();

            List<ActivityLog__c> logs = [
                SELECT Id, ContextDataTxt__c FROM ActivityLog__c
                WHERE RecordIdTxt__c = :request.Id AND ActionTypePk__c = 'Field_Change'
            ];
            System.assert(!logs.isEmpty(), 'Update tracking should produce activity logs for status change');
        }
    }

    @IsTest
    static void testDeleteTracking() {
        System.runAs(testUser) {
            WorkItem__c workItem = [SELECT Id FROM WorkItem__c LIMIT 1];
            NetworkEntity__c vendor = [SELECT Id FROM NetworkEntity__c LIMIT 1];

            DeliveryTriggerControl.disableAfterLogic();
            WorkRequest__c request = new WorkRequest__c(
                WorkItemId__c = workItem.Id,
                DeliveryEntityId__c = vendor.Id,
                StatusPk__c = 'Draft'
            );
            insert request;
            DeliveryTriggerControl.enableAfterLogic();
            DeliveryFieldTrackingService.clearCache();

            Test.startTest();
            delete request;
            Test.stopTest();

            List<ActivityLog__c> logs = [
                SELECT Id, ContextDataTxt__c FROM ActivityLog__c
                WHERE RecordIdTxt__c = :request.Id AND ActionTypePk__c = 'Field_Change'
            ];
            System.assert(!logs.isEmpty(), 'Delete tracking should produce activity logs');
        }
    }
}

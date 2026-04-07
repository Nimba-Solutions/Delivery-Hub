/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Tests for DeliveryDocumentTriggerHandler covering create,
 *               update, and delete field tracking through the trigger.
 * @author Cloud Nimbus LLC
 */
@IsTest
private class DeliveryDocumentTriggerHandlerTest {

    private static User testUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];

    @TestSetup
    static void setup() {
        DeliveryTriggerControl.disableAfterLogic();

        DeliveryHubSettings__c settings = DeliveryHubSettings__c.getOrgDefaults();
        settings.EnableActivityLoggingDateTime__c = Datetime.now();
        settings.EnableFieldTrackingDateTime__c = Datetime.now();
        upsert settings;

        NetworkEntity__c entity = new NetworkEntity__c(
            Name = 'Test Client',
            EntityTypePk__c = 'Client',
            StatusPk__c = 'Active'
        );
        insert entity;

        DeliveryTriggerControl.enableAfterLogic();
    }

    @IsTest
    static void testCreateTracking() {
        System.runAs(testUser) {
            NetworkEntity__c entity = [SELECT Id FROM NetworkEntity__c LIMIT 1];
            DeliveryFieldTrackingService.clearCache();

            Test.startTest();
            DeliveryDocument__c doc = new DeliveryDocument__c(
                NetworkEntityLookup__c = entity.Id,
                TemplatePk__c = 'Invoice',
                StatusPk__c = 'Draft',
                PeriodStartDate__c = Date.today().addDays(-30),
                PeriodEndDate__c = Date.today(),
                PublicTokenTxt__c = 'test-token-create',
                SnapshotTxt__c = '{}',
                VersionNumber__c = 1
            );
            insert doc;
            Test.stopTest();

            List<ActivityLog__c> logs = [
                SELECT Id, ContextDataTxt__c FROM ActivityLog__c
                WHERE RecordIdTxt__c = :doc.Id AND ActionTypePk__c = 'Field_Change'
            ];
            System.assert(!logs.isEmpty(), 'Create tracking should produce activity logs');
        }
    }

    @IsTest
    static void testUpdateTracking() {
        System.runAs(testUser) {
            NetworkEntity__c entity = [SELECT Id FROM NetworkEntity__c LIMIT 1];
            DeliveryTriggerControl.disableAfterLogic();

            DeliveryDocument__c doc = new DeliveryDocument__c(
                NetworkEntityLookup__c = entity.Id,
                TemplatePk__c = 'Invoice',
                StatusPk__c = 'Draft',
                PeriodStartDate__c = Date.today().addDays(-30),
                PeriodEndDate__c = Date.today(),
                PublicTokenTxt__c = 'test-token-update',
                SnapshotTxt__c = '{}',
                VersionNumber__c = 1
            );
            insert doc;
            DeliveryTriggerControl.enableAfterLogic();
            DeliveryFieldTrackingService.clearCache();

            Test.startTest();
            doc.StatusPk__c = 'Sent';
            update doc;
            Test.stopTest();

            List<ActivityLog__c> logs = [
                SELECT Id, ContextDataTxt__c FROM ActivityLog__c
                WHERE RecordIdTxt__c = :doc.Id AND ActionTypePk__c = 'Field_Change'
            ];
            System.assert(!logs.isEmpty(), 'Update tracking should produce activity logs for status change');
        }
    }

    @IsTest
    static void testDeleteTracking() {
        System.runAs(testUser) {
            NetworkEntity__c entity = [SELECT Id FROM NetworkEntity__c LIMIT 1];
            DeliveryTriggerControl.disableAfterLogic();

            DeliveryDocument__c doc = new DeliveryDocument__c(
                NetworkEntityLookup__c = entity.Id,
                TemplatePk__c = 'Invoice',
                StatusPk__c = 'Draft',
                PeriodStartDate__c = Date.today().addDays(-30),
                PeriodEndDate__c = Date.today(),
                PublicTokenTxt__c = 'test-token-delete',
                SnapshotTxt__c = '{}',
                VersionNumber__c = 1
            );
            insert doc;
            DeliveryTriggerControl.enableAfterLogic();
            DeliveryFieldTrackingService.clearCache();

            Test.startTest();
            delete doc;
            Test.stopTest();

            List<ActivityLog__c> logs = [
                SELECT Id, ContextDataTxt__c FROM ActivityLog__c
                WHERE RecordIdTxt__c = :doc.Id AND ActionTypePk__c = 'Field_Change'
            ];
            System.assert(!logs.isEmpty(), 'Delete tracking should produce activity logs');
        }
    }
}

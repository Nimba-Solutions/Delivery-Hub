/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Tests for DeliveryNetworkEntityTriggerHandler covering create,
 *               update, and delete field tracking through the trigger.
 * @author Cloud Nimbus LLC
 */
@IsTest
private class DeliveryNetworkEntityTriggerHandlerTest {

    private static User testUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];

    @TestSetup
    static void setup() {
        DeliveryTriggerControl.disableAfterLogic();

        DeliveryHubSettings__c settings = DeliveryHubSettings__c.getOrgDefaults();
        settings.EnableActivityLoggingDateTime__c = Datetime.now();
        settings.EnableFieldTrackingDateTime__c = Datetime.now();
        upsert settings;

        DeliveryTriggerControl.enableAfterLogic();
    }

    @IsTest
    static void testCreateTracking() {
        System.runAs(testUser) {
            DeliveryFieldTrackingService.clearCache();

            Test.startTest();
            NetworkEntity__c entity = new NetworkEntity__c(
                Name = 'Track Create Client',
                EntityTypePk__c = 'Client',
                StatusPk__c = 'Active'
            );
            insert entity;
            Test.stopTest();

            List<ActivityLog__c> logs = [
                SELECT Id, ContextDataTxt__c FROM ActivityLog__c
                WHERE RecordIdTxt__c = :entity.Id AND ActionTypePk__c = 'Field_Change'
            ];
            System.assert(!logs.isEmpty(), 'Create tracking should produce activity logs for entity');
        }
    }

    @IsTest
    static void testUpdateTracking() {
        System.runAs(testUser) {
            DeliveryTriggerControl.disableAfterLogic();
            NetworkEntity__c entity = new NetworkEntity__c(
                Name = 'Track Update Client',
                EntityTypePk__c = 'Client',
                StatusPk__c = 'Active'
            );
            insert entity;
            DeliveryTriggerControl.enableAfterLogic();
            DeliveryFieldTrackingService.clearCache();

            Test.startTest();
            entity.StatusPk__c = 'Inactive';
            update entity;
            Test.stopTest();

            List<ActivityLog__c> logs = [
                SELECT Id, ContextDataTxt__c FROM ActivityLog__c
                WHERE RecordIdTxt__c = :entity.Id AND ActionTypePk__c = 'Field_Change'
            ];
            System.assert(!logs.isEmpty(), 'Update tracking should produce activity logs for status change');
        }
    }

    @IsTest
    static void testDeleteTracking() {
        System.runAs(testUser) {
            DeliveryTriggerControl.disableAfterLogic();
            NetworkEntity__c entity = new NetworkEntity__c(
                Name = 'Track Delete Client',
                EntityTypePk__c = 'Client',
                StatusPk__c = 'Active'
            );
            insert entity;
            DeliveryTriggerControl.enableAfterLogic();
            DeliveryFieldTrackingService.clearCache();

            Test.startTest();
            delete entity;
            Test.stopTest();

            List<ActivityLog__c> logs = [
                SELECT Id, ContextDataTxt__c FROM ActivityLog__c
                WHERE RecordIdTxt__c = :entity.Id AND ActionTypePk__c = 'Field_Change'
            ];
            System.assert(!logs.isEmpty(), 'Delete tracking should produce activity logs');
        }
    }
}

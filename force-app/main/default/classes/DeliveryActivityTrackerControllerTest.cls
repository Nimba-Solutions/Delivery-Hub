/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Tests for DeliveryActivityTrackerController. Validates activity logging
 *               toggle behavior, field population, and error resilience.
 * @author Cloud Nimbus LLC
 */
@IsTest
private class DeliveryActivityTrackerControllerTest {

    private static User testUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];

    /**
     * @description Enables activity logging in org-level custom settings.
     */
    private static void enableActivityLogging() {
        DeliveryHubSettings__c settings = DeliveryHubSettings__c.getOrgDefaults();
        settings.EnableActivityLoggingDateTime__c = Datetime.now();
        upsert settings;
    }

    @IsTest
    static void testLogActivityDisabledByDefault() {
        System.runAs(testUser) {
            // Activity logging is off by default — no record should be created
            Test.startTest();
            DeliveryActivityTrackerController.logActivity(
                'Navigation',
                'Account (view)',
                'test-record-ref',
                '{"url":"https://test.lightning.force.com"}',
                'test-session-001'
            );
            Test.stopTest();

            List<ActivityLog__c> logs = [SELECT Id FROM ActivityLog__c];
            System.assertEquals(0, logs.size(), 'No activity log should be created when setting is disabled');
        }
    }

    @IsTest
    static void testLogActivityPersistsWhenEnabled() {
        System.runAs(testUser) {
            enableActivityLogging();

            // Create a real Account to use its ID
            Account testAcct = new Account(Name = 'Test Activity Account');
            insert testAcct;

            String contextJson = JSON.serialize(new Map<String, Object>{
                'url' => 'https://test.lightning.force.com/lightning/r/Account/' + testAcct.Id + '/view',
                'objectApiName' => 'Account',
                'recordId' => testAcct.Id,
                'actionName' => 'view',
                'timestamp' => '2026-03-12T10:00:00.000Z',
                'appName' => 'DeliveryHub'
            });

            Test.startTest();
            DeliveryActivityTrackerController.logActivity(
                'Navigation',
                'Account (view)',
                testAcct.Id,
                contextJson,
                'session-uuid-abc-123'
            );
            Test.stopTest();

            List<ActivityLog__c> logs = [
                SELECT ActionTypePk__c, ComponentNameTxt__c, RecordIdTxt__c,
                       UserIdTxt__c, SessionIdTxt__c, ContextDataTxt__c
                FROM ActivityLog__c
            ];
            System.assertEquals(1, logs.size(), 'One activity log should be persisted');
            System.assertEquals('Navigation', logs[0].ActionTypePk__c, 'Action type should match');
            System.assertEquals('Account (view)', logs[0].ComponentNameTxt__c, 'Component name should match');
            System.assertEquals(testAcct.Id, logs[0].RecordIdTxt__c, 'Record ID should match');
            System.assertEquals(UserInfo.getUserId(), logs[0].UserIdTxt__c, 'User ID should be set automatically');
            System.assertEquals('session-uuid-abc-123', logs[0].SessionIdTxt__c, 'Session ID should match');
            System.assert(logs[0].ContextDataTxt__c.contains('Account'), 'Context should contain object name');
        }
    }

    @IsTest
    static void testLogActivityWithBlankRecordId() {
        System.runAs(testUser) {
            enableActivityLogging();

            Test.startTest();
            DeliveryActivityTrackerController.logActivity(
                'Navigation',
                'Home',
                '',
                '{"url":"https://test.lightning.force.com/lightning/page/home"}',
                'session-uuid-def-456'
            );
            Test.stopTest();

            List<ActivityLog__c> logs = [
                SELECT ComponentNameTxt__c, RecordIdTxt__c
                FROM ActivityLog__c
            ];
            System.assertEquals(1, logs.size(), 'Activity log should be created for non-record pages');
            System.assertEquals('Home', logs[0].ComponentNameTxt__c, 'Component name should be Home');
            System.assertEquals(null, logs[0].RecordIdTxt__c, 'Record ID should be null for non-record pages');
        }
    }

    @IsTest
    static void testLogActivityWithNullContextData() {
        System.runAs(testUser) {
            enableActivityLogging();

            Test.startTest();
            DeliveryActivityTrackerController.logActivity(
                'Navigation',
                'Opportunity List',
                null,
                null,
                'session-uuid-ghi-789'
            );
            Test.stopTest();

            List<ActivityLog__c> logs = [
                SELECT ComponentNameTxt__c, ContextDataTxt__c
                FROM ActivityLog__c
            ];
            System.assertEquals(1, logs.size(), 'Record should still be created with null context');
            System.assertEquals('Opportunity List', logs[0].ComponentNameTxt__c, 'Component name should match');
            System.assertEquals(null, logs[0].ContextDataTxt__c, 'Context data should be null');
        }
    }

    @IsTest
    static void testLogActivityMultipleActionTypes() {
        System.runAs(testUser) {
            enableActivityLogging();

            Test.startTest();
            DeliveryActivityTrackerController.logActivity(
                'Button_Click',
                'deliveryHubBoard',
                '',
                '{"action":"save"}',
                'session-multi-001'
            );
            DeliveryActivityTrackerController.logActivity(
                'Feature_Use',
                'deliveryAiDraftPanel',
                '',
                '{"feature":"aiDraft"}',
                'session-multi-001'
            );
            Test.stopTest();

            List<ActivityLog__c> logs = [
                SELECT ActionTypePk__c FROM ActivityLog__c ORDER BY CreatedDate ASC
            ];
            System.assertEquals(2, logs.size(), 'Both activity logs should be persisted');
            System.assertEquals('Button_Click', logs[0].ActionTypePk__c, 'First log should be Button_Click');
            System.assertEquals('Feature_Use', logs[1].ActionTypePk__c, 'Second log should be Feature_Use');
        }
    }
}

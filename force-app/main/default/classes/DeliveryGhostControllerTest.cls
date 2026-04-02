/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Tests for DeliveryGhostController. Validates quick request creation,
 *               activity logging toggle behavior, and malformed JSON handling.
 * @author Cloud Nimbus LLC
 */
@IsTest
private class DeliveryGhostControllerTest {

    private static User testUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];

    /**
     * @description Inserts org-level DeliveryHubSettings__c with activity logging enabled.
     */
    private static void enableActivityLogging() {
        DeliveryHubSettings__c settings = DeliveryHubSettings__c.getOrgDefaults();
        settings.EnableActivityLoggingDateTime__c = Datetime.now();
        upsert settings;
    }

    @IsTest
    static void testCreateQuickRequest() {
        System.runAs(testUser) {
            Account mockRecord = new Account(Name = 'Test Context Account');
            insert mockRecord;

            Map<String, String> contextMap = new Map<String, String>{
                'url' => 'https://salesforce.com/test',
                'browser' => 'Chrome Test Agent',
                'objectName' => 'Account',
                'recordId' => mockRecord.Id
            };
            String contextJson = JSON.serialize(contextMap);

            Test.startTest();
            Id workItemId = DeliveryGhostController.createQuickRequest(
                'Test Issue',
                'Something is broken',
                'High',
                contextJson,
                'Bug'
            );
            Test.stopTest();

            WorkItem__c t = [SELECT BriefDescriptionTxt__c, DetailsTxt__c, PriorityPk__c, ActivatedDateTime__c, StatusPk__c FROM WorkItem__c WHERE Id = :workItemId LIMIT 1];

            System.assertEquals('[Bug] Test Issue - Something is broken', t.BriefDescriptionTxt__c, 'Work Item Name should include [Bug] prefix and description');
            System.assertEquals('High', t.PriorityPk__c, 'Priority should match');
            System.assert(t.DetailsTxt__c.contains('Auto-Captured Context'), 'Details should contain context header');
            System.assertNotEquals(null, t.ActivatedDateTime__c, 'Ghost Reporter workItem should be active');
            System.assertEquals('New', t.StatusPk__c, 'Ghost Reporter workItem should have New status');
        }
    }

    @IsTest
    static void testLogUserActivityDisabledByDefault() {
        System.runAs(testUser) {
            // Setting is OFF by default — no record should be created
            Map<String, Object> contextMap = new Map<String, Object>{
                'url' => 'https://salesforce.com/nav',
                'browser' => 'Safari',
                'objectName' => 'deliveryHubBoard'
            };

            Test.startTest();
            DeliveryGhostController.logUserActivity('Navigation', JSON.serialize(contextMap));
            Test.stopTest();

            List<ActivityLog__c> logs = [SELECT Id FROM ActivityLog__c];
            System.assertEquals(0, logs.size(), 'No activity log should be created when setting is disabled');
        }
    }

    @IsTest
    static void testLogUserActivityPersistsWhenEnabled() {
        System.runAs(testUser) {
            enableActivityLogging();

            Map<String, Object> contextMap = new Map<String, Object>{
                'url' => 'https://salesforce.com/nav',
                'browser' => 'Safari',
                'objectName' => 'deliveryHubBoard',
                'sessionId' => 'abc-123-def'
            };
            String contextJson = JSON.serialize(contextMap);

            Test.startTest();
            DeliveryGhostController.logUserActivity('Navigation', contextJson);
            Test.stopTest();

            List<ActivityLog__c> logs = [
                SELECT ActionTypePk__c, ComponentNameTxt__c, UserIdTxt__c, SessionIdTxt__c, ContextDataTxt__c
                FROM ActivityLog__c
            ];
            System.assertEquals(1, logs.size(), 'One activity log should be persisted');
            System.assertEquals('Navigation', logs[0].ActionTypePk__c, 'Action type should match');
            System.assertEquals('deliveryHubBoard', logs[0].ComponentNameTxt__c, 'Component should be extracted from context');
            System.assertEquals(UserInfo.getUserId(), logs[0].UserIdTxt__c, 'User ID should be set automatically');
            System.assertEquals('abc-123-def', logs[0].SessionIdTxt__c, 'Session ID should be extracted from context');
        }
    }

    @IsTest
    static void testLogUserActivityWithBadJson() {
        System.runAs(testUser) {
            enableActivityLogging();

            Test.startTest();
            DeliveryGhostController.logUserActivity('Error', 'not-valid-json');
            Test.stopTest();

            List<ActivityLog__c> logs = [
                SELECT ActionTypePk__c, ContextDataTxt__c
                FROM ActivityLog__c
            ];
            System.assertEquals(1, logs.size(), 'Record should still be created even with bad JSON');
            System.assertEquals('Error', logs[0].ActionTypePk__c, 'Action type should still be set');
            System.assertEquals('not-valid-json', logs[0].ContextDataTxt__c, 'Raw context should be stored as-is');
        }
    }

    @IsTest
    static void testLogUserActivityPopulatesRecordIdAndUrl() {
        System.runAs(testUser) {
            enableActivityLogging();

            Account testAcct = new Account(Name = 'Ghost Recorder URL Test');
            insert testAcct;
            String testUrl = 'https://myorg.lightning.force.com/lightning/r/Account/' + testAcct.Id + '/view';

            Map<String, Object> contextMap = new Map<String, Object>{
                'url' => testUrl,
                'browser' => 'Chrome',
                'objectName' => 'Account',
                'recordId' => testAcct.Id,
                'pageLabel' => 'Account',
                'sessionId' => 'sess-abc-123'
            };
            String contextJson = JSON.serialize(contextMap);

            Test.startTest();
            DeliveryGhostController.logUserActivity('Navigation', contextJson);
            Test.stopTest();

            List<ActivityLog__c> logs = [
                SELECT RecordIdTxt__c, PageUrlTxt__c, ComponentNameTxt__c, SessionIdTxt__c
                FROM ActivityLog__c
            ];
            System.assertEquals(1, logs.size(), 'One activity log should be persisted');
            System.assertEquals(testAcct.Id, logs[0].RecordIdTxt__c, 'RecordId should be extracted from context');
            System.assertEquals(testUrl, logs[0].PageUrlTxt__c, 'Page URL should be extracted from context');
            System.assertEquals('Account', logs[0].ComponentNameTxt__c, 'Component name should use pageLabel');
            System.assertEquals('sess-abc-123', logs[0].SessionIdTxt__c, 'Session ID should be extracted from context');
        }
    }

    @IsTest
    static void testLogUserActivityTruncatesLongUrl() {
        System.runAs(testUser) {
            enableActivityLogging();

            Account testAcct = new Account(Name = 'Ghost Recorder Truncate Test');
            insert testAcct;

            // Build a URL longer than 255 characters
            String longUrl = 'https://myorg.lightning.force.com/lightning/r/Account/' + testAcct.Id + '/view?';
            while (longUrl.length() < 310) {
                longUrl += 'param=value&';
            }
            System.assert(longUrl.length() > 255, 'Test URL should exceed 255 chars');

            Map<String, Object> contextMap = new Map<String, Object>{
                'url' => longUrl,
                'browser' => 'Chrome',
                'objectName' => 'Account',
                'recordId' => testAcct.Id,
                'pageLabel' => 'Account',
                'sessionId' => 'sess-trunc-test'
            };
            String contextJson = JSON.serialize(contextMap);

            Test.startTest();
            DeliveryGhostController.logUserActivity('Navigation', contextJson);
            Test.stopTest();

            List<ActivityLog__c> logs = [
                SELECT PageUrlTxt__c
                FROM ActivityLog__c
            ];
            System.assertEquals(1, logs.size(), 'Record should be created even with long URL');
            System.assertEquals(255, logs[0].PageUrlTxt__c.length(), 'Page URL should be truncated to 255 chars');
        }
    }

    @IsTest
    static void testLogUserActivityPageLabelFallsBackToObjectName() {
        System.runAs(testUser) {
            enableActivityLogging();

            // Context without pageLabel — should fall back to objectName
            Map<String, Object> contextMap = new Map<String, Object>{
                'url' => 'https://myorg.lightning.force.com/lightning/o/WorkItem__c/home',
                'browser' => 'Firefox',
                'objectName' => 'WorkItem__c'
            };
            String contextJson = JSON.serialize(contextMap);

            Test.startTest();
            DeliveryGhostController.logUserActivity('Navigation', contextJson);
            Test.stopTest();

            List<ActivityLog__c> logs = [
                SELECT ComponentNameTxt__c
                FROM ActivityLog__c
            ];
            System.assertEquals(1, logs.size(), 'One activity log should be persisted');
            System.assertEquals('WorkItem__c', logs[0].ComponentNameTxt__c, 'Component should fall back to objectName when pageLabel is absent');
        }
    }

    /**
     * @description Verifies createQuickRequest defaults to [Issue] prefix when workItemType is blank.
     */
    @IsTest
    static void testCreateQuickRequestBlankTypeDefaultsToIssue() {
        System.runAs(testUser) {
            Test.startTest();
            Id workItemId = DeliveryGhostController.createQuickRequest(
                'Something odd', 'Description here', 'Medium', null, ''
            );
            Test.stopTest();

            WorkItem__c t = [SELECT BriefDescriptionTxt__c FROM WorkItem__c WHERE Id = :workItemId LIMIT 1];
            System.assert(t.BriefDescriptionTxt__c.startsWith('[Issue]'), 'Blank type should default to [Issue] prefix');
        }
    }

    /**
     * @description Verifies createQuickRequest defaults to [Issue] prefix when workItemType is null.
     */
    @IsTest
    static void testCreateQuickRequestNullTypeDefaultsToIssue() {
        System.runAs(testUser) {
            Test.startTest();
            Id workItemId = DeliveryGhostController.createQuickRequest(
                'Null type test', 'Details', 'Low', null, null
            );
            Test.stopTest();

            WorkItem__c t = [SELECT BriefDescriptionTxt__c FROM WorkItem__c WHERE Id = :workItemId LIMIT 1];
            System.assert(t.BriefDescriptionTxt__c.startsWith('[Issue]'), 'Null type should default to [Issue] prefix');
        }
    }

    /**
     * @description Verifies createQuickRequest with null contextData omits context block.
     */
    @IsTest
    static void testCreateQuickRequestNullContextData() {
        System.runAs(testUser) {
            Test.startTest();
            Id workItemId = DeliveryGhostController.createQuickRequest(
                'No context', 'Just a description', 'High', null, 'Bug'
            );
            Test.stopTest();

            WorkItem__c t = [SELECT DetailsTxt__c FROM WorkItem__c WHERE Id = :workItemId LIMIT 1];
            System.assert(!t.DetailsTxt__c.contains('Auto-Captured Context'), 'Null context should not include context block');
            System.assertEquals('Just a description', t.DetailsTxt__c, 'Details should be just the description');
        }
    }

    /**
     * @description Verifies createQuickRequest truncates subject + description to 100 chars for BriefDescription.
     */
    @IsTest
    static void testCreateQuickRequestLongSubjectTruncation() {
        System.runAs(testUser) {
            // Build a subject that will exceed 100 chars when combined with prefix and description
            String longSubject = 'A'.repeat(80);
            String longDesc = 'B'.repeat(80);

            Test.startTest();
            Id workItemId = DeliveryGhostController.createQuickRequest(
                longSubject, longDesc, 'Medium', null, 'Feature'
            );
            Test.stopTest();

            WorkItem__c t = [SELECT BriefDescriptionTxt__c FROM WorkItem__c WHERE Id = :workItemId LIMIT 1];
            System.assertEquals(100, t.BriefDescriptionTxt__c.length(), 'BriefDescription should be truncated to 100 chars');
        }
    }

    /**
     * @description Verifies createQuickRequest with empty context string omits context block.
     */
    @IsTest
    static void testCreateQuickRequestEmptyContextString() {
        System.runAs(testUser) {
            Test.startTest();
            Id workItemId = DeliveryGhostController.createQuickRequest(
                'Empty ctx', 'Some desc', 'Low', '', 'Bug'
            );
            Test.stopTest();

            WorkItem__c t = [SELECT DetailsTxt__c FROM WorkItem__c WHERE Id = :workItemId LIMIT 1];
            System.assert(!t.DetailsTxt__c.contains('Auto-Captured Context'), 'Empty context should not include context block');
        }
    }

    /**
     * @description Verifies logUserActivity links to the active NetworkEntity when one exists.
     */
    @IsTest
    static void testLogUserActivityLinksNetworkEntity() {
        System.runAs(testUser) {
            enableActivityLogging();

            NetworkEntity__c entity = new NetworkEntity__c(
                Name = 'Ghost Entity Test', EntityTypePk__c = 'Client', StatusPk__c = 'Active'
            );
            insert entity;

            Map<String, Object> contextMap = new Map<String, Object>{
                'url' => 'https://salesforce.com/test',
                'browser' => 'Chrome',
                'objectName' => 'TestComponent'
            };

            Test.startTest();
            DeliveryGhostController.logUserActivity('Navigation', JSON.serialize(contextMap));
            Test.stopTest();

            List<ActivityLog__c> logs = [
                SELECT NetworkEntityId__c FROM ActivityLog__c
            ];
            System.assertEquals(1, logs.size(), 'One activity log should be persisted');
            System.assertNotEquals(null, logs[0].NetworkEntityId__c, 'NetworkEntity should be linked when active entity exists');
        }
    }

    /**
     * @description Verifies logUserActivity handles empty context string gracefully.
     */
    @IsTest
    static void testLogUserActivityEmptyContextString() {
        System.runAs(testUser) {
            enableActivityLogging();

            Test.startTest();
            DeliveryGhostController.logUserActivity('Button_Click', '');
            Test.stopTest();

            List<ActivityLog__c> logs = [
                SELECT ActionTypePk__c, ComponentNameTxt__c
                FROM ActivityLog__c
            ];
            System.assertEquals(1, logs.size(), 'Record should be created even with empty context');
            System.assertEquals('Button_Click', logs[0].ActionTypePk__c, 'Action type should still be set');
            System.assertEquals(null, logs[0].ComponentNameTxt__c, 'Component should be null for empty context');
        }
    }

    /**
     * @description Verifies createQuickRequest with blank description uses empty string in brief.
     */
    @IsTest
    static void testCreateQuickRequestBlankDescription() {
        System.runAs(testUser) {
            Test.startTest();
            Id workItemId = DeliveryGhostController.createQuickRequest(
                'No desc', '', 'High', null, 'Bug'
            );
            Test.stopTest();

            WorkItem__c t = [SELECT BriefDescriptionTxt__c, DetailsTxt__c FROM WorkItem__c WHERE Id = :workItemId LIMIT 1];
            System.assert(t.BriefDescriptionTxt__c.contains('[Bug] No desc'), 'Brief should contain subject with prefix');
        }
    }
}

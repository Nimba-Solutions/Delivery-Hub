/**
 * @author Cloud Nimbus LLC
 */
@IsTest
private class DeliveryGhostControllerTest {

    @IsTest
    static void testCreateQuickRequest() {
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

        WorkItem__c t = [SELECT BriefDescriptionTxt__c, DetailsTxt__c, PriorityPk__c, IsActiveBool__c, StatusPk__c FROM WorkItem__c WHERE Id = :workItemId LIMIT 1];

        System.assertEquals('[Bug] Test Issue - Something is broken', t.BriefDescriptionTxt__c, 'Work Item Name should include [Bug] prefix and description');
        System.assertEquals('High', t.PriorityPk__c, 'Priority should match');
        System.assert(t.DetailsTxt__c.contains('Auto-Captured Context'), 'Details should contain context header');
        System.assertEquals(true, t.IsActiveBool__c, 'Ghost Reporter workItem should be active');
        System.assertEquals('New', t.StatusPk__c, 'Ghost Reporter workItem should have New status');
    }

    @IsTest
    static void testLogUserActivityPersistsRecord() {
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

        List<Activity_Log__c> logs = [
            SELECT ActionTypePk__c, ComponentNameTxt__c, UserIdTxt__c, SessionIdTxt__c, ContextDataTxt__c
            FROM Activity_Log__c
        ];
        System.assertEquals(1, logs.size(), 'One activity log should be persisted');
        System.assertEquals('Navigation', logs[0].ActionTypePk__c, 'Action type should match');
        System.assertEquals('deliveryHubBoard', logs[0].ComponentNameTxt__c, 'Component should be extracted from context');
        System.assertEquals(UserInfo.getUserId(), logs[0].UserIdTxt__c, 'User ID should be set automatically');
        System.assertEquals('abc-123-def', logs[0].SessionIdTxt__c, 'Session ID should be extracted from context');
    }

    @IsTest
    static void testLogUserActivityWithBadJson() {
        // Should not throw — activity logging is best-effort
        Test.startTest();
        DeliveryGhostController.logUserActivity('Error', 'not-valid-json');
        Test.stopTest();

        List<Activity_Log__c> logs = [
            SELECT ActionTypePk__c, ContextDataTxt__c
            FROM Activity_Log__c
        ];
        System.assertEquals(1, logs.size(), 'Record should still be created even with bad JSON');
        System.assertEquals('Error', logs[0].ActionTypePk__c, 'Action type should still be set');
        System.assertEquals('not-valid-json', logs[0].ContextDataTxt__c, 'Raw context should be stored as-is');
    }
}

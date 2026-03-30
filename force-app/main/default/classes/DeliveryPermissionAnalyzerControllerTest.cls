@SuppressWarnings('PMD.ApexCRUDViolation')
@isTest
private class DeliveryPermissionAnalyzerControllerTest {

    @TestSetup
    static void setup() {
        DeliveryTriggerControl.runAfterLogic = false;

        NetworkEntity__c entity = new NetworkEntity__c(
            Name = 'Test Corp',
            EntityTypePk__c = 'Client',
            StatusPk__c = 'Active'
        );
        insert entity;

        // Create diverse activity logs to test aggregation
        String currentUserId = UserInfo.getUserId();
        String sessionId = 'test-session-001';
        List<ActivityLog__c> logs = new List<ActivityLog__c>();

        // User visits Account pages frequently
        for (Integer i = 0; i < 15; i++) {
            logs.add(new ActivityLog__c(
                ActionTypePk__c = 'Navigation',
                UserIdTxt__c = currentUserId,
                SessionIdTxt__c = sessionId,
                ComponentNameTxt__c = 'Account',
                PageUrlTxt__c = '/lightning/r/Account/001test/view',
                ContextDataTxt__c = '{"objectApiName":"Account","duration":' + (30 + i) + '}'
            ));
        }
        // Some Opportunity views
        for (Integer i = 0; i < 5; i++) {
            logs.add(new ActivityLog__c(
                ActionTypePk__c = 'Navigation',
                UserIdTxt__c = currentUserId,
                SessionIdTxt__c = 'test-session-002',
                ComponentNameTxt__c = 'Opportunity',
                PageUrlTxt__c = '/lightning/o/Opportunity/home',
                ContextDataTxt__c = '{"objectApiName":"Opportunity"}'
            ));
        }
        // A few Setup visits
        logs.add(new ActivityLog__c(
            ActionTypePk__c = 'Navigation',
            UserIdTxt__c = currentUserId,
            SessionIdTxt__c = sessionId,
            ComponentNameTxt__c = 'Setup',
            PageUrlTxt__c = '/lightning/setup/home',
            ContextDataTxt__c = '{"objectApiName":"Setup"}'
        ));
        insert logs;
    }

    @isTest
    static void testGetPermissionAnalysis() {
        Test.startTest();
        Map<String, Object> result = DeliveryPermissionAnalyzerController.getPermissionAnalysis();
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
        System.assert((Integer) result.get('totalUsers') >= 1, 'Should have at least 1 user');
        System.assert((Integer) result.get('totalLogs') >= 20, 'Should have at least 20 logs');

        List<Object> users = (List<Object>) result.get('users');
        System.assert(!users.isEmpty(), 'Should have user activity data');

        List<Object> objects = (List<Object>) result.get('objects');
        System.assert(!objects.isEmpty(), 'Should have object usage data');
    }

    @isTest
    static void testGetUserDetail() {
        String currentUserId = UserInfo.getUserId();

        Test.startTest();
        Map<String, Object> detail = DeliveryPermissionAnalyzerController.getUserDetail(currentUserId);
        Test.stopTest();

        System.assertNotEquals(null, detail, 'Detail should not be null');
        System.assertNotEquals(null, detail.get('userName'), 'Should have user name');
        System.assert((Integer) detail.get('totalPageViews') >= 20, 'Should have page views');
        System.assert((Integer) detail.get('uniqueObjects') >= 2, 'Should have multiple objects');
    }

    @isTest
    static void testGenerateSecurityReport() {
        Test.startTest();
        Map<String, Object> report = DeliveryPermissionAnalyzerController.generateSecurityReport();
        Test.stopTest();

        System.assertNotEquals(null, report, 'Report should not be null');
        System.assertEquals('Security_Audit', report.get('templateType'), 'Should be Security_Audit');
    }

    @isTest
    static void testGetPermissionAnalysisNoData() {
        // Delete all activity logs
        delete [SELECT Id FROM ActivityLog__c];

        Test.startTest();
        Map<String, Object> result = DeliveryPermissionAnalyzerController.getPermissionAnalysis();
        Test.stopTest();

        System.assertEquals(0, (Integer) result.get('totalUsers'), 'Should have 0 users');
        System.assertEquals(0, (Integer) result.get('totalLogs'), 'Should have 0 logs');
    }

    @isTest
    static void testGetUserDetailInvalidUser() {
        Test.startTest();
        Map<String, Object> detail = DeliveryPermissionAnalyzerController.getUserDetail('005000000000000');
        Test.stopTest();

        System.assertEquals(0, (Integer) detail.get('totalPageViews'), 'Should have 0 views for invalid user');
    }
}

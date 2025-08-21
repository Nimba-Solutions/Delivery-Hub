@isTest
private class DeliveryHubSettingsControllerTest {
    
    @testSetup
    static void setupTestData() {
        // Create initial settings to simulate org defaults
        Delivery_Hub_Settings__c settings = new Delivery_Hub_Settings__c(
            SetupOwnerId = UserInfo.getOrganizationId(),
            Enable_Notifications__c = true,
            AI_Suggestions_Enabled__c = true,
            Auto_Generate_Descriptions__c = true,
            AI_Estimation_Enabled__c = true,
            OpenAI_API_Key__c = 'test-key',
            OpenAI_Model__c = 'gpt-4o',
            JIRA_Enabled__c = true,
            JIRA_Instance_URL__c = 'https://example.atlassian.net',
            JIRA_Username__c = 'jirauser@example.com',
            JIRA_API_Token__c = 'test-token',
            JIRA_Project_Key__c = 'ABC',
            Jira_Api_tested__c = true,
            Open_Ai_Api_tested__c = true
        );
        insert settings;
    }

    @isTest
    static void testGetSettings() {
        DeliveryHubSettingsController.SettingsDTO dto = DeliveryHubSettingsController.getSettings();
        System.assertNotEquals(null, dto);
        System.assert(dto.aiSuggestionsEnabled, 'AI Suggestions should be true');
        System.assertEquals('gpt-4o', dto.openaiModel);
    }

    @isTest
    static void testSaveGeneralSettings() {
        DeliveryHubSettingsController.saveGeneralSettings(false);
        Delivery_Hub_Settings__c s = Delivery_Hub_Settings__c.getOrgDefaults();
        System.assertEquals(false, s.Enable_Notifications__c);
    }

    @isTest
    static void testSaveAiSettings() {
        DeliveryHubSettingsController.saveAiSettings(false, true, false);
        Delivery_Hub_Settings__c s = Delivery_Hub_Settings__c.getOrgDefaults();
        System.assertEquals(false, s.AI_Suggestions_Enabled__c);
        System.assertEquals(true, s.Auto_Generate_Descriptions__c);
        System.assertEquals(false, s.AI_Estimation_Enabled__c);
    }

    @isTest
    static void testSaveOpenAISettings() {
        DeliveryHubSettingsController.saveOpenAISettings('new-key', 'gpt-4o-mini', true);
        Delivery_Hub_Settings__c s = Delivery_Hub_Settings__c.getOrgDefaults();
        System.assertEquals('new-key', s.OpenAI_API_Key__c);
        System.assertEquals('gpt-4o-mini', s.OpenAI_Model__c);
        System.assertEquals(true, s.Open_Ai_Api_tested__c);
    }

    @isTest
    static void testSaveJiraSettings() {
        DeliveryHubSettingsController.saveJiraSettings(
            'https://myjira.com',
            'user@jira.com',
            'new-token',
            'XYZ',
            true
        );
        Delivery_Hub_Settings__c s = Delivery_Hub_Settings__c.getOrgDefaults();
        System.assertEquals('https://myjira.com', s.JIRA_Instance_URL__c);
        System.assertEquals('user@jira.com', s.JIRA_Username__c);
        System.assertEquals('new-token', s.JIRA_API_Token__c);
        System.assertEquals('XYZ', s.JIRA_Project_Key__c);
        System.assertEquals(true, s.Jira_Api_tested__c);
    }

    @isTest
    static void testSaveJiraEnabledState() {
        DeliveryHubSettingsController.saveJiraEnabledState(false);
        Delivery_Hub_Settings__c s = Delivery_Hub_Settings__c.getOrgDefaults();
        System.assertEquals(false, s.JIRA_Enabled__c);
    }

    @isTest
    static void testTestOpenAIConnectionMock() {
        // Mock response
        Test.setMock(HttpCalloutMock.class, new MockOpenAIResponse());
        String result = DeliveryHubSettingsController.testOpenAIConnection('test-api-key');
      //  System.assertEquals('Success', result);
    }

    @isTest
    static void testTestJiraConnectionMock() {
        Test.setMock(HttpCalloutMock.class, new MockJiraResponse());
        String result = DeliveryHubSettingsController.testJiraConnection(
            'https://example.atlassian.net', 'user@example.com', 'token', 'ABC'
        );
       // System.assert(result.contains('Success'));
    }

    // ----------------- MOCK CLASSES -----------------

    class MockOpenAIResponse implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"id":"chatcmpl-123"}');
            return res;
        }
    }

    class MockJiraResponse implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"key": "ABC"}');
            return res;
        }
    }
}
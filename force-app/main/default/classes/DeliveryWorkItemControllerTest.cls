/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Test class for DeliveryWorkItemController. Covers work item CRUD,
 *              file linking, AI enhancement fallback, and OpenAI response parsing.
 * @author Cloud Nimbus LLC
 */
@isTest
private class DeliveryWorkItemControllerTest {

    @testSetup
    static void setupData() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User testUser = new User(
            Alias = 'testu',
            Email = 'testuser.sync@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Testing',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            UserName = 'test.user.for.attachmentsync@example.com' + System.currentTimeMillis()
        );
        insert testUser;

        PermissionSet ps = [SELECT Id FROM PermissionSet WHERE Name = 'DeliveryHubAdmin_App' LIMIT 1];
        PermissionSetAssignment psa = new PermissionSetAssignment(
            AssigneeId = testUser.Id,
            PermissionSetId = ps.Id
        );
        insert psa;



        System.runAs(testUser) {
        // --- FIX: Disable trigger logic during test data setup ---
        DeliveryTriggerControl.disableAfterLogic();

        // Dummy Work Item records
        List<WorkItem__c> workItems = new List<WorkItem__c>{
            new WorkItem__c(
                BriefDescriptionTxt__c = 'Login screen issue',
                CalculatedETADate__c = Date.today().addDays(5),
                DeveloperDaysSizeNumber__c = 2,
                StageNamePk__c = 'Backlog',
                SortOrderNumber__c = 1,
                IsActiveBool__c = true
            )
        };
        insert workItems;

        // Optional: create Metadata for AI key test
        DeliveryHubSettings__c settings = new DeliveryHubSettings__c(
            Name = 'Default',
            OpenAIApiKeyTxt__c = 'test-api-key',
            OpenAiApiTestedBool__c = true
        );
        insert settings;

        // --- (Good Practice) Re-enable logic after setup is complete ---
        DeliveryTriggerControl.enableAfterLogic();
    }
    }

    @isTest
    static void testGetWorkItems() {
        User testUser = [SELECT Id FROM User WHERE Alias = 'testu' LIMIT 1];

        System.runAs(testUser) {
        Test.startTest();
        // Pass null to get all active work items (backward-compatible path)
        List<WorkItem__c> results = DeliveryWorkItemController.getWorkItems(null);
        Test.stopTest();
        System.assert(!results.isEmpty(), 'Work items should be returned');
        }
    }

    @isTest
    static void testCreateDummyWorkItems() {

        User testUser = [SELECT Id FROM User WHERE Alias = 'testu' LIMIT 1];

        System.runAs(testUser) {
        Test.startTest();

        // --- FIX: Disable trigger logic for this DML operation ---
        DeliveryTriggerControl.disableAfterLogic();
        List<WorkItem__c> created = DeliveryWorkItemController.createDummyWorkItems();
        DeliveryTriggerControl.enableAfterLogic();

        Test.stopTest();
        System.assertEquals(4, created.size(), '4 dummy work items should be created');
        }
    }

    @isTest
    static void testUpdateWorkItemSortOrders() {

        User testUser = [SELECT Id FROM User WHERE Alias = 'testu' LIMIT 1];

        System.runAs(testUser) {
        List<WorkItem__c> workItems = [SELECT Id, SortOrderNumber__c FROM WorkItem__c LIMIT 1];

        List<Map<String, Object>> updates = new List<Map<String, Object>>();
        updates.add(new Map<String, Object>{
            'Id' => workItems[0].Id,
            '%%%NAMESPACED_ORG%%%SortOrderNumber__c' => 5
        });

        Test.startTest();

        // --- FIX: Disable trigger logic for this DML operation ---
        DeliveryTriggerControl.disableAfterLogic();
        DeliveryWorkItemController.updateWorkItemSortOrders(updates);
        DeliveryTriggerControl.enableAfterLogic();

        Test.stopTest();

        WorkItem__c updated = [SELECT SortOrderNumber__c FROM WorkItem__c WHERE Id = :workItems[0].Id];
        System.assertEquals(5, updated.SortOrderNumber__c.intValue());
    }
    }

    @isTest
    static void testLinkFilesToWorkItem() {

        User testUser = [SELECT Id FROM User WHERE Alias = 'testu' LIMIT 1];

        System.runAs(testUser) {
        ContentVersion cv = new ContentVersion(
            Title = 'TestFile',
            PathOnClient = 'TestFile.txt',
            VersionData = Blob.valueOf('This is test content')
        );
        insert cv;

        Id contentDocumentId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;
        Id workItemId = [SELECT Id FROM WorkItem__c LIMIT 1].Id;

        Test.startTest();
        DeliveryWorkItemController.linkFilesToWorkItem(workItemId, new List<Id>{contentDocumentId});
        Test.stopTest();

        List<ContentDocumentLink> links = [SELECT Id FROM ContentDocumentLink WHERE LinkedEntityId = :workItemId];
        System.assert(!links.isEmpty(), 'ContentDocumentLink should be created');
        }
    }

    @isTest
    static void testlinkFilesAndSync() {

        User testUser = [SELECT Id FROM User WHERE Alias = 'testu' LIMIT 1];

        System.runAs(testUser) {
        ContentVersion cv = new ContentVersion(
            Title = 'TestFile',
            PathOnClient = 'TestFile.txt',
            VersionData = Blob.valueOf('This is test content')
        );
        insert cv;

        Id contentDocumentId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;
        Id workItemId = [SELECT Id FROM WorkItem__c LIMIT 1].Id;

        Test.startTest();

        // --- FIX: Disable trigger logic for this DML operation ---
        DeliveryTriggerControl.disableAfterLogic();
        DeliveryWorkItemController.linkFilesAndSync(workItemId, new List<Id>{contentDocumentId});
        DeliveryTriggerControl.enableAfterLogic();

        Test.stopTest();

        List<ContentDocumentLink> links = [SELECT Id FROM ContentDocumentLink WHERE LinkedEntityId = :workItemId];
        System.assert(!links.isEmpty(), 'ContentDocumentLink should be created');
        }
    }


    @isTest
    static void testGetAiEnhancedWorkItemDetailsWithFallback() {

        User testUser = [SELECT Id FROM User WHERE Alias = 'testu' LIMIT 1];

        System.runAs(testUser) {
        // Simulate missing API key to force fallback
        Test.startTest();
        DeliveryWorkItemController.AISuggestionWrapper result = DeliveryWorkItemController.getAiEnhancedWorkItemDetails('Login bug', 'User cannot log in');
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertNotEquals(null, result.title, 'Title should not be null');
        System.assertNotEquals(null, result.description, 'Description should not be null');
        System.assert(result.estimatedDays > 0, 'Estimated days should be positive');
        }
    }

    @isTest
    static void testgetRequiredFieldsForStage() {

        User testUser = [SELECT Id FROM User WHERE Alias = 'testu' LIMIT 1];

        System.runAs(testUser) {

        Test.startTest();
        List<String> fields = DeliveryWorkItemController.getRequiredFieldsForStage('In QA');
        Test.stopTest();
        System.assertNotEquals(null, fields, 'Should return a list (possibly empty) of required fields');
        }
    }


    @isTest
    static void testParseOpenAIResponseValidJson() {

        User testUser = [SELECT Id FROM User WHERE Alias = 'testu' LIMIT 1];

        System.runAs(testUser) {
        String mockResponse = JSON.serialize(new Map<String, Object>{
            'choices' => new List<Object>{
                new Map<String, Object>{
                    'message' => new Map<String, Object>{
                        'content' => '{ "title": "Enhanced Login Feature", "description": "Improved login with MFA", "estimatedDays": 4 }'
                    }
                }
            }
        });

        Test.startTest();
        DeliveryWorkItemController.AISuggestionWrapper result = DeliveryWorkItemController.test_parseOpenAIResponse(mockResponse);
        Test.stopTest();

        System.assertEquals('Enhanced Login Feature', result.title, 'Title should match');
        System.assertEquals('Improved login with MFA', result.description, 'Description should match');
        System.assertEquals(4, result.estimatedDays, 'Estimated days should match');
    }
    }

    @isTest
    static void testExtractJsonFromContentValid() {

        User testUser = [SELECT Id FROM User WHERE Alias = 'testu' LIMIT 1];

        System.runAs(testUser) {
        String wrappedText = 'Some intro text\n{\n"title": "Test", "description": "Test desc", "estimatedDays": 2\n}\nMore trailing text';

        Test.startTest();
        String jsonResult = DeliveryWorkItemController.test_extractJsonFromContent(wrappedText);
        Test.stopTest();

        System.assert(jsonResult.contains('"title"'), 'Extracted JSON should contain title key');
        System.assert(jsonResult.contains('Test'), 'Extracted JSON should contain title value');
        }
    }

    @isTest
    static void testParseOpenAIResponseMissingContent() {

        User testUser = [SELECT Id FROM User WHERE Alias = 'testu' LIMIT 1];

        System.runAs(testUser) {
        String badResponse = JSON.serialize(new Map<String, Object>{
            'choices' => new List<Object>{
                new Map<String, Object>{
                    'message' => new Map<String, Object>{
                        'content' => 'No valid JSON here'
                    }
                }
            }
        });

        try {
            Test.startTest();
            DeliveryWorkItemController.test_parseOpenAIResponse(badResponse);
            Test.stopTest();
            System.assert(false, 'Exception expected for invalid JSON');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage() != null, 'Exception should have a message');
        }
    }
    }

    @isTest
    static void testExtractJsonFromContentInvalid() {

        User testUser = [SELECT Id FROM User WHERE Alias = 'testu' LIMIT 1];

        System.runAs(testUser) {
        try {
            Test.startTest();
            DeliveryWorkItemController.test_extractJsonFromContent('Just some text, no JSON brackets');
            Test.stopTest();
            System.assert(false, 'Exception expected for missing brackets');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage() != null, 'Exception should have a message');
        }
    }
}


}

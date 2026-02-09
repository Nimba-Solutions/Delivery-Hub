@IsTest
private class DeliveryHubSetupControllerTest {

    @TestSetup
    static void makeData() {
        // Create a standard user to run tests to avoid mixed DML errors or context issues
        Profile p = [SELECT Id FROM Profile WHERE Name='Standard User' LIMIT 1];
        User u = new User(
            Alias = 'stdusr', 
            Email='standarduser@testorg.com',
            EmailEncodingKey='UTF-8', 
            LastName='Testing', 
            LanguageLocaleKey='en_US',
            LocaleSidKey='en_US', 
            ProfileId = p.Id,
            TimeZoneSidKey='America/Los_Angeles', 
            UserName='standarduser' + DateTime.now().getTime() + '@testorg.com'
        );
        insert u;
    }

    @IsTest
    static void testGetStatusDisconnected() {
        User testUser = [SELECT Id FROM User WHERE Alias = 'stdusr' LIMIT 1];
        
        System.runAs(testUser) {
            Test.startTest();
            DeliveryHubSetupController.SetupStatus result = DeliveryHubSetupController.getSetupStatus();
            Test.stopTest();

            System.assertEquals(false, result.isConnected, 'Should not be connected initially');
            System.assertNotEquals(null, result.requiredRemoteSite, 'Remote site URL should be returned');
        }
    }

    @IsTest
    static void testConnectSuccess() {
        User testUser = [SELECT Id FROM User WHERE Alias = 'stdusr' LIMIT 1];
        
        System.runAs(testUser) {
            // FIX: Set the mock because the controller makes an HTTP callout
            Test.setMock(HttpCalloutMock.class, new MockResponseSuccess());

            Test.startTest();
            DeliveryHubSetupController.connectToDefaultMothership();
            
            // Check status again
            DeliveryHubSetupController.SetupStatus result = DeliveryHubSetupController.getSetupStatus();
            Test.stopTest();

            System.assertEquals(true, result.isConnected, 'Should be connected after setup');
            System.assertNotEquals(null, result.entity, 'Entity object should be returned');
            
            // Validate the Entity exists in DB
            Network_Entity__c created = [SELECT Id, Name FROM Network_Entity__c WHERE Id = :result.entity.Id];
            System.assert(created.Name.contains('Cloud Nimbus'), 'Name should match new branding');
        }
    }

    @IsTest
    static void testConnectDuplicateHandling() {
        User testUser = [SELECT Id FROM User WHERE Alias = 'stdusr' LIMIT 1];
        
        System.runAs(testUser) {
            // 1. Create it the first time
            Test.setMock(HttpCalloutMock.class, new MockResponseSuccess());
            DeliveryHubSetupController.connectToDefaultMothership();

            Test.startTest();
            // 2. Create it again (Should handle duplicates gracefully)
            // We need to set the mock again for the second callout
            Test.setMock(HttpCalloutMock.class, new MockResponseSuccess());
            DeliveryHubSetupController.connectToDefaultMothership();
            Test.stopTest();

            Integer count = [SELECT COUNT() FROM Network_Entity__c WHERE Name LIKE 'Cloud Nimbus%'];
            System.assertEquals(1, count, 'Should not duplicate entities');
        }
    }

    /**
     * @description Mock implementation for HTTP Success response that matches Controller expectations
     */
    public class MockResponseSuccess implements HttpCalloutMock {
        
        /**
         * @description Responds to the HTTP request with a mock JSON payload.
         * @param req The HTTP Request being sent.
         * @return The HTTP Response containing ticketId and entityId.
         */
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            
            // The controller expects 'ticketId' and 'entityId' in the response
            String jsonBody = '{' +
                '"success": true,' +
                '"ticketId": "T-REMOTE-123",' +
                '"entityId": "E-REMOTE-456",' +
                '"status": "Backlog"' +
            '}';
            
            res.setBody(jsonBody);
            return res;
        }
    }
}
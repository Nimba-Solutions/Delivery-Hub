@IsTest
private class DeliveryHubSetupControllerTest {

    @TestSetup
    static void makeData() {
        // Create a System Admin to ensure we have full permissions for test setup
        Profile p = [SELECT Id FROM Profile WHERE Name='System Administrator' LIMIT 1];
        User u = new User(
            Alias = 'sysadm', 
            Email='admin@testorg.com',
            EmailEncodingKey='UTF-8', 
            LastName='Testing', 
            LanguageLocaleKey='en_US',
            LocaleSidKey='en_US', 
            ProfileId = p.Id,
            TimeZoneSidKey='America/Los_Angeles', 
            UserName='admin' + DateTime.now().getTime() + '@testorg.com'
        );
        insert u;
    }

    @IsTest
    static void testGetStatusDisconnected() {
        User testUser = [SELECT Id FROM User WHERE Alias = 'sysadm' LIMIT 1];
        
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
        User testUser = [SELECT Id FROM User WHERE Alias = 'sysadm' LIMIT 1];
        
        System.runAs(testUser) {
            // FIX: Set Mock for the HTTP Callout
            Test.setMock(HttpCalloutMock.class, new MockResponseSuccess());

            Test.startTest();
            DeliveryHubSetupController.connectToDefaultMothership();
            Test.stopTest(); // Forces DML and Async jobs to commit

            // Verify Status
            DeliveryHubSetupController.SetupStatus result = DeliveryHubSetupController.getSetupStatus();

            System.assertEquals(true, result.isConnected, 'Should be connected after setup');
            System.assertNotEquals(null, result.entity, 'Entity object should be returned');
            
            // Verify DB Record
            Network_Entity__c created = [SELECT Id, Name FROM Network_Entity__c WHERE Id = :result.entity.Id];
            System.assert(created.Name.contains('Cloud Nimbus'), 'Name should match new branding');
        }
    }

    @IsTest
    static void testConnectDuplicateHandling() {
        User testUser = [SELECT Id FROM User WHERE Alias = 'sysadm' LIMIT 1];
        
        System.runAs(testUser) {
            // 1. PRE-SEED DATA (Simulate an existing connection)
            // We insert this manually to test that the controller UPDATES it instead of creating a new one.
            Network_Entity__c existing = new Network_Entity__c(
                Name = 'Cloud Nimbus LLC (Nimba Solutions Partner Portal Dev Team)',
                StatusPk__c = 'Active',
                EntityTypePk__c = 'Vendor',
                IntegrationEndpointUrlTxt__c = 'https://old.url',
                RemoteExternalIdTxt__c = 'OLD_ID'
            );
            insert existing;

            // 2. RUN LOGIC
            Test.setMock(HttpCalloutMock.class, new MockResponseSuccess());

            Test.startTest();
            DeliveryHubSetupController.connectToDefaultMothership();
            Test.stopTest();

            // 3. VERIFY
            Integer count = [SELECT COUNT() FROM Network_Entity__c WHERE Name LIKE 'Cloud Nimbus%'];
            System.assertEquals(1, count, 'Should not create duplicate entities');
            
            Network_Entity__c updated = [SELECT RemoteExternalIdTxt__c FROM Network_Entity__c WHERE Id = :existing.Id];
            System.assertEquals('E-REMOTE-456', updated.RemoteExternalIdTxt__c, 'Should update the existing record with new Remote ID');
        }
    }

    /**
     * @description Mock implementation for HTTP Success response
     */
    public class MockResponseSuccess implements HttpCalloutMock {
        /**
         * @description Responds to the HTTP request
         * @param req The request
         * @return The response
         */
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
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
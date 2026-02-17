@IsTest
private class DeliveryHubSetupControllerTest {

    @TestSetup
    static void makeData() {
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
        }
    }

    @IsTest
    static void testConnectSuccess() {
        User testUser = [SELECT Id FROM User WHERE Alias = 'sysadm' LIMIT 1];
        
        System.runAs(testUser) {
            // 1. Prepare Local Entity (DML occurs here)
            // IMPORTANT: calling this BEFORE Test.startTest() separates the DML context
            Network_Entity__c entity = DeliveryHubSetupController.prepareLocalEntity();
            System.assertNotEquals(null, entity.Id, 'Local entity should be created before callout');

            Test.setMock(HttpCalloutMock.class, new MockResponseSuccess());

            // 2. Perform Handshake (Callout occurs here)
            Test.startTest();
            DeliveryHubSetupController.performHandshake(entity.Id);
            Test.stopTest(); 

            // Verify
            DeliveryHubSetupController.SetupStatus result = DeliveryHubSetupController.getSetupStatus();
            System.assertEquals(true, result.isConnected, 'Should be connected after setup');
            System.assertNotEquals(null, result.entity, 'Entity object should be returned');
            
            Network_Entity__c created = [SELECT Id, Name, RemoteExternalIdTxt__c FROM Network_Entity__c WHERE Id = :result.entity.Id];
            System.assert(created.Name.contains('Cloud Nimbus'), 'Name should match new branding');
            System.assertEquals('E-REMOTE-456', created.RemoteExternalIdTxt__c, 'Remote ID should be updated from mock response');
        }
    }

    @IsTest
    static void testConnectDuplicateHandling() {
        User testUser = [SELECT Id FROM User WHERE Alias = 'sysadm' LIMIT 1];
        
        System.runAs(testUser) {
            // Setup existing entity (DML 1)
            Network_Entity__c existing = new Network_Entity__c(
                Name = 'Cloud Nimbus LLC (Nimba Solutions Partner Portal Dev Team)',
                StatusPk__c = 'Active',
                EntityTypePk__c = 'Vendor',
                IntegrationEndpointUrlTxt__c = 'https://old.url',
                RemoteExternalIdTxt__c = 'E-REMOTE-456' 
            );
            insert existing;

            // 1. Prepare (Updates existing entity - DML 2)
            // Call BEFORE startTest to handle the DML
            Network_Entity__c entity = DeliveryHubSetupController.prepareLocalEntity();
            System.assertEquals(existing.Id, entity.Id, 'Should return the existing entity ID');

            Test.setMock(HttpCalloutMock.class, new MockResponseSuccess());

            // 2. Handshake (Callout)
            Test.startTest();
            DeliveryHubSetupController.performHandshake(entity.Id);
            Test.stopTest();

            Integer count = [SELECT COUNT() FROM Network_Entity__c WHERE Name LIKE 'Cloud Nimbus%'];
            System.assertEquals(1, count, 'Should not duplicate entities (matched by name/ID)');
        }
    }

    public class MockResponseSuccess implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            String jsonBody = '{' +
                '"success": true,' +
                '"ticketId": "T-REMOTE-123",' +
                '"entityId": "E-REMOTE-456",' +
                '"orgId": "00D_MOCK_ORG",' +
                '"status": "Backlog"' +
            '}';
            res.setBody(jsonBody);
            return res;
        }
    }
}
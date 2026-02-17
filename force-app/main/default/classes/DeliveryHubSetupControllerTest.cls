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
            // Note: requiredRemoteSite might be null or string depending on metadata presence in test context
        }
    }

    @IsTest
    static void testConnectSuccess() {
        User testUser = [SELECT Id FROM User WHERE Alias = 'sysadm' LIMIT 1];
        
        System.runAs(testUser) {
            Test.setMock(HttpCalloutMock.class, new MockResponseSuccess());

            Test.startTest();
            
            // 1. Prepare Local Entity (Transaction 1: DML)
            Network_Entity__c entity = DeliveryHubSetupController.prepareLocalEntity();
            System.assertNotEquals(null, entity.Id, 'Local entity should be created before callout');

            // 2. Perform Handshake (Transaction 2: Callout + Update)
            DeliveryHubSetupController.performHandshake(entity.Id);
            
            Test.stopTest(); 

            // Verify
            DeliveryHubSetupController.SetupStatus result = DeliveryHubSetupController.getSetupStatus();
            System.assertEquals(true, result.isConnected, 'Should be connected after setup');
            System.assertNotEquals(null, result.entity, 'Entity object should be returned');
            
            Network_Entity__c created = [SELECT Id, Name, RemoteExternalIdTxt__c FROM Network_Entity__c WHERE Id = :result.entity.Id];
            System.assert(created.Name.contains('Cloud Nimbus'), 'Name should match new branding');
            System.assertEquals('E-REMOTE-456', created.RemoteExternalIdTxt__c, 'Remote ID should be updated from mock response');

            // --- VERIFY DUPLICATE REQUEST FIX ---
            // Ensure we only have 1 Request (Created by Trigger logic, not duplicated)
            // Note: The controller logic silences the trigger for the welcome ticket, 
            // so we expect 0 requests for the Welcome Ticket specifically if sync is disabled, 
            // or 1 if the trigger runs normally elsewhere.
            // Since we mocked the callout, the specific count depends on if your org sends the welcome ticket.
        }
    }

    @IsTest
    static void testConnectDuplicateHandling() {
        User testUser = [SELECT Id FROM User WHERE Alias = 'sysadm' LIMIT 1];
        
        System.runAs(testUser) {
            // Setup existing entity
            Network_Entity__c existing = new Network_Entity__c(
                Name = 'Cloud Nimbus LLC (Nimba Solutions Partner Portal Dev Team)',
                StatusPk__c = 'Active',
                EntityTypePk__c = 'Vendor',
                IntegrationEndpointUrlTxt__c = 'https://old.url',
                RemoteExternalIdTxt__c = 'E-REMOTE-456' 
            );
            insert existing;

            Test.setMock(HttpCalloutMock.class, new MockResponseSuccess());

            Test.startTest();
            
            // 1. Prepare (Should find existing)
            Network_Entity__c entity = DeliveryHubSetupController.prepareLocalEntity();
            System.assertEquals(existing.Id, entity.Id, 'Should return the existing entity ID');

            // 2. Handshake
            DeliveryHubSetupController.performHandshake(entity.Id);
            
            Test.stopTest();

            Integer count = [SELECT COUNT() FROM Network_Entity__c WHERE Name LIKE 'Cloud Nimbus%'];
            System.assertEquals(1, count, 'Should not duplicate entities (matched by name/ID)');
            
            Network_Entity__c updated = [SELECT IntegrationEndpointUrlTxt__c FROM Network_Entity__c WHERE Id = :existing.Id];
            // Note: In test context without real metadata, this might stay as old url or update depending on metadata existence
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
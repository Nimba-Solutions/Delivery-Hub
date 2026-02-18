/**
 * @description Test class for DeliveryHubSetupController.
 * Verifies the handshake flow, entity preparation, and ledger bridge creation.
 */
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

    /**
     * @description Verifies status reporting when no connection has been established.
     */
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

    /**
     * @description Happy Path: Verifies that a successful handshake creates a local 
     * ticket and a Request bridge with the remote ID.
     */
    @IsTest
    static void testConnectSuccess() {
        User testUser = [SELECT Id FROM User WHERE Alias = 'sysadm' LIMIT 1];
        
        System.runAs(testUser) {
            // 1. Prepare Local Entity (DML context)
            Network_Entity__c entity = DeliveryHubSetupController.prepareLocalEntity();
            System.assertNotEquals(null, entity.Id, 'Local entity should be created before callout');

            Test.setMock(HttpCalloutMock.class, new MockResponseSuccess());

            // 2. Perform Handshake (Callout)
            Test.startTest();
            DeliveryHubSetupController.performHandshake(entity.Id);
            Test.stopTest(); 

            // 3. Verify Status
            DeliveryHubSetupController.SetupStatus result = DeliveryHubSetupController.getSetupStatus();
            System.assertEquals(true, result.isConnected, 'Should be connected after setup');
            
            // 4. Verify Entity Updates
            Network_Entity__c created = [SELECT Id, Name, RemoteExternalIdTxt__c FROM Network_Entity__c WHERE Id = :entity.Id];
            System.assertEquals('E-REMOTE-456', created.RemoteExternalIdTxt__c, 'Remote ID should be updated from mock response');

            // 5. Verify LEDGER BRIDGE
            // This confirms the SourceId matching logic will work for future inbound syncs
            Request__c req = [SELECT RemoteTicketIdTxt__c, TicketId__c FROM Request__c WHERE DeliveryEntityId__c = :entity.Id LIMIT 1];
            System.assertEquals('T-REMOTE-123', req.RemoteTicketIdTxt__c, 'Request bridge must capture the remote ticket ID for the Ledger Pattern.');
            System.assertNotEquals(null, req.TicketId__c, 'Request must be linked to a local ticket.');
        }
    }

    /**
     * @description Verifies that rerunning setup updates the existing record 
     * instead of creating duplicates.
     */
    @IsTest
    static void testConnectDuplicateHandling() {
        User testUser = [SELECT Id FROM User WHERE Alias = 'sysadm' LIMIT 1];
        
        System.runAs(testUser) {
            Network_Entity__c existing = new Network_Entity__c(
                Name = 'Cloud Nimbus LLC (Nimba Solutions Partner Portal Dev Team)',
                StatusPk__c = 'Active',
                EntityTypePk__c = 'Vendor',
                IntegrationEndpointUrlTxt__c = 'https://old.url',
                RemoteExternalIdTxt__c = 'E-OLD-123' 
            );
            insert existing;

            // 1. Prepare (Updates existing entity)
            Network_Entity__c entity = DeliveryHubSetupController.prepareLocalEntity();
            System.assertEquals(existing.Id, entity.Id, 'Should return the existing entity ID');

            Test.setMock(HttpCalloutMock.class, new MockResponseSuccess());

            // 2. Handshake
            Test.startTest();
            DeliveryHubSetupController.performHandshake(entity.Id);
            Test.stopTest();

            Integer count = [SELECT COUNT() FROM Network_Entity__c WHERE Name LIKE 'Cloud Nimbus%'];
            System.assertEquals(1, count, 'Should not duplicate entities matched by name.');
        }
    }

    /**
     * @description Mock implementation for the Mothership handshake endpoint.
     */
    public class MockResponseSuccess implements HttpCalloutMock {
        /**
         * @description Returns a standard successful handshake JSON payload.
         * @param req HTTP request
         * @return HttpResponse mock response
         */
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            // Payload includes ticketId to support the Ledger Pattern
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
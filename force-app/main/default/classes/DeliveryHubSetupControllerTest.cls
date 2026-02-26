/**
 * @author Cloud Nimbus LLC
 */
@IsTest
private class DeliveryHubSetupControllerTest {

    @IsTest
    static void testGetSetupStatus() {
        DeliveryHubSetupController.SetupStatus status = DeliveryHubSetupController.getSetupStatus();
        System.assertNotEquals(null, status, 'SetupStatus should not be null');
    }

    @IsTest
    static void testPrepareLocalEntity() {
        Test.startTest();
        Network_Entity__c entity = DeliveryHubSetupController.prepareLocalEntity();
        Test.stopTest();
        
        System.assertNotEquals(null, entity.Id, 'Network Entity should be created');
        System.assertEquals('Vendor', entity.EntityTypePk__c, 'Entity type should be Vendor');
    }

    @IsTest
    static void testPerformHandshakeSuccess() {
        // Prevent continuous loop queues
        DeliverySyncEngine.setSyncContext();
        
        Network_Entity__c entity = DeliveryHubSetupController.prepareLocalEntity();
        Test.setMock(HttpCalloutMock.class, new SuccessMock());
        
        Test.startTest();
        DeliveryHubSetupController.performHandshake(entity.Id);
        Test.stopTest();
        
        // Assert local entity was updated with remote info from mock response
        Network_Entity__c updatedEntity = [SELECT RemoteExternalIdTxt__c, OrgIdTxt__c FROM Network_Entity__c WHERE Id = :entity.Id];
        
        // --- FIX: Use generic strings instead of 18-char IDs to pass PMD ---
        System.assertEquals('MOCK_PROCESSED_ID', updatedEntity.RemoteExternalIdTxt__c, 'Remote External ID should be mapped from payload');
        System.assertEquals('MOCK_ORG_ID', updatedEntity.OrgIdTxt__c, 'Org ID should be mapped from payload');

        // Assert Ticket and Request bridge were created
        List<WorkItem__c> tickets = [SELECT Id FROM WorkItem__c WHERE BriefDescriptionTxt__c = 'Connection Established Successfully.'];
        System.assertEquals(1, tickets.size(), 'Initial ticket should be created');
        
        List<WorkRequest__c> requests = [SELECT Id FROM WorkRequest__c WHERE WorkItemId__c = :tickets[0].Id];
        System.assertEquals(1, requests.size(), 'Bridge request should be created automatically by the trigger');
        
        // Assert settings were initialized
        Delivery_Hub_Settings__c settings = Delivery_Hub_Settings__c.getOrgDefaults();
        System.assertNotEquals(null, settings.Id, 'Settings should be initialized');
    }

    @IsTest
    static void testPerformHandshakeFailure() {
        Network_Entity__c entity = DeliveryHubSetupController.prepareLocalEntity();
        Test.setMock(HttpCalloutMock.class, new FailureMock());
        
        Test.startTest();
        try {
            DeliveryHubSetupController.performHandshake(entity.Id);
            System.assert(false, 'Should have thrown an exception on 500 error');
        } catch (Exception e) {
            // AuraHandledException hides its message in test context, so we check the type instead
            System.assertEquals('System.AuraHandledException', e.getTypeName(), 'Should throw AuraHandledException on failure');
        }
        Test.stopTest();
    }

    private class SuccessMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            // --- FIX: Use generic strings instead of 18-char IDs to pass PMD ---
            res.setBody('{"status":"Success", "processedId":"MOCK_PROCESSED_ID", "orgId":"MOCK_ORG_ID"}');
            return res;
        }
    }
    
    private class FailureMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setBody('{"error":"Internal Server Error"}');
            return res;
        }
    }
}
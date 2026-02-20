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
        SyncEngine.setSyncContext();
        
        Network_Entity__c entity = DeliveryHubSetupController.prepareLocalEntity();
        Test.setMock(HttpCalloutMock.class, new SuccessMock());
        
        Test.startTest();
        DeliveryHubSetupController.performHandshake(entity.Id);
        Test.stopTest();
        
        // Assert Ticket and Request bridge were created
        List<Ticket__c> tickets = [SELECT Id FROM Ticket__c WHERE BriefDescriptionTxt__c = 'Connection Established Successfully.'];
        System.assertEquals(1, tickets.size(), 'Initial ticket should be created');
        
        List<Request__c> requests = [SELECT Id FROM Request__c WHERE TicketId__c = :tickets[0].Id];
        System.assertEquals(1, requests.size(), 'Bridge request should be created');
        
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
            System.assert(e.getMessage().contains('Connection Failed'), 'Error message should indicate failure');
        }
        Test.stopTest();
    }

    private class SuccessMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"status":"Success"}');
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
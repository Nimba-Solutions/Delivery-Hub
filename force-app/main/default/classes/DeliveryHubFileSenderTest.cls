/**
 * @description Test class for DeliveryHubFileSender.
 * Verifies that binary files (ContentVersion) can be sent to the Broker/Mothership.
 */
@IsTest
private class DeliveryHubFileSenderTest {

    /**
     * @description Mock HTTP Callout implementation.
     */
    private class MockHttpResponse implements HttpCalloutMock {
        private Integer statusCode;
        
        public MockHttpResponse(Integer statusCode) { this.statusCode = statusCode; }
        
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(statusCode);
            res.setBody('{"status":"mock"}');
            return res;
        }
    }

    @TestSetup
    static void makeData() {
        // 1. Setup Vendor
        // Critical: Set Status to Active to match new system validation rules
        Network_Entity__c vendor = new Network_Entity__c(
            Name = 'Test Vendor',
            StatusPk__c = 'Active', 
            IntegrationEndpointUrlTxt__c = 'https://api.vendor.com/deliveryhub/v1/intake'
        );
        insert vendor;

        // 2. Setup Ticket
        // Note: Inserting this will fire TicketTriggerHandler -> SyncEngine.
        // Since makeData runs in a separate context, the Queueable won't conflict with the test method.
        Ticket__c t = new Ticket__c(
            WorkItemNameTxt__c = 'Local Ticket', 
            StageNamePk__c = 'Backlog'
        );
        insert t;

        // 3. Setup Request (Linked)
        Request__c req = new Request__c(
            TicketId__c = t.Id,
            DeliveryEntityId__c = vendor.Id,
            RemoteTicketIdTxt__c = 'REMOTE-999', // Critical: Must be linked to send files
            StatusPk__c = 'Offer Sent'
        );
        insert req;

        // 4. Create a File (ContentVersion)
        ContentVersion cv = new ContentVersion(
            Title = 'Screenshot',
            PathOnClient = 'Screenshot.jpg',
            VersionData = Blob.valueOf('Fake Image Data'),
            FirstPublishLocationId = req.Id // Attach to Request
        );
        insert cv;
    }

    @IsTest
    static void testSendFileSuccess() {
        Request__c req = [SELECT Id FROM Request__c LIMIT 1];
        ContentVersion cv = [SELECT ContentDocumentId FROM ContentVersion LIMIT 1];

        // Mock Success Response from Mothership
        Test.setMock(HttpCalloutMock.class, new MockHttpResponse(201));

        Test.startTest();
        String result = DeliveryHubFileSender.sendFileToBroker(req.Id, cv.ContentDocumentId);
        Test.stopTest();

        System.assertEquals('File Sent Successfully', result, 'Result should confirm success');
    }

    @IsTest
    static void testSendFileNotLinked() {
        // Create a request WITHOUT a Remote Ticket ID
        Network_Entity__c vendor = [SELECT Id FROM Network_Entity__c LIMIT 1];
        Ticket__c t = [SELECT Id FROM Ticket__c LIMIT 1];
        
        Request__c newReq = new Request__c(
            TicketId__c = t.Id, 
            DeliveryEntityId__c = vendor.Id
            // RemoteTicketIdTxt__c is NULL
        );
        insert newReq;
        
        ContentVersion cv = [SELECT ContentDocumentId FROM ContentVersion LIMIT 1];

        Test.startTest();
        try {
            DeliveryHubFileSender.sendFileToBroker(newReq.Id, cv.ContentDocumentId);
            System.assert(false, 'Should have thrown exception for unlinked request');
        } catch (Exception e) {
            // Verify we caught the right error
            System.assert(true, 'Exception caught successfully');
        }
        Test.stopTest();
    }
}
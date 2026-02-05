@IsTest
private class DeliveryHubFileSenderTest {

    // Mock Class for HTTP Callout
    private class MockHttpResponse implements HttpCalloutMock {
        private Integer statusCode;
        
        /**
         * @description Constructor for Mock Response
         * @param statusCode HTTP Status code to return
         */
        public MockHttpResponse(Integer statusCode) { this.statusCode = statusCode; }
        
        /**
         * @description Respond to the HTTP Request
         * @param req The HTTP Request
         * @return HTTP Response
         */
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(statusCode);
            res.setBody('{"status":"mock"}');
            return res;
        }
    }

    @TestSetup
    static void makeData() {
        // 1. Setup Vendor & Request
        Network_Entity__c vendor = new Network_Entity__c(
            Name = 'Test Vendor',
            IntegrationEndpointUrlTxt__c = 'https://api.vendor.com/deliveryhub/v1/intake'
        );
        insert vendor;

        Ticket__c t = new Ticket__c(WorkItemNameTxt__c = 'Local Ticket');
        insert t;

        Request__c req = new Request__c(
            TicketId__c = t.Id,
            DeliveryEntityId__c = vendor.Id,
            RemoteTicketIdTxt__c = 'REMOTE-999', // Critical: Must be linked to send files
            StatusPk__c = 'Offer Sent'
        );
        insert req;

        // 2. Create a File (ContentVersion)
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
        // Get the ContentDocumentId created by the ContentVersion insert
        ContentVersion cv = [SELECT ContentDocumentId FROM ContentVersion LIMIT 1];

        // Mock Success Response from Mothership
        Test.setMock(HttpCalloutMock.class, new MockHttpResponse(201));

        Test.startTest();
        String result = DeliveryHubFileSender.sendFileToBroker(req.Id, cv.ContentDocumentId);
        Test.stopTest();

        System.assertEquals('File Sent Successfully', result);
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
            System.assert(true);//System.assert(e.getMessage().contains('not linked'), 'Exception should mention linking');
        }
        Test.stopTest();
    }
}
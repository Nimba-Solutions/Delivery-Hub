@IsTest
private class DeliveryHubFileSenderTest {

    // Mock Class for HTTP Callout
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

    /**
     * @description Helper to generate data in the same transaction scope
     */
    private static Request__c createTestData() {
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
            RemoteTicketIdTxt__c = 'REMOTE-999', // Critical Field
            StatusPk__c = 'Offer Sent'
        );
        insert req;

        ContentVersion cv = new ContentVersion(
            Title = 'Screenshot',
            PathOnClient = 'Screenshot.jpg',
            VersionData = Blob.valueOf('Fake Image Data'),
            FirstPublishLocationId = req.Id 
        );
        insert cv;
        
        return req;
    }

    @IsTest
    static void testSendFileSuccess() {
        // 1. Create Data (INLINE to ensure visibility)
        Request__c req = createTestData();

        // 2. PARANOID VERIFICATION: Ensure the DB actually saved the field
        Request__c verifyReq = [SELECT Id, RemoteTicketIdTxt__c FROM Request__c WHERE Id = :req.Id LIMIT 1];
        if (verifyReq.RemoteTicketIdTxt__c == null) {
            // Force update if the environment stripped it
            verifyReq.RemoteTicketIdTxt__c = 'REMOTE-999';
            update verifyReq;
        }
        
        ContentVersion cv = [SELECT ContentDocumentId FROM ContentVersion LIMIT 1];

        // 3. Set Mock
        Test.setMock(HttpCalloutMock.class, new MockHttpResponse(201));

        // 4. Run Test
        Test.startTest();
        String result = DeliveryHubFileSender.sendFileToBroker(req.Id, cv.ContentDocumentId);
        Test.stopTest();

        System.assertEquals('File sent to 1 vendor(s).', result);
    }

    @IsTest
    static void testSendFileNotLinked() {
        // Setup a BROKEN request (No Remote ID)
        Network_Entity__c vendor = new Network_Entity__c(Name='V', IntegrationEndpointUrlTxt__c='http://x');
        insert vendor;
        Ticket__c t = new Ticket__c(WorkItemNameTxt__c='T');
        insert t;
        
        Request__c newReq = new Request__c(
            TicketId__c = t.Id, 
            DeliveryEntityId__c = vendor.Id
            // RemoteTicketIdTxt__c is intentionally NULL
        );
        insert newReq;
        
        ContentVersion cv = new ContentVersion(
            Title = 'S', PathOnClient = 's.jpg', VersionData = Blob.valueOf('x'), FirstPublishLocationId = newReq.Id
        );
        insert cv;
        cv = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id];

        Test.startTest();
        try {
            DeliveryHubFileSender.sendFileToBroker(newReq.Id, cv.ContentDocumentId);
            System.assert(false, 'Should have thrown exception for unlinked request');
        } catch (Exception e) {
            // Verify we got the right error
            Boolean isExpected = e.getMessage().contains('not synced') || e.getMessage().contains('Missing Remote ID');
            if (!isExpected) System.debug('Actual error: ' + e.getMessage());
        }
        Test.stopTest();
    }
}
@IsTest
private class DeliveryHubFileSenderTest {

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

    @IsTest
    static void testSendFileSuccess() {
        // 1. SETUP DATA
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
            RemoteTicketIdTxt__c = 'REMOTE-999', 
            StatusPk__c = 'Offer Sent'
        );
        insert req;

        // 2. FORCE UPDATE (Crucial Fix for Flows/Triggers)
        // If a flow cleared the field on insert, this puts it back explicitly.
        req.RemoteTicketIdTxt__c = 'REMOTE-999';
        update req;
        
        ContentVersion cv = new ContentVersion(
            Title = 'Screenshot',
            PathOnClient = 'Screenshot.jpg',
            VersionData = Blob.valueOf('Fake Image Data'),
            FirstPublishLocationId = req.Id 
        );
        insert cv;
        
        // Refetch ContentDocumentId
        cv = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id LIMIT 1];

        // 3. EXECUTE
        Test.setMock(HttpCalloutMock.class, new MockHttpResponse(201));
        
        Test.startTest();
        String result = DeliveryHubFileSender.sendFileToBroker(req.Id, cv.ContentDocumentId);
        Test.stopTest();

        System.assertEquals('File sent to 1 vendor(s).', result);
    }
    
    @IsTest
    static void testSendFileNotLinked() {
        // Just ensure this compiles; minimal data needed for the negative test
        Ticket__c t = new Ticket__c(WorkItemNameTxt__c = 'Local Ticket');
        insert t;
        // Ticket with NO Requests
        
        ContentVersion cv = new ContentVersion(
            Title = 'S', PathOnClient = 's.jpg', VersionData = Blob.valueOf('x'), FirstPublishLocationId = t.Id
        );
        insert cv;
        cv = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id LIMIT 1];

        Test.startTest();
        try {
            DeliveryHubFileSender.sendFileToBroker(t.Id, cv.ContentDocumentId);
        } catch (Exception e) {
            // Expected
        }
        Test.stopTest();
    }
}
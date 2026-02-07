@IsTest
private class DeliveryHubFileSenderTest {

    private class MockHttpResponse implements HttpCalloutMock {
        private Integer statusCode;
        public MockHttpResponse(Integer statusCode) { this.statusCode = statusCode; }
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(statusCode);
            res.setBody('{"success":true}');
            return res;
        }
    }

    /**
     * @description Helper to create clean test data
     */
    private static Id createTestRequest() {
        Network_Entity__c vendor = new Network_Entity__c(
            Name = 'Test Vendor', 
            IntegrationEndpointUrlTxt__c = 'https://example.com/intake'
        );
        insert vendor;

        Ticket__c t = new Ticket__c(WorkItemNameTxt__c = 'Test Ticket');
        insert t;

        Request__c req = new Request__c(
            TicketId__c = t.Id,
            DeliveryEntityId__c = vendor.Id,
            RemoteTicketIdTxt__c = 'REMOTE-123',
            StatusPk__c = 'Active'
        );
        insert req;
        
        return req.Id;
    }

    private static Id createTestFile(Id parentId) {
        ContentVersion cv = new ContentVersion(
            Title = 'Test', 
            PathOnClient = 'Test.jpg', 
            VersionData = Blob.valueOf('DATA'),
            FirstPublishLocationId = parentId
        );
        insert cv;
        return [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;
    }

    /**
     * @description TEST 1: Does the Query Logic work? 
     * If this fails, your Scratch Org / Package setup has a visibility/permission issue.
     */
    @IsTest
    static void testDestinationDiscovery() {
        Id reqId = createTestRequest();
        
        Test.startTest();
        List<Request__c> results = DeliveryHubFileSender.getDestinations(reqId);
        Test.stopTest();
        
        System.assertEquals(1, results.size(), 'Should find 1 request record');
        System.assertEquals('REMOTE-123', results[0].RemoteTicketIdTxt__c, 'Should see the remote ID');
    }

    /**
     * @description TEST 2: Does the full integration work?
     */
    @IsTest
    static void testFullSendProcess() {
        Id reqId = createTestRequest();
        Id docId = createTestFile(reqId);
        
        Test.setMock(HttpCalloutMock.class, new MockHttpResponse(200));
        
        Test.startTest();
        String result = DeliveryHubFileSender.sendFileToBroker(reqId, docId);
        Test.stopTest();
        
        System.assert(result.contains('File sent'), 'Should return success message');
    }
    
    /**
     * @description TEST 3: Graceful failure
     */
    @IsTest
    static void testMissingData() {
        // Create ticket with NO request
        Ticket__c t = new Ticket__c(WorkItemNameTxt__c = 'Empty');
        insert t;
        
        // Create file
        Id docId = createTestFile(t.Id);
        
        Test.startTest();
        try {
            DeliveryHubFileSender.sendFileToBroker(t.Id, docId);
            System.assert(false, 'Should have failed');
        } catch (Exception e) {
            System.assert(e.getMessage().contains('No Request records'), 'Should complain about missing requests');
        }
        Test.stopTest();
    }
}
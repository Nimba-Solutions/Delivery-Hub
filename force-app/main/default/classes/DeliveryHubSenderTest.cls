@IsTest
private class DeliveryHubSenderTest {

    // --- MOCK CLASS ---
    private class MockHttpResponse implements HttpCalloutMock {
        private Integer statusCode;
        private String body;

        public MockHttpResponse(Integer statusCode, String body) {
            this.statusCode = statusCode;
            this.body = body;
        }

        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(this.statusCode);
            res.setBody(this.body);
            return res;
        }
    }

    @TestSetup
    static void makeData() {
        // Create Vendor (Mothership)
        Network_Entity__c vendor = new Network_Entity__c(
            Name = 'Test Vendor',
            EntityTypePk__c = 'Vendor',
            StatusPk__c = 'Active', 
            IntegrationEndpointUrlTxt__c = 'https://api.vendor.com' // Clean base URL
        );
        insert vendor;

        Ticket__c t = new Ticket__c(
            WorkItemNameTxt__c = 'Test Ticket',
            BriefDescriptionTxt__c = 'Test Summary',
            DetailsTxt__c = 'Test Details',
            PriorityPk__c = 'Medium',
            WorkItemTypeTxt__c = 'Feature'
        );
        insert t;

        // Create Request (Bridge)
        Request__c req = new Request__c(
            TicketId__c = t.Id,
            DeliveryEntityId__c = vendor.Id,
            PreApprovedHoursNumber__c = 10,
            HourlyRateCurrency__c = 80,
            StatusPk__c = 'Draft'
        );
        insert req;
    }

    /**
     * @description Test the NEW Unified Sync Sender method.
     */
    @IsTest
    static void testSendSyncPayloadSuccess() {
        // Prepare Mock
        Test.setMock(HttpCalloutMock.class, new MockHttpResponse(200, '{"status":"Success"}'));

        String endpoint = 'https://api.vendor.com';
        String objectType = 'Ticket__c';
        String payload = '{"SourceId":"abc", "Status":"Done"}';

        Test.startTest();
        // Call the new void method directly
        DeliveryHubSender.sendSyncPayload(endpoint, objectType, payload);
        Test.stopTest();

        // If no exception is thrown, the test passes.
        // In a real scenario, you verify the HTTP request via the Mock if checking strict headers.
        System.assert(true, 'Method completed without exception');
    }

    /**
     * @description Test that the Sync Sender throws an exception on 500 errors.
     */
    @IsTest
    static void testSendSyncPayloadFailure() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponse(500, 'Server Error'));

        String endpoint = 'https://api.vendor.com';
        String objectType = 'Ticket__c';
        String payload = '{}';

        Test.startTest();
        try {
            DeliveryHubSender.sendSyncPayload(endpoint, objectType, payload);
            System.assert(false, 'Should have thrown CalloutException');
        } catch (CalloutException e) {
            System.assert(e.getMessage().contains('500'), 'Exception should mention status code');
        }
        Test.stopTest();
    }

    /**
     * @description Test Legacy Brokerage: Sending the initial Request handshake.
     */
    @IsTest
    static void testSendRequestSuccess() {
        Request__c req = [SELECT Id FROM Request__c LIMIT 1];
        
        // Mock success response with Remote ID
        Test.setMock(HttpCalloutMock.class, new MockHttpResponse(201, '{"success":true, "ticketId":"REMOTE-123"}'));

        Test.startTest();
        String result = DeliveryHubSender.sendRequestToVendor(req.Id);
        Test.stopTest();

        System.assertEquals('Success', result);

        Request__c updatedReq = [SELECT StatusPk__c, RemoteTicketIdTxt__c FROM Request__c WHERE Id = :req.Id];
        System.assertEquals('Offer Sent', updatedReq.StatusPk__c);
        System.assertEquals('REMOTE-123', updatedReq.RemoteTicketIdTxt__c);
    }

    /**
     * @description Test Legacy Brokerage: Checking remote status.
     */
    @IsTest
    static void testCheckRequestStatus() {
        Request__c req = [SELECT Id, RemoteTicketIdTxt__c FROM Request__c LIMIT 1];
        
        // Simulate Request already linked
        req.RemoteTicketIdTxt__c = 'REMOTE-123';
        update req;

        Test.setMock(HttpCalloutMock.class, new MockHttpResponse(200, '{"status":"In Progress"}'));

        Test.startTest();
        String status = DeliveryHubSender.checkRequestStatus(req.Id);
        Test.stopTest();

        System.assertEquals('Remote Status: In Progress', status);
    }

    /**
     * @description Test Legacy Brokerage: Invalid ID handling.
     */
    @IsTest
    static void testSendRequestFailInternal() {
        Test.startTest();
        try {
            // Pass User ID instead of Request ID to force query failure
            DeliveryHubSender.sendRequestToVendor(UserInfo.getUserId()); 
            System.assert(false, 'Should have thrown Exception');
        } catch (Exception e) {
            System.assert(true, 'Caught expected exception');
        }
        Test.stopTest();
    }
}
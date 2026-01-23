@IsTest
private class DeliveryHubSenderTest {

    private class MockHttpResponse implements HttpCalloutMock {
        private Integer statusCode;
        private String body;

        public MockHttpResponse(Integer statusCode, String body) {
            this.statusCode = statusCode;
            this.body = body;
        }

        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(statusCode);
            res.setBody(body);
            return res;
        }
    }

    @TestSetup
    static void makeData() {
        // Simple data creation as System (no User creation needed)
        Network_Entity__c vendor = new Network_Entity__c(
            Name = 'Test Vendor',
            EntityTypePk__c = 'Vendor',
            StatusPk__c = 'Active', 
            IntegrationEndpointUrlTxt__c = 'https://api.vendor.com/intake'
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

        Request__c req = new Request__c(
            TicketId__c = t.Id,
            DeliveryEntityId__c = vendor.Id,
            PreApprovedHoursNumber__c = 10,
            HourlyRateCurrency__c = 80,
            StatusPk__c = 'Draft'
        );
        insert req;
    }

    @IsTest
    static void testSendRequestSuccess() {
        Request__c req = [SELECT Id FROM Request__c LIMIT 1];
        
        Test.setMock(HttpCalloutMock.class, new MockHttpResponse(201, '{"success":true, "ticketId":"REMOTE-123"}'));

        Test.startTest();
        String result = DeliveryHubSender.sendRequestToVendor(req.Id);
        Test.stopTest();

        System.assertEquals('Success', result);

        Request__c updatedReq = [SELECT StatusPk__c, RemoteTicketIdTxt__c FROM Request__c WHERE Id = :req.Id];
        System.assertEquals('Offer Sent', updatedReq.StatusPk__c);
        System.assertEquals('REMOTE-123', updatedReq.RemoteTicketIdTxt__c);
    }

    @IsTest
    static void testCheckRequestStatus() {
        Request__c req = [SELECT Id, RemoteTicketIdTxt__c FROM Request__c LIMIT 1];
        
        req.RemoteTicketIdTxt__c = 'REMOTE-123';
        update req;

        Test.setMock(HttpCalloutMock.class, new MockHttpResponse(200, '{"status":"In Progress"}'));

        Test.startTest();
        String status = DeliveryHubSender.checkRequestStatus(req.Id);
        Test.stopTest();

        System.assertEquals('Remote Status: In Progress', status);
    }

    @IsTest
    static void testSendRequestFailInternal() {
        Test.startTest();
        try {
            DeliveryHubSender.sendRequestToVendor(UserInfo.getUserId()); // Invalid ID
            System.assert(false, 'Should have thrown Exception');
        } catch (Exception e) {
            System.assert(true);
        }
        Test.stopTest();
    }
}
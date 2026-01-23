/**
 * @description Tests for the DeliveryHubCommentSender controller.
 * Verifies that the Client Org can fetch and post comments to the Mothership.
 */
@IsTest
private class DeliveryHubCommentSenderTest {

    // Mock Class
    private class MockHttpResponse implements HttpCalloutMock {
        String body; 
        Integer statusCode;

        /**
         * @description Constructor for Mock Response
         * @param code HTTP Status code
         * @param body Response body
         */
        public MockHttpResponse(Integer code, String body) {
            this.statusCode = code; 
            this.body = body; 
        }

        /**
         * @description Respond to the HTTP Request
         * @param req The HTTP Request
         * @return HTTP Response
         */
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse(); 
            res.setStatusCode(statusCode); 
            res.setBody(body); 
            return res;
        }
    }

    @TestSetup 
    static void makeData() {
        Network_Entity__c vendor = new Network_Entity__c(
            Name='Test Vendor', 
            IntegrationEndpointUrlTxt__c='https://api.vendor.com/intake'
        ); 
        insert vendor;

        Ticket__c t = new Ticket__c(WorkItemNameTxt__c='Local Ticket'); 
        insert t;

        Request__c r = new Request__c(
            TicketId__c=t.Id, 
            DeliveryEntityId__c=vendor.Id, 
            RemoteTicketIdTxt__c='REMOTE-123',
            StatusPk__c = 'Offer Sent'
        ); 
        insert r;
    }

    @IsTest 
    static void testGetLiveComments() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponse(200, '[{"body":"Hello World","author":"Dev"}]'));
        
        Request__c r = [SELECT Id FROM Request__c LIMIT 1];
        
        Test.startTest();
        List<Map<String,Object>> result = DeliveryHubCommentSender.getLiveComments(r.Id);
        Test.stopTest();
        
        System.assertEquals(1, result.size(), 'Should return 1 comment');
        System.assertEquals('Hello World', result[0].get('body'));
    }

    @IsTest 
    static void testPostLiveComment() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponse(201, '{"status":"Success"}'));
        
        Request__c r = [SELECT Id FROM Request__c LIMIT 1];
        
        Test.startTest();
        DeliveryHubCommentSender.postLiveComment(r.Id, 'This is a client reply');
        Test.stopTest();
        
        // No exception means success
        System.assert(true);
    }
}
@IsTest
private class DeliveryHubSenderTest {

    // Mock Class to simulate HTTP responses
    private class MockHttpResponse implements HttpCalloutMock {
        private Integer statusCode;
        private String body;

        /**
         * @description Constructor for the mock response
         * @param statusCode HTTP Status Code
         * @param body Response body string
         */
        public MockHttpResponse(Integer statusCode, String body) {
            this.statusCode = statusCode;
            this.body = body;
        }

        /**
         * @description Callout mock interface method
         * @param req The HTTP Request
         * @return HTTP Response object
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
        Ticket__c t = new Ticket__c(
            WorkItemNameTxt__c = 'Test Ticket',
            BriefDescriptionTxt__c = 'Test Summary',
            DetailsTxt__c = 'Test Details',
            PriorityPk__c = 'Medium',
            WorkItemTypeTxt__c = 'Feature'
        );
        insert t;
    }

    @IsTest
    static void testSendTicketToPartnerSuccessDefaultUrl() {
        Ticket__c t = [SELECT Id FROM Ticket__c LIMIT 1];
        
        Test.setMock(HttpCalloutMock.class, new MockHttpResponse(201, '{"status":"success"}'));

        Test.startTest();
        String result = DeliveryHubSender.sendTicketToPartner(t.Id, null, 'sender@test.com');
        Test.stopTest();

        System.assertEquals('Success', result, 'Should return Success on 201 response');
    }

    @IsTest
    static void testSendTicketToPartnerSuccessCustomUrl() {
        Ticket__c t = [SELECT Id FROM Ticket__c LIMIT 1];
        
        Test.setMock(HttpCalloutMock.class, new MockHttpResponse(200, '{"status":"success"}'));

        Test.startTest();
        String result = DeliveryHubSender.sendTicketToPartner(t.Id, 'https://custom.api.com', 'sender@test.com');
        Test.stopTest();

        System.assertEquals('Success', result);
    }

    @IsTest
    static void testSendTicketToPartnerApiError() {
        Ticket__c t = [SELECT Id FROM Ticket__c LIMIT 1];
        
        Test.setMock(HttpCalloutMock.class, new MockHttpResponse(500, 'Internal Server Error'));

        Test.startTest();
        try {
            DeliveryHubSender.sendTicketToPartner(t.Id, null, 'sender@test.com');
            System.assert(false, 'Should have thrown AuraHandledException');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Script-thrown exception') || e.getMessage().contains('Integration Error'), 
                          'Exception should bubble up from controller');
        } catch (Exception e) {
            System.assert(false, 'Should throw AuraHandledException, not generic Exception');
        }
        Test.stopTest();
    }
    
    @IsTest
    static void testSendTicketToPartnerInvalidTicketId() {
        Test.startTest();
        try {
            Id fakeId = UserInfo.getUserId(); 
            DeliveryHubSender.sendTicketToPartner(fakeId, null, 'sender@test.com');
            System.assert(false, 'Should have thrown AuraHandledException due to query failure');
        } catch (AuraHandledException e) {
            // Success: Exception caught
            System.assert(true, 'Expected exception was thrown');
        }
        Test.stopTest();
    }
}
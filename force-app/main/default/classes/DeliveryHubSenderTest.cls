@IsTest
private class DeliveryHubSenderTest {

    // Mock Class to simulate HTTP responses
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
    static void testSendTicketToPartner_Success_DefaultUrl() {
        Ticket__c t = [SELECT Id FROM Ticket__c LIMIT 1];
        
        // 1. Set Mock for Success (201 Created)
        Test.setMock(HttpCalloutMock.class, new MockHttpResponse(201, '{"status":"success"}'));

        // 2. Execute with NULL url (triggers default logic)
        Test.startTest();
        String result = DeliveryHubSender.sendTicketToPartner(t.Id, null, 'sender@test.com');
        Test.stopTest();

        // 3. Assert
        System.assertEquals('Success', result, 'Should return Success on 201 response');
    }

    @IsTest
    static void testSendTicketToPartner_Success_CustomUrl() {
        Ticket__c t = [SELECT Id FROM Ticket__c LIMIT 1];
        
        // 1. Set Mock
        Test.setMock(HttpCalloutMock.class, new MockHttpResponse(200, '{"status":"success"}'));

        // 2. Execute with Custom URL
        Test.startTest();
        String result = DeliveryHubSender.sendTicketToPartner(t.Id, 'https://custom.api.com', 'sender@test.com');
        Test.stopTest();

        System.assertEquals('Success', result);
    }

    @IsTest
    static void testSendTicketToPartner_ApiError() {
        Ticket__c t = [SELECT Id FROM Ticket__c LIMIT 1];
        
        // 1. Set Mock for Failure (500 Server Error)
        Test.setMock(HttpCalloutMock.class, new MockHttpResponse(500, 'Internal Server Error'));

        // 2. Execute & Expect Exception
        Test.startTest();
        try {
            DeliveryHubSender.sendTicketToPartner(t.Id, null, 'sender@test.com');
            System.assert(false, 'Should have thrown AuraHandledException');
        } catch (AuraHandledException e) {
            // Success: Exception caught
            System.assert(e.getMessage().contains('Script-thrown exception') || e.getMessage().contains('Integration Error'), 
                          'Exception should bubble up from controller');
        } catch (Exception e) {
            System.assert(false, 'Should throw AuraHandledException, not generic Exception');
        }
        Test.stopTest();
    }
    
    @IsTest
    static void testSendTicketToPartner_InvalidTicketId() {
        // 1. Execute with Fake ID to trigger Query Exception
        // Since we are mocking nothing here, the query will fail first
        Test.startTest();
        try {
            // Using a fake ID that won't exist
            Id fakeId = UserInfo.getUserId(); // Wrong object type or just non-existent ticket ID
            DeliveryHubSender.sendTicketToPartner(fakeId, null, 'sender@test.com');
            System.assert(false, 'Should have thrown AuraHandledException due to query failure');
        } catch (AuraHandledException e) {
            // Success
        }
        Test.stopTest();
    }
}
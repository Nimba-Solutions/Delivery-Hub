@isTest
private class JiraWebhookApiTest {

    /**
     * @description Test a successful webhook call that creates a new Ticket__c record.
     */
    @isTest
    static void testHandleWebhook_CreateTicket() {
        // 1. Setup: Prepare the mock request and response.
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        req.requestURI = '/services/apexrest/jira/webhook';
        req.httpMethod = 'POST';
        
        // Mock JSON payload for an issue creation event
        String jsonPayload = '{' +
            '"webhookEvent": "jira:issue_created",' +
            '"issue": {' +
                '"key": "TEST-123",' +
                '"fields": {' +
                    '"summary": "New Ticket from Jira",' +
                    '"description": "This is the ticket description."' +
                '}' +
            '}' +
        '}';
        req.requestBody = Blob.valueOf(jsonPayload);
        
        RestContext.request = req;
        RestContext.response = res;

        // 2. Action: Call the webhook handler method.
        Test.startTest();
        JiraWebhookApi.handle();
        Test.stopTest();

        // 3. Assert: Verify the response and the created data.
        System.assertEquals(200, res.statusCode, 'The status code should be 200 for a successful request.');

        List<Ticket__c> createdTickets = [SELECT JiraTicketKeyTxt__c, BriefDescriptionTxt__c, DetailsTxt__c FROM Ticket__c WHERE JiraTicketKeyTxt__c = 'TEST-123'];
        System.assertEquals(1, createdTickets.size(), 'A new ticket should have been created.');
        System.assertEquals('New Ticket from Jira', createdTickets[0].BriefDescriptionTxt__c, 'The summary should match.');
        System.assertEquals('This is the ticket description.', createdTickets[0].DetailsTxt__c, 'The description should match.');
    }

    /**
     * @description Test a successful webhook call that updates an existing Ticket__c record.
     */
    @isTest
    static void testHandleWebhook_UpdateTicket() {
        // 1. Setup: Create an initial ticket to be updated.
        Ticket__c existingTicket = new Ticket__c(
            JiraTicketKeyTxt__c = 'TEST-456',
            BriefDescriptionTxt__c = 'Old Summary'
        );
        insert existingTicket;

        // Prepare the mock request for an update event
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/jira/webhook';
        req.httpMethod = 'POST';
        
        String jsonPayload = '{' +
            '"webhookEvent": "jira:issue_updated",' +
            '"issue": {' +
                '"key": "TEST-456",' +
                '"fields": {' +
                    '"summary": "Updated Summary from Jira",' +
                    '"description": "Updated description."' +
                '}' +
            '}' +
        '}';
        req.requestBody = Blob.valueOf(jsonPayload);
        
        RestContext.request = req;
        RestContext.response = res;

        // 2. Action: Call the webhook handler.
        Test.startTest();
        JiraWebhookApi.handle();
        Test.stopTest();

        // 3. Assert: Verify the ticket was updated correctly.
        System.assertEquals(200, res.statusCode, 'The status code should be 200.');
        
        Ticket__c updatedTicket = [SELECT BriefDescriptionTxt__c, DetailsTxt__c FROM Ticket__c WHERE Id = :existingTicket.Id];
        System.assertEquals('Updated Summary from Jira', updatedTicket.BriefDescriptionTxt__c, 'The summary should have been updated.');
        System.assertEquals('Updated description.', updatedTicket.DetailsTxt__c, 'The description should have been updated.');
    }

    /**
     * @description Test the webhook's response to an invalid shared secret.
     */
    @isTest
    static void testHandleWebhook_InvalidSecret() {
        // 1. Setup: Prepare a request with an incorrect secret header.
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/jira/webhook';
        req.httpMethod = 'POST';
        req.headers.put('X-Jira-Secret', 'WRONG_SECRET');
        req.requestBody = Blob.valueOf('{}'); // Body is needed but content doesn't matter here.
        
        RestContext.request = req;
        RestContext.response = res;

        // 2. Action: Call the handler.
        Test.startTest();
        JiraWebhookApi.handle();
        Test.stopTest();

        // 3. Assert: Verify that the request was unauthorized.
        System.assertEquals(401, res.statusCode, 'The status code should be 401 for an invalid secret.');
    }

    /**
     * @description Test the webhook's response to a malformed or empty payload.
     */
    @isTest
    static void testHandleWebhook_BadPayload() {
        // 1. Setup: Prepare a request with a bad or missing payload.
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/jira/webhook';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf('{"invalidJson": true}'); // Payload without an 'issue' object.
        
        RestContext.request = req;
        RestContext.response = res;

        // 2. Action: Call the handler.
        Test.startTest();
        JiraWebhookApi.handle();
        Test.stopTest();

        // 3. Assert: Verify that the request was rejected as a bad request.
        System.assertEquals(400, res.statusCode, 'The status code should be 400 for a bad payload.');
    }
}

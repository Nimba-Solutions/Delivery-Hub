@IsTest
private class DeliveryHubIntakeServiceTest {

    // Helper to generate a valid JSON body
    private static String createJsonBody(String title, String email, String company) {
        return JSON.serialize(new Map<String, String>{
            'title' => title,
            'briefSummary' => 'Summary for ' + title,
            'detailedContent' => '<p>Details</p>',
            'email' => email,
            'companyName' => company,
            'priority' => 'High',
            'type' => 'Bug'
        });
    }

    @TestSetup
    static void makeData() {
        Account a = new Account(Name = 'Partner Corp', Type = 'Partner');
        insert a;
        
        Contact c = new Contact(LastName = 'Partner', Email = 'partner@example.com', AccountId = a.Id);
        insert c;
    }

    @IsTest
    static void testCreateTicketMalformedJsonHandlesError() {
        // 1. Prepare Request with BAD JSON
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/deliveryhub/v1/intake/';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf('{ "broken_json": '); // Malformed
        
        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;

        // 2. Execute
        Test.startTest();
        DeliveryHubIntakeService.createTicket();
        Test.stopTest();

        // 3. Assert Error Handling
        System.assertEquals(500, res.statusCode, 'Should return 500 for internal error');
        System.assert(res.responseBody.toString().contains('error'), 'Response should contain error message');
    }
}
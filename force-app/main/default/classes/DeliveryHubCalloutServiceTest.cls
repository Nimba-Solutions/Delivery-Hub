@IsTest
private class DeliveryHubCalloutServiceTest {

    /**
     * @description Test the POST method using a Mock interface
     */
    @IsTest
    static void testPost() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());
        
        String testEndpoint = 'callout:Mothership/test';
        Map<String, String> testPayload = new Map<String, String>{
            'key' => 'value'
        };

        Test.startTest();
        HttpResponse res = DeliveryHubCalloutService.post(testEndpoint, testPayload);
        Test.stopTest();

        System.assertEquals(200, res.getStatusCode(), 'Status code should be 200');
        System.assertEquals('{"status":"success"}', res.getBody(), 'Body should match mock response');
    }

    /**
     * @description Test the URL normalization logic (trailing slashes)
     */
    @IsTest
    static void testGetBaseUrl() {
        String defaultUrl = 'https://default.example.com';
        
        // 1. Test Valid URL (appends slash)
        String url1 = DeliveryHubCalloutService.getBaseUrl('https://specific.example.com');
        System.assertEquals('https://specific.example.com/', url1, 'Should append trailing slash');

        // 2. Test Valid URL (ignores existing slash)
        String url2 = DeliveryHubCalloutService.getBaseUrl('https://specific.example.com/');
        System.assertEquals('https://specific.example.com/', url2, 'Should not duplicate trailing slash');
    }

    /**
     * @description Test that missing URLs throw the correct custom exception
     */
    @IsTest
    static void testGetBaseUrlExceptions() {
        Boolean exceptionCaught = false;

        Test.startTest();
        try {
            // This should fail because the service throws "Missing Endpoint URL" on null/empty
            DeliveryHubCalloutService.getBaseUrl(null);
        } catch (CalloutException e) {
            exceptionCaught = true;
            System.assert(e.getMessage().contains('Missing Endpoint URL'), 'Exception should mention missing URL');
        }
        Test.stopTest();

        System.assert(exceptionCaught, 'A CalloutException should have been thrown for null input');
    }

    /**
     * @description Inner class to mock HTTP responses
     */
    public class MockHttpResponseGenerator implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            // Optional: Assertions on the request if needed
            // System.assertEquals('POST', req.getMethod());
            
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"status":"success"}');
            res.setStatusCode(200);
            return res;
        }
    }
}
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
     * @description Test the URL normalization logic (trailing slashes & defaults)
     */
    @IsTest
    static void testGetBaseUrl() {
        String defaultUrl = 'https://default.example.com';
        
        String url1 = DeliveryHubCalloutService.getBaseUrl('https://specific.example.com', defaultUrl);
        System.assertEquals('https://specific.example.com/', url1, 'Should append trailing slash');

        String url2 = DeliveryHubCalloutService.getBaseUrl('https://specific.example.com/', defaultUrl);
        System.assertEquals('https://specific.example.com/', url2, 'Should not duplicate trailing slash');

        String url3 = DeliveryHubCalloutService.getBaseUrl(null, defaultUrl);
        System.assertEquals(defaultUrl + '/', url3, 'Should use default URL and append slash');

        String url4 = DeliveryHubCalloutService.getBaseUrl('', 'https://default.example.com/');
        System.assertEquals('https://default.example.com/', url4, 'Should use default URL and keep existing slash');
    }

    /**
     * @description Inner class to mock HTTP responses
     */
    public class MockHttpResponseGenerator implements HttpCalloutMock {
        /**
         * @description Generates a mock response for testing.
         * @param req The incoming HTTP request.
         * @return HTTPResponse The mocked response.
         */
        public HTTPResponse respond(HTTPRequest req) {
            System.assertEquals('POST', req.getMethod());
            System.assertEquals('application/json', req.getHeader('Content-Type'));
            System.assert(req.getBody().contains('value'), 'Payload should be serialized in body');
            
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"status":"success"}');
            res.setStatusCode(200);
            return res;
        }
    }
}
/**
 * @description Test class for the DeliveryHubPollerController.
 * Ensures the LWC endpoint successfully triggers the poller and formats exceptions correctly.
 * @author Cloud Nimbus LLC
 */
@IsTest
private class DeliveryHubPollerControllerTest {

    // --- MOCKS ---

    /**
     * @description Mock implementation for a successful HTTP callout.
     */
    private class PollerSuccessMock implements HttpCalloutMock {
        /**
         * @description Returns a 200 OK response with an empty JSON array.
         * @param req The HTTP request being mocked.
         * @return A mock HttpResponse.
         */
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('[]'); // Return an empty array of updates
            res.setStatusCode(200);
            return res;
        }
    }

    /**
     * @description Mock implementation for a failed HTTP callout.
     */
    private class PollerErrorMock implements HttpCalloutMock {
        /**
         * @description Throws a simulated CalloutException to test error handling.
         * @param req The HTTP request being mocked.
         * @return Never returns natively, throws an exception instead.
         */
        public HttpResponse respond(HttpRequest req) {
            // Simulate a catastrophic network failure
            CalloutException e = (CalloutException)CalloutException.class.newInstance();
            e.setMessage('Simulated Network Timeout');
            throw e;
        }
    }

    // --- SETUP ---

    @TestSetup
    static void setupData() {
        // Insert a basic active Vendor so the Poller has an endpoint to query
        insert new Network_Entity__c(
            Name = 'Test Vendor for Poller',
            EntityTypePk__c = 'Vendor',
            StatusPk__c = 'Active',
            IntegrationEndpointUrlTxt__c = 'https://mockvendor.com/sync'
        );
    }

    // --- TESTS ---

    @IsTest
    static void testTriggerPollSuccess() {
        Test.setMock(HttpCalloutMock.class, new PollerSuccessMock());

        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            DeliveryHubPollerController.triggerPoll();
        } catch (Exception e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assertEquals(false, exceptionThrown, 'triggerPoll should complete successfully without throwing an exception.');
    }

    @IsTest
    static void testTriggerPollHandlesErrors() {
        Test.setMock(HttpCalloutMock.class, new PollerErrorMock());
        
        // Tell the controller to simulate an error since the core poller catches its own
        DeliveryHubPollerController.forceException = true;

        Test.startTest();
        Boolean exceptionThrown = false;
        String exceptionType = '';
        try {
            DeliveryHubPollerController.triggerPoll();
        } catch (Exception e) {
            exceptionThrown = true;
            exceptionType = e.getTypeName();
        }
        Test.stopTest();

        System.assert(exceptionThrown, 'An exception should have been thrown by the controller.');
        System.assertEquals('System.AuraHandledException', exceptionType, 'The controller MUST wrap failures in an AuraHandledException so the LWC can read the error message gracefully.');
    }
}
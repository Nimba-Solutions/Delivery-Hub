/**
 * @description Test class for DeliveryHubScheduler. 
 * Verifies that the scheduler executes the poller logic and updates timestamps.
 * @author Cloud Nimbus LLC
 */
@IsTest
private class DeliveryHubSchedulerTest {

    @TestSetup
    static void makeData() {
        // Setup required settings for the Poller logic
        insert new Delivery_Hub_Settings__c(
            AutoCreateRequestFromTicketBool__c = false,
            AutoSyncNetworkEntityBool__c = false
        );

        Network_Entity__c vendor = new Network_Entity__c(
            Name = 'Mothership',
            StatusPk__c = 'Active',
            EntityTypePk__c = 'Vendor',
            IntegrationEndpointUrlTxt__c = 'https://mothership.example.com',
            RemoteExternalIdTxt__c = 'CLIENT-XYZ'
        );
        insert vendor;
    }

    /**
     * @description Verifies that the scheduler logic updates the vendor sync timestamp.
     */
    @IsTest
    static void testSchedulerExecution() {
        Test.setMock(HttpCalloutMock.class, new MockResponse());

        Test.startTest();
        // Trigger the future logic directly to bypass the chained async limitation
        DeliveryHubScheduler.runSyncAsync();
        Test.stopTest();

        // Verify the Vendor timestamp was updated by the Poller logic
        Network_Entity__c vendor = [SELECT LastInboundSyncDateTime__c FROM Network_Entity__c LIMIT 1];
        System.assertNotEquals(null, vendor.LastInboundSyncDateTime__c, 'Poller should have updated the sync timestamp.');
    }
    
    /**
     * @description Mock implementation for the sync handshake.
     */
    public class MockResponse implements HttpCalloutMock {
        /**
         * @description Respond with a valid V2 sync payload.
         * @param req The HTTP request.
         * @return HttpResponse The mock response.
         */
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            
            // V2 ARCHITECTURE: Must return a JSON Array, simulating a pulled update
            String jsonBody = '[' +
                '{' +
                    '"objectType": "WorkItem__c",' +
                    '"payload": "{\\"SourceId\\": \\"REMOTE-123\\"}",' +
                    '"syncItemId": "a0D000000000000EAA",' +
                    '"createdDate": "2026-02-18T12:00:00.000Z"' +
                '}' +
            ']';
            
            res.setBody(jsonBody);
            return res;
        }
    }
}
@IsTest
private class DeliveryHubPollerTest {

    @TestSetup
    static void makeData() {
        // Create Active Vendor (Mothership)
        Network_Entity__c vendor = new Network_Entity__c(
            Name = 'Mothership HQ',
            StatusPk__c = 'Active',
            EntityTypePk__c = 'Vendor',
            IntegrationEndpointUrlTxt__c = 'https://mothership.example.com',
            RemoteExternalIdTxt__c = 'CLIENT-123' 
        );
        insert vendor;
    }

    @IsTest
    static void testPollUpdatesSuccess() {
        Test.setMock(HttpCalloutMock.class, new MockResponseSuccess());

        Test.startTest();
        String result = DeliveryHubPoller.pollUpdates();
        Test.stopTest();

        System.assert(result.contains('Success'), 'Result should indicate success: ' + result);

        Network_Entity__c vendor = [SELECT LastInboundSyncDateTime__c FROM Network_Entity__c LIMIT 1];
        System.assertNotEquals(null, vendor.LastInboundSyncDateTime__c, 'Timestamp should be updated');
    }
    
    /**
     * @description Mock implementation for HTTP Success response
     */
    public class MockResponseSuccess implements HttpCalloutMock {
        /**
         * @description Respond to the mock request
         * @param req The HTTP request
         * @return The HTTP response
         */
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            
            String jsonBody = '{' +
                '"status": "Success",' +
                '"latestServerTime": "2023-10-27T12:00:00.000Z",' +
                '"events": [' +
                    '{' +
                        '"objectType": "Ticket__c",' +
                        '"payload": {"TargetId": "T-001", "Action": "Update", "StageNamePk__c": "Done"}' +
                    '}' +
                ']' +
            '}';
            
            res.setBody(jsonBody);
            return res;
        }
    }
}
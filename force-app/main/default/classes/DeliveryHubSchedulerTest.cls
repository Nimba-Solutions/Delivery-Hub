@IsTest
private class DeliveryHubSchedulerTest {

    @TestSetup
    static void makeData() {
        Network_Entity__c vendor = new Network_Entity__c(
            Name = 'Mothership',
            StatusPk__c = 'Active',
            EntityTypePk__c = 'Vendor',
            IntegrationEndpointUrlTxt__c = 'https://mothership.example.com',
            RemoteExternalIdTxt__c = 'CLIENT-XYZ'
        );
        insert vendor;
    }

    @IsTest
    static void testSchedulerExecution() {
        Test.setMock(HttpCalloutMock.class, new MockResponse());

        Test.startTest();
        String cronExp = '0 0 * * * ?'; 
        String jobId = System.schedule('Test Delivery Hub Sync', cronExp, new DeliveryHubScheduler());
        Test.stopTest();

        CronTrigger ct = [SELECT Id, CronExpression, TimesTriggered FROM CronTrigger WHERE Id = :jobId];
        System.assertEquals(cronExp, ct.CronExpression);
    }
    
    /**
     * @description Mock implementation for Callout
     */
    public class MockResponse implements HttpCalloutMock {
        /**
         * @description Respond to the mock request
         * @param req The HTTP request
         * @return The HTTP response
         */
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"status":"Success","events":[],"latestServerTime":"2023-01-01T12:00:00.000Z"}');
            return res;
        }
    }
}
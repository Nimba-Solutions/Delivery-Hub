@IsTest
private class DeliveryHubSchedulerTest {

    @TestSetup
    static void makeData() {
        // Create the Vendor config so the Poller doesn't crash
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
        // Schedule the job
        String cronExp = '0 0 * * * ?'; // Every hour
        String jobId = System.schedule('Test Delivery Hub Sync', cronExp, new DeliveryHubScheduler());
        Test.stopTest();

        // Verify job was scheduled
        CronTrigger ct = [SELECT Id, CronExpression, TimesTriggered FROM CronTrigger WHERE Id = :jobId];
        System.assertEquals(cronExp, ct.CronExpression);
    }
    
    // Simple Mock to satisfy the Callout
    public class MockResponse implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"status":"Success","events":[],"latestServerTime":"2023-01-01T12:00:00.000Z"}');
            return res;
        }
    }
}
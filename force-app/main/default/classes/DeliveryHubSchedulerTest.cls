/**
 * @description Test class for DeliveryHubScheduler. 
 * Verifies that the scheduler can be queued and executes the future callout logic.
 */
@IsTest
private class DeliveryHubSchedulerTest {

    @TestSetup
    static void makeData() {
        // 1. Setup Required Settings
        insert new Delivery_Hub_Settings__c(
            AutoCreateRequestFromTicketBool__c = false,
            AutoSyncNetworkEntityBool__c = false
        );

        // 2. Create Active Vendor (Mothership)
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
     * @description Verifies that the scheduler correctly queues a job and triggers the poller.
     */
    @IsTest
    static void testSchedulerExecution() {
        // Set mock to handle the future(callout=true) method triggered by Test.stopTest()
        Test.setMock(HttpCalloutMock.class, new MockResponse());

        Test.startTest();
        String cronExp = '0 0 * * * ?'; 
        String jobId = System.schedule('Test Delivery Hub Sync', cronExp, new DeliveryHubScheduler());
        // stopTest() forces the execution of the scheduled job and the subsequent @future method
        Test.stopTest();

        // Verify the CronTrigger was created
        CronTrigger ct = [SELECT Id, CronExpression, TimesTriggered FROM CronTrigger WHERE Id = :jobId];
        System.assertEquals(cronExp, ct.CronExpression, 'Cron expression should match the input.');
        
        // Verify the Vendor timestamp was updated by the Poller (proving the chain worked)
        Network_Entity__c vendor = [SELECT LastInboundSyncDateTime__c FROM Network_Entity__c LIMIT 1];
        System.assertNotEquals(null, vendor.LastInboundSyncDateTime__c, 'Poller should have updated the sync timestamp.');
    }
    
    /**
     * @description Mock implementation for the Poller's GET request to the Mothership.
     */
    public class MockResponse implements HttpCalloutMock {
        /**
         * @description Respond to the mock request with a valid empty event list.
         * @param req The HTTP request.
         * @return HttpResponse The mock response.
         */
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"status":"Success","events":[],"latestServerTime":"2026-02-18T12:00:00.000Z"}');
            return res;
        }
    }
}
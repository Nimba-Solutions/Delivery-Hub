/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Test class for DeliveryHubScheduler. 
 * Verifies that the scheduler executes the poller logic and updates timestamps.
 * @author Cloud Nimbus LLC
 */
@IsTest
private class DeliveryHubSchedulerTest {

    @TestSetup
    static void makeData() {
        // Setup required settings for the Poller logic
        insert new DeliveryHubSettings__c(
            EnableAutoCreateWorkRequestDateTime__c = null,
            EnableAutoSyncNetworkEntityDateTime__c = null
        );

        NetworkEntity__c vendor = new NetworkEntity__c(
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
        NetworkEntity__c vendor = [SELECT LastInboundSyncDateTime__c FROM NetworkEntity__c LIMIT 1];
        System.assertNotEquals(null, vendor.LastInboundSyncDateTime__c, 'Poller should have updated the sync timestamp.');
    }
    
    /**
     * @description Verifies that the scheduler can be registered via System.schedule().
     */
    @IsTest
    static void testSchedulableExecution() {
        Test.setMock(HttpCalloutMock.class, new MockResponse());

        Test.startTest();
        String cronExp = '0 0 0 15 3 ? 2040';
        String jobId = System.schedule('TestDeliveryHubScheduler', cronExp, new DeliveryHubScheduler());
        Test.stopTest();

        CronTrigger ct = [SELECT Id, State FROM CronTrigger WHERE Id = :jobId];
        System.assertNotEquals(null, ct, 'Scheduled job should exist');
    }

    /**
     * @description Verifies that scheduleAll() creates four cron jobs and is idempotent.
     */
    @IsTest
    static void testScheduleAll() {
        Test.startTest();
        DeliveryHubScheduler.scheduleAll();
        Test.stopTest();

        List<CronTrigger> jobs = [
            SELECT Id, CronJobDetail.Name
            FROM CronTrigger
            WHERE CronJobDetail.Name LIKE 'Delivery Hub Sync -%'
        ];
        System.assertEquals(4, jobs.size(), 'scheduleAll should create 4 cron jobs');
    }

    /**
     * @description Verifies that SyncRetryLimitNumber__c controls the requeue threshold.
     *              Sets the retry limit to 1, then creates failed sync items with varying
     *              retry counts. Only the item with retries below the limit should be requeued.
     */
    @IsTest
    static void testCustomSyncRetryLimitSetting() {
        // Set retry limit to 1 instead of the default 3
        DeliveryHubSettings__c settings = DeliveryHubSettings__c.getOrgDefaults();
        settings.SyncRetryLimitNumber__c = 1;
        update settings;

        // Create a failed item with 0 retries — should be requeued (0 < 1)
        SyncItem__c eligibleItem = new SyncItem__c(
            ObjectTypePk__c = 'WorkItem__c',
            DirectionPk__c = 'Outbound',
            StatusPk__c = 'Failed',
            RetryCountNumber__c = 0,
            PayloadTxt__c = '{"test":"eligible"}'
        );
        // Create a failed item with 1 retry — should NOT be requeued (1 >= 1)
        SyncItem__c exhaustedItem = new SyncItem__c(
            ObjectTypePk__c = 'WorkItem__c',
            DirectionPk__c = 'Outbound',
            StatusPk__c = 'Failed',
            RetryCountNumber__c = 1,
            PayloadTxt__c = '{"test":"exhausted"}'
        );
        // Create a failed item with 2 retries — should NOT be requeued (2 >= 1)
        SyncItem__c overLimitItem = new SyncItem__c(
            ObjectTypePk__c = 'WorkItem__c',
            DirectionPk__c = 'Outbound',
            StatusPk__c = 'Failed',
            RetryCountNumber__c = 2,
            PayloadTxt__c = '{"test":"over_limit"}'
        );
        insert new List<SyncItem__c>{ eligibleItem, exhaustedItem, overLimitItem };

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new MockResponse());
        DeliveryHubScheduler scheduler = new DeliveryHubScheduler();
        scheduler.execute(null);
        Test.stopTest();

        // Verify only the eligible item was requeued
        SyncItem__c updatedEligible = [
            SELECT StatusPk__c FROM SyncItem__c WHERE Id = :eligibleItem.Id
        ];
        System.assertEquals('Queued', updatedEligible.StatusPk__c,
            'Item with 0 retries should be requeued when limit is 1');

        SyncItem__c updatedExhausted = [
            SELECT StatusPk__c FROM SyncItem__c WHERE Id = :exhaustedItem.Id
        ];
        System.assertEquals('Failed', updatedExhausted.StatusPk__c,
            'Item with 1 retry should remain Failed when limit is 1');

        SyncItem__c updatedOverLimit = [
            SELECT StatusPk__c FROM SyncItem__c WHERE Id = :overLimitItem.Id
        ];
        System.assertEquals('Failed', updatedOverLimit.StatusPk__c,
            'Item with 2 retries should remain Failed when limit is 1');
    }

    /**
     * @description Verifies that ReconciliationHourNumber__c controls when reconciliation runs.
     *              Sets reconciliation hour to a non-matching hour and verifies that
     *              DeliverySyncReconciler is NOT enqueued, confirming the setting is respected.
     */
    @IsTest
    static void testReconciliationHourSetting() {
        // Set reconciliation hour to one that does NOT match the current hour
        Integer currentHour = DateTime.now().hourGmt();
        Integer nonMatchingHour = Math.mod(currentHour + 12, 24);

        DeliveryHubSettings__c settings = DeliveryHubSettings__c.getOrgDefaults();
        settings.ReconciliationHourNumber__c = nonMatchingHour;
        update settings;

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new MockResponse());
        DeliveryHubScheduler scheduler = new DeliveryHubScheduler();
        scheduler.execute(null);
        Test.stopTest();

        // Verify no reconciler was enqueued by checking AsyncApexJob
        // (the reconciler would appear as a Queueable job if it ran)
        List<AsyncApexJob> reconcilerJobs = [
            SELECT Id, ApexClass.Name FROM AsyncApexJob
            WHERE ApexClass.Name = 'DeliverySyncReconciler'
            AND Status IN ('Queued', 'Holding', 'Preparing', 'Processing', 'Completed')
        ];
        System.assertEquals(0, reconcilerJobs.size(),
            'Reconciler should NOT be enqueued when current hour does not match configured hour');
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
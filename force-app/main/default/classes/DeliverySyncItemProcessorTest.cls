/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Test class for DeliverySyncItemProcessor.
 * Verifies outbound transmission logic and status updates.
 * @author Cloud Nimbus LLC
 */
@IsTest
private class DeliverySyncItemProcessorTest {

    @TestSetup
    static void makeData() {
        // FIX: Prevent DeliverySyncEngine from firing during setup so it doesn't enqueue 
        // a processor that sweeps up and fails our test records before the test starts!
        DeliverySyncEngine.setSyncContext();

        // 1. Setup Network Entity (Vendor)
        NetworkEntity__c vendor = new NetworkEntity__c(
            Name = 'Mothership HQ',
            StatusPk__c = 'Active',
            EntityTypePk__c = 'Vendor',
            IntegrationEndpointUrlTxt__c = 'https://mothership.example.com'
        );
        insert vendor;

        // 2. Setup Work Item
        WorkItem__c t = new WorkItem__c(
            BriefDescriptionTxt__c = 'Test Work Item',
            StageNamePk__c = 'Backlog'
        );
        insert t;

        // 3. Setup Request (The Bridge)
        WorkRequest__c req = new WorkRequest__c(
            WorkItemId__c = t.Id,
            DeliveryEntityId__c = vendor.Id,
            StatusPk__c = 'Active',
            RemoteWorkItemIdTxt__c = 'REMOTE-123'
        );
        insert req;

        // 4. Setup Outbound Sync Item
        SyncItem__c item = new SyncItem__c(
            StatusPk__c = 'Queued',
            DirectionPk__c = 'Outbound',
            WorkItemId__c = t.Id,
            RequestId__c = req.Id,
            ObjectTypePk__c = 'WorkItem__c',
            PayloadTxt__c = '{"StageNamePk__c":"In Development"}'
        );
        insert item;
        
        // Clean up auto-generated passive items just in case
        delete [SELECT Id FROM SyncItem__c WHERE RequestId__c = null];
    }

    /**
     * @description Verifies successful HTTP 200 response marks item as Synced.
     */
    @IsTest
    static void testProcessSuccess() {
        Test.setMock(HttpCalloutMock.class, new MockSuccess());

        Test.startTest();
        System.enqueueJob(new DeliverySyncItemProcessor());
        Test.stopTest();

        SyncItem__c result = [SELECT StatusPk__c, ErrorLogTxt__c FROM SyncItem__c WHERE RequestId__c != null LIMIT 1];
        System.assertEquals('Synced', result.StatusPk__c, 'Status should update to Synced on 200 OK. Error: ' + result.ErrorLogTxt__c);
    }

    /**
     * @description Verifies HTTP 500 failure marks item as Failed and logs the error.
     */
    @IsTest
    static void testProcessHttpFailure() {
        Test.setMock(HttpCalloutMock.class, new MockFailure());

        Test.startTest();
        System.enqueueJob(new DeliverySyncItemProcessor());
        Test.stopTest();

        SyncItem__c result = [SELECT StatusPk__c, ErrorLogTxt__c FROM SyncItem__c WHERE RequestId__c != null LIMIT 1];
        System.assertEquals('Failed', result.StatusPk__c, 'Status should update to Failed on 500 error');
        System.assert(result.ErrorLogTxt__c.contains('500'), 'Error log should contain status code');
    }

    /**
     * @description Mock for successful response.
     */
    private class MockSuccess implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"status":"Success"}');
            return res;
        }
    }

    /**
     * @description Mock for failed response.
     */
    private class MockFailure implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setBody('Internal Server Error');
            return res;
        }
    }
}
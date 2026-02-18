@IsTest
private class SyncItemProcessorTest {

    // --- MOCK CLASS ---
    private class DeliveryHubMock implements HttpCalloutMock {
        private Integer statusCode;
        private String responseBody;

        public DeliveryHubMock(Integer code, String body) {
            this.statusCode = code;
            this.responseBody = body;
        }

        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody(this.responseBody);
            res.setStatusCode(this.statusCode);
            return res;
        }
    }

    @TestSetup
    static void setupData() {
        // 1. Create Vendor (Mothership)
        Network_Entity__c vendor = new Network_Entity__c(
            Name = 'Mothership',
            EntityTypePk__c = 'Vendor',
            StatusPk__c = 'Active', 
            IntegrationEndpointUrlTxt__c = 'https://fake-endpoint.com'
        );
        insert vendor;

        // 2. Create Ticket
        Ticket__c t = new Ticket__c(BriefDescriptionTxt__c = 'Test Ticket');
        insert t;

        // 3. Create Request (The Bridge) - REQUIRED for Processor to find the URL
        Request__c req = new Request__c(
            TicketId__c = t.Id,
            DeliveryEntityId__c = vendor.Id,
            StatusPk__c = 'Active',
            RemoteTicketIdTxt__c = 'REMOTE-101'
        );
        insert req;
    }

    @IsTest
    static void testProcessSuccess() {
        Ticket__c t = [SELECT Id FROM Ticket__c LIMIT 1];
        Request__c req = [SELECT Id, TicketId__c FROM Request__c LIMIT 1];

        // Manually create a Queued Item linked to the Request
        Sync_Item__c item = new Sync_Item__c(
            TicketId__c = t.Id,
            RequestId__c = req.Id, // Link is Critical
            LocalRecordIdTxt__c = t.Id, 
            ObjectTypePk__c = 'Ticket__c',
            PayloadTxt__c = '{"Action":"Update", "StageNamePk__c":"Done"}',
            DirectionPk__c = 'Outbound',
            StatusPk__c = 'Queued'
        );
        insert item;

        // Mock 200 OK
        Test.setMock(HttpCalloutMock.class, new DeliveryHubMock(200, '{"status":"Success"}'));

        Test.startTest();
        System.enqueueJob(new SyncItemProcessor());
        Test.stopTest();

        Sync_Item__c result = [SELECT StatusPk__c, ErrorLogTxt__c FROM Sync_Item__c WHERE Id = :item.Id];
        System.assertEquals('Synced', result.StatusPk__c, 'Status should update to Synced on 200 OK');
        System.assertEquals(null, result.ErrorLogTxt__c, 'Error log should be clear');
    }

    @IsTest
    static void testProcessHttpFailure() {
        Ticket__c t = [SELECT Id FROM Ticket__c LIMIT 1];
        Request__c req = [SELECT Id, TicketId__c FROM Request__c LIMIT 1];

        Sync_Item__c item = new Sync_Item__c(
            TicketId__c = t.Id,
            RequestId__c = req.Id,
            LocalRecordIdTxt__c = t.Id, 
            ObjectTypePk__c = 'Ticket__c',
            PayloadTxt__c = '{"Action":"Fail"}',
            DirectionPk__c = 'Outbound',
            StatusPk__c = 'Queued'
        );
        insert item;

        // Mock 500 Server Error
        Test.setMock(HttpCalloutMock.class, new DeliveryHubMock(500, 'Server Error'));

        Test.startTest();
        System.enqueueJob(new SyncItemProcessor());
        Test.stopTest();

        Sync_Item__c result = [SELECT StatusPk__c, ErrorLogTxt__c FROM Sync_Item__c WHERE Id = :item.Id];
        System.assertEquals('Failed', result.StatusPk__c, 'Status should fail on 500 error');
        System.assert(result.ErrorLogTxt__c.contains('500'), 'Error log should contain status code');
    }

    @IsTest
    static void testMissingEndpointConfiguration() {
        Ticket__c t = [SELECT Id FROM Ticket__c LIMIT 1];
        
        // Create a Vendor WITHOUT a URL
        Network_Entity__c badVendor = new Network_Entity__c(
            Name = 'Bad Config', 
            EntityTypePk__c = 'Vendor', 
            StatusPk__c = 'Active'
            // Missing IntegrationEndpointUrlTxt__c
        );
        insert badVendor;

        Request__c badReq = new Request__c(
            TicketId__c = t.Id,
            DeliveryEntityId__c = badVendor.Id,
            StatusPk__c = 'Active',
            RemoteTicketIdTxt__c = 'REMOTE-BAD'
        );
        insert badReq;

        Sync_Item__c item = new Sync_Item__c(
            TicketId__c = t.Id,
            RequestId__c = badReq.Id,
            ObjectTypePk__c = 'Ticket__c',
            PayloadTxt__c = '{}',
            DirectionPk__c = 'Outbound',
            StatusPk__c = 'Queued'
        );
        insert item;

        Test.startTest();
        System.enqueueJob(new SyncItemProcessor());
        Test.stopTest();

        Sync_Item__c result = [SELECT StatusPk__c, ErrorLogTxt__c FROM Sync_Item__c WHERE Id = :item.Id];
        System.assertEquals('Failed', result.StatusPk__c, 'Should fail if URL is missing');
        System.assert(result.ErrorLogTxt__c.contains('Configuration Error'), 'Should log config error');
    }
}
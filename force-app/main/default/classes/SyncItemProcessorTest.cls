@IsTest
private class SyncItemProcessorTest {

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
        // 1. Mothership Node
        Network_Entity__c entity = new Network_Entity__c(
            Name = 'Mothership Node',
            StatusPk__c = 'Active', 
            IntegrationEndpointUrlTxt__c = 'https://example.com/api'
        );
        insert entity;

        // 2. Ticket
        Ticket__c t = new Ticket__c(BriefDescriptionTxt__c = 'Test');
        insert t;
        
        // CLEANUP: Delete the Sync Item created by the Ticket Trigger to avoid noise
        delete [SELECT Id FROM Sync_Item__c];

        // 3. Request (Connection)
        Request__c r = new Request__c(
            TicketId__c = t.Id,
            DeliveryEntityId__c = entity.Id,
            RemoteTicketIdTxt__c = 'REMOTE-200',
            StatusPk__c = 'Open'
        );
        insert r;

        // 4. Comment (For Legacy Test)
        Ticket_Comment__c c = new Ticket_Comment__c(
            TicketId__c = t.Id,
            BodyTxt__c = 'Test Payload',
            AuthorTxt__c = 'Tester'
        );
        insert c;

        // 5. Queue Item (Legacy Path - No Payload)
        Sync_Item__c item = new Sync_Item__c(
            TicketId__c = t.Id,
            TicketCommentId__c = c.Id,
            RequestId__c = r.Id,
            LocalRecordIdTxt__c = c.Id,
            ObjectTypePk__c = 'Ticket_Comment__c',
            DirectionPk__c = 'Outbound',
            StatusPk__c = 'Queued'
        );
        insert item;
    }

    /**
     * @description Verifies the LEGACY path (Ticket_Comment__c without Payload).
     */
    @IsTest
    static void testLegacyPathSuccess() {
        Test.setMock(HttpCalloutMock.class, new DeliveryHubMock(200, '{"status":"Success"}'));

        Test.startTest();
        System.enqueueJob(new SyncItemProcessor());
        Test.stopTest();

        Sync_Item__c result = [SELECT StatusPk__c, ErrorLogTxt__c FROM Sync_Item__c WHERE ObjectTypePk__c = 'Ticket_Comment__c' LIMIT 1];
        
        System.assertEquals('Synced', result.StatusPk__c, 'Legacy item should be Synced. Error: ' + result.ErrorLogTxt__c);
        System.assertEquals(null, result.ErrorLogTxt__c, 'Error log should be empty');
    }

    /**
     * @description Verifies the NEW Unified Engine path (Sync Items WITH Payload).
     */
    @IsTest
    static void testUnifiedPathSuccess() {
        Ticket__c t = [SELECT Id FROM Ticket__c LIMIT 1];
        
        // Setup a Sync Item with JSON Payload (The new way)
        Sync_Item__c unifiedItem = new Sync_Item__c(
            TicketId__c = t.Id,
            LocalRecordIdTxt__c = t.Id, 
            ObjectTypePk__c = 'Ticket__c',
            PayloadTxt__c = '{"Action":"Update", "StageNamePk__c":"Done"}',
            DirectionPk__c = 'Outbound',
            StatusPk__c = 'Queued'
        );
        insert unifiedItem;

        Test.setMock(HttpCalloutMock.class, new DeliveryHubMock(200, '{"status":"Success"}'));

        Test.startTest();
        System.enqueueJob(new SyncItemProcessor());
        Test.stopTest();

        Sync_Item__c result = [SELECT StatusPk__c, ErrorLogTxt__c FROM Sync_Item__c WHERE Id = :unifiedItem.Id];
        System.assertEquals('Synced', result.StatusPk__c, 'Unified item should be Synced. Error: ' + result.ErrorLogTxt__c);
    }

    /**
     * @description Verifies that HTTP 500 updates status to 'Failed'.
     */
    @IsTest
    static void testProcessorFailure() {
        Test.setMock(HttpCalloutMock.class, new DeliveryHubMock(500, 'Server Error'));

        Test.startTest();
        System.enqueueJob(new SyncItemProcessor());
        Test.stopTest();

        Sync_Item__c result = [SELECT StatusPk__c, ErrorLogTxt__c FROM Sync_Item__c WHERE ObjectTypePk__c = 'Ticket_Comment__c' LIMIT 1];
        
        System.assertEquals('Failed', result.StatusPk__c, 'Status should be Failed on 500 error');
        System.assert(result.ErrorLogTxt__c != null, 'Error log should be populated');
    }

    /**
     * @description Verifies handling of records deleted before processing (Legacy Path).
     */
    @IsTest
    static void testSourceRecordDeleted() {
        // Delete the comment referenced by the legacy sync item
        Ticket_Comment__c c = [SELECT Id FROM Ticket_Comment__c LIMIT 1];
        delete c;

        Test.startTest();
        System.enqueueJob(new SyncItemProcessor());
        Test.stopTest();

        Sync_Item__c result = [SELECT StatusPk__c, ErrorLogTxt__c FROM Sync_Item__c WHERE ObjectTypePk__c = 'Ticket_Comment__c' LIMIT 1];
        
        System.assertEquals('Failed', result.StatusPk__c, 'Status should fail if source record is missing');
        // We use check for NOT NULL because exact error wording might vary based on implementation
        System.assert(result.ErrorLogTxt__c != null, 'Error log should be populated');
    }
}
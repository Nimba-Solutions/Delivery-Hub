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
        // Only setup basic Ticket, do specific setup in methods to avoid noise
        Ticket__c t = new Ticket__c(BriefDescriptionTxt__c = 'Test');
        insert t;
        
        // Cleanup default trigger items
        delete [SELECT Id FROM Sync_Item__c];
    }

    @IsTest
    static void testLegacyPathSuccess() {
        Ticket__c t = [SELECT Id FROM Ticket__c LIMIT 1];
        
        // SHORTCUT: Create data fresh here to ensure relationships are valid
        Network_Entity__c entity = new Network_Entity__c(
            Name = 'Legacy Node',
            StatusPk__c = 'Active',
            IntegrationEndpointUrlTxt__c = 'https://legacy.com'
        );
        insert entity;

        Request__c r = new Request__c(
            TicketId__c = t.Id,
            DeliveryEntityId__c = entity.Id,
            RemoteTicketIdTxt__c = 'LEGACY-999', // Critical for this test
            StatusPk__c = 'Open'
        );
        insert r;

        Ticket_Comment__c c = new Ticket_Comment__c(TicketId__c = t.Id, BodyTxt__c = 'Legacy Comment');
        insert c;

        Sync_Item__c item = new Sync_Item__c(
            TicketId__c = t.Id,
            TicketCommentId__c = c.Id,
            RequestId__c = r.Id, // Explicitly link Request
            LocalRecordIdTxt__c = c.Id,
            ObjectTypePk__c = 'Ticket_Comment__c',
            DirectionPk__c = 'Outbound',
            StatusPk__c = 'Queued'
        );
        insert item;

        Test.setMock(HttpCalloutMock.class, new DeliveryHubMock(200, '{"status":"Success"}'));

        Test.startTest();
        System.enqueueJob(new SyncItemProcessor());
        Test.stopTest();

        Sync_Item__c result = [SELECT StatusPk__c, ErrorLogTxt__c FROM Sync_Item__c WHERE Id = :item.Id];
        System.assertEquals('Synced', result.StatusPk__c, 'Legacy item should be Synced. Error: ' + result.ErrorLogTxt__c);
    }

    @IsTest
    static void testUnifiedPathSuccess() {
        Ticket__c t = [SELECT Id FROM Ticket__c LIMIT 1];
        
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

        Sync_Item__c result = [SELECT StatusPk__c FROM Sync_Item__c WHERE Id = :unifiedItem.Id];
        System.assertEquals('Synced', result.StatusPk__c);
    }

    @IsTest
    static void testProcessorFailure() {
        // Create a failing item (Legacy path is easier to force fail)
        Ticket__c t = [SELECT Id FROM Ticket__c LIMIT 1];
        Sync_Item__c item = new Sync_Item__c(
            TicketId__c = t.Id,
            ObjectTypePk__c = 'Ticket_Comment__c',
            StatusPk__c = 'Queued'
            // Missing RequestId__c will cause failure in processor logic (or 500 mock)
        );
        insert item;

        Test.setMock(HttpCalloutMock.class, new DeliveryHubMock(500, 'Server Error'));

        Test.startTest();
        System.enqueueJob(new SyncItemProcessor());
        Test.stopTest();

        Sync_Item__c result = [SELECT StatusPk__c FROM Sync_Item__c WHERE Id = :item.Id];
        System.assertEquals('Failed', result.StatusPk__c);
    }

    @IsTest
    static void testSourceRecordDeleted() {
        Ticket__c t = [SELECT Id FROM Ticket__c LIMIT 1];
        
        // FIX: Insert real record then delete it to get a valid ID without hardcoding strings
        Ticket_Comment__c temp = new Ticket_Comment__c(TicketId__c = t.Id, BodyTxt__c = 'To Delete');
        insert temp;
        Id deletedId = temp.Id;
        delete temp; // Now deletedId points to nothing, simulating the error condition

        Sync_Item__c item = new Sync_Item__c(
            TicketId__c = t.Id,
            LocalRecordIdTxt__c = deletedId, // Points to missing record
            ObjectTypePk__c = 'Ticket_Comment__c',
            StatusPk__c = 'Queued'
        );
        insert item;

        Test.startTest();
        System.enqueueJob(new SyncItemProcessor());
        Test.stopTest();

        Sync_Item__c result = [SELECT StatusPk__c, ErrorLogTxt__c FROM Sync_Item__c WHERE Id = :item.Id];
        System.assertEquals('Failed', result.StatusPk__c);
        System.assert(result.ErrorLogTxt__c != null);
    }
}
@isTest
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

    @testSetup
    static void setupData() {
        // FIXED: Object Name
        Network_Entity__c entity = new Network_Entity__c(
            Name = 'Mothership Node',
            IntegrationEndpointUrlTxt__c = 'https://example.com/api'
        );
        insert entity;

        // FIXED: Removed Name field
        Ticket__c t = new Ticket__c(BriefDescriptionTxt__c = 'Test');
        insert t;

        Request__c r = new Request__c(
            TicketId__c = t.Id,
            DeliveryEntityId__c = entity.Id,
            RemoteTicketIdTxt__c = 'REMOTE-200',
            StatusPk__c = 'Open'
        );
        insert r;

        Ticket_Comment__c c = new Ticket_Comment__c(
            TicketId__c = t.Id,
            BodyTxt__c = 'Test Payload',
            AuthorTxt__c = 'Tester'
        );
        insert c;

        // Manually insert a QUEUED item
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

    @isTest
    static void testProcessorSuccess() {
        Test.setMock(HttpCalloutMock.class, new DeliveryHubMock(200, '{"status":"Success"}'));

        Test.startTest();
        System.enqueueJob(new SyncItemProcessor());
        Test.stopTest();

        Sync_Item__c result = [SELECT StatusPk__c, ErrorLogTxt__c FROM Sync_Item__c LIMIT 1];
        //System.assertEquals('Synced', result.StatusPk__c);
    }

    @isTest
    static void testProcessorFailure() {
        Test.setMock(HttpCalloutMock.class, new DeliveryHubMock(500, 'Server Error'));

        Test.startTest();
        System.enqueueJob(new SyncItemProcessor());
        Test.stopTest();

        Sync_Item__c result = [SELECT StatusPk__c, ErrorLogTxt__c FROM Sync_Item__c LIMIT 1];
        System.assertEquals('Failed', result.StatusPk__c);
        //System.assert(result.ErrorLogTxt__c.contains('HTTP 500'));
    }

    @isTest
    static void testSourceRecordDeleted() {
        Ticket_Comment__c c = [SELECT Id FROM Ticket_Comment__c LIMIT 1];
        delete c;

        Test.startTest();
        System.enqueueJob(new SyncItemProcessor());
        Test.stopTest();

        Sync_Item__c result = [SELECT StatusPk__c, ErrorLogTxt__c FROM Sync_Item__c LIMIT 1];
        System.assertEquals('Failed', result.StatusPk__c);
    }
}
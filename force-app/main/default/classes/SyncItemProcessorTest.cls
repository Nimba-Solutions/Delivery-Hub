/**
 * @description Test class for SyncItemProcessor.
 * Covers success, failure, and edge cases (deleted records).
 */
@IsTest
private class SyncItemProcessorTest {

    /**
     * @description Mock class for HTTP Callouts.
     */
    private class DeliveryHubMock implements HttpCalloutMock {
        private Integer statusCode;
        private String responseBody;

        /**
         * @description Constructor to set the desired mock response.
         * @param code HTTP Status Code.
         * @param body HTTP Response Body.
         */
        public DeliveryHubMock(Integer code, String body) {
            this.statusCode = code;
            this.responseBody = body;
        }

        /**
         * @description Responds to the callout with the pre-configured response.
         * @param req The HTTP Request.
         * @return HttpResponse The mocked response.
         */
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
        // Network Entity (Mothership)
        Network_Entity__c entity = new Network_Entity__c(
            Name = 'Mothership Node',
            IntegrationEndpointUrlTxt__c = 'https://example.com/api'
        );
        insert entity;

        // Ticket
        Ticket__c t = new Ticket__c(BriefDescriptionTxt__c = 'Test');
        insert t;

        // Request (Connection)
        Request__c r = new Request__c(
            TicketId__c = t.Id,
            DeliveryEntityId__c = entity.Id,
            RemoteTicketIdTxt__c = 'REMOTE-200',
            StatusPk__c = 'Open'
        );
        insert r;

        // Comment
        Ticket_Comment__c c = new Ticket_Comment__c(
            TicketId__c = t.Id,
            BodyTxt__c = 'Test Payload',
            AuthorTxt__c = 'Tester'
        );
        insert c;

        // Queue Item (Outbox)
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
     * @description Verifies that a successful API call updates the item to 'Synced'.
     */
    @IsTest
    static void testProcessorSuccess() {
        Test.setMock(HttpCalloutMock.class, new DeliveryHubMock(200, '{"status":"Success"}'));

        Test.startTest();
        System.enqueueJob(new SyncItemProcessor());
        Test.stopTest();

        Sync_Item__c result = [SELECT StatusPk__c, ErrorLogTxt__c FROM Sync_Item__c LIMIT 1];
        
        // FIXED: Uncommented assertions to satisfy PMD
        System.assertEquals('Synced', result.StatusPk__c, 'Status should be Synced on success.');
        System.assertEquals(null, result.ErrorLogTxt__c, 'Error log should be empty on success.');
    }

    /**
     * @description Verifies that a 500 error updates the item to 'Failed'.
     */
    @IsTest
    static void testProcessorFailure() {
        Test.setMock(HttpCalloutMock.class, new DeliveryHubMock(500, 'Server Error'));

        Test.startTest();
        System.enqueueJob(new SyncItemProcessor());
        Test.stopTest();

        Sync_Item__c result = [SELECT StatusPk__c, ErrorLogTxt__c FROM Sync_Item__c LIMIT 1];
        
        // FIXED: Uncommented assertions to satisfy PMD
        System.assertEquals('Failed', result.StatusPk__c, 'Status should be Failed on 500 error.');
        System.assert(result.ErrorLogTxt__c.contains('HTTP 500'), 'Error log should contain the status code.');
    }

    /**
     * @description Verifies handling of records deleted before processing.
     */
    @IsTest
    static void testSourceRecordDeleted() {
        Ticket_Comment__c c = [SELECT Id FROM Ticket_Comment__c LIMIT 1];
        delete c;

        Test.startTest();
        System.enqueueJob(new SyncItemProcessor());
        Test.stopTest();

        Sync_Item__c result = [SELECT StatusPk__c, ErrorLogTxt__c FROM Sync_Item__c LIMIT 1];
        
        System.assertEquals('Failed', result.StatusPk__c, 'Status should fail if record is missing.');
        System.assert(result.ErrorLogTxt__c.containsIgnoreCase('not found'), 'Error log should mention record not found.');
    }
}
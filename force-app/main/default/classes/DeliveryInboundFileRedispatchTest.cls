/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Tests the scheduler's orphaned-inbound-file recovery sweep
 *              (DeliveryHubScheduler.requeueOrphanedInboundFiles). Reproduces the
 *              T6 defect: an inbound ContentVersion SyncItem parked 'Queued' whose
 *              ingest-time DeliveryFileBytesFetcher enqueue was skipped (queueable
 *              depth exhausted on the poll path) sits Queued forever because no
 *              existing sweep re-dispatches it. The new sweep claims rows aged past
 *              one scheduler cycle and re-enqueues the fetcher; fresh rows are left
 *              alone so a live ingest-time fetcher is never raced/duplicated.
 * @author Cloud Nimbus LLC
 */
@IsTest
private class DeliveryInboundFileRedispatchTest {

    private static final String PEER_ORG_ID = 'peer-org-redispatch-test';
    private static final String TEST_BYTES = 'orphaned file bytes payload';

    /**
     * @description Inserts a Connected peer NetworkEntity (with auth + endpoint so
     *              the re-dispatched fetcher can complete its mocked callout) and a
     *              host WorkItem the inbound file links to.
     */
    @TestSetup
    static void makeData() {
        DeliverySyncEngine.setSyncContext();
        insert new NetworkEntity__c(
            Name = 'Source Peer Org',
            EntityTypePk__c = 'Vendor',
            StatusPk__c = 'Active',
            ConnectionStatusPk__c = 'Connected',
            OrgIdTxt__c = PEER_ORG_ID,
            ApiKeyTxt__c = 'peer-api-key',
            HmacSecretTxt__c = 'peer-hmac-secret',
            IntegrationEndpointUrlTxt__c = 'https://peer.example.com'
        );
        insert new WorkItem__c(BriefDescriptionTxt__c = 'Host WI');
    }

    /**
     * @description Builds a Queued inbound ContentVersion SyncItem carrying a
     *              pull-callout payload that the fetcher can satisfy from the mock.
     * @param sha256 Expected hex digest of the bytes the mock returns.
     * @return The inserted SyncItem__c Id.
     */
    private static Id insertQueuedInboundFile(String sha256) {
        WorkItem__c wi = [SELECT Id FROM WorkItem__c LIMIT 1];
        Map<String, Object> payload = new Map<String, Object>{
            'SourceId' => 'cv-orphan-src',
            'ContentDocumentId' => 'cd-orphan',
            'SenderOrgId' => PEER_ORG_ID,
            'Title' => 'Orphan File',
            'PathOnClient' => 'orphan.txt',
            'Sha256' => sha256,
            'FileTransport' => 'pull-callout'
        };
        SyncItem__c item = new SyncItem__c(
            DirectionPk__c = 'Inbound',
            StatusPk__c = 'Queued',
            ObjectTypePk__c = 'ContentVersion',
            PayloadTxt__c = JSON.serialize(payload),
            WorkItemLookup__c = wi.Id,
            RemoteExternalIdTxt__c = 'cv-orphan-src'
        );
        insert item;
        return item.Id;
    }

    @IsTest
    static void testAgedOrphanIsRedispatchedAndSynced() {
        String expectedSha = EncodingUtil.convertToHex(
            Crypto.generateDigest('SHA-256', Blob.valueOf(TEST_BYTES))
        );
        Id syncId = insertQueuedInboundFile(expectedSha);
        // Age past the one-cycle (15 min) cutoff so the safety-net sweep claims it.
        Test.setCreatedDate(syncId, Datetime.now().addMinutes(-30));

        Test.setMock(HttpCalloutMock.class, new MockBytes(200, TEST_BYTES));

        Test.startTest();
        DeliveryHubScheduler.requeueOrphanedInboundFiles();
        Test.stopTest();

        SyncItem__c after = [
            SELECT StatusPk__c, LocalRecordIdTxt__c, ErrorLogTxt__c
            FROM SyncItem__c WHERE Id = :syncId
        ];
        System.assertEquals('Synced', after.StatusPk__c,
            'An aged, orphaned inbound ContentVersion should be re-dispatched and synced. Error: '
            + after.ErrorLogTxt__c);
        System.assertNotEquals(null, after.LocalRecordIdTxt__c,
            'Re-dispatch should land the ContentVersion and record its Id');
    }

    @IsTest
    static void testFreshQueuedRowIsNotRedispatched() {
        // A row created within the current scheduler cycle must be left alone —
        // its ingest-time fetcher may still be in flight. Re-dispatching it would
        // risk a double callout and a duplicate ContentVersion insert.
        Id syncId = insertQueuedInboundFile('0'.repeat(64));

        Test.setMock(HttpCalloutMock.class, new MockBytes(200, TEST_BYTES));

        Test.startTest();
        DeliveryHubScheduler.requeueOrphanedInboundFiles();
        Test.stopTest();

        SyncItem__c after = [SELECT StatusPk__c FROM SyncItem__c WHERE Id = :syncId];
        System.assertEquals('Queued', after.StatusPk__c,
            'A fresh (non-aged) Queued row must be left for its in-flight fetcher');
    }

    @IsTest
    static void testNonContentVersionQueuedRowIsIgnored() {
        // The sweep is scoped to ContentVersion files only — a Queued inbound
        // WorkItem row (handled by the generic processor/poller path) must not be
        // handed to the file-bytes fetcher even when aged.
        WorkItem__c wi = [SELECT Id FROM WorkItem__c LIMIT 1];
        SyncItem__c item = new SyncItem__c(
            DirectionPk__c = 'Inbound',
            StatusPk__c = 'Queued',
            ObjectTypePk__c = 'WorkItem__c',
            PayloadTxt__c = '{}',
            WorkItemLookup__c = wi.Id,
            RemoteExternalIdTxt__c = 'wi-src'
        );
        insert item;
        Test.setCreatedDate(item.Id, Datetime.now().addMinutes(-30));

        Test.startTest();
        DeliveryHubScheduler.requeueOrphanedInboundFiles();
        Test.stopTest();

        SyncItem__c after = [SELECT StatusPk__c FROM SyncItem__c WHERE Id = :item.Id];
        System.assertEquals('Queued', after.StatusPk__c,
            'A non-ContentVersion inbound row must be untouched by the file re-dispatch sweep');
    }

    /**
     * @description HttpCalloutMock returning a configurable status + body, mirroring
     *              the peer /fileBytes octet-stream response the fetcher expects.
     */
    private class MockBytes implements HttpCalloutMock {
        private final Integer status;
        private final String body;
        /**
         * @description Builds the mock.
         * @param status HTTP status code to return.
         * @param body Response body returned as an octet-stream blob.
         */
        public MockBytes(Integer status, String body) {
            this.status = status;
            this.body = body;
        }
        /**
         * @description Answers any request with the pre-configured response.
         * @param req Ignored.
         * @return The mock HttpResponse.
         */
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(status);
            res.setHeader('Content-Type', 'application/octet-stream');
            res.setBodyAsBlob(Blob.valueOf(body));
            return res;
        }
    }
}

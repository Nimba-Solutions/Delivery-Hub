/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Tests for DeliveryFileBytesFetcher — mocks the peer-org
 *              callout, verifies happy path (ContentVersion insert + CDL +
 *              SyncItem Synced), sha256 integrity mismatch, and endpoint-
 *              missing failure path.
 * @author Cloud Nimbus LLC
 */
@IsTest
private class DeliveryFileBytesFetcherTest {

    private static final String PEER_ORG_ID = '00D000000000001';
    private static final String TEST_BYTES = 'received bytes payload';

    @TestSetup
    static void makeData() {
        // Prevent cascade triggers during setup
        DeliverySyncEngine.setSyncContext();

        NetworkEntity__c peer = new NetworkEntity__c(
            Name = 'Source Peer Org',
            EntityTypePk__c = 'Vendor',
            StatusPk__c = 'Active',
            ConnectionStatusPk__c = 'Connected',
            OrgIdTxt__c = PEER_ORG_ID,
            ApiKeyTxt__c = 'peer-api-key',
            HmacSecretTxt__c = 'peer-hmac-secret',
            IntegrationEndpointUrlTxt__c = 'https://peer.example.com'
        );
        insert peer;

        WorkItem__c wi = new WorkItem__c(BriefDescriptionTxt__c = 'Host WI');
        insert wi;
    }

    /**
     * @description Builds a Queued inbound SyncItem__c with the desired
     *              pull-callout payload and returns its Id.
     */
    private static Id insertInboundItem(String sourceCdId, String sha256) {
        WorkItem__c wi = [SELECT Id FROM WorkItem__c LIMIT 1];
        Map<String, Object> payload = new Map<String, Object>{
            'SourceId' => '068000000000001',
            'ContentDocumentId' => sourceCdId,
            'SenderOrgId' => PEER_ORG_ID,
            'Title' => 'Received File',
            'PathOnClient' => 'received.txt',
            'Sha256' => sha256,
            'FileTransport' => 'pull-callout'
        };
        SyncItem__c item = new SyncItem__c(
            DirectionPk__c = 'Inbound',
            StatusPk__c = 'Queued',
            ObjectTypePk__c = 'ContentVersion',
            PayloadTxt__c = JSON.serialize(payload),
            WorkItemLookup__c = wi.Id,
            RemoteExternalIdTxt__c = '068000000000001'
        );
        insert item;
        return item.Id;
    }

    @IsTest
    static void testHappyPathInsertsContentVersionAndLink() {
        String cdId = '069000000000100AAA';
        String expectedSha = EncodingUtil.convertToHex(
            Crypto.generateDigest('SHA-256', Blob.valueOf(TEST_BYTES))
        );
        Id syncId = insertInboundItem(cdId, expectedSha);
        WorkItem__c wi = [SELECT Id FROM WorkItem__c LIMIT 1];

        Test.setMock(HttpCalloutMock.class, new MockBytes(200, TEST_BYTES));

        Test.startTest();
        System.enqueueJob(new DeliveryFileBytesFetcher(syncId, wi.Id));
        Test.stopTest();

        SyncItem__c after = [SELECT StatusPk__c, LocalRecordIdTxt__c, ErrorLogTxt__c FROM SyncItem__c WHERE Id = :syncId];
        System.assertEquals('Synced', after.StatusPk__c,
            'SyncItem should be Synced after successful fetch. Error: ' + after.ErrorLogTxt__c);
        System.assertNotEquals(null, after.LocalRecordIdTxt__c,
            'SyncItem should record the new ContentVersion Id');

        List<ContentDocumentLink> cdls = [
            SELECT Id, ContentDocumentId FROM ContentDocumentLink
            WHERE LinkedEntityId = :wi.Id
        ];
        System.assertEquals(1, cdls.size(),
            'A ContentDocumentLink should tie the new file to the WorkItem');
    }

    @IsTest
    static void testSha256MismatchFailsItem() {
        String cdId = '069000000000200AAA';
        // Intentionally supply the wrong expected hash
        String wrongSha = '0'.repeat(64);
        Id syncId = insertInboundItem(cdId, wrongSha);
        WorkItem__c wi = [SELECT Id FROM WorkItem__c LIMIT 1];

        Test.setMock(HttpCalloutMock.class, new MockBytes(200, TEST_BYTES));

        Test.startTest();
        System.enqueueJob(new DeliveryFileBytesFetcher(syncId, wi.Id));
        Test.stopTest();

        SyncItem__c after = [SELECT StatusPk__c, ErrorLogTxt__c FROM SyncItem__c WHERE Id = :syncId];
        System.assertEquals('Failed', after.StatusPk__c,
            'Integrity mismatch should fail the item so the retry engine can act');
        System.assertNotEquals(null, after.ErrorLogTxt__c, 'Error log should describe the mismatch');
        System.assert(after.ErrorLogTxt__c.containsIgnoreCase('integrity'),
            'Error should mention integrity failure. Was: ' + after.ErrorLogTxt__c);
    }

    @IsTest
    static void testCalloutHttp500FailsItem() {
        String cdId = '069000000000300AAA';
        String expectedSha = EncodingUtil.convertToHex(
            Crypto.generateDigest('SHA-256', Blob.valueOf(TEST_BYTES))
        );
        Id syncId = insertInboundItem(cdId, expectedSha);
        WorkItem__c wi = [SELECT Id FROM WorkItem__c LIMIT 1];

        Test.setMock(HttpCalloutMock.class, new MockBytes(500, 'server exploded'));

        Test.startTest();
        System.enqueueJob(new DeliveryFileBytesFetcher(syncId, wi.Id));
        Test.stopTest();

        SyncItem__c after = [SELECT StatusPk__c, ErrorLogTxt__c FROM SyncItem__c WHERE Id = :syncId];
        System.assertEquals('Failed', after.StatusPk__c,
            'HTTP >= 400 should move the row to Failed');
        System.assert(after.ErrorLogTxt__c.contains('500'),
            'Error log should surface the HTTP status');
    }

    @IsTest
    static void testUnknownSenderOrgFailsItem() {
        WorkItem__c wi = [SELECT Id FROM WorkItem__c LIMIT 1];
        Map<String, Object> payload = new Map<String, Object>{
            'SourceId' => '068000000000999',
            'ContentDocumentId' => '069000000000999AAA',
            'SenderOrgId' => '00D000000000ZZZ', // not a registered peer
            'Title' => 'Orphan',
            'FileTransport' => 'pull-callout',
            'Sha256' => null
        };
        SyncItem__c item = new SyncItem__c(
            DirectionPk__c = 'Inbound',
            StatusPk__c = 'Queued',
            ObjectTypePk__c = 'ContentVersion',
            PayloadTxt__c = JSON.serialize(payload),
            WorkItemLookup__c = wi.Id,
            RemoteExternalIdTxt__c = '068000000000999'
        );
        insert item;

        // No callout should even fire — but set a mock just in case
        Test.setMock(HttpCalloutMock.class, new MockBytes(200, TEST_BYTES));

        Test.startTest();
        System.enqueueJob(new DeliveryFileBytesFetcher(item.Id, wi.Id));
        Test.stopTest();

        SyncItem__c after = [SELECT StatusPk__c, ErrorLogTxt__c FROM SyncItem__c WHERE Id = :item.Id];
        System.assertEquals('Failed', after.StatusPk__c,
            'Unregistered sender org should fail the row with a clear error');
        System.assert(after.ErrorLogTxt__c.containsIgnoreCase('NetworkEntity'),
            'Error should mention NetworkEntity resolution failure. Was: ' + after.ErrorLogTxt__c);
    }

    /**
     * @description Mock HttpCalloutMock that returns a configurable status
     *              code and body. Used to simulate both happy-path and
     *              error-path responses from the peer /fileBytes endpoint.
     */
    private class MockBytes implements HttpCalloutMock {
        /** @description HTTP status to return. */
        private final Integer status;
        /** @description Response body to return. */
        private final String body;
        /**
         * @description Builds a mock with the given status and body.
         * @param status HTTP status code.
         * @param body Response body as a string.
         */
        public MockBytes(Integer status, String body) {
            this.status = status;
            this.body = body;
        }
        /**
         * @description Returns the pre-configured mock HttpResponse.
         * @param req Ignored — any inbound request is answered.
         * @return Mock HttpResponse.
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

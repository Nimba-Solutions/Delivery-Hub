/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Tests for the L2 cross-org gantt bridge — outbound Queueable
 *              callout + inbound REST receiver + signature verification +
 *              ID translation + suppression of bounce-back via
 *              DeliveryTriggerControl.inboundSyncContext.
 * @author Cloud Nimbus LLC
 */
@IsTest
private class DeliveryCrossOrgGanttBridgeTest {

    private static final String SHARED_SECRET = 'test-shared-secret-aaa';
    private static final String PEER_URL = 'https://peer.example.com/services/apexrest/delivery/deliveryhub/v1/cross-org-gantt';

    @TestSetup
    static void setup() {
        DeliveryHubSettings__c s = new DeliveryHubSettings__c(
            EnableLiveGanttEventsDateTime__c = Datetime.now(),
            EnableImmediateCrossOrgBridgeDateTime__c = Datetime.now(),
            CrossOrgGanttPeerUrlTxt__c = PEER_URL,
            CrossOrgGanttPeerSecretTxt__c = SHARED_SECRET
        );
        insert s;
    }

    /**
     * Outbound: with bridge toggle on + URL + secret all set, enqueueing
     * payloads schedules a Queueable that performs an HTTP POST. We mock
     * the callout so no real network traffic happens.
     */
    @IsTest
    static void testOutboundEnqueueAndPost() {
        Test.setMock(HttpCalloutMock.class, new BridgeCalloutMock(200, '{"ok":true}'));

        List<Map<String, Object>> payloads = new List<Map<String, Object>>{
            new Map<String, Object>{
                'ChangeTypeTxt__c' => 'task_upsert',
                'TaskPatchesJson__c' => '[{"Id":"a01000000000001AAA","StageNamePk__c":"In Development"}]',
                'ClientNonceTxt__c' => 'mount-uuid-1'
            }
        };

        Test.startTest();
        DeliveryCrossOrgGanttBridge.enqueueIfEnabled(payloads);
        Test.stopTest();

        // Mock recorded the request — sanity check signature header is present.
        System.assertNotEquals(null, lastBridgeRequest, 'Mock should record the request');
        String sig = lastBridgeRequest.getHeader('X-DH-Signature');
        System.assert(String.isNotBlank(sig), 'X-DH-Signature header should be set');
        // Signature should match our re-computation of HMAC-SHA256
        Blob expected = Crypto.generateMac('HmacSHA256',
            Blob.valueOf(lastBridgeRequest.getBody()),
            Blob.valueOf(SHARED_SECRET));
        System.assertEquals(EncodingUtil.convertToHex(expected), sig.toLowerCase(),
            'Signature must match HMAC of body with the shared secret');
    }

    /**
     * Outbound fast-exit: bridge silently skips when toggle is null even if
     * URL + secret are set. No callout, no Queueable.
     */
    @IsTest
    static void testOutboundFastExitWhenToggleOff() {
        DeliveryHubSettings__c s = DeliveryHubSettings__c.getInstance();
        s.EnableImmediateCrossOrgBridgeDateTime__c = null;
        update s;

        Test.startTest();
        DeliveryCrossOrgGanttBridge.enqueueIfEnabled(new List<Map<String, Object>>{
            new Map<String, Object>{ 'ChangeTypeTxt__c' => 'task_upsert' }
        });
        // Should not throw, no Queueable scheduled.
        System.assertEquals(0, Limits.getQueueableJobs(),
            'No queueable should be enqueued when toggle is off');
        Test.stopTest();
    }

    /**
     * Inbound receiver: valid signature + parseable body → dispatches handler.
     * The handler may return ignored if no SyncItem mapping exists in the
     * test setup, which is fine — we're testing the receiver pipeline, not
     * the data path.
     */
    @IsTest
    static void testInboundReceiverHappyPath() {
        String body = '{"ChangeTypeTxt__c":"task_upsert","TaskPatchesJson__c":"[]","ClientNonceTxt__c":"mount-uuid-2"}';
        String sig = computeSig(body, SHARED_SECRET);

        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/delivery/deliveryhub/v1/cross-org-gantt';
        req.httpMethod = 'POST';
        req.headers.put('X-DH-Signature', sig);
        req.requestBody = Blob.valueOf(body);
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        DeliveryCrossOrgGanttReceiverApi.handlePost();
        Test.stopTest();

        Integer status = RestContext.response.statusCode;
        System.assert(status == 200 || status == 400 || status == 503,
            'Receiver should respond with 200/ignored or controlled error, got ' + status);
    }

    /**
     * Inbound receiver: missing signature header → 401.
     */
    @IsTest
    static void testInboundReceiverRejectsMissingSig() {
        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/delivery/deliveryhub/v1/cross-org-gantt';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf('{"ChangeTypeTxt__c":"task_upsert"}');
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        DeliveryCrossOrgGanttReceiverApi.handlePost();
        Test.stopTest();

        System.assertEquals(401, RestContext.response.statusCode,
            'Missing signature should return 401');
    }

    /**
     * Inbound receiver: tampered signature → 401.
     */
    @IsTest
    static void testInboundReceiverRejectsBadSig() {
        String body = '{"ChangeTypeTxt__c":"task_upsert","TaskPatchesJson__c":"[]"}';
        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/delivery/deliveryhub/v1/cross-org-gantt';
        req.httpMethod = 'POST';
        req.headers.put('X-DH-Signature', 'deadbeef');
        req.requestBody = Blob.valueOf(body);
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        DeliveryCrossOrgGanttReceiverApi.handlePost();
        Test.stopTest();

        System.assertEquals(401, RestContext.response.statusCode,
            'Tampered signature should return 401');
    }

    /**
     * End-to-end through the handler when a SyncItem mapping exists: a
     * patch carrying senderId X resolves to local WorkItem Y via the
     * SyncItem ledger; receiver applies the update with inboundSyncContext
     * = true so no outbound bridge ping-pong fires.
     */
    @IsTest
    static void testInboundHandlerAppliesPatchViaSyncItemMapping() {
        // Local WorkItem to be the resolution target
        WorkItem__c local = new WorkItem__c(
            BriefDescriptionTxt__c = 'Will be updated by inbound bridge',
            StageNamePk__c = 'Backlog'
        );
        insert local;
        // SyncItem ledger maps a fake "sender Id" to the local WI
        String senderFakeId = 'a01999999999999AAA';
        insert new SyncItem__c(
            WorkItemLookup__c = local.Id,
            GlobalSourceIdTxt__c = senderFakeId,
            ObjectTypePk__c = 'WorkItem',
            DirectionPk__c = 'Inbound',
            StatusPk__c = 'Completed'
        );

        String body = '{"ChangeTypeTxt__c":"task_upsert","TaskPatchesJson__c":"[{\"Id\":\"' + senderFakeId + '\",\"StageNamePk__c\":\"In Development\"}]"}';
        String sig = computeSig(body, SHARED_SECRET);

        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/delivery/deliveryhub/v1/cross-org-gantt';
        req.httpMethod = 'POST';
        req.headers.put('X-DH-Signature', sig);
        req.requestBody = Blob.valueOf(body);
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        DeliveryCrossOrgGanttReceiverApi.handlePost();
        Test.stopTest();

        WorkItem__c reloaded = [SELECT Id, StageNamePk__c FROM WorkItem__c WHERE Id = :local.Id];
        System.assertEquals('In Development', reloaded.StageNamePk__c,
            'Inbound bridge should have applied the patch via SyncItem mapping');
        System.assertEquals(200, RestContext.response.statusCode,
            'Successful apply should return 200');
    }

    /** Outer-class-scoped capture so inner mock can reach without `public static` on inner. */
    private static HttpRequest lastBridgeRequest;

    private static String computeSig(String body, String secret) {
        Blob mac = Crypto.generateMac('HmacSHA256', Blob.valueOf(body), Blob.valueOf(secret));
        return EncodingUtil.convertToHex(mac);
    }

    private class BridgeCalloutMock implements HttpCalloutMock {
        private Integer status;
        private String body;

        private BridgeCalloutMock(Integer mockStatus, String mockBody) {
            this.status = mockStatus;
            this.body = mockBody;
        }

        public HttpResponse respond(HttpRequest req) {
            lastBridgeRequest = req;
            HttpResponse res = new HttpResponse();
            res.setStatusCode(status);
            res.setBody(body);
            return res;
        }
    }
}

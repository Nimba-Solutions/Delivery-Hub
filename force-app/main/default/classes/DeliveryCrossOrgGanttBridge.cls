/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Layer 2 of the live-events architecture: an immediate (per-DML)
 *               Queueable callout that POSTs WorkItem change payloads to a peer
 *               org's inbound webhook. Replaces the hourly SyncEngine drain
 *               for WorkItem fast-lane changes only — the existing SyncEngine
 *               (DeliverySyncItemProcessor + SyncItem__c ledger) remains the
 *               durable retry log and continues to own non-fast-lane fields.
 *
 *               Demo flow proven by this class:
 *                 User edits WorkItem in Nimba → trigger publishes intra-org
 *                 Platform Event AND enqueues this Queueable → callout to
 *                 MF-Prod's webhook → MF-Prod handler does DML with
 *                 inboundSyncContext=true → MF-Prod trigger publishes its
 *                 OWN intra-org Platform Event → MF-Prod gantt LWC + record
 *                 detail page both refresh within ~2-3 sec.
 *
 *               Failure mode: callout failure logs via System.debug; the
 *               existing SyncEngine path still captures the change in
 *               SyncItem__c (slow-lane) so eventual consistency holds even
 *               when the fast-lane is down.
 * @author Cloud Nimbus LLC
 */
public with sharing class DeliveryCrossOrgGanttBridge implements Queueable, Database.AllowsCallouts {

    /** Payload shape mirrors DeliveryWorkItemChange__e fields: ChangeType, TaskPatchesJson, ClientNonce. */
    private final List<Map<String, Object>> payloads;

    public DeliveryCrossOrgGanttBridge(List<Map<String, Object>> payloads) {
        this.payloads = payloads;
    }

    public void execute(QueueableContext context) {
        DeliveryHubSettings__c settings = DeliveryHubSettings__c.getInstance();
        if (settings == null
            || settings.EnableImmediateCrossOrgBridgeDateTime__c == null
            || String.isBlank(settings.CrossOrgGanttPeerUrlTxt__c)
            || String.isBlank(settings.CrossOrgGanttPeerSecretTxt__c)) {
            return;
        }
        String peerUrl = settings.CrossOrgGanttPeerUrlTxt__c;
        String secret = settings.CrossOrgGanttPeerSecretTxt__c;
        for (Map<String, Object> payload : payloads) {
            postOne(peerUrl, secret, payload);
        }
    }

    private void postOne(String peerUrl, String secret, Map<String, Object> payload) {
        String body = JSON.serialize(payload);
        String signature = computeHmacSha256(body, secret);
        try {
            HttpRequest req = new HttpRequest();
            req.setEndpoint(peerUrl);
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setHeader('X-DH-Signature', signature);
            req.setHeader('X-DH-Source', 'cross-org-gantt');
            req.setBody(body);
            req.setTimeout(15000);
            HttpResponse res = new Http().send(req);
            if (res.getStatusCode() >= 300) {
                System.debug(LoggingLevel.WARN,
                    'CrossOrgGanttBridge non-2xx: ' + res.getStatusCode() + ' ' + res.getBody());
            }
        } catch (Exception e) {
            // Do not throw — slow-lane SyncEngine still has the change in SyncItem__c.
            System.debug(LoggingLevel.WARN,
                'CrossOrgGanttBridge callout failed: ' + e.getTypeName() + ' - ' + e.getMessage());
        }
    }

    /** HMAC-SHA256 hex digest matching the verifier on the inbound side. */
    @TestVisible
    private static String computeHmacSha256(String body, String secret) {
        Blob mac = Crypto.generateMac(
            'HmacSHA256',
            Blob.valueOf(body == null ? '' : body),
            Blob.valueOf(secret == null ? '' : secret)
        );
        return EncodingUtil.convertToHex(mac);
    }

    /**
     * Static helper invoked from DeliveryWorkItemTriggerHandler.publishLiveGanttEvents.
     * Fast-exits when the bridge isn't configured so we don't waste a Queueable slot.
     */
    public static void enqueueIfEnabled(List<Map<String, Object>> payloads) {
        if (payloads == null || payloads.isEmpty()) return;
        DeliveryHubSettings__c settings = DeliveryHubSettings__c.getInstance();
        if (settings == null
            || settings.EnableImmediateCrossOrgBridgeDateTime__c == null
            || String.isBlank(settings.CrossOrgGanttPeerUrlTxt__c)
            || String.isBlank(settings.CrossOrgGanttPeerSecretTxt__c)) {
            return;
        }
        // Guard against test-context callouts: enqueue only when not in a
        // test that hasn't started a Test.startTest block. Callers in real
        // trigger context skip this.
        if (Test.isRunningTest() && !System.isQueueable() && Limits.getQueueableJobs() >= Limits.getLimitQueueableJobs()) {
            return;
        }
        System.enqueueJob(new DeliveryCrossOrgGanttBridge(payloads));
    }
}

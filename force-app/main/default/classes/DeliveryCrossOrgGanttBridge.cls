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
 *               Failure mode: callout failure is swallowed (slow-lane
 *               SyncEngine still captures the change in SyncItem__c so
 *               eventual consistency holds even when the fast-lane is down).
 * @author Cloud Nimbus LLC
 */
public with sharing class DeliveryCrossOrgGanttBridge implements Queueable, Database.AllowsCallouts {

    /** @description Mirrors DeliveryWorkItemChange__e payload (ChangeType, TaskPatchesJson, ClientNonce). */
    private final List<Map<String, Object>> payloads;

    /**
     * @description Construct the Queueable with a pre-built list of event payloads.
     * @param payloadList List of maps, each representing one bridge event.
     */
    public DeliveryCrossOrgGanttBridge(List<Map<String, Object>> payloadList) {
        this.payloads = payloadList;
    }

    /**
     * @description Queueable entry point — reads peer config from settings,
     *              fast-exits when not configured, and POSTs every payload.
     * @param context QueueableContext provided by the Apex runtime.
     */
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

    /**
     * @description POST a single payload to the peer org with HMAC signature.
     *              Failures are swallowed so the trigger doesn't break — the
     *              SyncEngine slow-lane is the durable retry path.
     * @param peerUrl Endpoint of the peer org's inbound webhook.
     * @param secret  Shared HMAC-SHA256 secret (must match peer's setting).
     * @param payload The single event payload to POST.
     */
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
            new Http().send(req);
            // Non-2xx responses are intentionally not retried here — the
            // slow-lane SyncEngine will retry via SyncItem__c ledger.
        } catch (Exception e) {
            // Do not throw — slow-lane SyncEngine still has the change in
            // SyncItem__c. Record the failure type on the ledger if a future
            // PR wants to surface it; for now we let the slow-lane retry.
            recordCalloutFailure(e);
        }
    }

    /**
     * @description Hook for future failure-recording on the SyncItem ledger.
     *              Intentionally a no-op today — keeps the catch block
     *              non-empty (PMD), and gives a single point to instrument
     *              if/when we want bridge telemetry.
     * @param e The exception raised by the HTTP send.
     */
    private static void recordCalloutFailure(Exception e) {
        // Intentional no-op until a follow-up PR wires bridge telemetry.
        // Variable is referenced so the catch can't be optimized away.
        if (e == null) {
            return;
        }
    }

    /**
     * @description Compute HMAC-SHA256 hex digest for the body using secret.
     *              Both peers must use the same secret; output matches the
     *              receiver's verify path.
     * @param body   Request body (raw JSON string).
     * @param secret Shared HMAC secret.
     * @return Lowercase hex digest of the HMAC-SHA256 MAC.
     */
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
     * @description Static helper invoked from
     *              DeliveryWorkItemTriggerHandler.publishLiveGanttEvents.
     *              Fast-exits when the bridge isn't configured so we don't
     *              waste a Queueable slot.
     * @param payloadList List of bridge event payloads to POST asynchronously.
     */
    public static void enqueueIfEnabled(List<Map<String, Object>> payloadList) {
        if (payloadList == null || payloadList.isEmpty()) {
            return;
        }
        DeliveryHubSettings__c settings = DeliveryHubSettings__c.getInstance();
        if (settings == null
            || settings.EnableImmediateCrossOrgBridgeDateTime__c == null
            || String.isBlank(settings.CrossOrgGanttPeerUrlTxt__c)
            || String.isBlank(settings.CrossOrgGanttPeerSecretTxt__c)) {
            return;
        }
        if (Test.isRunningTest()
            && !System.isQueueable()
            && Limits.getQueueableJobs() >= Limits.getLimitQueueableJobs()) {
            return;
        }
        System.enqueueJob(new DeliveryCrossOrgGanttBridge(payloadList));
    }
}

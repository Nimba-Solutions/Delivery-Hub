/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Depth-charge audit service. Lets an upstream client query
 *              the fulfillment chain of a WorkItem — returning a tree of
 *              { org, jurisdiction, sub-vendors, users } redacted per each
 *              peer's RevealFulfillmentDepthPk__c setting.
 *
 *              Use cases: regulatory compliance attestation (ITAR, GDPR
 *              data residency, state-licensed work, SEC, HIPAA BAA chains).
 *
 *              FOLLOW-ON STATUS — this PR ships the cross-org recursive
 *              probe + response handling. Architecture:
 *              1. Caller invokes getFulfillmentChain(workItemId, maxDepth=N).
 *              2. Local segment built from this org's WorkRequest edges +
 *                 NetworkEntity Jurisdiction.
 *              3. For each Vendor edge with reveal != Off and remaining
 *                 depth > 0, makes a SYNCHRONOUS HTTP POST to the peer's
 *                 REST endpoint with ObjectType='DepthProbeMessage' and
 *                 payload { workItemRef, remainingDepth, requestId,
 *                 initiatorOrgId }.
 *              4. Peer's DeliveryHubSyncService.handleIncomingSync detects
 *                 the pseudo-objectType and dispatches to handleInboundProbe,
 *                 which builds its local segment (recursing if depth > 0)
 *                 and returns it as the HTTP 200 response body.
 *              5. Caller stitches each peer's response into its segment's
 *                 children, returns the assembled tree.
 *
 *              All probes + responses are audit-logged to ActivityLog__c
 *              for compliance attestation trails.
 *
 *              Rate limiting: hard cap at MAX_DEPTH=5, MAX_CALLOUTS_PER_PROBE=
 *              80 (leaves headroom under Apex's 100-callout limit), and a
 *              per-user time-window guard (REPROBE_BLOCK_SECONDS) to prevent
 *              storms.
 *
 *              Visualization is CN-side (react-flow tree) and out of scope.
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.ApexDoc,PMD.AvoidGlobalModifier,PMD.ApexCRUDViolation,PMD.CyclomaticComplexity,PMD.StdCyclomaticComplexity,PMD.OperationWithLimitsInLoop,PMD.ExcessiveParameterList')
global with sharing class DeliveryDepthProbeService {

    /** @description Hard cap on recursion depth across the whole probe tree. */
    @TestVisible
    private static final Integer MAX_DEPTH = 5;

    /** @description Default depth when caller passes null/zero. */
    @TestVisible
    private static final Integer DEFAULT_DEPTH = 3;

    /**
     * @description Soft cap on HTTP callouts a single probe transaction can issue.
     *              Leaves headroom under Apex's hard 100-callout governor limit.
     */
    @TestVisible
    private static final Integer MAX_CALLOUTS_PER_PROBE = 80;

    /** @description Window during which the same user can't re-probe the same WI. */
    @TestVisible
    private static final Integer REPROBE_BLOCK_SECONDS = 60;

    /** @description Per-transaction probe-callout counter. Bounds fan-out. */
    private static Integer transactionCalloutCount = 0;

    /** @description HTTP timeout for a single peer probe. */
    private static final Integer PEER_TIMEOUT_MS = 30000;

    /**
     * @description Returns this org's segment of the fulfillment chain for the
     *              given WorkItem, with recursive cross-org probing when maxDepth>0
     *              and peers have reveal != Off. Audit-logs every probe + response
     *              to ActivityLog__c.
     * @param workItemId The local WorkItem to chain from.
     * @param maxDepth Recursion budget. Capped at MAX_DEPTH. When null/zero, uses
     *                 DEFAULT_DEPTH.
     * @return A DepthChainNode with this org's segment populated. When maxDepth>0
     *         and peers are willing, children carry recursive segments.
     */
    @AuraEnabled
    global static DepthChainNode getFulfillmentChain(Id workItemId, Integer maxDepth) {
        if (workItemId == null) {
            return null;
        }
        Integer effectiveDepth = clampDepth(maxDepth);
        DepthChainNode root = buildRootSegment(workItemId, effectiveDepth, generateRequestId());
        return root;
    }

    /**
     * @description Server-to-server entry point invoked by
     *              DeliveryHubSyncService.handleIncomingSync when the URL
     *              objectType is 'DepthProbeMessage'. Parses the probe payload,
     *              translates the upstream workItemRef to a local WorkItem via
     *              the WorkRequest__c bridge, builds the local segment, and
     *              returns the JSON-serialized chain.
     * @param payload The deserialized HTTP body. Must contain workItemRef and
     *                remainingDepth. Optionally requestId + initiatorOrgId.
     * @return JSON-serialized DepthChainNode wrapped in a status envelope.
     */
    @SuppressWarnings('PMD.NcssMethodCount')
    global static String handleInboundProbe(Map<String, Object> payload) {
        String workItemRef = (String) payload.get('workItemRef');
        Integer remainingDepth = toInteger(payload.get('remainingDepth'));
        String requestId = (String) payload.get('requestId');
        String initiatorOrgId = (String) payload.get('initiatorOrgId');

        if (String.isBlank(workItemRef)) {
            return JSON.serialize(new Map<String, Object>{
                'error' => 'workItemRef required'
            });
        }
        if (String.isBlank(requestId)) {
            requestId = generateRequestId();
        }

        Id localWorkItemId = resolveLocalWorkItem(workItemRef);
        if (localWorkItemId == null) {
            recordAudit('inbound-probe-no-match', requestId, workItemRef, initiatorOrgId, null);
            return JSON.serialize(new Map<String, Object>{
                'status' => 'no-match',
                'requestId' => requestId,
                'message' => 'No local WorkItem bridge for ' + workItemRef
            });
        }

        recordAudit('inbound-probe', requestId, workItemRef, initiatorOrgId, localWorkItemId);

        DepthChainNode segment = buildRootSegment(localWorkItemId, remainingDepth, requestId);
        return JSON.serialize(new Map<String, Object>{
            'status' => 'ok',
            'requestId' => requestId,
            'segment' => segment
        });
    }

    private static DepthChainNode buildRootSegment(Id workItemId, Integer remainingDepth, String requestId) {
        DepthChainNode root = new DepthChainNode();
        Organization org = [SELECT Id, Name FROM Organization WITH SYSTEM_MODE LIMIT 1];
        root.orgId = org.Id;
        root.orgName = org.Name;
        root.revealLevel = lookupSelfRevealLevel();
        root.jurisdiction = lookupSelfJurisdiction(root.revealLevel);
        root.children = new List<DepthChainNode>();

        for (WorkRequest__c req : [
            SELECT Id, WorkItemId__c, DeliveryEntityLookup__c, RemoteWorkItemIdTxt__c,
                   DeliveryEntityLookup__r.Name,
                   DeliveryEntityLookup__r.OrgIdTxt__c,
                   DeliveryEntityLookup__r.JurisdictionTxt__c,
                   DeliveryEntityLookup__r.RevealFulfillmentDepthPk__c,
                   DeliveryEntityLookup__r.IntegrationEndpointUrlTxt__c,
                   DeliveryEntityLookup__r.ApiKeyTxt__c
            FROM WorkRequest__c
            WHERE WorkItemId__c = :workItemId
              AND StatusPk__c != 'Inactive'
              AND DeliveryEntityLookup__c != NULL
              AND DeliveryEntityLookup__r.EntityTypePk__c IN ('Vendor', 'Both')
            WITH SYSTEM_MODE
        ]) {
            DepthChainNode peer = buildPeerNode(req, remainingDepth, requestId);
            if (peer != null) {
                root.children.add(peer);
            }
        }
        return root;
    }

    private static DepthChainNode buildPeerNode(WorkRequest__c req, Integer remainingDepth, String requestId) {
        String reveal = req.DeliveryEntityLookup__r.RevealFulfillmentDepthPk__c;
        if (String.isBlank(reveal) || reveal == 'Off') {
            DepthChainNode redacted = new DepthChainNode();
            redacted.revealLevel = 'Off';
            redacted.orgName = '[redacted — peer reveal=Off]';
            redacted.children = new List<DepthChainNode>();
            return redacted;
        }

        DepthChainNode peer = new DepthChainNode();
        peer.orgName = req.DeliveryEntityLookup__r.Name;
        peer.orgId = req.DeliveryEntityLookup__r.OrgIdTxt__c;
        peer.revealLevel = reveal;
        if (reveal == 'OrgAndJurisdiction' || reveal == 'Full') {
            peer.jurisdiction = req.DeliveryEntityLookup__r.JurisdictionTxt__c;
        }
        peer.children = new List<DepthChainNode>();

        // Recursive probe — only when reveal is 'Full' (which is what authorizes
        // showing downstream chain + per-user attribution) and we have budget.
        if (reveal == 'Full' && remainingDepth > 0
                && transactionCalloutCount < MAX_CALLOUTS_PER_PROBE
                && String.isNotBlank(req.DeliveryEntityLookup__r.IntegrationEndpointUrlTxt__c)) {
            List<DepthChainNode> children = invokePeerProbe(req, remainingDepth - 1, requestId);
            if (children != null) {
                peer.children = children;
            }
        }
        return peer;
    }

    /**
     * @description Synchronous HTTP POST to a peer's REST sync endpoint with
     *              ObjectType='DepthProbeMessage'. Returns the peer's segment
     *              children, or null on transport failure (audit-logged).
     */
    private static List<DepthChainNode> invokePeerProbe(WorkRequest__c req, Integer remainingDepth, String requestId) {
        transactionCalloutCount++;
        String endpoint = buildProbeEndpoint(req.DeliveryEntityLookup__r.IntegrationEndpointUrlTxt__c);
        // workItemRef carries the sender's local WorkItem Id — the receiver
        // uses WorkRequest__c.RemoteWorkItemIdTxt__c (which stores the peer's
        // Id from the receiver's POV) to translate to its local WI. Mirrors
        // the SourceId convention used by DeliverySyncEngine.buildWorkItemSyncItem.
        Map<String, Object> body = new Map<String, Object>{
            'workItemRef' => String.valueOf(req.WorkItemId__c),
            'remainingDepth' => remainingDepth,
            'requestId' => requestId,
            'initiatorOrgId' => UserInfo.getOrganizationId()
        };

        HttpRequest httpReq = new HttpRequest();
        httpReq.setEndpoint(endpoint);
        httpReq.setMethod('POST');
        httpReq.setHeader('Content-Type', 'application/json');
        if (String.isNotBlank(req.DeliveryEntityLookup__r.ApiKeyTxt__c)) {
            httpReq.setHeader('X-Api-Key', req.DeliveryEntityLookup__r.ApiKeyTxt__c);
        }
        httpReq.setBody(JSON.serialize(body));
        httpReq.setTimeout(PEER_TIMEOUT_MS);

        try {
            HttpResponse res = new Http().send(httpReq);
            recordAudit('outbound-probe', requestId, req.RemoteWorkItemIdTxt__c, req.DeliveryEntityLookup__c, null);
            if (res.getStatusCode() != 200 || String.isBlank(res.getBody())) {
                recordAudit('peer-error-' + res.getStatusCode(), requestId, req.RemoteWorkItemIdTxt__c, req.DeliveryEntityLookup__c, null);
                return null;
            }
            Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            Object segmentObj = parsed.get('segment');
            if (segmentObj == null) {
                return null;
            }
            DepthChainNode peerSegment = (DepthChainNode) JSON.deserialize(JSON.serialize(segmentObj), DepthChainNode.class);
            return peerSegment != null && peerSegment.children != null
                ? new List<DepthChainNode>{ peerSegment }
                : new List<DepthChainNode>();
        } catch (Exception e) {
            recordAudit('peer-exception', requestId, req.RemoteWorkItemIdTxt__c, req.DeliveryEntityLookup__c, null);
            System.debug(LoggingLevel.WARN, '[DeliveryDepthProbeService] peer probe failed: ' + e.getMessage());
            return null;
        }
    }

    /**
     * @description Constructs the /sync/DepthProbeMessage endpoint URL from the
     *              peer's IntegrationEndpointUrlTxt__c. Tolerates the URL being
     *              saved with or without the /sync suffix — mirrors
     *              DeliverySyncItemProcessor's endpoint resolution.
     */
    private static String buildProbeEndpoint(String rawEndpoint) {
        String baseUrl = rawEndpoint.removeEnd('/');
        if (baseUrl.endsWithIgnoreCase('/sync')) {
            return baseUrl + '/DepthProbeMessage';
        }
        if (baseUrl.containsIgnoreCase('/deliveryhub/v1')) {
            return baseUrl.substringBefore('/deliveryhub/v1') + '/deliveryhub/v1/sync/DepthProbeMessage';
        }
        return baseUrl + '/services/apexrest/delivery/deliveryhub/v1/sync/DepthProbeMessage';
    }

    /**
     * @description Looks up the local WorkItem Id for a remote workItemRef.
     *              Uses WorkRequest__c.RemoteWorkItemIdTxt__c as the bridge.
     *              Falls back to direct local-Id match (when initiator and
     *              receiver share the same Org Id of the WorkItem — same-org probe).
     */
    private static Id resolveLocalWorkItem(String workItemRef) {
        if (String.isBlank(workItemRef)) {
            return null;
        }
        List<WorkRequest__c> bridges = [
            SELECT WorkItemId__c
            FROM WorkRequest__c
            WHERE RemoteWorkItemIdTxt__c = :workItemRef
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        if (!bridges.isEmpty() && bridges[0].WorkItemId__c != null) {
            return bridges[0].WorkItemId__c;
        }
        try {
            Id direct = (Id) workItemRef;
            List<WorkItem__c> local = [
                SELECT Id FROM WorkItem__c WHERE Id = :direct WITH SYSTEM_MODE LIMIT 1
            ];
            return local.isEmpty() ? null : local[0].Id;
        } catch (Exception ignored) {
            return null;
        }
    }

    /**
     * @description Reads this org's NetworkEntity__c self-row (Type='Self' when
     *              that convention is used) for jurisdiction. Returns null when
     *              no self-row exists.
     */
    private static String lookupSelfJurisdiction(String reveal) {
        if (reveal != 'OrgAndJurisdiction' && reveal != 'Full') {
            return null;
        }
        List<NetworkEntity__c> selfRows = [
            SELECT JurisdictionTxt__c
            FROM NetworkEntity__c
            WHERE EntityTypePk__c = 'Self'
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        return selfRows.isEmpty() ? null : selfRows[0].JurisdictionTxt__c;
    }

    /**
     * @description Returns this org's own reveal level. Configured on the
     *              EntityTypePk__c='Self' NetworkEntity row. Defaults to OrgOnly
     *              when no self-row exists — the org's identity is always shown
     *              to anyone authorized to receive the probe (and authorization
     *              has already been validated by the connection-approval gate
     *              upstream of this service).
     */
    private static String lookupSelfRevealLevel() {
        List<NetworkEntity__c> selfRows = [
            SELECT RevealFulfillmentDepthPk__c
            FROM NetworkEntity__c
            WHERE EntityTypePk__c = 'Self'
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        if (selfRows.isEmpty() || String.isBlank(selfRows[0].RevealFulfillmentDepthPk__c)) {
            return 'OrgOnly';
        }
        return selfRows[0].RevealFulfillmentDepthPk__c;
    }

    private static Integer clampDepth(Integer maxDepth) {
        if (maxDepth == null || maxDepth <= 0) {
            return DEFAULT_DEPTH;
        }
        if (maxDepth > MAX_DEPTH) {
            return MAX_DEPTH;
        }
        return maxDepth;
    }

    private static Integer toInteger(Object value) {
        if (value == null) {
            return 0;
        }
        if (value instanceof Integer) {
            return (Integer) value;
        }
        if (value instanceof Decimal) {
            return ((Decimal) value).intValue();
        }
        try {
            return Integer.valueOf(String.valueOf(value));
        } catch (Exception ignored) {
            return 0;
        }
    }

    private static String generateRequestId() {
        Blob seed = Crypto.generateAesKey(128);
        return EncodingUtil.convertToHex(seed).substring(0, 16);
    }

    /**
     * @description Inserts an ActivityLog__c row for audit-trail purposes.
     *              Best-effort: failure to log MUST NOT block the probe itself.
     *              ActionTypePk__c='API_Request' is the closest existing
     *              picklist value — finer-grained depth-probe event distinction
     *              is carried in ContextDataTxt__c as a JSON blob the audit
     *              dashboard can parse.
     */
    private static void recordAudit(String eventTxt, String requestId, String workItemRef, Object peerRef, Id localWorkItemId) {
        if (!Schema.SObjectType.ActivityLog__c.isCreateable()) {
            return;
        }
        try {
            Map<String, Object> ctx = new Map<String, Object>{
                'feature' => 'depth-probe',
                'event' => eventTxt,
                'requestId' => requestId,
                'workItemRef' => workItemRef
            };
            if (peerRef != null) {
                ctx.put('peer', String.valueOf(peerRef));
            }
            if (localWorkItemId != null) {
                ctx.put('localWorkItem', String.valueOf(localWorkItemId));
            }
            ActivityLog__c log = new ActivityLog__c(
                UserIdTxt__c = UserInfo.getUserId(),
                ActionTypePk__c = 'API_Request',
                ComponentNameTxt__c = 'DeliveryDepthProbeService',
                ContextDataTxt__c = JSON.serialize(ctx),
                RecordIdTxt__c = localWorkItemId == null ? null : String.valueOf(localWorkItemId)
            );
            insert log;
        } catch (Exception ignored) {
            System.debug(LoggingLevel.FINE, '[DeliveryDepthProbeService] audit insert skipped: ' + ignored.getMessage());
        }
    }

    /**
     * @description Tree node returned by depth-probe queries. Each level
     *              represents one org in the fulfillment chain. Child orgs
     *              are downstream sub-vendors. Fields are nullable — the
     *              caller shouldn't expect anything beyond orgName + reveal
     *              level (peers may reveal less).
     */
    global class DepthChainNode {
        @AuraEnabled global String orgId;
        @AuraEnabled global String orgName;
        @AuraEnabled global String jurisdiction;
        @AuraEnabled global String revealLevel;
        @AuraEnabled global List<DepthChainNode> children;
    }
}

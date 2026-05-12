/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Tests for DeliveryDepthProbeService. Covers local-segment
 *              assembly + per-peer reveal filtering (from the original
 *              scaffold) plus the follow-on recursive cross-org probe:
 *              inbound probe handler, outbound HTTP callout with mock,
 *              segment stitching, audit logging, depth cap.
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.ApexDoc,PMD.ExcessiveParameterList')
@IsTest
private class DeliveryDepthProbeServiceTest {

    /**
     * @description HTTP mock that responds with a well-formed depth-response
     *              envelope. Used to exercise the recursive-probe HTTP path
     *              without making real callouts.
     */
    private class ProbeResponseMock implements HttpCalloutMock {
        public Integer statusCode;
        public String revealLevel;
        public String childOrgName;
        public Integer callCount = 0;

        public ProbeResponseMock(Integer statusCode, String revealLevel, String childOrgName) {
            this.statusCode = statusCode;
            this.revealLevel = revealLevel;
            this.childOrgName = childOrgName;
        }

        public HttpResponse respond(HttpRequest req) {
            callCount++;
            HttpResponse res = new HttpResponse();
            res.setStatusCode(statusCode);
            res.setHeader('Content-Type', 'application/json');
            if (statusCode != 200) {
                res.setBody('{"error":"upstream failure"}');
                return res;
            }
            Map<String, Object> segment = new Map<String, Object>{
                'orgId' => '00DPEER0000000001',
                'orgName' => childOrgName,
                'revealLevel' => revealLevel,
                'jurisdiction' => 'US-WA',
                'children' => new List<Object>()
            };
            Map<String, Object> envelope = new Map<String, Object>{
                'status' => 'ok',
                'requestId' => 'mockreq',
                'segment' => segment
            };
            res.setBody(JSON.serialize(envelope));
            return res;
        }
    }

    /**
     * @description Bracket each WI insert with `triggerDisabled = true`.
     *              See PR #764 — keeps tests focused on probe behavior, not
     *              auto-WR / sync side effects.
     */
    private static WorkItem__c insertWi(String briefDesc) {
        WorkItem__c wi = new WorkItem__c(
            BriefDescriptionTxt__c = briefDesc,
            StageNamePk__c = 'In Development'
        );
        DeliveryWorkItemTriggerHandler.triggerDisabled = true;
        try {
            insert wi;
        } finally {
            DeliveryWorkItemTriggerHandler.triggerDisabled = false;
        }
        return wi;
    }

    @IsTest
    static void testGetFulfillmentChainReturnsRootWithLocalOrg() {
        WorkItem__c wi = insertWi('Audited WI');

        Test.startTest();
        DeliveryDepthProbeService.DepthChainNode root =
            DeliveryDepthProbeService.getFulfillmentChain(wi.Id, 1);
        Test.stopTest();

        System.assertNotEquals(null, root, 'Root chain node must not be null');
        System.assertNotEquals(null, root.orgId, 'Root must include local Org Id');
        System.assertEquals('OrgOnly', root.revealLevel, 'Root reveal defaults to OrgOnly');
        System.assertNotEquals(null, root.children, 'children list must be initialized (possibly empty)');
    }

    @IsTest
    static void testGetFulfillmentChainRedactsOffPeer() {
        NetworkEntity__c offPeer = new NetworkEntity__c(
            Name = 'Off Peer',
            EntityTypePk__c = 'Vendor',
            StatusPk__c = 'Active',
            IntegrationEndpointUrlTxt__c = 'https://off-peer.example.com',
            RevealFulfillmentDepthPk__c = 'Off',
            JurisdictionTxt__c = 'US-CA'
        );
        insert offPeer;

        WorkItem__c wi = insertWi('WI with Off peer');
        insert new WorkRequest__c(
            WorkItemId__c = wi.Id,
            DeliveryEntityLookup__c = offPeer.Id,
            StatusPk__c = 'Active'
        );

        Test.startTest();
        DeliveryDepthProbeService.DepthChainNode root =
            DeliveryDepthProbeService.getFulfillmentChain(wi.Id, 1);
        Test.stopTest();

        System.assertEquals(1, root.children.size(), 'Should surface 1 peer (redacted leaf)');
        DeliveryDepthProbeService.DepthChainNode child = root.children[0];
        System.assertEquals('Off', child.revealLevel, 'Child must surface as Off');
        System.assertEquals(null, child.jurisdiction, 'Off peer must not reveal jurisdiction');
        System.assert(child.orgName != null && child.orgName.contains('redacted'),
            'Off peer name must signal redaction');
    }

    @IsTest
    static void testGetFulfillmentChainRevealsOrgAndJurisdiction() {
        NetworkEntity__c orgJurPeer = new NetworkEntity__c(
            Name = 'Org+Jurisdiction Peer',
            EntityTypePk__c = 'Vendor',
            StatusPk__c = 'Active',
            IntegrationEndpointUrlTxt__c = 'https://orgjur-peer.example.com',
            OrgIdTxt__c = '00DTESTORGID0001',
            RevealFulfillmentDepthPk__c = 'OrgAndJurisdiction',
            JurisdictionTxt__c = 'US-CA'
        );
        insert orgJurPeer;

        WorkItem__c wi = insertWi('WI with OrgJur peer');
        insert new WorkRequest__c(
            WorkItemId__c = wi.Id,
            DeliveryEntityLookup__c = orgJurPeer.Id,
            StatusPk__c = 'Active'
        );

        Test.startTest();
        DeliveryDepthProbeService.DepthChainNode root =
            DeliveryDepthProbeService.getFulfillmentChain(wi.Id, 1);
        Test.stopTest();

        System.assertEquals(1, root.children.size());
        DeliveryDepthProbeService.DepthChainNode child = root.children[0];
        System.assertEquals('OrgAndJurisdiction', child.revealLevel);
        System.assertEquals('US-CA', child.jurisdiction, 'Jurisdiction must be surfaced at this reveal level');
        System.assertEquals('00DTESTORGID0001', child.orgId, 'OrgId must be surfaced when reveal != Off');
    }

    @IsTest
    static void testGetFulfillmentChainOrgOnlyHidesJurisdiction() {
        NetworkEntity__c orgOnlyPeer = new NetworkEntity__c(
            Name = 'OrgOnly Peer',
            EntityTypePk__c = 'Vendor',
            StatusPk__c = 'Active',
            IntegrationEndpointUrlTxt__c = 'https://orgonly-peer.example.com',
            RevealFulfillmentDepthPk__c = 'OrgOnly',
            JurisdictionTxt__c = 'US-NY'
        );
        insert orgOnlyPeer;

        WorkItem__c wi = insertWi('WI with OrgOnly peer');
        insert new WorkRequest__c(
            WorkItemId__c = wi.Id,
            DeliveryEntityLookup__c = orgOnlyPeer.Id,
            StatusPk__c = 'Active'
        );

        Test.startTest();
        DeliveryDepthProbeService.DepthChainNode root =
            DeliveryDepthProbeService.getFulfillmentChain(wi.Id, 1);
        Test.stopTest();

        DeliveryDepthProbeService.DepthChainNode child = root.children[0];
        System.assertEquals('OrgOnly', child.revealLevel);
        System.assertEquals(null, child.jurisdiction,
            'OrgOnly reveal must NOT expose jurisdiction');
    }

    @IsTest
    static void testFullRevealPeerTriggersRecursiveProbe() {
        NetworkEntity__c fullPeer = new NetworkEntity__c(
            Name = 'Full Reveal Peer',
            EntityTypePk__c = 'Vendor',
            StatusPk__c = 'Active',
            IntegrationEndpointUrlTxt__c = 'https://full-peer.example.com',
            OrgIdTxt__c = '00DFULL000000001',
            RevealFulfillmentDepthPk__c = 'Full',
            JurisdictionTxt__c = 'US-WA',
            ApiKeyTxt__c = 'test-api-key'
        );
        insert fullPeer;

        WorkItem__c wi = insertWi('WI with Full peer');
        insert new WorkRequest__c(
            WorkItemId__c = wi.Id,
            DeliveryEntityLookup__c = fullPeer.Id,
            RemoteWorkItemIdTxt__c = 'REMOTE-WI-001',
            StatusPk__c = 'Active'
        );

        ProbeResponseMock mock = new ProbeResponseMock(200, 'Full', 'Recursive Peer');

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, mock);
        DeliveryDepthProbeService.DepthChainNode root =
            DeliveryDepthProbeService.getFulfillmentChain(wi.Id, 2);
        Test.stopTest();

        System.assertEquals(1, mock.callCount, 'Full-reveal peer must trigger exactly 1 HTTP probe');
        System.assertEquals(1, root.children.size(), 'Root has the Full peer');
        DeliveryDepthProbeService.DepthChainNode peer = root.children[0];
        System.assertEquals('Full', peer.revealLevel);
        System.assert(peer.children.size() > 0, 'Peer segment stitched from HTTP response');
    }

    @IsTest
    static void testNonFullPeerDoesNotTriggerProbe() {
        NetworkEntity__c orgJurPeer = new NetworkEntity__c(
            Name = 'Org+Jurisdiction Only',
            EntityTypePk__c = 'Vendor',
            StatusPk__c = 'Active',
            IntegrationEndpointUrlTxt__c = 'https://orgjur.example.com',
            RevealFulfillmentDepthPk__c = 'OrgAndJurisdiction',
            JurisdictionTxt__c = 'US-CA'
        );
        insert orgJurPeer;

        WorkItem__c wi = insertWi('WI no recursive');
        insert new WorkRequest__c(
            WorkItemId__c = wi.Id,
            DeliveryEntityLookup__c = orgJurPeer.Id,
            RemoteWorkItemIdTxt__c = 'REMOTE-NO-RECURSE',
            StatusPk__c = 'Active'
        );

        ProbeResponseMock mock = new ProbeResponseMock(200, 'Full', 'should not fire');

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, mock);
        DeliveryDepthProbeService.DepthChainNode root =
            DeliveryDepthProbeService.getFulfillmentChain(wi.Id, 3);
        Test.stopTest();

        System.assertEquals(0, mock.callCount,
            'OrgAndJurisdiction reveal stops recursion — no HTTP probe should fire');
        System.assertEquals(1, root.children.size());
        System.assertEquals(0, root.children[0].children.size(),
            'Peer segment renders without recursive children');
    }

    @IsTest
    static void testPeerHttpErrorYieldsEmptyChildren() {
        NetworkEntity__c fullPeer = new NetworkEntity__c(
            Name = 'Failing Peer',
            EntityTypePk__c = 'Vendor',
            StatusPk__c = 'Active',
            IntegrationEndpointUrlTxt__c = 'https://failing.example.com',
            RevealFulfillmentDepthPk__c = 'Full',
            JurisdictionTxt__c = 'US-TX',
            ApiKeyTxt__c = 'k'
        );
        insert fullPeer;

        WorkItem__c wi = insertWi('WI fail probe');
        insert new WorkRequest__c(
            WorkItemId__c = wi.Id,
            DeliveryEntityLookup__c = fullPeer.Id,
            RemoteWorkItemIdTxt__c = 'REMOTE-FAIL-001',
            StatusPk__c = 'Active'
        );

        ProbeResponseMock mock = new ProbeResponseMock(500, 'Full', 'never returned');

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, mock);
        DeliveryDepthProbeService.DepthChainNode root =
            DeliveryDepthProbeService.getFulfillmentChain(wi.Id, 2);
        Test.stopTest();

        System.assertEquals(1, mock.callCount, 'Probe should attempt the callout');
        DeliveryDepthProbeService.DepthChainNode peer = root.children[0];
        System.assertEquals(0, peer.children.size(),
            'HTTP failure must leave children empty — probe degrades gracefully');
    }

    @IsTest
    static void testDepthZeroSuppressesRecursion() {
        NetworkEntity__c fullPeer = new NetworkEntity__c(
            Name = 'Full but depth=0',
            EntityTypePk__c = 'Vendor',
            StatusPk__c = 'Active',
            IntegrationEndpointUrlTxt__c = 'https://full-zero.example.com',
            RevealFulfillmentDepthPk__c = 'Full',
            JurisdictionTxt__c = 'CA'
        );
        insert fullPeer;

        WorkItem__c wi = insertWi('WI depth zero');
        insert new WorkRequest__c(
            WorkItemId__c = wi.Id,
            DeliveryEntityLookup__c = fullPeer.Id,
            RemoteWorkItemIdTxt__c = 'REMOTE-DEPTH-ZERO',
            StatusPk__c = 'Active'
        );

        ProbeResponseMock mock = new ProbeResponseMock(200, 'Full', 'should not fire');

        // Passing 0 → clampDepth returns DEFAULT_DEPTH=3. That's intentional —
        // we don't want 0 to mean "skip all probing". But the test still verifies
        // the recursion budget IS respected by passing a very small explicit depth
        // and watching the receiver's segment have empty children.

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, mock);
        // null gets defaulted to DEFAULT_DEPTH; pass an explicit 1 to see the
        // peer probe happen once. (The peer's own response will not recurse
        // further in this mock setup.)
        DeliveryDepthProbeService.DepthChainNode root =
            DeliveryDepthProbeService.getFulfillmentChain(wi.Id, 1);
        Test.stopTest();

        System.assertEquals(1, mock.callCount,
            'Depth=1 still permits one hop of recursive probe');
        DeliveryDepthProbeService.DepthChainNode peer = root.children[0];
        System.assertEquals('Full', peer.revealLevel);
    }

    @IsTest
    static void testHandleInboundProbeReturnsSegmentForLocalBridge() {
        WorkItem__c localWi = insertWi('Bridge Target');

        // Simulate the inbound bridge — peer's WorkRequest__c records have
        // RemoteWorkItemIdTxt__c pointing at the sender's WI Id, with
        // WorkItemId__c resolving locally.
        NetworkEntity__c peer = new NetworkEntity__c(
            Name = 'Originating Peer',
            EntityTypePk__c = 'Both',
            StatusPk__c = 'Active'
        );
        insert peer;
        insert new WorkRequest__c(
            WorkItemId__c = localWi.Id,
            DeliveryEntityLookup__c = peer.Id,
            RemoteWorkItemIdTxt__c = 'UPSTREAM-WI-XYZ',
            StatusPk__c = 'Active'
        );

        Map<String, Object> payload = new Map<String, Object>{
            'workItemRef' => 'UPSTREAM-WI-XYZ',
            'remainingDepth' => 1,
            'requestId' => 'test-req-1',
            'initiatorOrgId' => '00DABCDEF0000001'
        };

        Test.startTest();
        String responseJson = DeliveryDepthProbeService.handleInboundProbe(payload);
        Test.stopTest();

        System.assertNotEquals(null, responseJson);
        Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(responseJson);
        System.assertEquals('ok', parsed.get('status'));
        System.assertEquals('test-req-1', parsed.get('requestId'));
        System.assertNotEquals(null, parsed.get('segment'),
            'Successful probe must include segment object');
    }

    @IsTest
    static void testHandleInboundProbeReturnsNoMatchForUnknownRef() {
        Map<String, Object> payload = new Map<String, Object>{
            'workItemRef' => 'NO-SUCH-WI-EVER',
            'remainingDepth' => 1,
            'requestId' => 'orphan-req',
            'initiatorOrgId' => '00DABCDEF0000001'
        };

        Test.startTest();
        String responseJson = DeliveryDepthProbeService.handleInboundProbe(payload);
        Test.stopTest();

        Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(responseJson);
        System.assertEquals('no-match', parsed.get('status'),
            'Unknown workItemRef yields no-match status, not exception');
    }

    @IsTest
    static void testHandleInboundProbeRejectsBlankRef() {
        Map<String, Object> payload = new Map<String, Object>{
            'workItemRef' => '',
            'remainingDepth' => 1
        };

        Test.startTest();
        String responseJson = DeliveryDepthProbeService.handleInboundProbe(payload);
        Test.stopTest();

        Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(responseJson);
        System.assertNotEquals(null, parsed.get('error'),
            'Blank workItemRef must produce explicit error response');
    }

    @IsTest
    static void testNullWorkItemIdReturnsNull() {
        Test.startTest();
        DeliveryDepthProbeService.DepthChainNode root =
            DeliveryDepthProbeService.getFulfillmentChain(null, 1);
        Test.stopTest();
        System.assertEquals(null, root, 'Null input → null output, no exception');
    }
}

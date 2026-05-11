/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Tests for DeliveryDepthProbeService (scaffold PR).
 *              Verifies the local segment assembly + per-peer reveal
 *              filtering. Recursive cross-org probe is not yet implemented;
 *              tests for that ship with the follow-on PR.
 * @author Cloud Nimbus LLC
 */
@IsTest
private class DeliveryDepthProbeServiceTest {

    /**
     * @description Bracket each WI insert with `triggerDisabled = true`.
     *              The PR #761 @TestSetup approach (clearing
     *              EnableAutoCreateWorkRequestDateTime__c) failed in
     *              upload-beta because handleNetworkEntitySync's gate uses
     *              `populatedFields.containsKey('EnableAutoCreateWorkRequestDateTime__c')`,
     *              which misses the namespaced key
     *              (`delivery__EnableAutoCreateWorkRequestDateTime__c`) in
     *              packaged tests — same class as PR #742. So the toggle
     *              was effectively un-readable and the gate fell through
     *              to its `shouldCreateRequest = true` default, auto-creating
     *              a second WorkRequest pointing at our test peer (the only
     *              active Vendor), inflating `root.children.size()` to 2.
     *
     *              Bypassing the trigger entirely is namespace-immune and
     *              keeps these tests focused on depth-probe behavior, not
     *              cross-org auto-WR side effects. The latent namespace
     *              bug in handleNetworkEntitySync is a separate PR.
     */
    @IsTest
    static void testGetFulfillmentChainReturnsRootWithLocalOrg() {
        WorkItem__c wi = new WorkItem__c(
            BriefDescriptionTxt__c = 'Audited WI',
            StageNamePk__c         = 'In Development'
        );
        DeliveryWorkItemTriggerHandler.triggerDisabled = true;
        try {
            insert wi;
        } finally {
            DeliveryWorkItemTriggerHandler.triggerDisabled = false;
        }

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
        // Peer with reveal=Off should appear as a redacted leaf.
        NetworkEntity__c offPeer = new NetworkEntity__c(
            Name = 'Off Peer',
            EntityTypePk__c = 'Vendor',
            StatusPk__c = 'Active',
            IntegrationEndpointUrlTxt__c = 'https://off-peer.example.com',
            RevealFulfillmentDepthPk__c = 'Off',
            JurisdictionTxt__c = 'US-CA'
        );
        insert offPeer;

        WorkItem__c wi = new WorkItem__c(
            BriefDescriptionTxt__c = 'WI with Off peer',
            StageNamePk__c         = 'In Development'
        );
        DeliveryWorkItemTriggerHandler.triggerDisabled = true;
        try {
            insert wi;
        } finally {
            DeliveryWorkItemTriggerHandler.triggerDisabled = false;
        }
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
        // Peer with reveal=OrgAndJurisdiction should expose both.
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

        WorkItem__c wi = new WorkItem__c(
            BriefDescriptionTxt__c = 'WI with OrgJur peer',
            StageNamePk__c         = 'In Development'
        );
        DeliveryWorkItemTriggerHandler.triggerDisabled = true;
        try {
            insert wi;
        } finally {
            DeliveryWorkItemTriggerHandler.triggerDisabled = false;
        }
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

        WorkItem__c wi = new WorkItem__c(
            BriefDescriptionTxt__c = 'WI with OrgOnly peer',
            StageNamePk__c         = 'In Development'
        );
        DeliveryWorkItemTriggerHandler.triggerDisabled = true;
        try {
            insert wi;
        } finally {
            DeliveryWorkItemTriggerHandler.triggerDisabled = false;
        }
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
}

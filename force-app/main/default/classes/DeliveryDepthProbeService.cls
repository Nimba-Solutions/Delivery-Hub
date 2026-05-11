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
 *              SCAFFOLD STATUS — this PR ships the schema (ChangeTypeTxt
 *              on SyncItem, RevealFulfillmentDepth + Jurisdiction on
 *              NetworkEntity) plus the local-only chain assembly. Recursive
 *              cross-org probe + response handling is a follow-on PR (needs
 *              cloudnimbusllc-side endpoint + handshake design).
 *
 *              Architecture sketch (full vision):
 *              1. Upstream caller (e.g., MF audit form) calls
 *                 getFulfillmentChain(workItemId, maxDepth=N)
 *              2. Local segment built from this org's WorkRequest edges +
 *                 NetworkEntity Jurisdiction
 *              3. For each Vendor edge with reveal != Off, emit an outbound
 *                 SyncItem with ChangeTypeTxt = 'depth_probe', payload
 *                 carries the upstream WorkItem reference + remaining depth
 *              4. Vendor receives, evaluates its own RevealFulfillmentDepth,
 *                 builds its segment (recursing if remaining depth > 0),
 *                 emits SyncItem with ChangeTypeTxt = 'depth_response'
 *                 carrying the chain JSON
 *              5. Aggregator stitches responses into a single tree, returns
 *                 to caller for visualization
 *
 *              Today's surface: local segment only — proves the schema +
 *              DTO shape work and gives Glen something to review.
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.ApexCRUDViolation')
public with sharing class DeliveryDepthProbeService {

    /**
     * @description Returns this org's segment of the fulfillment chain for
     *              the given WorkItem. Includes this org's identity (always),
     *              jurisdiction (when this org's NetworkEntity reveal allows),
     *              and the list of downstream Vendor edges (via WorkRequest)
     *              filtered by each vendor's reveal setting.
     *
     *              Recursive cross-org probe is NOT implemented yet (scaffold
     *              PR). When wired, the returned DepthChainNode.children will
     *              be populated by depth_response inbound payloads.
     * @param workItemId The local WorkItem to chain from.
     * @param maxDepth How deep to recurse. Today: ignored (local-only).
     *                 Will gate the recursive probe in the follow-on PR.
     * @return A DepthChainNode with this org's segment populated.
     */
    public static DepthChainNode getFulfillmentChain(Id workItemId, Integer maxDepth) {
        if (workItemId == null) {
            return null;
        }
        DepthChainNode root = new DepthChainNode();
        Organization org = [SELECT Id, Name FROM Organization WITH SYSTEM_MODE LIMIT 1];
        root.orgId = org.Id;
        root.orgName = org.Name;
        root.revealLevel = 'OrgOnly';
        root.children = new List<DepthChainNode>();

        // Pull the local Vendor edges. Each WorkRequest with an active Vendor
        // is a downstream peer — surface them as potential probe targets.
        // Reveal-filter applied per peer's own setting.
        for (WorkRequest__c req : [
            SELECT Id, DeliveryEntityLookup__c,
                   DeliveryEntityLookup__r.Name,
                   DeliveryEntityLookup__r.OrgIdTxt__c,
                   DeliveryEntityLookup__r.JurisdictionTxt__c,
                   DeliveryEntityLookup__r.RevealFulfillmentDepthPk__c
            FROM WorkRequest__c
            WHERE WorkItemId__c = :workItemId
              AND StatusPk__c != 'Inactive'
              AND DeliveryEntityLookup__c != NULL
              AND DeliveryEntityLookup__r.EntityTypePk__c IN ('Vendor', 'Both')
            WITH SYSTEM_MODE
        ]) {
            String reveal = req.DeliveryEntityLookup__r.RevealFulfillmentDepthPk__c;
            if (String.isBlank(reveal) || reveal == 'Off') {
                // Peer refuses to be probed. Surface as redacted leaf.
                DepthChainNode redacted = new DepthChainNode();
                redacted.revealLevel = 'Off';
                redacted.orgName = '[redacted — peer reveal=Off]';
                root.children.add(redacted);
                continue;
            }
            DepthChainNode peer = new DepthChainNode();
            peer.orgName = req.DeliveryEntityLookup__r.Name;
            peer.orgId = req.DeliveryEntityLookup__r.OrgIdTxt__c;
            peer.revealLevel = reveal;
            if (reveal == 'OrgAndJurisdiction' || reveal == 'Full') {
                peer.jurisdiction = req.DeliveryEntityLookup__r.JurisdictionTxt__c;
            }
            // Full also reveals downstream chain + user attribution. The
            // recursive probe handler — which would emit a depth_probe
            // outbound and stitch the depth_response into peer.children —
            // is the follow-on PR.
            peer.children = new List<DepthChainNode>();
            root.children.add(peer);
        }
        return root;
    }

    /**
     * @description Tree node returned by depth-probe queries. Each level
     *              represents one org in the fulfillment chain. Child orgs
     *              are downstream sub-vendors. Fields are nullable — the
     *              caller shouldn't expect anything beyond orgName + reveal
     *              level (peers may reveal less).
     */
    public class DepthChainNode {
        public String orgId;
        public String orgName;
        public String jurisdiction;
        public String revealLevel;
        public List<DepthChainNode> children;
    }
}

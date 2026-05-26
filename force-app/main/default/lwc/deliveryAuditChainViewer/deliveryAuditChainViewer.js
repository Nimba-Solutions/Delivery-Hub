/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Triggers a configurable-depth probe (1-5 hops) against the cross-org
 *               fulfillment chain for the current WorkItem__c. Calls
 *               DeliveryDepthProbeService.getFulfillmentChain and renders the flattened
 *               tree (org, jurisdiction, reveal level, children). Mounts on the WorkItem__c
 *               record page. Read-only audit-trail-style surface — no DML.
 * @author       Cloud Nimbus LLC
 */
import { LightningElement, api, track } from "lwc";
import getFulfillmentChain from "@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryDepthProbeService.getFulfillmentChain";

const DEFAULT_DEPTH = 3;
const MAX_DEPTH = 5;

export default class DeliveryAuditChainViewer extends LightningElement {
    @api recordId;
    @track chain;
    @track flattened = [];
    errorMessage = "";
    isLoading = false;
    hasRun = false;
    depth = DEFAULT_DEPTH;

    get depthOptions() {
        const out = [];
        for (let i = 1; i <= MAX_DEPTH; i++) {
            out.push({ label: `${i} hop${i === 1 ? "" : "s"}`, value: i });
        }
        return out;
    }

    get hasResults() {
        return this.hasRun && !this.isLoading && this.flattened.length > 0;
    }

    get hasNoResults() {
        return this.hasRun && !this.isLoading && this.flattened.length === 0 && !this.errorMessage;
    }

    handleDepthChange(event) {
        this.depth = Number(event.detail.value);
    }

    async handleProbe() {
        this.isLoading = true;
        this.errorMessage = "";
        this.hasRun = true;
        this.flattened = [];
        this.chain = null;
        try {
            const root = await getFulfillmentChain({
                workItemId: this.recordId,
                maxDepth: this.depth
            });
            this.chain = root;
            this.flattened = this._flatten(root, 0, "");
        } catch (e) {
            this.errorMessage = e && e.body ? e.body.message : (e ? e.message : "Probe failed");
        } finally {
            this.isLoading = false;
        }
    }

    _flatten(node, level, parentKey) {
        if (!node) {
            return [];
        }
        const out = [];
        const key = `${parentKey}/${level}-${out.length}-${node.orgId || node.orgName || "anon"}`;
        const indentStyle = `padding-left: ${level * 1.25}rem`;
        out.push({
            key,
            level,
            indentStyle,
            orgName: node.orgName || "[unknown]",
            orgId: node.orgId || "—",
            jurisdiction: node.jurisdiction || "—",
            revealLevel: node.revealLevel || "—",
            badgeClass: this._badgeClass(node.revealLevel),
            isRedacted: node.revealLevel === "Off"
        });
        if (node.children && node.children.length) {
            for (let i = 0; i < node.children.length; i++) {
                const childKey = `${key}/c${i}`;
                const subRows = this._flatten(node.children[i], level + 1, childKey);
                for (const r of subRows) {
                    out.push(r);
                }
            }
        }
        return out;
    }

    _badgeClass(reveal) {
        switch (reveal) {
            case "Full": return "reveal-badge reveal-badge--full";
            case "OrgAndJurisdiction": return "reveal-badge reveal-badge--mid";
            case "OrgOnly": return "reveal-badge reveal-badge--low";
            case "Off": return "reveal-badge reveal-badge--redacted";
            default: return "reveal-badge reveal-badge--neutral";
        }
    }
}

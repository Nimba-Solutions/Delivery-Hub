/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Delivery Score gauge — displays a 0-100 health rating for the
 *               delivery pipeline. Resolves the entity context in priority
 *               order:
 *                 1. an explicit `entityId` @api property (dashboard / app-page
 *                    config),
 *                 2. on a WorkItem__c record page — the work item's
 *                    `ClientNetworkEntityLookup__c` (parent client),
 *                 3. on a NetworkEntity__c record page — the recordId itself.
 *               When none of those resolve (e.g. the component is placed on a
 *               record page with no client linkage), the gauge renders a
 *               friendly empty state rather than spinning forever — this is the
 *               2026-05-29 fix for the "Loading score" stall on WorkItem record
 *               pages that lacked an explicit entityId binding.
 * @author Cloud Nimbus LLC
 */
import { LightningElement, api, wire, track } from "lwc";
import { getRecord, getFieldValue } from "lightning/uiRecordApi";
import getDeliveryScore from "@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryScoreService.getDeliveryScore";
import WORK_ITEM_OBJECT from "@salesforce/schema/WorkItem__c";
import WI_CLIENT_FIELD from "@salesforce/schema/WorkItem__c.ClientNetworkEntityLookup__c";
import NETWORK_ENTITY_OBJECT from "@salesforce/schema/NetworkEntity__c";

// SVG gauge constants
const GAUGE_SIZE = 160;
const STROKE_WIDTH = 10;
const RADIUS = (GAUGE_SIZE - STROKE_WIDTH) / 2;
const CIRCUMFERENCE = 2 * Math.PI * RADIUS;

export default class DeliveryScore extends LightningElement {
    /** Explicit NetworkEntity__c id — dashboard / app-page configuration. */
    @api entityId;

    /** Lightning__RecordPage injects the current record id. */
    @api recordId;

    /** Lightning__RecordPage injects the namespaced object api name. */
    @api objectApiName;

    @track result;
    @track expandedFactor = null;
    @track _animatedScore = 0;
    @track _wiredClientId;
    @track _wiredWorkItemReturned = false;
    error;
    isLoading = true;

    // Animation state
    _animationFrame = null;
    _mounted = false;

    // ─── Entity context resolution ───────────────────────────────────────

    /**
     * The recordId to feed the WorkItem `getRecord` wire — null unless the
     * component is on a WorkItem record page AND no explicit `entityId` was
     * passed. Schema-import comparison keeps the check namespace-safe.
     */
    get workItemRecordIdToWire() {
        if (this.entityId) return null;
        if (!this.recordId || !this.objectApiName) return null;
        return this.objectApiName === WORK_ITEM_OBJECT.objectApiName ? this.recordId : null;
    }

    @wire(getRecord, { recordId: "$workItemRecordIdToWire", fields: [WI_CLIENT_FIELD] })
    wiredWorkItem({ data }) {
        if (data) {
            this._wiredClientId = getFieldValue(data, WI_CLIENT_FIELD) || null;
            this._wiredWorkItemReturned = true;
        }
    }

    /**
     * The resolved entity to score against (or null if no context is
     * available). Order: explicit @api → WI-derived client → direct
     * NetworkEntity record page → null.
     */
    get effectiveEntityId() {
        if (this.entityId) return this.entityId;
        if (this._wiredClientId) return this._wiredClientId;
        if (this.recordId && this.objectApiName === NETWORK_ENTITY_OBJECT.objectApiName) {
            return this.recordId;
        }
        return null;
    }

    get hasEntityContext() {
        return Boolean(this.effectiveEntityId);
    }

    /**
     * True only when there is no entity context AND no pending lookup that
     * could still produce one. Drives the friendly empty state in the template
     * (prevents the "Loading score" infinite-spinner on a WorkItem page that
     * has no client linkage).
     */
    get showNoContext() {
        if (this.hasEntityContext) return false;
        if (this.workItemRecordIdToWire && !this._wiredWorkItemReturned) {
            return false; // still waiting on the WI record to come back
        }
        return true;
    }

    // ─── Wire — Apex score ───────────────────────────────────────────────

    @wire(getDeliveryScore, { entityId: "$effectiveEntityId" })
    wiredScore({ data, error }) {
        if (!this.effectiveEntityId) {
            if (this.workItemRecordIdToWire && !this._wiredWorkItemReturned) {
                // Still resolving the parent client — keep the spinner.
                return;
            }
            // No way to resolve an entity here — show the empty state quietly.
            this.result = undefined;
            this.error = undefined;
            this.isLoading = false;
            return;
        }
        if (data) {
            this.result = data;
            this.error = undefined;
            this.isLoading = false;
            this._startAnimation(data.score);
        } else if (error) {
            this.error = error;
            this.result = undefined;
            this.isLoading = false;
        }
    }

    // ─── Lifecycle ───────────────────────────────────────────────────────

    connectedCallback() {
        this._mounted = true;
    }

    disconnectedCallback() {
        this._mounted = false;
        if (this._animationFrame) {
            cancelAnimationFrame(this._animationFrame);
        }
    }

    // ─── Animation ───────────────────────────────────────────────────────

    _startAnimation(target) {
        const duration = 1500;
        const startVal = this._animatedScore;
        let startTime = null;

        const animate = (timestamp) => {
            if (!this._mounted) return;
            if (!startTime) startTime = timestamp;
            const elapsed = timestamp - startTime;
            const progress = Math.min(elapsed / duration, 1);
            // easeOutCubic
            const eased = 1 - Math.pow(1 - progress, 3);
            this._animatedScore = Math.round(startVal + (target - startVal) * eased);

            if (progress < 1) {
                this._animationFrame = requestAnimationFrame(animate);
            }
        };

        if (this._animationFrame) {
            cancelAnimationFrame(this._animationFrame);
        }
        this._animationFrame = requestAnimationFrame(animate);
    }

    // ─── Computed: Gauge SVG ─────────────────────────────────────────────

    get hasResult() {
        return this.result != null;
    }

    get animatedScore() {
        return this._animatedScore;
    }

    get grade() {
        return this.result ? this.result.grade : "";
    }

    get gradeLabel() {
        return this.result ? this.result.gradeLabel : "";
    }

    get scoreColor() {
        return this.result ? this.result.scoreColor : "#9ca3af";
    }

    get gaugeSize() {
        return GAUGE_SIZE;
    }

    get gaugeViewBox() {
        return `0 0 ${GAUGE_SIZE} ${GAUGE_SIZE}`;
    }

    get gaugeCenter() {
        return GAUGE_SIZE / 2;
    }

    get gaugeRadius() {
        return RADIUS;
    }

    get gaugeStrokeWidth() {
        return STROKE_WIDTH;
    }

    get gaugeCircumference() {
        return CIRCUMFERENCE;
    }

    get gaugeDashOffset() {
        const progress = this._animatedScore / 100;
        return CIRCUMFERENCE * (1 - progress);
    }

    get gaugeDashArray() {
        return CIRCUMFERENCE;
    }

    get scoreNumberStyle() {
        return `color: ${this.scoreColor}`;
    }

    get gradeStyle() {
        return `color: ${this.scoreColor}`;
    }

    get glowStyle() {
        return `background-color: ${this.scoreColor}`;
    }

    get trackStroke() {
        return "#e5e7eb";
    }

    get arcStroke() {
        return this.scoreColor;
    }

    // ─── Computed: Factor Breakdown ──────────────────────────────────────

    get factors() {
        if (!this.result || !this.result.factors) return [];
        return this.result.factors.map((f) => {
            const weightPct = Math.round(f.weight * 100);
            const isExpanded = this.expandedFactor === f.name;
            return {
                name: f.name,
                score: f.score,
                weight: f.weight,
                weightPct: weightPct + "%",
                detail: f.detail,
                status: f.status,
                isExpanded: isExpanded,
                key: f.name,
                statusIcon: f.status === "good" ? "✓" : f.status === "warning" ? "⚠" : "✗",
                statusColorClass: "status-icon status-" + f.status,
                barColorClass: "factor-bar-fill bar-" + f.status,
                barStyle: "width: " + f.score + "%",
                chevronClass: "chevron" + (isExpanded ? " chevron-expanded" : ""),
                detailClass: "factor-detail" + (isExpanded ? " factor-detail-expanded" : "")
            };
        });
    }

    get showBreakdown() {
        return this.result && this.result.factors && this.result.factors.length > 0;
    }

    // ─── Handlers ────────────────────────────────────────────────────────

    handleToggleFactor(event) {
        const name = event.currentTarget.dataset.name;
        this.expandedFactor = this.expandedFactor === name ? null : name;
    }
}

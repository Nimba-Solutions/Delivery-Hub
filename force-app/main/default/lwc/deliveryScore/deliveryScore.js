/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Delivery Score gauge — displays a 0-100 health rating for the delivery pipeline.
 *               Shows a circular SVG gauge with score/grade and an expandable factor breakdown.
 * @author Cloud Nimbus LLC
 */
import { LightningElement, api, wire, track } from "lwc";
import getDeliveryScore from "@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryScoreService.getDeliveryScore";

// SVG gauge constants
const GAUGE_SIZE = 160;
const STROKE_WIDTH = 10;
const RADIUS = (GAUGE_SIZE - STROKE_WIDTH) / 2;
const CIRCUMFERENCE = 2 * Math.PI * RADIUS;

export default class DeliveryScore extends LightningElement {
    @api entityId;

    @track result;
    @track expandedFactor = null;
    @track _animatedScore = 0;
    error;
    isLoading = true;

    // Animation state
    _animationFrame = null;
    _mounted = false;

    // ─── Wire ────────────────────────────────────────────────────────────

    @wire(getDeliveryScore, { entityId: "$entityId" })
    wiredScore({ data, error }) {
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
                statusIcon: f.status === "good" ? "\u2713" : f.status === "warning" ? "\u26A0" : "\u2717",
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

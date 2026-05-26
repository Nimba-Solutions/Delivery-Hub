/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Velocity-based burn-up SVG chart for a WorkItem__c tree. Wires
 *               DeliveryForecastService.calculateProjectForecast and renders cumulative
 *               actual hours, the scope line, and a velocity-extrapolated projection out
 *               to scope intersection. Mounts on the WorkItem__c record page (also exposed
 *               on AppPage / HomePage). Read-only forecasting view — no DML.
 * @author       Cloud Nimbus LLC
 */
import { LightningElement, api, wire, track } from "lwc";
import calculateProjectForecast from "@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryForecastService.calculateProjectForecast";

const SVG_WIDTH = 720;
const SVG_HEIGHT = 360;
const PADDING_TOP = 24;
const PADDING_RIGHT = 24;
const PADDING_BOTTOM = 56;
const PADDING_LEFT = 60;
const GRID_LINE_COUNT = 5;

export default class DeliveryProjectBurnUpChart extends LightningElement {
    @api recordId;
    @track forecast;
    @track errorMessage = "";
    isLoading = true;

    @wire(calculateProjectForecast, { workItemId: "$recordId" })
    wiredForecast({ data, error }) {
        this.isLoading = false;
        if (data) {
            this.forecast = data;
            this.errorMessage = "";
        } else if (error) {
            this.errorMessage = error.body ? error.body.message : error.message;
            this.forecast = null;
        }
    }

    // ── State flags ──────────────────────────────────────────────

    get hasError() {
        return !this.isLoading && this.errorMessage;
    }

    get isEmpty() {
        if (this.isLoading || this.errorMessage || !this.forecast) {
            return false;
        }
        return !this._history.length;
    }

    get hasData() {
        return !this.isLoading && !this.errorMessage && !this.isEmpty && this.forecast;
    }

    get hasProjection() {
        return this.forecast && this.forecast.hasVelocity && this.forecast.hasEstimate;
    }

    get isOverBudget() {
        return this.forecast && this.forecast.isOverBudgetTrajectory;
    }

    // ── Headline numbers ─────────────────────────────────────────

    get velocityDisplay() {
        if (!this.forecast || !this.forecast.hasVelocity) {
            return "—";
        }
        return `${this._formatHours(this.forecast.currentVelocityHoursPerWeek)}h/wk`;
    }

    get weeksRemainingDisplay() {
        if (!this.forecast || !this.forecast.hasVelocity) {
            return "—";
        }
        if (this.forecast.weeksRemaining === 0) {
            return "Done";
        }
        return `${this.forecast.weeksRemaining}`;
    }

    get projectedCompletionDisplay() {
        if (!this.forecast || !this.forecast.projectedCompletionDate) {
            return "—";
        }
        return this._formatDate(this.forecast.projectedCompletionDate);
    }

    get confidenceRangeDisplay() {
        if (!this.forecast || !this.forecast.confidenceLowDate || !this.forecast.confidenceHighDate) {
            return "";
        }
        return `${this._formatDate(this.forecast.confidenceLowDate)} – ${this._formatDate(this.forecast.confidenceHighDate)}`;
    }

    get projectedFinalDisplay() {
        if (!this.forecast) {
            return "—";
        }
        return `${this._formatHours(this.forecast.projectedFinalHours)}h`;
    }

    get scopeDisplay() {
        if (!this.forecast || !this.forecast.hasEstimate) {
            return "—";
        }
        return `${this._formatHours(this.forecast.totalEstimatedHours)}h`;
    }

    get overBudgetClass() {
        return this.isOverBudget
            ? "summary-value summary-value--alert"
            : "summary-value summary-value--ok";
    }

    get statusBannerClass() {
        return this.isOverBudget ? "status-banner status-banner--over" : "status-banner status-banner--under";
    }

    get statusBannerText() {
        if (!this.forecast || !this.forecast.hasVelocity) {
            return "No velocity data yet — log work to enable forecasting.";
        }
        if (!this.forecast.hasEstimate) {
            return "Set an estimated-hours total to enable scope projection.";
        }
        if (this.isOverBudget) {
            return `Trending ${this._formatHours(this.forecast.projectedFinalHours - this.forecast.totalEstimatedHours)}h past scope at current velocity.`;
        }
        return `On track to finish around ${this.projectedCompletionDisplay} at current velocity.`;
    }

    // ── SVG geometry ─────────────────────────────────────────────

    get svgViewBox() {
        return `0 0 ${SVG_WIDTH} ${SVG_HEIGHT}`;
    }

    get chartLeft() {
        return PADDING_LEFT;
    }

    get chartRight() {
        return SVG_WIDTH - PADDING_RIGHT;
    }

    get chartTop() {
        return PADDING_TOP;
    }

    get chartBottom() {
        return SVG_HEIGHT - PADDING_BOTTOM;
    }

    get yLabelX() {
        return PADDING_LEFT - 8;
    }

    get xLabelY() {
        return SVG_HEIGHT - PADDING_BOTTOM + 18;
    }

    get _chartWidth() {
        return this.chartRight - this.chartLeft;
    }

    get _chartHeight() {
        return this.chartBottom - this.chartTop;
    }

    get _history() {
        return (this.forecast && this.forecast.history) || [];
    }

    get _projection() {
        return (this.forecast && this.forecast.projection) || [];
    }

    get _allPoints() {
        return this._history.concat(this._projection);
    }

    get _scopeMax() {
        const points = this._allPoints;
        let max = 0;
        for (const p of points) {
            if (p.cumulativeHours > max) {
                max = p.cumulativeHours;
            }
            if (p.scopeHours > max) {
                max = p.scopeHours;
            }
        }
        if (this.forecast && this.forecast.totalEstimatedHours > max) {
            max = this.forecast.totalEstimatedHours;
        }
        return max > 0 ? max : 1;
    }

    get _niceMax() {
        const raw = this._scopeMax;
        const magnitude = Math.pow(10, Math.floor(Math.log10(raw || 1)));
        const normalized = raw / magnitude;
        let nice;
        if (normalized <= 1) {
            nice = 1;
        } else if (normalized <= 2) {
            nice = 2;
        } else if (normalized <= 5) {
            nice = 5;
        } else {
            nice = 10;
        }
        return nice * magnitude;
    }

    _xForIndex(idx) {
        const total = this._allPoints.length;
        if (total <= 1) {
            return this.chartLeft;
        }
        return this.chartLeft + (idx / (total - 1)) * this._chartWidth;
    }

    _yForValue(value) {
        const niceMax = this._niceMax;
        if (niceMax === 0) {
            return this.chartBottom;
        }
        return this.chartBottom - (value / niceMax) * this._chartHeight;
    }

    // ── Polylines ────────────────────────────────────────────────

    get actualLinePoints() {
        const history = this._history;
        if (!history.length) {
            return "";
        }
        return history
            .map((p, i) => `${this._xForIndex(i)},${this._yForValue(p.cumulativeHours)}`)
            .join(" ");
    }

    get projectionLinePoints() {
        const projection = this._projection;
        const history = this._history;
        if (!projection.length || !history.length) {
            return "";
        }
        // Anchor the projection at the last actual point so the dashed line starts there.
        const anchorIdx = history.length - 1;
        const anchorX = this._xForIndex(anchorIdx);
        const anchorY = this._yForValue(history[anchorIdx].cumulativeHours);
        const tail = projection
            .map((p, j) => `${this._xForIndex(history.length + j)},${this._yForValue(p.cumulativeHours)}`)
            .join(" ");
        return `${anchorX},${anchorY} ${tail}`;
    }

    get scopeLineY() {
        if (!this.forecast || !this.forecast.hasEstimate) {
            return null;
        }
        return this._yForValue(this.forecast.totalEstimatedHours);
    }

    get hasScopeLine() {
        return this.scopeLineY !== null && this.forecast && this.forecast.hasEstimate;
    }

    // ── Axes ─────────────────────────────────────────────────────

    get gridLines() {
        const lines = [];
        const niceMax = this._niceMax;
        for (let i = 0; i <= GRID_LINE_COUNT; i++) {
            const value = (niceMax / GRID_LINE_COUNT) * i;
            lines.push({
                key: `grid-${i}`,
                labelKey: `grid-label-${i}`,
                y: this._yForValue(value),
                label: this._formatHours(value)
            });
        }
        return lines;
    }

    get xLabels() {
        const all = this._allPoints;
        if (!all.length) {
            return [];
        }
        const step = all.length > 12 ? Math.ceil(all.length / 8) : 1;
        const labels = [];
        for (let i = 0; i < all.length; i += step) {
            labels.push({
                key: `x-${i}`,
                x: this._xForIndex(i),
                label: this._formatDate(all[i].weekStart)
            });
        }
        return labels;
    }

    get todayMarkerX() {
        const history = this._history;
        if (!history.length) {
            return null;
        }
        return this._xForIndex(history.length - 1);
    }

    get hasTodayMarker() {
        return this.todayMarkerX !== null;
    }

    // ── Helpers ──────────────────────────────────────────────────

    _formatHours(value) {
        if (value === null || value === undefined) {
            return "0";
        }
        const num = Number(value);
        if (!Number.isFinite(num)) {
            return "0";
        }
        if (Math.abs(num) >= 100) {
            return num.toFixed(0);
        }
        if (Math.abs(num) >= 10) {
            return num.toFixed(1);
        }
        return num.toFixed(2);
    }

    _formatDate(isoString) {
        if (!isoString) {
            return "";
        }
        const parts = String(isoString).split("-");
        if (parts.length < 3) {
            return String(isoString);
        }
        const monthIdx = parseInt(parts[1], 10) - 1;
        const day = parseInt(parts[2], 10);
        const monthNames = [
            "Jan", "Feb", "Mar", "Apr", "May", "Jun",
            "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
        ];
        return `${monthNames[monthIdx]} ${day}`;
    }
}

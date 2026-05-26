/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  SVG bar chart of monthly hours logged across a WorkItem__c tree, with a
 *               linear-amortized monthly target overlay when estimated hours + start/end
 *               dates are present. Wires DeliveryHoursAnalyticsController.getMonthlyHoursForProject.
 *               Default window is 12 months back; user-toggleable to 60-month "all time" view.
 *               Mounts on the WorkItem__c record page (also exposed on AppPage / HomePage).
 * @author       Cloud Nimbus LLC
 */
import { LightningElement, api, wire, track } from "lwc";
import getMonthlyHoursForProject from "@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryHoursAnalyticsController.getMonthlyHoursForProject";

const SVG_WIDTH = 720;
const SVG_HEIGHT = 320;
const PADDING_TOP = 24;
const PADDING_RIGHT = 24;
const PADDING_BOTTOM = 48;
const PADDING_LEFT = 56;
const GRID_LINE_COUNT = 5;
const BAR_GAP_RATIO = 0.35;
const DEFAULT_MONTHS_BACK = 12;
const ALL_TIME_MONTHS_BACK = 60;

export default class DeliveryProjectMonthlyHours extends LightningElement {
    @api recordId;
    @track summary;
    @track errorMessage = "";
    isLoading = true;
    showAllTime = false;

    @wire(getMonthlyHoursForProject, {
        workItemId: "$recordId",
        monthsBack: "$_monthsBack"
    })
    wiredHours({ data, error }) {
        this.isLoading = false;
        if (data) {
            this.summary = data;
            this.errorMessage = "";
        } else if (error) {
            this.errorMessage = error.body ? error.body.message : error.message;
            this.summary = null;
        }
    }

    get _monthsBack() {
        return this.showAllTime ? ALL_TIME_MONTHS_BACK : DEFAULT_MONTHS_BACK;
    }

    // ── State flags ──────────────────────────────────────────────

    get hasError() {
        return !this.isLoading && this.errorMessage;
    }

    get isEmpty() {
        if (this.isLoading || this.errorMessage || !this.summary) {
            return false;
        }
        const months = this.summary.months || [];
        return months.every((m) => !m.hoursLogged);
    }

    get hasData() {
        return !this.isLoading && !this.errorMessage && !this.isEmpty && this.summary;
    }

    get hasTarget() {
        return this.summary && this.summary.hasEstimate && this.summary.monthlyTarget > 0;
    }

    get toggleLabel() {
        return this.showAllTime ? "Last 12 months" : "All time";
    }

    // ── Summary headline numbers ─────────────────────────────────

    get totalEstimatedDisplay() {
        return this.summary ? this._formatHours(this.summary.totalEstimatedHours) : "0";
    }

    get totalLoggedDisplay() {
        return this.summary ? this._formatHours(this.summary.totalLoggedHours) : "0";
    }

    get monthlyTargetDisplay() {
        return this.summary ? this._formatHours(this.summary.monthlyTarget) : "0";
    }

    get descendantCountDisplay() {
        return this.summary ? this.summary.descendantCount : 0;
    }

    get isOverBudget() {
        if (!this.summary || !this.summary.hasEstimate) {
            return false;
        }
        return this.summary.totalLoggedHours > this.summary.totalEstimatedHours;
    }

    get variancePercent() {
        if (!this.summary || !this.summary.hasEstimate || !this.summary.totalEstimatedHours) {
            return "";
        }
        const delta = this.summary.totalLoggedHours - this.summary.totalEstimatedHours;
        const pct = (delta / this.summary.totalEstimatedHours) * 100;
        const sign = pct >= 0 ? "+" : "";
        return `${sign}${pct.toFixed(0)}%`;
    }

    get varianceClass() {
        return this.isOverBudget
            ? "summary-variance summary-variance--over"
            : "summary-variance summary-variance--under";
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

    get _months() {
        return (this.summary && this.summary.months) || [];
    }

    get _maxValue() {
        let max = 0;
        for (const row of this._months) {
            if (row.hoursLogged > max) {
                max = row.hoursLogged;
            }
        }
        if (this.hasTarget && this.summary.monthlyTarget > max) {
            max = this.summary.monthlyTarget;
        }
        return max > 0 ? max : 1;
    }

    get _niceMax() {
        const raw = this._maxValue;
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

    _yForValue(value) {
        const niceMax = this._niceMax;
        if (niceMax === 0) {
            return this.chartBottom;
        }
        return this.chartBottom - (value / niceMax) * this._chartHeight;
    }

    get _slotWidth() {
        const count = this._months.length;
        return count > 0 ? this._chartWidth / count : 0;
    }

    get _barWidth() {
        return this._slotWidth * (1 - BAR_GAP_RATIO);
    }

    get _barXOffset() {
        return (this._slotWidth - this._barWidth) / 2;
    }

    // ── Bars ─────────────────────────────────────────────────────

    get bars() {
        const months = this._months;
        const out = [];
        for (let i = 0; i < months.length; i++) {
            const row = months[i];
            const slotX = this.chartLeft + i * this._slotWidth;
            const x = slotX + this._barXOffset;
            const yTop = this._yForValue(row.hoursLogged);
            const height = this.chartBottom - yTop;
            out.push({
                key: `bar-${i}`,
                x,
                y: yTop,
                width: this._barWidth,
                height: height > 0 ? height : 0,
                cssClass: row.overTarget ? "bar bar--over" : "bar bar--under",
                tooltipKey: `tip-${i}`,
                tooltip: this._buildTooltip(row)
            });
        }
        return out;
    }

    _buildTooltip(row) {
        const parts = [`${row.monthLabel}: ${this._formatHours(row.hoursLogged)}h`];
        if (row.monthlyTarget > 0) {
            parts.push(`target ${this._formatHours(row.monthlyTarget)}h`);
            const variance = row.hoursLogged - row.monthlyTarget;
            const sign = variance >= 0 ? "+" : "";
            parts.push(`${sign}${this._formatHours(variance)}h`);
        }
        return parts.join(" · ");
    }

    // ── Target line ──────────────────────────────────────────────

    get targetLineY() {
        return this.hasTarget ? this._yForValue(this.summary.monthlyTarget) : 0;
    }

    // ── Grid + labels ────────────────────────────────────────────

    get gridLines() {
        const lines = [];
        const niceMax = this._niceMax;
        for (let i = 0; i <= GRID_LINE_COUNT; i++) {
            const value = (niceMax / GRID_LINE_COUNT) * i;
            const y = this._yForValue(value);
            lines.push({
                key: `grid-${i}`,
                labelKey: `grid-label-${i}`,
                y,
                label: this._formatHours(value)
            });
        }
        return lines;
    }

    get xLabels() {
        const months = this._months;
        if (months.length === 0) {
            return [];
        }
        const step = months.length > 12 ? Math.ceil(months.length / 12) : 1;
        const labels = [];
        for (let i = 0; i < months.length; i += step) {
            const slotX = this.chartLeft + i * this._slotWidth;
            labels.push({
                key: `x-${i}`,
                x: slotX + this._slotWidth / 2,
                label: months[i].monthLabel
            });
        }
        return labels;
    }

    // ── Handlers ─────────────────────────────────────────────────

    handleToggleRange() {
        this.showAllTime = !this.showAllTime;
        this.isLoading = true;
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
}

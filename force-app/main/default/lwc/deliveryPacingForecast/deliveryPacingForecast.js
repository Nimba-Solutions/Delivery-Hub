/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Salesforce-native Pacing & Forecast view — the parallel to the
 *               nimbus-gantt Pacing view (SAME model both render). Hours-first, fully
 *               interactive over a single server payload:
 *
 *               • ACTUALS (past): all logged hours per period (green bars; red when
 *                 over that period's amortized target).
 *               • FORECAST (future): each in-flight item's remaining estimate
 *                 (estimate − logged) spread across the forward periods its
 *                 EstimatedStart → EstimatedEnd span covers — the same dates the Gantt
 *                 drag-writes — rendered as light-blue bars. So the chart reads
 *                 actual → today → forecast.
 *               • Unscheduled remaining (un-dated work the forecast can't place) is
 *                 surfaced as an amber note.
 *
 *               Controls applied CLIENT-SIDE over the returned data (only the Range +
 *               Bucket re-wire Apex): Range (Next 3/6 · Rest of year · This Qtr · YTD ·
 *               All · Custom), Bucket (Week/Month/Quarter), Measure (Hours/$ when a
 *               blended rate is present), Mode (Per-period / Cumulative burn-up), and
 *               Series toggles (Actual / Forecast / Target).
 *
 *               Click a bar → a drill-down panel lists the in-flight items contributing
 *               that period (work item · this period · % of item · est · logged ·
 *               remaining · % used + a meta line). Click a work-item row → navigate to
 *               that WorkItem record (NavigationMixin standard__recordPage) — DH's
 *               native advantage over NG. Pure-SVG chart (no chart library). Wires
 *               DeliveryHoursAnalyticsController.getPortfolioPacing.
 * @author       Cloud Nimbus LLC
 */
import { LightningElement, track, wire } from "lwc";
import { NavigationMixin } from "lightning/navigation";
import WORK_ITEM_OBJECT from "@salesforce/schema/WorkItem__c";
import getPortfolioPacing from "@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryHoursAnalyticsController.getPortfolioPacing";

const SVG_WIDTH = 760;
const SVG_HEIGHT = 320;
const PADDING_TOP = 24;
const PADDING_RIGHT = 24;
const PADDING_BOTTOM = 48;
const PADDING_LEFT = 56;
const GRID_LINE_COUNT = 5;
const BAR_GAP_RATIO = 0.35;
const DEFAULT_PERIODS_BACK = 6;

// Range selector values.
const RANGE_NEXT3 = "next3";
const RANGE_NEXT6 = "next6";
const RANGE_REST_OF_YEAR = "rest-of-year";
const RANGE_THIS_QTR = "this-qtr";
const RANGE_YTD = "ytd";
const RANGE_ALL = "all";
const RANGE_CUSTOM = "custom";

export default class DeliveryPacingForecast extends NavigationMixin(
    LightningElement
) {
    @track pacing;
    @track errorMessage = "";
    isLoading = true;

    // Server-driving controls (re-wire Apex).
    granularity = "Month";
    range = RANGE_NEXT3;
    customStart = null;
    customEnd = null;

    // Client-only controls (no re-wire).
    measure = "hours";
    mode = "per-period";
    showActual = true;
    showForecast = true;
    showTarget = true;

    // Drill-down selection.
    @track selectedPeriodKey = null;

    @wire(getPortfolioPacing, {
        granularity: "$granularity",
        periodsBack: "$_periodsBack",
        periodsForward: "$_periodsForward"
    })
    wiredPacing({ data, error }) {
        this.isLoading = false;
        if (data) {
            this.pacing = data;
            this.errorMessage = "";
        } else if (error) {
            this.errorMessage = error.body ? error.body.message : error.message;
            this.pacing = null;
        }
    }

    // ── Wire inputs ──────────────────────────────────────────────

    get _periodsBack() {
        if (this.range === RANGE_YTD) {
            return this._periodsSinceYearStart();
        }
        if (this.range === RANGE_ALL) {
            return 24;
        }
        if (this.range === RANGE_CUSTOM) {
            return this._customPeriodsBack();
        }
        return DEFAULT_PERIODS_BACK;
    }

    get _periodsForward() {
        switch (this.range) {
            case RANGE_NEXT3:
                return 3;
            case RANGE_NEXT6:
                return 6;
            case RANGE_REST_OF_YEAR:
                return this._restOfYearPeriods();
            case RANGE_THIS_QTR:
                return this._restOfQuarterPeriods();
            case RANGE_YTD:
                return 0;
            case RANGE_ALL:
                return 12;
            case RANGE_CUSTOM:
                return this._customPeriodsForward();
            default:
                return 3;
        }
    }

    _periodsSinceYearStart() {
        const today = new Date();
        if (this.granularity === "Week") {
            const yearStart = new Date(today.getFullYear(), 0, 1);
            const msPerWeek = 7 * 24 * 60 * 60 * 1000;
            return Math.max(
                1,
                Math.ceil((today.getTime() - yearStart.getTime()) / msPerWeek) + 1
            );
        }
        if (this.granularity === "Quarter") {
            return Math.floor(today.getMonth() / 3) + 1;
        }
        return today.getMonth() + 1;
    }

    /**
     * Forward periods needed to reach the end of the current calendar year at the
     * selected granularity. Always at least 1 so the forecast band is visible.
     */
    _restOfYearPeriods() {
        const today = new Date();
        const year = today.getFullYear();
        if (this.granularity === "Week") {
            const yearEnd = new Date(year, 11, 31);
            const msPerWeek = 7 * 24 * 60 * 60 * 1000;
            const weeks = Math.ceil(
                (yearEnd.getTime() - today.getTime()) / msPerWeek
            );
            return Math.max(1, weeks);
        }
        if (this.granularity === "Quarter") {
            const currentQuarter = Math.floor(today.getMonth() / 3);
            return Math.max(1, 3 - currentQuarter);
        }
        return Math.max(1, 12 - today.getMonth());
    }

    _restOfQuarterPeriods() {
        const today = new Date();
        if (this.granularity === "Quarter") {
            return 1;
        }
        const monthInQuarter = today.getMonth() % 3;
        if (this.granularity === "Week") {
            return Math.max(1, (3 - monthInQuarter) * 4);
        }
        return Math.max(1, 3 - monthInQuarter);
    }

    _periodsBetween(startDate, endDate) {
        if (!startDate || !endDate) {
            return 0;
        }
        const s = new Date(startDate);
        const e = new Date(endDate);
        if (Number.isNaN(s.getTime()) || Number.isNaN(e.getTime()) || e < s) {
            return 0;
        }
        if (this.granularity === "Week") {
            const msPerWeek = 7 * 24 * 60 * 60 * 1000;
            return Math.max(1, Math.ceil((e.getTime() - s.getTime()) / msPerWeek) + 1);
        }
        if (this.granularity === "Quarter") {
            return (
                (e.getFullYear() - s.getFullYear()) * 4 +
                (Math.floor(e.getMonth() / 3) - Math.floor(s.getMonth() / 3)) +
                1
            );
        }
        return (
            (e.getFullYear() - s.getFullYear()) * 12 +
            (e.getMonth() - s.getMonth()) +
            1
        );
    }

    _customPeriodsBack() {
        if (!this.customStart) {
            return DEFAULT_PERIODS_BACK;
        }
        const today = new Date();
        const start = new Date(this.customStart);
        if (start >= today) {
            return 1;
        }
        return Math.max(1, this._periodsBetween(start, today));
    }

    _customPeriodsForward() {
        if (!this.customEnd) {
            return 3;
        }
        const today = new Date();
        const end = new Date(this.customEnd);
        if (end <= today) {
            return 0;
        }
        return Math.max(0, this._periodsBetween(today, end) - 1);
    }

    // ── Combobox / button-group options ──────────────────────────

    get granularityOptions() {
        return [
            { label: "Weekly", value: "Week" },
            { label: "Monthly", value: "Month" },
            { label: "Quarterly", value: "Quarter" }
        ];
    }

    get rangeOptions() {
        return [
            { label: "Next 3", value: RANGE_NEXT3 },
            { label: "Next 6", value: RANGE_NEXT6 },
            { label: "Rest of year", value: RANGE_REST_OF_YEAR },
            { label: "This quarter", value: RANGE_THIS_QTR },
            { label: "Year to date", value: RANGE_YTD },
            { label: "All", value: RANGE_ALL },
            { label: "Custom", value: RANGE_CUSTOM }
        ];
    }

    get measureOptions() {
        return [
            { label: "Hours", value: "hours" },
            { label: "Dollars", value: "dollars" }
        ];
    }

    get modeOptions() {
        return [
            { label: "Per period", value: "per-period" },
            { label: "Cumulative", value: "cumulative" }
        ];
    }

    get isCustomRange() {
        return this.range === RANGE_CUSTOM;
    }

    get isDollarMeasure() {
        return this.measure === "dollars" && this.hasRate;
    }

    // ── State flags ──────────────────────────────────────────────

    get hasError() {
        return !this.isLoading && this.errorMessage;
    }

    get summary() {
        return (this.pacing && this.pacing.summary) || null;
    }

    get isEmpty() {
        if (this.isLoading || this.errorMessage || !this.pacing) {
            return false;
        }
        const periods = this.pacing.periods || [];
        if (periods.length === 0) {
            return true;
        }
        const s = this.summary;
        const noActuals = periods.every((p) => !p.actualHours);
        const noForecast = periods.every((p) => !p.forecastHours);
        return noActuals && noForecast && !(s && s.estimatedHours);
    }

    get hasData() {
        return (
            !this.isLoading && !this.errorMessage && !this.isEmpty && this.pacing
        );
    }

    get hasTarget() {
        return this.summary && this.summary.hasEstimate;
    }

    get showTargetSeries() {
        return this.hasTarget && this.showTarget;
    }

    get hasRate() {
        return this.pacing && this.pacing.blendedRate > 0;
    }

    get scopeLabel() {
        return this.pacing ? this.pacing.scopeLabel : "";
    }

    // ── Headline summary cards ───────────────────────────────────

    get loggedDisplay() {
        return this.summary ? this._formatMeasure(this.summary.loggedHours) : "0";
    }

    get estimatedDisplay() {
        return this.summary
            ? this._formatMeasure(this.summary.estimatedHours)
            : "0";
    }

    get remainingDisplay() {
        return this.summary
            ? this._formatMeasure(this.summary.remainingHours)
            : "0";
    }

    get projectedFinalDisplay() {
        return this.summary
            ? this._formatMeasure(this.summary.projectedFinalHours)
            : "0";
    }

    get pacingPctDisplay() {
        if (!this.summary || !this.summary.pacingPct) {
            return "—";
        }
        return `${this.summary.pacingPct}%`;
    }

    get pacingPctClass() {
        const base = "summary-value";
        if (!this.summary) {
            return base;
        }
        return this.summary.isOverBudgetTrajectory
            ? `${base} summary-value--over`
            : base;
    }

    get activeItemsDisplay() {
        return this.summary ? this.summary.activeItems : 0;
    }

    get projectedFinalClass() {
        const base = "summary-value";
        if (this.summary && this.summary.isOverBudgetTrajectory) {
            return `${base} summary-value--over`;
        }
        return base;
    }

    // ── Unscheduled-remaining note ───────────────────────────────

    get hasUnscheduled() {
        return this.summary && this.summary.unscheduledRemainingHours > 0;
    }

    get unscheduledNote() {
        if (!this.hasUnscheduled) {
            return "";
        }
        const hours = this._formatHours(this.summary.unscheduledRemainingHours);
        return `${hours}h of remaining work can't be placed on the forecast — size and schedule these (set start/end dates on the Gantt) so the projection can place them.`;
    }

    get forecastCappedNote() {
        if (!this.summary || !this.summary.forecastCapped) {
            return "";
        }
        return "Showing the soonest-ending in-flight items only — the forecast set was capped. Projection may be partial.";
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

    get _periods() {
        return (this.pacing && this.pacing.periods) || [];
    }

    /**
     * The per-period plot value for the bar series, honoring Measure ($ vs hours) and
     * Mode (cumulative burn-up vs per-period). Cumulative accumulates the combined
     * actual+forecast spend so the line climbs toward projected final.
     */
    _plotValue(period, runningTotal) {
        const rate = this.isDollarMeasure ? this.pacing.blendedRate : 1;
        const raw = period.isForecast
            ? period.forecastHours || 0
            : period.actualHours || 0;
        if (this.mode === "cumulative") {
            return (runningTotal + raw) * rate;
        }
        return raw * rate;
    }

    _targetPlotValue(period, runningTarget) {
        const rate = this.isDollarMeasure ? this.pacing.blendedRate : 1;
        const raw = period.targetHours || 0;
        if (this.mode === "cumulative") {
            return (runningTarget + raw) * rate;
        }
        return raw * rate;
    }

    get _maxValue() {
        let max = 0;
        let running = 0;
        let runningTarget = 0;
        for (const p of this._periods) {
            const series = this._plotValue(p, running);
            const target = this._targetPlotValue(p, runningTarget);
            running += p.isForecast ? p.forecastHours || 0 : p.actualHours || 0;
            runningTarget += p.targetHours || 0;
            const candidate = Math.max(
                this.showActual || this.showForecast ? series : 0,
                this.showTargetSeries ? target : 0
            );
            if (candidate > max) {
                max = candidate;
            }
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
        const count = this._periods.length;
        return count > 0 ? this._chartWidth / count : 0;
    }

    get _barWidth() {
        return this._slotWidth * (1 - BAR_GAP_RATIO);
    }

    get _barXOffset() {
        return (this._slotWidth - this._barWidth) / 2;
    }

    // ── Bars (actual + forecast) ─────────────────────────────────

    get bars() {
        const periods = this._periods;
        const out = [];
        let running = 0;
        for (let i = 0; i < periods.length; i++) {
            const p = periods[i];
            const visible = p.isForecast ? this.showForecast : this.showActual;
            const value = this._plotValue(p, running);
            running += p.isForecast ? p.forecastHours || 0 : p.actualHours || 0;
            if (!visible) {
                continue;
            }
            const slotX = this.chartLeft + i * this._slotWidth;
            const x = slotX + this._barXOffset;
            const yTop = this._yForValue(value);
            const height = this.chartBottom - yTop;
            out.push({
                key: `bar-${i}`,
                periodKey: String(i),
                x,
                y: yTop,
                width: this._barWidth,
                height: height > 0 ? height : 0,
                cssClass: this._barClass(p, String(i)),
                tooltip: this._buildTooltip(p)
            });
        }
        return out;
    }

    _barClass(p, periodKey) {
        const selected =
            this.selectedPeriodKey === periodKey ? " bar--selected" : "";
        if (p.isForecast) {
            return `bar bar--forecast${selected}`;
        }
        if (p.overTarget) {
            return `bar bar--over${selected}`;
        }
        return `bar bar--actual${selected}`;
    }

    _buildTooltip(p) {
        const raw = p.isForecast ? p.forecastHours || 0 : p.actualHours || 0;
        const kind = p.isForecast ? "forecast" : "logged";
        const parts = [`${p.label}: ${this._formatHours(raw)}h ${kind}`];
        if (p.targetHours > 0) {
            parts.push(`target ${this._formatHours(p.targetHours)}h`);
        }
        if (this.hasRate) {
            parts.push(`${this._formatMoney(raw * this.pacing.blendedRate)}`);
        }
        return parts.join(" · ");
    }

    // ── Target line (per-period amortized estimate) ──────────────

    get targetPoints() {
        if (!this.showTargetSeries) {
            return "";
        }
        const periods = this._periods;
        const points = [];
        let running = 0;
        for (let i = 0; i < periods.length; i++) {
            const value = this._targetPlotValue(periods[i], running);
            running += periods[i].targetHours || 0;
            const x = this.chartLeft + i * this._slotWidth + this._slotWidth / 2;
            const y = this._yForValue(value);
            points.push(`${x.toFixed(1)},${y.toFixed(1)}`);
        }
        return points.join(" ");
    }

    // ── Current-period marker ────────────────────────────────────

    get currentMarkerX() {
        const periods = this._periods;
        for (let i = 0; i < periods.length; i++) {
            if (periods[i].isCurrent) {
                return this.chartLeft + i * this._slotWidth + this._slotWidth / 2;
            }
        }
        return 0;
    }

    get hasCurrentMarker() {
        return this.currentMarkerX > 0;
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
                label: this.isDollarMeasure
                    ? this._formatMoney(value)
                    : this._formatHours(value)
            });
        }
        return lines;
    }

    get xLabels() {
        const periods = this._periods;
        if (periods.length === 0) {
            return [];
        }
        const step = periods.length > 12 ? Math.ceil(periods.length / 12) : 1;
        const labels = [];
        for (let i = 0; i < periods.length; i += step) {
            const slotX = this.chartLeft + i * this._slotWidth;
            labels.push({
                key: `x-${i}`,
                x: slotX + this._slotWidth / 2,
                label: periods[i].label
            });
        }
        return labels;
    }

    // ── Drill-down panel ─────────────────────────────────────────

    get selectedPeriod() {
        if (this.selectedPeriodKey === null) {
            return null;
        }
        const idx = parseInt(this.selectedPeriodKey, 10);
        const periods = this._periods;
        return Number.isFinite(idx) && periods[idx] ? periods[idx] : null;
    }

    get hasDrillDown() {
        const p = this.selectedPeriod;
        return !!(p && p.items && p.items.length > 0);
    }

    get drillEmpty() {
        const p = this.selectedPeriod;
        return !!(p && (!p.items || p.items.length === 0));
    }

    get drillTitle() {
        const p = this.selectedPeriod;
        return p ? `${p.label} — in-flight work` : "";
    }

    get drillRows() {
        const p = this.selectedPeriod;
        if (!p || !p.items) {
            return [];
        }
        const rate = this.hasRate ? this.pacing.blendedRate : null;
        return p.items.map((it, i) => {
            const overBudget = it.budgetUsedPct > 100;
            const meta = [];
            if (it.priorityGroup) {
                meta.push(it.priorityGroup);
            }
            if (it.developerName) {
                meta.push(it.developerName);
            }
            if (it.stage) {
                meta.push(it.stage);
            }
            if (it.startDate && it.endDate) {
                meta.push(`${it.startDate} → ${it.endDate}`);
            }
            return {
                key: `${p.label}-row-${i}`,
                workItemId: it.workItemId,
                name: it.name,
                thisPeriod: this._formatHours(it.hoursThisPeriod),
                thisPeriodDollars: rate
                    ? this._formatMoney(it.hoursThisPeriod * rate)
                    : "",
                pctOfItem: `${it.pctOfItem}%`,
                estimated: this._formatHours(it.estimatedHours),
                logged: this._formatHours(it.loggedHours),
                remaining: this._formatHours(it.remainingHours),
                budgetUsedPct: `${it.budgetUsedPct}%`,
                budgetClass: overBudget
                    ? "drill-cell drill-cell--over"
                    : "drill-cell",
                metaLine: meta.join(" · ")
            };
        });
    }

    // ── Legend ───────────────────────────────────────────────────

    get measureWord() {
        return this.isDollarMeasure ? "$" : "hours";
    }

    // ── Handlers (server-driving) ────────────────────────────────

    handleGranularityChange(event) {
        this.granularity = event.detail.value;
        this.selectedPeriodKey = null;
        this.isLoading = true;
    }

    handleRangeChange(event) {
        this.range = event.detail.value;
        this.selectedPeriodKey = null;
        if (this.range !== RANGE_CUSTOM) {
            this.isLoading = true;
        }
    }

    handleCustomStartChange(event) {
        this.customStart = event.detail.value;
        if (this.customStart && this.customEnd) {
            this.isLoading = true;
        }
    }

    handleCustomEndChange(event) {
        this.customEnd = event.detail.value;
        if (this.customStart && this.customEnd) {
            this.isLoading = true;
        }
    }

    // ── Handlers (client-only) ───────────────────────────────────

    handleMeasureChange(event) {
        this.measure = event.detail.value;
    }

    handleModeChange(event) {
        this.mode = event.detail.value;
    }

    handleToggleActual() {
        this.showActual = !this.showActual;
    }

    handleToggleForecast() {
        this.showForecast = !this.showForecast;
    }

    handleToggleTarget() {
        this.showTarget = !this.showTarget;
    }

    get actualToggleClass() {
        return this.showActual
            ? "series-toggle series-toggle--on series-toggle--actual"
            : "series-toggle";
    }

    get forecastToggleClass() {
        return this.showForecast
            ? "series-toggle series-toggle--on series-toggle--forecast"
            : "series-toggle";
    }

    get targetToggleClass() {
        return this.showTarget
            ? "series-toggle series-toggle--on series-toggle--target"
            : "series-toggle";
    }

    // ── Drill-down handlers ──────────────────────────────────────

    handleBarClick(event) {
        const key = event.currentTarget.dataset.periodKey;
        this.selectedPeriodKey = this.selectedPeriodKey === key ? null : key;
    }

    handleCloseDrill() {
        this.selectedPeriodKey = null;
    }

    handleRowClick(event) {
        const recordId = event.currentTarget.dataset.recordId;
        if (!recordId) {
            return;
        }
        this[NavigationMixin.Navigate]({
            // eslint-disable-next-line new-cap
            type: "standard__recordPage",
            attributes: {
                recordId,
                objectApiName: WORK_ITEM_OBJECT.objectApiName,
                actionName: "view"
            }
        });
    }

    // ── Formatting helpers ───────────────────────────────────────

    _formatMeasure(hours) {
        if (this.isDollarMeasure) {
            return this._formatMoney((Number(hours) || 0) * this.pacing.blendedRate);
        }
        return `${this._formatHours(hours)}h`;
    }

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

    _formatMoney(value) {
        const num = Number(value);
        if (!Number.isFinite(num)) {
            return "";
        }
        return `$${num.toLocaleString(undefined, {
            minimumFractionDigits: 0,
            maximumFractionDigits: 0
        })}`;
    }
}

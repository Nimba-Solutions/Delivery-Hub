/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Portfolio Pacing & Forecast HomePage card. Renders an account/org-level
 *               pacing view across ALL active root WorkItems: actual logged hours (bars),
 *               an amortized target line, and a forward run-rate forecast (dashed bars).
 *               The user picks the bucket granularity (Week / Month / Quarter) and the
 *               forward horizon (3 / 6 / 12 periods or rest-of-year), which re-wires the
 *               Apex call. Pure-SVG chart (no chart library), mirroring
 *               deliveryProjectMonthlyHours. Hours are primary; $ shown when the org has a
 *               single resolvable blended rate. Wires
 *               DeliveryHoursAnalyticsController.getPortfolioPacing.
 * @author       Cloud Nimbus LLC
 */
import { LightningElement, track, wire } from "lwc";
import { CurrentPageReference } from "lightning/navigation";
import getPortfolioPacing from "@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryHoursAnalyticsController.getPortfolioPacing";
import getHiddenHomeComponents from "@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryHomeVisibilityController.getHiddenHomeComponents";

// This component's key in the Home-visibility map (matches its LWC folder name).
const HOME_COMPONENT_KEY = "deliveryPacingForecast";

const SVG_WIDTH = 760;
const SVG_HEIGHT = 320;
const PADDING_TOP = 24;
const PADDING_RIGHT = 24;
const PADDING_BOTTOM = 48;
const PADDING_LEFT = 56;
const GRID_LINE_COUNT = 5;
const BAR_GAP_RATIO = 0.35;
const DEFAULT_PERIODS_BACK = 6;
const REST_OF_YEAR = "rest-of-year";

export default class DeliveryPacingForecast extends LightningElement {
    @track pacing;
    @track errorMessage = "";
    isLoading = true;

    granularity = "Month";
    horizon = "3";

    // ── Home-page visibility (admin-toggleable, default = shown) ──
    @wire(CurrentPageReference) _homePageRef;
    @wire(getHiddenHomeComponents) _hiddenHomeComponents;

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

    // ── Home-page visibility getters ─────────────────────────────
    // The card hides ONLY on the app Home page when an admin has toggled it
    // off in Settings. Everywhere else it always renders.

    get isOnHomePage() {
        const ref = this._homePageRef;
        if (!ref) {
            return false;
        }
        const attrs = ref.attributes || {};
        if (ref.type === "standard__namedPage" && attrs.pageName === "home") {
            return true;
        }
        const url = attrs.url
            || (typeof window !== "undefined" && window.location ? window.location.pathname : "");
        return typeof url === "string" && url.indexOf("/lightning/page/home") !== -1;
    }

    get isHiddenOnHome() {
        if (!this.isOnHomePage) {
            return false;
        }
        const map = this._hiddenHomeComponents && this._hiddenHomeComponents.data;
        return !!(map && map[HOME_COMPONENT_KEY] === true);
    }

    get isNotHiddenOnHome() {
        return !this.isHiddenOnHome;
    }

    // ── Wire inputs ──────────────────────────────────────────────

    get _periodsBack() {
        return DEFAULT_PERIODS_BACK;
    }

    get _periodsForward() {
        if (this.horizon === REST_OF_YEAR) {
            return this._restOfYearPeriods();
        }
        const n = parseInt(this.horizon, 10);
        return Number.isFinite(n) ? n : 3;
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
            const weeks = Math.ceil((yearEnd.getTime() - today.getTime()) / msPerWeek);
            return Math.max(1, weeks);
        }
        if (this.granularity === "Quarter") {
            const currentQuarter = Math.floor(today.getMonth() / 3);
            return Math.max(1, 3 - currentQuarter);
        }
        return Math.max(1, 12 - today.getMonth());
    }

    // ── Combobox / button-group options ──────────────────────────

    get granularityOptions() {
        return [
            { label: "Weekly", value: "Week" },
            { label: "Monthly", value: "Month" },
            { label: "Quarterly", value: "Quarter" }
        ];
    }

    get horizonOptions() {
        return [
            { label: "Next 3", value: "3" },
            { label: "Next 6", value: "6" },
            { label: "Next 12", value: "12" },
            { label: "Rest of year", value: REST_OF_YEAR }
        ];
    }

    // ── State flags ──────────────────────────────────────────────

    get hasError() {
        return !this.isLoading && this.errorMessage;
    }

    get isEmpty() {
        if (this.isLoading || this.errorMessage || !this.pacing) {
            return false;
        }
        const periods = this.pacing.periods || [];
        if (periods.length === 0) {
            return true;
        }
        const noActuals = periods.every((p) => !p.loggedHours);
        const noForecast = periods.every((p) => !p.forecastHours);
        return noActuals && noForecast && !this.pacing.totalEstimatedHours;
    }

    get hasData() {
        return !this.isLoading && !this.errorMessage && !this.isEmpty && this.pacing;
    }

    get hasTarget() {
        return this.pacing && this.pacing.hasEstimate;
    }

    get hasRate() {
        return this.pacing && this.pacing.blendedRate > 0;
    }

    // ── Headline numbers ─────────────────────────────────────────

    get totalEstimatedDisplay() {
        return this.pacing ? this._formatHours(this.pacing.totalEstimatedHours) : "0";
    }

    get totalLoggedDisplay() {
        return this.pacing ? this._formatHours(this.pacing.totalLoggedHours) : "0";
    }

    get projectedFinalDisplay() {
        return this.pacing ? this._formatHours(this.pacing.projectedFinalHours) : "0";
    }

    get rootCountDisplay() {
        return this.pacing ? this.pacing.rootCount : 0;
    }

    get projectedFinalDollarDisplay() {
        if (!this.hasRate) {
            return "";
        }
        return this._formatMoney(this.pacing.projectedFinalHours * this.pacing.blendedRate);
    }

    get loggedDollarDisplay() {
        if (!this.hasRate) {
            return "";
        }
        return this._formatMoney(this.pacing.totalLoggedHours * this.pacing.blendedRate);
    }

    get pacingPercent() {
        if (!this.pacing || !this.pacing.hasEstimate || !this.pacing.totalEstimatedHours) {
            return "";
        }
        const pct = (this.pacing.projectedFinalHours / this.pacing.totalEstimatedHours) * 100;
        return `${pct.toFixed(0)}%`;
    }

    get isOverBudget() {
        return this.pacing && this.pacing.isOverBudgetTrajectory;
    }

    get pacingClass() {
        return this.isOverBudget
            ? "summary-variance summary-variance--over"
            : "summary-variance summary-variance--under";
    }

    get trajectoryLabel() {
        return this.isOverBudget ? "Over budget at current pace" : "On track at current pace";
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

    get _maxValue() {
        let max = 0;
        for (const p of this._periods) {
            const candidate = Math.max(p.loggedHours || 0, p.forecastHours || 0, p.targetHours || 0);
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
        for (let i = 0; i < periods.length; i++) {
            const p = periods[i];
            const value = p.isForecast ? p.forecastHours || 0 : p.loggedHours || 0;
            const slotX = this.chartLeft + i * this._slotWidth;
            const x = slotX + this._barXOffset;
            const yTop = this._yForValue(value);
            const height = this.chartBottom - yTop;
            out.push({
                key: `bar-${i}`,
                x,
                y: yTop,
                width: this._barWidth,
                height: height > 0 ? height : 0,
                cssClass: this._barClass(p),
                tooltip: this._buildTooltip(p)
            });
        }
        return out;
    }

    _barClass(p) {
        if (p.isForecast) {
            return "bar bar--forecast";
        }
        if (p.overTarget) {
            return "bar bar--over";
        }
        return "bar bar--under";
    }

    _buildTooltip(p) {
        const value = p.isForecast ? p.forecastHours || 0 : p.loggedHours || 0;
        const kind = p.isForecast ? "forecast" : "logged";
        const parts = [`${p.label}: ${this._formatHours(value)}h ${kind}`];
        if (p.targetHours > 0) {
            parts.push(`target ${this._formatHours(p.targetHours)}h`);
        }
        if (this.hasRate) {
            parts.push(`${this._formatMoney(value * this.pacing.blendedRate)}`);
        }
        return parts.join(" · ");
    }

    // ── Target line (per-period amortized estimate) ──────────────

    get targetPoints() {
        if (!this.hasTarget) {
            return "";
        }
        const periods = this._periods;
        const points = [];
        for (let i = 0; i < periods.length; i++) {
            const x = this.chartLeft + i * this._slotWidth + this._slotWidth / 2;
            const y = this._yForValue(periods[i].targetHours || 0);
            points.push(`${x.toFixed(1)},${y.toFixed(1)}`);
        }
        return points.join(" ");
    }

    // ── Forecast boundary marker ─────────────────────────────────

    get forecastBoundaryX() {
        const periods = this._periods;
        for (let i = 0; i < periods.length; i++) {
            if (periods[i].isForecast) {
                return this.chartLeft + i * this._slotWidth;
            }
        }
        return 0;
    }

    get hasForecastBoundary() {
        const x = this.forecastBoundaryX;
        return x > this.chartLeft;
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

    // ── Handlers ─────────────────────────────────────────────────

    handleGranularityChange(event) {
        this.granularity = event.detail.value;
        this.isLoading = true;
    }

    handleHorizonChange(event) {
        this.horizon = event.detail.value;
        this.isLoading = true;
    }

    // ── Formatting helpers ───────────────────────────────────────

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

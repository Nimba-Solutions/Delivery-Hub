import { LightningElement, wire } from 'lwc';
import getCycleTimeData from '@salesforce/apex/DeliveryCycleTimeController.getCycleTimeData';
import getCurrentStageAges from '@salesforce/apex/DeliveryCycleTimeController.getCurrentStageAges';

/** @description Maximum number of weeks to display in the cycle time chart */
const MAX_WEEKS = 12;
/** @description Chart layout constants */
const CHART_LEFT_PAD = 45;
const CHART_TOP_PAD = 25;
const CHART_HEIGHT = 180;
const BAR_GAP = 4;

/** @description Threshold constants for color coding (days) */
const AMBER_THRESHOLD = 5;
const RED_THRESHOLD = 10;

/** @description Color constants */
const COLOR_GREEN = '#4bca81';
const COLOR_AMBER = '#f2a33a';
const COLOR_RED = '#e25c5c';
const COLOR_CHART_BAR = '#1b96ff';

export default class DeliveryCycleTimeChart extends LightningElement {
    /** @type {Array} Weekly cycle time data from Apex */
    _cycleTimeRaw = [];
    /** @type {Array} Stage age data from Apex */
    _stageAgeRaw = [];
    /** @type {boolean} Loading state for cycle time wire */
    _cycleTimeLoading = true;
    /** @type {boolean} Loading state for stage age wire */
    _stageAgeLoading = true;

    /**
     * @description Wire adapter for weekly cycle time data.
     * @param {Object} result - Wire result with data and error properties.
     */
    @wire(getCycleTimeData, { workflowTypeName: 'Software_Delivery' })
    wiredCycleTime(result) {
        this._cycleTimeLoading = false;
        if (result.data) {
            this._cycleTimeRaw = result.data;
        } else if (result.error) {
            this._cycleTimeRaw = [];
        }
    }

    /**
     * @description Wire adapter for current stage age data.
     * @param {Object} result - Wire result with data and error properties.
     */
    @wire(getCurrentStageAges, { workflowTypeName: 'Software_Delivery' })
    wiredStageAges(result) {
        this._stageAgeLoading = false;
        if (result.data) {
            this._stageAgeRaw = result.data;
        } else if (result.error) {
            this._stageAgeRaw = [];
        }
    }

    // ── Computed: loading ───────────────────────────────────────────────────

    /** @returns {boolean} True while either wire call is still loading */
    get isLoading() {
        return this._cycleTimeLoading || this._stageAgeLoading;
    }

    // ── Computed: cycle time chart ──────────────────────────────────────────

    /** @returns {boolean} True if cycle time data exists */
    get hasCycleTimeData() {
        return this._cycleTimeRaw.length > 0;
    }

    /** @returns {boolean} True if no cycle time data and not loading */
    get noCycleTimeData() {
        return !this._cycleTimeLoading && this._cycleTimeRaw.length === 0;
    }

    /**
     * @description Returns the last MAX_WEEKS of cycle time data, trimmed.
     * @returns {Array} Trimmed weekly data
     */
    get _trimmedCycleData() {
        const data = this._cycleTimeRaw || [];
        return data.length > MAX_WEEKS ? data.slice(data.length - MAX_WEEKS) : data;
    }

    /** @returns {number} Width of the chart area based on bar count */
    get cycleTimeChartWidth() {
        const count = this._trimmedCycleData.length;
        return CHART_LEFT_PAD + count * 52;
    }

    /** @returns {string} SVG viewBox attribute for the cycle time chart */
    get cycleTimeViewBox() {
        return `0 0 ${this.cycleTimeChartWidth + 10} ${CHART_HEIGHT + 50}`;
    }

    /** @returns {number} Y coordinate of the chart baseline */
    get cycleTimeBaseline() {
        return CHART_HEIGHT;
    }

    /**
     * @description Builds bar descriptors for the SVG cycle time chart.
     * @returns {Array} Array of bar objects with positioning and labels
     */
    get cycleTimeBars() {
        const data = this._trimmedCycleData;
        if (data.length === 0) {
            return [];
        }

        const maxVal = this._computeMaxCycleValue(data);
        const barWidth = 40;
        const usableHeight = CHART_HEIGHT - CHART_TOP_PAD;

        return data.map((item, idx) => {
            const ratio = maxVal > 0 ? item.avgCycleDays / maxVal : 0;
            const barHeight = Math.max(ratio * usableHeight, 2);
            const x = CHART_LEFT_PAD + idx * (barWidth + BAR_GAP);
            const y = CHART_HEIGHT - barHeight;
            const labelX = x + barWidth / 2;

            return {
                key: `week-${idx}`,
                x,
                y,
                width: barWidth,
                height: barHeight,
                fill: COLOR_CHART_BAR,
                value: item.avgCycleDays,
                label: this._formatWeekLabel(item.weekLabel),
                labelX,
                labelY: y - 4,
                weekLabelY: CHART_HEIGHT + 16,
                weekLabelTransform: `rotate(-45 ${labelX} ${CHART_HEIGHT + 16})`
            };
        });
    }

    // ── Computed: stage age bars ─────────────────────────────────────────────

    /** @returns {boolean} True if stage age data exists */
    get hasStageData() {
        return this._stageAgeRaw.length > 0;
    }

    /** @returns {boolean} True if no stage data and not loading */
    get noStageData() {
        return !this._stageAgeLoading && this._stageAgeRaw.length === 0;
    }

    /**
     * @description Builds horizontal bar descriptors for the stage age chart.
     * @returns {Array} Array of stage bar objects with styling
     */
    get stageAgeBars() {
        const data = this._stageAgeRaw || [];
        if (data.length === 0) {
            return [];
        }

        const maxDays = this._computeMaxStageDays(data);

        return data.map((item, idx) => {
            const pct = maxDays > 0 ? (item.avgDays / maxDays) * 100 : 0;
            const color = this._getStageColor(item.avgDays);

            return {
                key: `stage-${idx}`,
                stageName: item.stageName,
                avgDays: item.avgDays,
                itemCount: item.itemCount,
                barClass: 'stage-bar',
                barStyle: `width: ${Math.max(pct, 2)}%; background-color: ${color};`
            };
        });
    }

    // ── Private helpers ─────────────────────────────────────────────────────

    /**
     * @description Computes the maximum avgCycleDays value from cycle data.
     * @param {Array} data - Array of weekly cycle time objects
     * @returns {number} Maximum value or 1 if all zeros
     */
    _computeMaxCycleValue(data) {
        let max = 0;
        for (const item of data) {
            if (item.avgCycleDays > max) {
                max = item.avgCycleDays;
            }
        }
        return max || 1;
    }

    /**
     * @description Computes the maximum avgDays value from stage data.
     * @param {Array} data - Array of stage age objects
     * @returns {number} Maximum value or 1 if all zeros
     */
    _computeMaxStageDays(data) {
        let max = 0;
        for (const item of data) {
            if (item.avgDays > max) {
                max = item.avgDays;
            }
        }
        return max || 1;
    }

    /**
     * @description Returns a color based on the number of days (green/amber/red).
     * @param {number} days - Number of days
     * @returns {string} Hex color code
     */
    _getStageColor(days) {
        if (days >= RED_THRESHOLD) {
            return COLOR_RED;
        }
        if (days >= AMBER_THRESHOLD) {
            return COLOR_AMBER;
        }
        return COLOR_GREEN;
    }

    /**
     * @description Formats an ISO week label (e.g. "2026-W09") to a shorter form ("W09").
     * @param {string} weekLabel - Full week label
     * @returns {string} Shortened week label
     */
    _formatWeekLabel(weekLabel) {
        if (!weekLabel) {
            return '';
        }
        const parts = weekLabel.split('-');
        return parts.length === 2 ? parts[1] : weekLabel;
    }
}

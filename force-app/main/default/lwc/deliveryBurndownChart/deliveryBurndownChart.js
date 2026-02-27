/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @author Cloud Nimbus LLC
 */
import { LightningElement, wire, track } from "lwc";
import getBurndownData from "@salesforce/apex/DeliveryBurndownController.getBurndownData";

// SVG layout constants
const SVG_WIDTH = 700;
const SVG_HEIGHT = 360;
const PADDING_TOP = 30;
const PADDING_RIGHT = 30;
const PADDING_BOTTOM = 50;
const PADDING_LEFT = 55;
const GRID_LINE_COUNT = 5;

export default class DeliveryBurndownChart extends LightningElement {
    @track rawData = [];
    @track errorMessage = "";
    isLoading = true;

    @wire(getBurndownData, { workflowTypeName: "Software_Delivery" })
    wiredBurndown({ data, error }) {
        this.isLoading = false;
        if (data) {
            this.rawData = data;
            this.errorMessage = "";
        } else if (error) {
            this.errorMessage = error.body
                ? error.body.message
                : error.message;
            this.rawData = [];
        }
    }

    // ── State flags ──────────────────────────────────────────────

    get hasError() {
        return !this.isLoading && this.errorMessage;
    }

    get isEmpty() {
        return !this.isLoading && !this.errorMessage && this._isAllZeroes;
    }

    get hasData() {
        return !this.isLoading && !this.errorMessage && !this._isAllZeroes;
    }

    get _isAllZeroes() {
        if (!this.rawData || this.rawData.length === 0) {
            return true;
        }
        return this.rawData.every(
            (r) =>
                r.totalCreated === 0 &&
                r.totalCompleted === 0 &&
                r.openCount === 0
        );
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
        return SVG_HEIGHT - PADDING_BOTTOM + 20;
    }

    get _chartWidth() {
        return this.chartRight - this.chartLeft;
    }

    get _chartHeight() {
        return this.chartBottom - this.chartTop;
    }

    // ── Scales ───────────────────────────────────────────────────

    get _maxValue() {
        if (!this.rawData || this.rawData.length === 0) {
            return 1;
        }
        let max = 0;
        for (const row of this.rawData) {
            if (row.totalCreated > max) {
                max = row.totalCreated;
            }
            if (row.totalCompleted > max) {
                max = row.totalCompleted;
            }
            if (row.openCount > max) {
                max = row.openCount;
            }
        }
        return max > 0 ? max : 1;
    }

    get _niceMax() {
        const raw = this._maxValue;
        // Round up to a nice number for the Y axis
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

    _xForIndex(index) {
        const count = this.rawData.length;
        if (count <= 1) {
            return this.chartLeft;
        }
        return (
            this.chartLeft + (index / (count - 1)) * this._chartWidth
        );
    }

    _yForValue(value) {
        const niceMax = this._niceMax;
        if (niceMax === 0) {
            return this.chartBottom;
        }
        return (
            this.chartBottom -
            (value / niceMax) * this._chartHeight
        );
    }

    // ── Grid lines (horizontal) ─────────────────────────────────

    get gridLines() {
        const lines = [];
        const niceMax = this._niceMax;
        for (let i = 0; i <= GRID_LINE_COUNT; i++) {
            const value = Math.round((niceMax / GRID_LINE_COUNT) * i);
            const y = this._yForValue(value);
            lines.push({
                key: `grid-${i}`,
                labelKey: `grid-label-${i}`,
                y,
                label: String(value)
            });
        }
        return lines;
    }

    // ── X axis labels ────────────────────────────────────────────

    get xLabels() {
        if (!this.rawData || this.rawData.length === 0) {
            return [];
        }
        const labels = [];
        // Show every other label to avoid crowding
        const step = this.rawData.length > 8 ? 2 : 1;
        for (let i = 0; i < this.rawData.length; i += step) {
            const dateStr = this.rawData[i].date;
            labels.push({
                key: `x-${i}`,
                x: this._xForIndex(i),
                label: this._formatDate(dateStr)
            });
        }
        return labels;
    }

    // ── Polyline points ──────────────────────────────────────────

    get openLinePoints() {
        return this._buildPolylinePoints("openCount");
    }

    get completedLinePoints() {
        return this._buildPolylinePoints("totalCompleted");
    }

    _buildPolylinePoints(field) {
        if (!this.rawData || this.rawData.length === 0) {
            return "";
        }
        return this.rawData
            .map((row, i) => {
                const x = this._xForIndex(i);
                const y = this._yForValue(row[field]);
                return `${x},${y}`;
            })
            .join(" ");
    }

    // ── Dot arrays ───────────────────────────────────────────────

    get openDots() {
        return this._buildDots("openCount", "open");
    }

    get completedDots() {
        return this._buildDots("totalCompleted", "completed");
    }

    _buildDots(field, prefix) {
        if (!this.rawData || this.rawData.length === 0) {
            return [];
        }
        return this.rawData.map((row, i) => ({
            key: `${prefix}-${i}`,
            x: this._xForIndex(i),
            y: this._yForValue(row[field])
        }));
    }

    // ── Helpers ──────────────────────────────────────────────────

    _formatDate(isoString) {
        if (!isoString) {
            return "";
        }
        const parts = isoString.split("-");
        const month = parseInt(parts[1], 10);
        const day = parseInt(parts[2], 10);
        const monthNames = [
            "Jan", "Feb", "Mar", "Apr", "May", "Jun",
            "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
        ];
        return `${monthNames[month - 1]} ${day}`;
    }
}

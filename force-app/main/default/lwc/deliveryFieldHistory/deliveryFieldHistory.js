/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Field History LWC. Displays a table of field change history
 *               records with optional SVG trend line chart for numeric metrics.
 *               Configurable via App Builder for field name, label, max records,
 *               and chart toggle.
 * @author Cloud Nimbus LLC
 */
import { LightningElement, api, wire } from 'lwc';
import getFieldChangeHistory from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryFieldChangeService.getFieldChangeHistory';
import getFieldChangeTrend from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryFieldChangeService.getFieldChangeTrend';

const COLUMNS = [
    { label: 'Date', fieldName: 'formattedDate', type: 'text', sortable: false, initialWidth: 160 },
    { label: 'Field', fieldName: 'fieldLabel', type: 'text', sortable: false, initialWidth: 120 },
    { label: 'Old Value', fieldName: 'oldValue', type: 'text', sortable: false },
    { label: 'New Value', fieldName: 'newValue', type: 'text', sortable: false },
    {
        label: 'Change',
        fieldName: 'delta',
        type: 'text',
        sortable: false,
        initialWidth: 90,
        cellAttributes: { class: { fieldName: 'deltaCssClass' } }
    },
    { label: 'Changed By', fieldName: 'userName', type: 'text', sortable: false, initialWidth: 130 },
    { label: 'Notes', fieldName: 'notes', type: 'text', sortable: false }
];

// Columns without the Field column (used when filtering by a specific field)
const COLUMNS_SINGLE_FIELD = COLUMNS.filter(c => c.fieldName !== 'fieldLabel');

// Chart dimensions
const CHART_WIDTH = 600;
const CHART_HEIGHT = 180;
const CHART_PADDING = { top: 20, right: 30, bottom: 40, left: 50 };

export default class DeliveryFieldHistory extends LightningElement {
    @api recordId;
    @api fieldName = '';
    @api metricLabel = 'Field History';
    @api maxRecords = 25;
    @api showChart = false;

    _wiredHistoryResult;
    _wiredTrendResult;
    _historyData = [];
    _trendData = [];
    historyError;
    trendError;

    // ── Wire: Field Change History ─────────────────────────────────────

    @wire(getFieldChangeHistory, {
        recordId: '$recordId',
        fieldName: '$fieldName',
        limitCount: '$maxRecords'
    })
    wiredHistory(result) {
        this._wiredHistoryResult = result;
        const { data, error } = result;
        if (data) {
            this._historyData = data;
            this.historyError = undefined;
        } else if (error) {
            this.historyError = error;
            this._historyData = [];
        }
    }

    // ── Wire: Trend Data (only fetched when showChart is true) ─────────

    @wire(getFieldChangeTrend, {
        recordId: '$recordId',
        fieldName: '$trendFieldName',
        limitCount: '$maxRecords'
    })
    wiredTrend(result) {
        this._wiredTrendResult = result;
        const { data, error } = result;
        if (data) {
            this._trendData = data;
            this.trendError = undefined;
        } else if (error) {
            this.trendError = error;
            this._trendData = [];
        }
    }

    /**
     * Reactive param for trend wire — returns the fieldName when showChart
     * is true, otherwise undefined to prevent the wire from firing.
     */
    get trendFieldName() {
        // Normalize boolean — App Builder may pass string "true"/"false"
        const chartEnabled = this.showChart === true || this.showChart === 'true';
        return chartEnabled ? this.fieldName : undefined;
    }

    // ── Loading / Empty / Error Getters ────────────────────────────────

    get isLoading() {
        return !this._wiredHistoryResult ||
            (!this._wiredHistoryResult.data && !this._wiredHistoryResult.error);
    }

    get hasEntries() {
        return this._historyData.length > 0;
    }

    get showEmpty() {
        return !this.isLoading && !this.hasEntries && !this.historyError;
    }

    get hasError() {
        return !!this.historyError;
    }

    // ── Table Data ─────────────────────────────────────────────────────

    get columns() {
        return this.fieldName ? COLUMNS_SINGLE_FIELD : COLUMNS;
    }

    get tableData() {
        return this._historyData.map(entry => {
            const ts = new Date(entry.timestamp);
            const deltaNum = entry.delta != null ? Number(entry.delta) : null;
            let deltaDisplay = '';
            let deltaCssClass = '';

            if (deltaNum != null && !isNaN(deltaNum)) {
                deltaDisplay = deltaNum > 0 ? '+' + deltaNum : String(deltaNum);
                deltaCssClass = deltaNum > 0
                    ? 'slds-text-color_success'
                    : deltaNum < 0
                        ? 'slds-text-color_error'
                        : '';
            } else if (entry.delta != null) {
                deltaDisplay = String(entry.delta);
            }

            return {
                id: entry.id,
                formattedDate: ts.toLocaleString(),
                fieldLabel: entry.fieldLabel || entry.fieldName || '',
                oldValue: entry.oldValue != null ? String(entry.oldValue) : '',
                newValue: entry.newValue != null ? String(entry.newValue) : '',
                delta: deltaDisplay,
                deltaCssClass,
                userName: entry.userName || 'System',
                notes: entry.notes || ''
            };
        });
    }

    get recordCount() {
        const count = this._historyData.length;
        return count + (count === 1 ? ' record' : ' records');
    }

    // ── Chart Data (SVG trend line) ────────────────────────────────────

    get hasTrendData() {
        const chartEnabled = this.showChart === true || this.showChart === 'true';
        return chartEnabled && this._trendData.length >= 2;
    }

    get chartViewBox() {
        return `0 0 ${CHART_WIDTH} ${CHART_HEIGHT}`;
    }

    get chartElements() {
        const data = this._trendData;
        if (!data || data.length < 2) return null;

        const plotLeft   = CHART_PADDING.left;
        const plotRight  = CHART_WIDTH - CHART_PADDING.right;
        const plotTop    = CHART_PADDING.top;
        const plotBottom = CHART_HEIGHT - CHART_PADDING.bottom;
        const plotWidth  = plotRight - plotLeft;
        const plotHeight = plotBottom - plotTop;

        // Extract numeric values
        const values = data.map(d => Number(d.value) || 0);
        const minVal = Math.min(...values);
        const maxVal = Math.max(...values);
        const range = maxVal - minVal || 1;

        // Scale functions
        const xScale = (i) => plotLeft + (i / (data.length - 1)) * plotWidth;
        const yScale = (v) => plotBottom - ((v - minVal) / range) * plotHeight;

        // Build polyline points
        const polylinePoints = data
            .map((d, i) => `${xScale(i)},${yScale(Number(d.value) || 0)}`)
            .join(' ');

        // Build dots
        const dots = data.map((d, i) => {
            const val = Number(d.value) || 0;
            return {
                key: 'dot-' + i,
                cx: xScale(i),
                cy: yScale(val),
                title: `${d.label || this.metricLabel}: ${val}`
            };
        });

        // Y-axis labels (min, mid, max)
        const midVal = (minVal + maxVal) / 2;
        const yLabels = [
            { key: 'y-max', x: plotLeft - 8, y: plotTop + 4, text: this._formatAxisValue(maxVal), anchor: 'end' },
            { key: 'y-mid', x: plotLeft - 8, y: plotTop + plotHeight / 2 + 4, text: this._formatAxisValue(midVal), anchor: 'end' },
            { key: 'y-min', x: plotLeft - 8, y: plotBottom + 4, text: this._formatAxisValue(minVal), anchor: 'end' }
        ];

        // Horizontal grid lines
        const gridLines = [
            { key: 'grid-max', x1: plotLeft, y1: plotTop, x2: plotRight, y2: plotTop },
            { key: 'grid-mid', x1: plotLeft, y1: plotTop + plotHeight / 2, x2: plotRight, y2: plotTop + plotHeight / 2 },
            { key: 'grid-min', x1: plotLeft, y1: plotBottom, x2: plotRight, y2: plotBottom }
        ];

        // X-axis date labels — show first, middle, last
        const xLabels = [];
        const labelIndices = [0, Math.floor(data.length / 2), data.length - 1];
        const uniqueIndices = [...new Set(labelIndices)];
        for (const i of uniqueIndices) {
            const ts = new Date(data[i].timestamp);
            xLabels.push({
                key: 'x-' + i,
                x: xScale(i),
                y: plotBottom + 16,
                text: (ts.getMonth() + 1) + '/' + ts.getDate()
            });
        }

        return {
            polylinePoints,
            dots,
            yLabels,
            gridLines,
            xLabels,
            axisLine: {
                x1: plotLeft,
                y1: plotBottom,
                x2: plotRight,
                y2: plotBottom
            }
        };
    }

    _formatAxisValue(val) {
        if (val == null) return '';
        if (Number.isInteger(val)) return String(val);
        return val.toFixed(1);
    }
}

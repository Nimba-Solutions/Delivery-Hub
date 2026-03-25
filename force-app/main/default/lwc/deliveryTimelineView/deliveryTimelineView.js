/* eslint-disable */
/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Horizontal Gantt-style timeline view of active work items.
 *               Grouped by NetworkEntity, color-coded by stage, with zoom
 *               (week/month/quarter) and scroll controls. Today marker shown
 *               as a prominent labeled vertical line. Unscheduled items (no
 *               explicit dates) shown in a separate section below the chart.
 * @author Cloud Nimbus LLC
 */
import { LightningElement, wire, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getTimelineData from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryTimelineController.getTimelineData';
import getWorkflowTypes from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryWorkflowConfigService.getWorkflowTypes';
import getWorkflowConfig from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryWorkflowConfigService.getWorkflowConfig';

const MS_PER_DAY = 86400000;
const ZOOM_WEEK = 'week';
const ZOOM_MONTH = 'month';
const ZOOM_QUARTER = 'quarter';
const DAY_WIDTHS = { week: 40, month: 16, quarter: 6 };
const ENTITY_LABEL_WIDTH = 180;
const BAR_HEIGHT = 28;
const ROW_GAP = 4;
const MONTH_NAMES = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

export default class DeliveryTimelineView extends NavigationMixin(LightningElement) {
    @track selectedWorkflowType = '';
    @track zoomLevel = ZOOM_MONTH;
    @track timelineRows = [];
    @track workflowTypes = [];
    @track stageColorMap = {};

    _timelineDataResult;

    @wire(getWorkflowTypes)
    wiredWorkflowTypes({ data }) {
        if (data) {
            this.workflowTypes = data;
            const defaultType = data.find((t) => t.isDefault);
            if (defaultType && !this.selectedWorkflowType) {
                this.selectedWorkflowType = defaultType.developerName;
            }
        }
    }

    @wire(getWorkflowConfig, { workflowTypeName: '$selectedWorkflowType' })
    wiredConfig(result) {
        if (result.data) {
            const colorMap = {};
            const stages = result.data.stages || [];
            stages.forEach((s) => {
                colorMap[s.apiValue] = s.cardColor || '#6B7280';
            });
            this.stageColorMap = colorMap;
        }
    }

    @wire(getTimelineData, { workflowTypeName: '$selectedWorkflowType' })
    wiredTimeline(result) {
        this._timelineDataResult = result;
        if (result.data) {
            this.timelineRows = result.data;
        }
    }

    get isLoading() {
        return !this._timelineDataResult || (!this._timelineDataResult.data && !this._timelineDataResult.error);
    }

    get isEmpty() {
        return !this.isLoading && (!this.timelineRows || this.timelineRows.length === 0);
    }

    // -- Card title with item count --

    get scheduledRows() {
        return (this.timelineRows || []).filter(r => r.hasExplicitDates !== false);
    }

    get _unscheduledRows() {
        return (this.timelineRows || []).filter(r => r.hasExplicitDates === false);
    }

    get totalItemCount() {
        return this.timelineRows ? this.timelineRows.length : 0;
    }

    get cardTitle() {
        const count = this.totalItemCount;
        if (count === 0) return 'Timeline';
        return 'Timeline (' + count + ' item' + (count === 1 ? '' : 's') + ')';
    }

    // -- Legend --

    get legendItems() {
        const usedStages = new Set();
        (this.timelineRows || []).forEach(r => {
            if (r.stage) usedStages.add(r.stage);
        });
        const items = [];
        usedStages.forEach(stage => {
            const color = this.stageColorMap[stage] || '#6B7280';
            items.push({
                stage,
                swatchStyle: 'background-color: ' + color + ';'
            });
        });
        items.sort((a, b) => a.stage.localeCompare(b.stage));
        return items;
    }

    get hasLegendItems() {
        return this.legendItems.length > 0;
    }

    // -- Unscheduled items --

    get unscheduledItems() {
        return this._unscheduledRows.map(row => {
            const color = this.stageColorMap[row.stage] || '#6B7280';
            return {
                workItemId: row.workItemId,
                name: row.name,
                description: row.description,
                stage: row.stage,
                swatchStyle: 'background-color: ' + color + ';',
                tooltipText: row.name + ': ' + (row.description || '') + '\nStage: ' + row.stage + '\nNo dates set'
            };
        });
    }

    get hasUnscheduledItems() {
        return this.unscheduledItems.length > 0;
    }

    get unscheduledCount() {
        return this.unscheduledItems.length;
    }

    // -- Workflow type options --

    get workflowTypeOptions() {
        const opts = [{ label: 'All Types', value: '' }];
        this.workflowTypes.forEach((t) => {
            opts.push({ label: t.label, value: t.developerName });
        });
        return opts;
    }

    get weekVariant() {
        return this.zoomLevel === ZOOM_WEEK ? 'brand' : 'neutral';
    }
    get monthVariant() {
        return this.zoomLevel === ZOOM_MONTH ? 'brand' : 'neutral';
    }
    get quarterVariant() {
        return this.zoomLevel === ZOOM_QUARTER ? 'brand' : 'neutral';
    }

    get timelineBounds() {
        const scheduled = this.scheduledRows;
        if (!scheduled || scheduled.length === 0) {
            const now = new Date();
            return { start: now, end: new Date(now.getTime() + 30 * MS_PER_DAY) };
        }
        let earliest = null;
        let latest = null;
        scheduled.forEach((row) => {
            const sd = this._parseDate(row.startDate);
            const ed = this._parseDate(row.endDate);
            if (!earliest || sd < earliest) {
                earliest = sd;
            }
            if (!latest || ed > latest) {
                latest = ed;
            }
        });
        const padStart = new Date(earliest.getTime() - 7 * MS_PER_DAY);
        const padEnd = new Date(latest.getTime() + 14 * MS_PER_DAY);
        return { start: padStart, end: padEnd };
    }

    get totalDays() {
        const bounds = this.timelineBounds;
        return Math.ceil((bounds.end - bounds.start) / MS_PER_DAY);
    }

    get dayWidth() {
        return DAY_WIDTHS[this.zoomLevel] || DAY_WIDTHS[ZOOM_MONTH];
    }

    get totalGridWidth() {
        return this.totalDays * this.dayWidth;
    }

    get gridTemplateStyle() {
        return 'grid-template-columns: ' + ENTITY_LABEL_WIDTH + 'px ' + this.totalGridWidth + 'px;';
    }

    get dateColumns() {
        const bounds = this.timelineBounds;
        const cols = [];
        const start = new Date(bounds.start);
        const dayW = this.dayWidth;

        if (this.zoomLevel === ZOOM_WEEK) {
            this._buildWeekColumns(cols, start, dayW);
        } else if (this.zoomLevel === ZOOM_MONTH) {
            this._buildMonthColumns(cols, start, bounds, dayW);
        } else {
            this._buildQuarterColumns(cols, start, bounds, dayW);
        }
        return cols;
    }

    get entityGroups() {
        const scheduled = this.scheduledRows;
        if (!scheduled || scheduled.length === 0) {
            return [];
        }

        const bounds = this.timelineBounds;
        const dayW = this.dayWidth;
        const grouped = {};
        const groupOrder = [];

        scheduled.forEach((row) => {
            const eName = row.entityName || 'Unassigned';
            if (!grouped[eName]) {
                grouped[eName] = { entityName: eName, entityId: row.entityId, items: [] };
                groupOrder.push(eName);
            }

            const sd = this._parseDate(row.startDate);
            const ed = this._parseDate(row.endDate);
            const startOffset = this._dayOffset(bounds.start, sd);
            const duration = Math.max(this._dayOffset(sd, ed), 1);
            const left = startOffset * dayW;
            const width = duration * dayW;
            const color = this.stageColorMap[row.stage] || '#6B7280';
            const itemIndex = grouped[eName].items.length;
            const top = itemIndex * (BAR_HEIGHT + ROW_GAP);

            grouped[eName].items.push({
                workItemId: row.workItemId,
                name: row.name,
                description: row.description,
                stage: row.stage,
                tooltipText: row.name + ': ' + (row.description || '') + '\nStage: ' + row.stage + '\n' + row.startDate + ' - ' + row.endDate,
                barStyle: 'left: ' + left + 'px; width: ' + width + 'px; top: ' + top + 'px; background-color: ' + color + '; height: ' + BAR_HEIGHT + 'px;'
            });
        });

        return groupOrder.map((eName, idx) => {
            const grp = grouped[eName];
            const rowCount = grp.items.length;
            const bodyHeight = rowCount * (BAR_HEIGHT + ROW_GAP) + ROW_GAP;
            return {
                entityKey: 'eh-' + idx,
                entityBodyKey: 'eb-' + idx,
                entityName: grp.entityName,
                items: grp.items,
                rowStyle: 'height: ' + bodyHeight + 'px;',
                bodyStyle: 'height: ' + bodyHeight + 'px;'
            };
        });
    }

    get todayLineInBodyStyle() {
        const bounds = this.timelineBounds;
        const today = new Date();
        const offset = this._dayOffset(bounds.start, today);
        const left = offset * this.dayWidth;
        return 'left: ' + left + 'px;';
    }

    handleWorkflowTypeChange(event) {
        this.selectedWorkflowType = event.detail.value;
    }

    handleZoomWeek() {
        this.zoomLevel = ZOOM_WEEK;
    }

    handleZoomMonth() {
        this.zoomLevel = ZOOM_MONTH;
    }

    handleZoomQuarter() {
        this.zoomLevel = ZOOM_QUARTER;
    }

    handleScrollLeft() {
        const container = this.refs.timelineContainer;
        if (container) {
            container.scrollLeft -= 200;
        }
    }

    handleScrollRight() {
        const container = this.refs.timelineContainer;
        if (container) {
            container.scrollLeft += 200;
        }
    }

    handleScrollToToday() {
        const container = this.refs.timelineContainer;
        if (container) {
            const bounds = this.timelineBounds;
            const today = new Date();
            const offset = this._dayOffset(bounds.start, today);
            const targetLeft = offset * this.dayWidth - container.clientWidth / 2;
            container.scrollLeft = Math.max(0, targetLeft);
        }
    }

    handleBarClick(event) {
        const recordId = event.currentTarget.dataset.id;
        if (recordId) {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: recordId,
                    objectApiName: 'WorkItem__c',
                    actionName: 'view'
                }
            });
        }
    }

    renderedCallback() {
        if (!this._hasScrolledToToday && this.timelineRows && this.timelineRows.length > 0) {
            this._hasScrolledToToday = true;
            Promise.resolve().then(() => {
                this.handleScrollToToday();
            });
        }
    }

    _buildWeekColumns(cols, start, dayW) {
        for (let i = 0; i < this.totalDays; i++) {
            const d = new Date(start.getTime() + i * MS_PER_DAY);
            const isToday = this._isSameDay(d, new Date());
            const isWeekend = d.getDay() === 0 || d.getDay() === 6;
            let cls = 'date-col';
            if (isToday) { cls += ' today-col'; }
            if (isWeekend) { cls += ' weekend-col'; }
            cols.push({
                key: 'd-' + i,
                label: (d.getMonth() + 1) + '/' + d.getDate(),
                cssClass: cls,
                style: 'width: ' + dayW + 'px; min-width: ' + dayW + 'px;'
            });
        }
    }

    _buildMonthColumns(cols, start, bounds, dayW) {
        let cursor = new Date(start);
        while (cursor.getDay() !== 1) {
            cursor = new Date(cursor.getTime() + MS_PER_DAY);
        }
        const prevEnd = this._dayOffset(start, cursor);
        if (prevEnd > 0) {
            cols.push({
                key: 'pre',
                label: '',
                cssClass: 'date-col',
                style: 'width: ' + (prevEnd * dayW) + 'px; min-width: ' + (prevEnd * dayW) + 'px;'
            });
        }
        while (cursor < bounds.end) {
            const weekEnd = new Date(cursor.getTime() + 7 * MS_PER_DAY);
            const displayEnd = weekEnd > bounds.end ? bounds.end : weekEnd;
            const span = this._dayOffset(cursor, displayEnd);
            const colWidth = span * dayW;
            cols.push({
                key: 'w-' + cursor.getTime(),
                label: (cursor.getMonth() + 1) + '/' + cursor.getDate(),
                cssClass: 'date-col',
                style: 'width: ' + colWidth + 'px; min-width: ' + colWidth + 'px;'
            });
            cursor = weekEnd;
        }
    }

    _buildQuarterColumns(cols, start, bounds, dayW) {
        let cursor = new Date(start.getFullYear(), start.getMonth(), 1);
        const daysBeforeFirstMonth = this._dayOffset(start, cursor);
        if (daysBeforeFirstMonth < 0) {
            const nextMonth = new Date(cursor.getFullYear(), cursor.getMonth() + 1, 1);
            const partialDays = this._dayOffset(start, nextMonth);
            const colWidth = partialDays * dayW;
            cols.push({
                key: 'm-' + cursor.getTime(),
                label: MONTH_NAMES[cursor.getMonth()] + ' ' + cursor.getFullYear(),
                cssClass: 'date-col month-col',
                style: 'width: ' + colWidth + 'px; min-width: ' + colWidth + 'px;'
            });
            cursor = nextMonth;
        }
        while (cursor < bounds.end) {
            const nextMonth = new Date(cursor.getFullYear(), cursor.getMonth() + 1, 1);
            const displayEnd = nextMonth > bounds.end ? bounds.end : nextMonth;
            const span = this._dayOffset(cursor, displayEnd);
            const colWidth = span * dayW;
            if (colWidth > 0) {
                cols.push({
                    key: 'm-' + cursor.getTime(),
                    label: MONTH_NAMES[cursor.getMonth()] + ' ' + cursor.getFullYear(),
                    cssClass: 'date-col month-col',
                    style: 'width: ' + colWidth + 'px; min-width: ' + colWidth + 'px;'
                });
            }
            cursor = nextMonth;
        }
    }

    _parseDate(dateStr) {
        if (!dateStr) {
            return new Date();
        }
        const parts = dateStr.split('-');
        return new Date(parseInt(parts[0], 10), parseInt(parts[1], 10) - 1, parseInt(parts[2], 10));
    }

    _dayOffset(from, to) {
        return Math.round((to.getTime() - from.getTime()) / MS_PER_DAY);
    }

    _isSameDay(d1, d2) {
        return d1.getFullYear() === d2.getFullYear()
            && d1.getMonth() === d2.getMonth()
            && d1.getDate() === d2.getDate();
    }
}

/* eslint-disable */
/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Horizontal Gantt-style timeline view of active work items.
 *               Grouped by NetworkEntity, color-coded by stage, with zoom
 *               (week/month/quarter) and scroll controls. Today marker shown
 *               as a prominent labeled vertical line. Unscheduled items (no
 *               explicit dates) shown in a separate section below the chart.
 *
 *               Enhanced features:
 *               - Quick-edit modal on click (Shift+click navigates to record)
 *               - Dependency arrows (SVG overlay)
 *               - Summary stats bar
 *               - Shared toolbar (deliveryGanttToolbar)
 *               - "My Work" filter
 *               - Drag-to-reschedule
 * @author Cloud Nimbus LLC
 */
import { LightningElement, wire, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import userId from '@salesforce/user/Id';
import getTimelineData from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryTimelineController.getTimelineData';
import getWorkflowTypes from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryWorkflowConfigService.getWorkflowTypes';
import getWorkflowConfig from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryWorkflowConfigService.getWorkflowConfig';
import getGanttDependencies from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryGanttController.getGanttDependencies';
import updateWorkItemDates from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryGanttController.updateWorkItemDates';

const MS_PER_DAY = 86400000;
const ZOOM_WEEK = 'Week';
const ZOOM_MONTH = 'Month';
const ZOOM_QUARTER = 'Quarter';
const DAY_WIDTHS = { Week: 40, Month: 16, Quarter: 6 };
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

    // Quick-edit modal state
    @track showQuickEdit = false;
    @track selectedWorkItemId = null;

    // Dependency arrows
    @track showDependencies = false;
    @track dependencies = [];

    // My Work filter
    @track myWorkOnly = false;

    // Drag state (not @track — internal only)
    _isDragging = false;
    _dragWorkItemId = null;
    _dragStartX = 0;
    _dragOriginalLeft = 0;
    _dragOriginalWidth = 0;
    _dragBarEl = null;
    _dragStartDate = null;
    _dragEndDate = null;

    _timelineDataResult;
    _depsResult;

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

    @wire(getGanttDependencies)
    wiredDeps(result) {
        this._depsResult = result;
        if (result.data) {
            this.dependencies = result.data;
        }
    }

    get isLoading() {
        return !this._timelineDataResult || (!this._timelineDataResult.data && !this._timelineDataResult.error);
    }

    get isEmpty() {
        return !this.isLoading && (!this.timelineRows || this.timelineRows.length === 0);
    }

    // -- Filtered rows (respects myWorkOnly) --

    get _filteredRows() {
        let rows = this.timelineRows || [];
        if (this.myWorkOnly && userId) {
            rows = rows.filter(r => r.developerId === userId);
        }
        return rows;
    }

    get scheduledRows() {
        return this._filteredRows.filter(r => r.hasExplicitDates !== false);
    }

    get _unscheduledRows() {
        return this._filteredRows.filter(r => r.hasExplicitDates === false);
    }

    get totalItemCount() {
        return this._filteredRows.length;
    }

    // -- Summary stats --

    get scheduledCount() {
        return this.scheduledRows.length;
    }

    get overdueCount() {
        const today = new Date();
        return this.scheduledRows.filter(r => {
            const ed = this._parseDate(r.endDate);
            return ed < today;
        }).length;
    }

    get onTrackCount() {
        return this.scheduledCount - this.overdueCount;
    }

    get unscheduledCount() {
        return this._unscheduledRows.length;
    }

    get hasStats() {
        return this.totalItemCount > 0;
    }

    // -- Toolbar props --

    get toolbarTitle() {
        const count = this.totalItemCount;
        if (count === 0) return 'Timeline';
        return 'Timeline (' + count + ' item' + (count === 1 ? '' : 's') + ')';
    }

    get toolbarSubtitle() {
        if (this.myWorkOnly) return 'Showing my work only';
        return '';
    }

    get workflowTypeOptions() {
        const opts = [{ label: 'All Types', value: '' }];
        this.workflowTypes.forEach((t) => {
            opts.push({ label: t.label, value: t.developerName });
        });
        return opts;
    }

    // -- Legend --

    get legendItems() {
        const usedStages = new Set();
        this._filteredRows.forEach(r => {
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

    // -- Timeline geometry --

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
                startDate: row.startDate,
                endDate: row.endDate,
                tooltipText: row.name + ': ' + (row.description || '') + '\nStage: ' + row.stage + '\n' + row.startDate + ' - ' + row.endDate,
                barStyle: 'left: ' + left + 'px; width: ' + width + 'px; top: ' + top + 'px; background-color: ' + color + '; height: ' + BAR_HEIGHT + 'px;',
                left,
                top,
                width
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

    // -- Dependency arrow SVG data --

    get svgViewBox() {
        // SVG covers the full timeline body area
        const groups = this.entityGroups;
        let totalHeight = 0;
        groups.forEach(g => {
            totalHeight += g.items.length * (BAR_HEIGHT + ROW_GAP) + ROW_GAP;
        });
        return '0 0 ' + this.totalGridWidth + ' ' + Math.max(totalHeight, 100);
    }

    get svgWidth() {
        return this.totalGridWidth;
    }

    get svgHeight() {
        const groups = this.entityGroups;
        let totalHeight = 0;
        groups.forEach(g => {
            totalHeight += g.items.length * (BAR_HEIGHT + ROW_GAP) + ROW_GAP;
        });
        return Math.max(totalHeight, 100);
    }

    get dependencyArrows() {
        if (!this.showDependencies || !this.dependencies || this.dependencies.length === 0) {
            return [];
        }

        // Build a map of workItemId -> { left, top, width } from all entity groups
        const barMap = {};
        let cumulativeTop = 0;
        this.entityGroups.forEach(group => {
            group.items.forEach(item => {
                barMap[item.workItemId] = {
                    left: item.left,
                    top: item.top + cumulativeTop,
                    width: item.width
                };
            });
            cumulativeTop += group.items.length * (BAR_HEIGHT + ROW_GAP) + ROW_GAP;
        });

        const arrows = [];
        this.dependencies.forEach(dep => {
            const src = barMap[dep.source];
            const tgt = barMap[dep.target];
            if (!src || !tgt) return; // both must be visible

            // From right edge of source to left edge of target
            const x1 = src.left + src.width;
            const y1 = src.top + BAR_HEIGHT / 2;
            const x2 = tgt.left;
            const y2 = tgt.top + BAR_HEIGHT / 2;

            // Bezier control points for a nice curved arrow
            const midX = (x1 + x2) / 2;
            const path = 'M ' + x1 + ' ' + y1
                + ' C ' + midX + ' ' + y1 + ', ' + midX + ' ' + y2 + ', ' + x2 + ' ' + y2;

            // Arrowhead: small triangle at the target end
            const arrowSize = 6;
            const arrowHead = 'M ' + x2 + ' ' + y2
                + ' L ' + (x2 - arrowSize) + ' ' + (y2 - arrowSize / 2)
                + ' L ' + (x2 - arrowSize) + ' ' + (y2 + arrowSize / 2)
                + ' Z';

            arrows.push({
                key: dep.id,
                pathD: path,
                arrowD: arrowHead
            });
        });

        return arrows;
    }

    get hasDependencyArrows() {
        return this.dependencyArrows.length > 0;
    }

    // -- Toolbar event handlers --

    handleZoomChange(event) {
        this.zoomLevel = event.detail.value;
    }

    handleEntityChange(event) {
        this.selectedWorkflowType = event.detail.value;
    }

    handleToggleDependencies() {
        this.showDependencies = !this.showDependencies;
    }

    handleToggleMyWork() {
        this.myWorkOnly = !this.myWorkOnly;
    }

    handleScrollToday() {
        this.handleScrollToToday();
    }

    handleRefresh() {
        refreshApex(this._timelineDataResult);
        refreshApex(this._depsResult);
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

    // -- Bar click → quick-edit modal (Shift+click → navigate) --

    handleBarClick(event) {
        // Don't open modal/navigate if we just finished dragging
        if (this._justDragged) {
            this._justDragged = false;
            return;
        }

        const recordId = event.currentTarget.dataset.id;
        if (!recordId) return;

        if (event.shiftKey) {
            // Power user: Shift+click navigates to the record page
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: recordId,
                    objectApiName: 'WorkItem__c',
                    actionName: 'view'
                }
            });
        } else {
            // Normal click: open quick-edit modal
            this.selectedWorkItemId = recordId;
            this.showQuickEdit = true;
        }
    }

    handleQuickEditSave() {
        this.showQuickEdit = false;
        this.selectedWorkItemId = null;
        refreshApex(this._timelineDataResult);
    }

    handleQuickEditClose() {
        this.showQuickEdit = false;
        this.selectedWorkItemId = null;
    }

    // -- Drag-to-reschedule --

    handleBarMouseDown(event) {
        // Only left-click initiates drag
        if (event.button !== 0) return;
        // Don't start drag if shift is held (that's for navigation)
        if (event.shiftKey) return;

        const barEl = event.currentTarget;
        const workItemId = barEl.dataset.id;
        const startDate = barEl.dataset.startdate;
        const endDate = barEl.dataset.enddate;
        if (!workItemId) return;

        this._isDragging = false; // becomes true after threshold
        this._dragWorkItemId = workItemId;
        this._dragStartX = event.clientX;
        this._dragOriginalLeft = parseInt(barEl.style.left, 10) || 0;
        this._dragOriginalWidth = parseInt(barEl.style.width, 10) || 0;
        this._dragBarEl = barEl;
        this._dragStartDate = startDate;
        this._dragEndDate = endDate;
        this._dragThresholdMet = false;

        // Attach global listeners (cleaned up on mouseup)
        this._boundMouseMove = this._handleDragMove.bind(this);
        this._boundMouseUp = this._handleDragEnd.bind(this);
        window.addEventListener('mousemove', this._boundMouseMove);
        window.addEventListener('mouseup', this._boundMouseUp);
    }

    _handleDragMove(event) {
        const deltaX = event.clientX - this._dragStartX;

        // Require at least 5px of movement to start drag (avoids accidental drag on click)
        if (!this._dragThresholdMet) {
            if (Math.abs(deltaX) < 5) return;
            this._dragThresholdMet = true;
            this._isDragging = true;
            if (this._dragBarEl) {
                this._dragBarEl.classList.add('dragging');
            }
        }

        if (this._dragBarEl) {
            const newLeft = this._dragOriginalLeft + deltaX;
            this._dragBarEl.style.left = newLeft + 'px';
        }
    }

    _handleDragEnd(event) {
        // Clean up global listeners immediately
        window.removeEventListener('mousemove', this._boundMouseMove);
        window.removeEventListener('mouseup', this._boundMouseUp);

        if (this._dragBarEl) {
            this._dragBarEl.classList.remove('dragging');
        }

        if (!this._isDragging || !this._dragThresholdMet) {
            // No meaningful drag happened — let click handler fire
            this._isDragging = false;
            this._dragBarEl = null;
            return;
        }

        // Prevent the click handler from firing after drag
        this._justDragged = true;

        const deltaX = event.clientX - this._dragStartX;
        const deltaDays = Math.round(deltaX / this.dayWidth);

        if (deltaDays === 0) {
            // No day change — reset position
            if (this._dragBarEl) {
                this._dragBarEl.style.left = this._dragOriginalLeft + 'px';
            }
            this._isDragging = false;
            this._dragBarEl = null;
            return;
        }

        // Calculate new dates
        const origStart = this._parseDate(this._dragStartDate);
        const origEnd = this._parseDate(this._dragEndDate);
        const newStart = new Date(origStart.getTime() + deltaDays * MS_PER_DAY);
        const newEnd = new Date(origEnd.getTime() + deltaDays * MS_PER_DAY);

        const newStartStr = this._formatDate(newStart);
        const newEndStr = this._formatDate(newEnd);

        this._isDragging = false;
        this._dragBarEl = null;

        // Persist dates
        updateWorkItemDates({
            workItemId: this._dragWorkItemId,
            startDate: newStartStr,
            endDate: newEndStr
        })
            .then(() => {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Rescheduled',
                    message: 'Moved to ' + newStartStr + ' \u2013 ' + newEndStr,
                    variant: 'success'
                }));
                return refreshApex(this._timelineDataResult);
            })
            .catch(err => {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Error',
                    message: err.body ? err.body.message : 'Could not update dates',
                    variant: 'error'
                }));
                // Refresh to reset bar to original position
                return refreshApex(this._timelineDataResult);
            });
    }

    // -- Lifecycle --

    renderedCallback() {
        if (!this._hasScrolledToToday && this.timelineRows && this.timelineRows.length > 0) {
            this._hasScrolledToToday = true;
            Promise.resolve().then(() => {
                this.handleScrollToToday();
            });
        }
    }

    // -- Date column builders --

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

    // -- Utility --

    _parseDate(dateStr) {
        if (!dateStr) {
            return new Date();
        }
        const parts = dateStr.split('-');
        return new Date(parseInt(parts[0], 10), parseInt(parts[1], 10) - 1, parseInt(parts[2], 10));
    }

    _formatDate(d) {
        const yyyy = d.getFullYear();
        const mm = String(d.getMonth() + 1).padStart(2, '0');
        const dd = String(d.getDate()).padStart(2, '0');
        return yyyy + '-' + mm + '-' + dd;
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

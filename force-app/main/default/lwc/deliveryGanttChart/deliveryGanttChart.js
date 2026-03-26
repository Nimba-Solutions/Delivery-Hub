/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @author Cloud Nimbus LLC
 */
import { LightningElement, wire, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import USER_ID from '@salesforce/user/Id';
import getWorkItemsForGantt from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryGanttController.getWorkItemsForGantt';
import getGanttDependencies from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryGanttController.getGanttDependencies';
import updateWorkItemDates from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryGanttController.updateWorkItemDates';
import getWorkflowConfig from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryWorkflowConfigService.getWorkflowConfig';

const MS_PER_DAY = 86400000;

export default class DeliveryGanttChart extends NavigationMixin(LightningElement) {
    @track windowDays = 60;
    @track isLoading = true;
    @track errorMessage = '';
    @track rawRows = [];
    @track workflowConfig = null;

    // Dependencies
    @track rawDependencies = [];
    @track showDependencies = false;

    // Quick-edit modal
    @track showQuickEdit = false;
    @track selectedWorkItemId = null;

    // My work / assigned items filter
    @track myWorkOnly = false;

    // Wire result refs for refreshApex
    _wiredGanttResult;
    _wiredDepsResult;

    // Current user
    currentUserId = USER_ID;

    // ── Wires ─────────────────────────────────────────────────────────────────

    @wire(getWorkItemsForGantt)
    wiredWorkItems(result) {
        this._wiredGanttResult = result;
        this.isLoading = false;
        if (result.data) {
            this.rawRows = result.data;
        } else if (result.error) {
            this.errorMessage = result.error.body ? result.error.body.message : result.error.message;
        }
    }

    @wire(getGanttDependencies)
    wiredDependencies(result) {
        this._wiredDepsResult = result;
        if (result.data) {
            this.rawDependencies = result.data;
        } else if (result.error) {
            console.error('[DeliveryGanttChart] getGanttDependencies error:', result.error);
        }
    }

    // Static workflowTypeName: Gantt is Software_Delivery only for now
    @wire(getWorkflowConfig, { workflowTypeName: 'Software_Delivery' })
    wiredConfig({ data, error }) {
        if (data) { this.workflowConfig = data; }
        else if (error) { console.error('[DeliveryGanttChart] getWorkflowConfig error:', error); }
    }

    // CMT-driven stage -> card color lookup
    get _stageColorMap() {
        if (!this.workflowConfig?.stages) return {};
        const map = {};
        this.workflowConfig.stages.forEach(s => { map[s.apiValue] = s.cardColor; });
        return map;
    }

    // ── Toolbar props ──────────────────────────────────────────────────────────

    get toolbarTitle() { return 'Delivery Timeline'; }

    get toolbarSubtitle() {
        const start = new Date();
        start.setHours(0, 0, 0, 0);
        const end = new Date(start.getTime() + this.windowDays * MS_PER_DAY);
        const count = this.filteredRows.length;
        const suffix = count === 1 ? 'item' : 'items';
        return `${count} work ${suffix} \u2022 ${this.fmtDate(start)} \u2013 ${this.fmtDate(end)}`;
    }

    get toolbarZoomLevels() { return '30d,60d,90d'; }
    get toolbarCurrentZoom() { return `${this.windowDays}d`; }

    // ── Toolbar event handlers ─────────────────────────────────────────────────

    handleZoomChange(event) {
        const value = event.detail.value;
        const days = parseInt(value, 10);
        if (!isNaN(days)) {
            this.windowDays = days;
        }
    }

    handleToggleDependencies() {
        this.showDependencies = !this.showDependencies;
    }

    handleToggleMyWork() {
        this.myWorkOnly = !this.myWorkOnly;
    }

    handleScrollToday() {
        // Scroll the chart body to ensure the today line is visible
        const body = this.template.querySelector('.gantt-body');
        if (body) {
            body.scrollLeft = 0;
        }
    }

    handleRefresh() {
        this.isLoading = true;
        Promise.all([
            refreshApex(this._wiredGanttResult),
            refreshApex(this._wiredDepsResult)
        ]).then(() => {
            this.isLoading = false;
        });
    }

    // ── Filtered rows ──────────────────────────────────────────────────────────

    get filteredRows() {
        let rows = [...this.rawRows];

        // "Assigned Items" filter — show only items with a developer assigned
        if (this.myWorkOnly) {
            rows = rows.filter(r => r.developerId != null);
        }

        return rows;
    }

    // ── Dependency lookup ──────────────────────────────────────────────────────

    get _dependencyMap() {
        if (!this.showDependencies || !this.rawDependencies.length) return {};
        // Build map: targetWorkItemId -> [sourceWorkItemId, ...]
        const map = {};
        this.rawDependencies.forEach(dep => {
            if (!map[dep.target]) {
                map[dep.target] = [];
            }
            map[dep.target].push(dep.source);
        });
        return map;
    }

    // ── Computed chart data ───────────────────────────────────────────────────

    get ganttRows() {
        const today = new Date();
        today.setHours(0, 0, 0, 0);
        const windowEnd = new Date(today.getTime() + this.windowDays * MS_PER_DAY);
        const depMap = this._dependencyMap;
        const rows = this.filteredRows;

        // Build tree hierarchy: group children under parents
        const rowIdSet = new Set(rows.map(r => r.workItemId));
        const topLevel = [];
        const childMap = {};
        rows.forEach(r => {
            if (r.parentWorkItemId && rowIdSet.has(r.parentWorkItemId)) {
                if (!childMap[r.parentWorkItemId]) childMap[r.parentWorkItemId] = [];
                childMap[r.parentWorkItemId].push(r);
            } else {
                topLevel.push(r);
            }
        });

        // Flatten: parent then children with indent
        const orderedRows = [];
        topLevel.forEach(r => {
            orderedRows.push({ row: r, indent: 0 });
            if (childMap[r.workItemId]) {
                childMap[r.workItemId].forEach(child => {
                    orderedRows.push({ row: child, indent: 1 });
                });
            }
        });

        return orderedRows.map(({ row: r, indent }) => {
            const uatMs   = new Date(r.uatDate).getTime();
            const startMs = new Date(r.createdDate).getTime();
            const winMs   = this.windowDays * MS_PER_DAY;
            const todayMs = today.getTime();

            // Clamp bar to [today - windowDays/2, today + windowDays] range
            const windowStartMs = todayMs - Math.round(winMs * 0.2); // 20% before today

            const left = Math.max(0, Math.min(100, ((startMs - windowStartMs) / (winMs * 1.2)) * 100));
            const right = Math.max(0, Math.min(100, ((uatMs  - windowStartMs) / (winMs * 1.2)) * 100));
            const width = Math.max(0.5, right - left); // minimum sliver

            const daysToUat = (uatMs - todayMs) / MS_PER_DAY;
            let barClass = 'gantt-bar';
            if (uatMs < todayMs) {
                barClass += ' gantt-bar--overdue';
            } else if (daysToUat < 7) {
                barClass += ' gantt-bar--warning';
            } else if (startMs > windowEnd.getTime()) {
                barClass += ' gantt-bar--future';
            }

            const stageColor = this._stageColorMap[r.stage] || 'var(--gantt-gray)';
            const barStyle = `left:${left.toFixed(1)}%; width:${width.toFixed(1)}%; background:${stageColor};`;

            let stageBadgeClass = 'gantt-stage-badge';
            if (uatMs < todayMs) { stageBadgeClass += ' badge--overdue'; }

            const desc = r.description || '';
            const descShort = desc.length > 45 ? desc.substring(0, 45) + '\u2026' : desc;
            const daysToUatRounded = Math.round(daysToUat);
            const daysStr = daysToUat >= 0
                ? `${daysToUatRounded} day${daysToUatRounded === 1 ? '' : 's'} remaining`
                : `${Math.abs(daysToUatRounded)} day${Math.abs(daysToUatRounded) === 1 ? '' : 's'} overdue`;
            const barTooltip = [
                desc || r.name,
                `Stage: ${r.stage}${r.priority ? ' | Priority: ' + r.priority : ''}`,
                `UAT: ${r.uatDate} (${daysStr})`,
                r.developerName ? `Developer: ${r.developerName}` : null
            ].filter(Boolean).join('\n');

            // Dependency info
            const deps = depMap[r.workItemId];
            const hasDependencies = this.showDependencies && deps && deps.length > 0;
            const dependencyCount = hasDependencies ? deps.length : 0;
            const dependencyLabel = hasDependencies
                ? `Blocked by ${dependencyCount} item${dependencyCount === 1 ? '' : 's'}`
                : '';

            // Developer first name for column
            const devFirstName = r.developerName ? r.developerName.split(' ')[0] : '';

            // Row class with child indent
            let rowClass = 'gantt-row';
            if (indent > 0) rowClass += ' gantt-row--child';

            return {
                workItemId:       r.workItemId,
                name:             r.name,
                description:      desc,
                descShort,
                stage:            r.stage,
                priority:         r.priority,
                uatDate:          r.uatDate,
                developerName:    r.developerName,
                devFirstName,
                rowClass,
                labelStyle:       indent > 0 ? 'padding-left: 1.25rem;' : '',
                barClass,
                barStyle,
                stageBadgeClass,
                barTooltip,
                hasDependencies,
                dependencyLabel
            };
        });
    }

    get dateLabels() {
        const today = new Date();
        today.setHours(0, 0, 0, 0);
        const winMs   = this.windowDays * MS_PER_DAY;
        const windowStartMs = today.getTime() - Math.round(winMs * 0.2);
        const totalMs = winMs * 1.2;

        const labels = [];
        const count  = Math.min(this.windowDays <= 30 ? 5 : 6, 7);
        for (let i = 0; i <= count; i++) {
            const t = new Date(windowStartMs + (totalMs * i) / count);
            const leftPct = ((i / count) * 100).toFixed(1);
            labels.push({
                key:   `dl-${i}`,
                label: this.fmtDate(t),
                style: `left:${leftPct}%`
            });
        }
        return labels;
    }

    get todayLineStyle() {
        const today = new Date();
        today.setHours(0, 0, 0, 0);
        const winMs   = this.windowDays * MS_PER_DAY;
        const windowStartMs = today.getTime() - Math.round(winMs * 0.2);
        const totalMs = winMs * 1.2;
        const pct = (((today.getTime() - windowStartMs) / totalMs) * 100).toFixed(1);
        return `left:${pct}%`;
    }

    // ── Click handler — single click opens quick-edit; double-click navigates ──

    handleRowClick(event) {
        event.preventDefault();
        const sfId = event.currentTarget.dataset.id;
        if (sfId) {
            this.selectedWorkItemId = sfId;
            this.showQuickEdit = true;
        }
    }

    handleRowDblClick(event) {
        event.preventDefault();
        const recordId = event.currentTarget.dataset.id;
        if (recordId) {
            this.showQuickEdit = false;
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

    // ── Drag-to-reschedule ────────────────────────────────────────────────────

    handleBarDragStart(event) {
        const barEl = event.currentTarget;
        const workItemId = barEl.dataset.id;
        if (!workItemId) return;

        event.preventDefault();
        const startX = event.clientX || (event.touches && event.touches[0].clientX);
        barEl.classList.add('gantt-bar--dragging');

        const onMove = (e) => {
            const clientX = e.clientX || (e.touches && e.touches[0].clientX);
            const dx = clientX - startX;
            barEl.style.transform = 'translateX(' + dx + 'px)';
        };

        const onEnd = (e) => {
            document.removeEventListener('mousemove', onMove);
            document.removeEventListener('mouseup', onEnd);
            document.removeEventListener('touchmove', onMove);
            document.removeEventListener('touchend', onEnd);

            barEl.classList.remove('gantt-bar--dragging');
            barEl.style.transform = '';

            const clientX = e.clientX || (e.changedTouches && e.changedTouches[0].clientX);
            const dx = clientX - startX;

            // Only save if meaningful drag (> 5px)
            if (Math.abs(dx) < 5) return;

            // Calculate day offset from pixel movement
            const trackEl = barEl.parentElement;
            if (!trackEl) return;
            const trackWidth = trackEl.getBoundingClientRect().width;
            const winMs = this.windowDays * MS_PER_DAY;
            const totalMs = winMs * 1.2;
            const daysDelta = Math.round((dx / trackWidth) * (totalMs / MS_PER_DAY));

            const row = this.rawRows.find(r => r.workItemId === workItemId);
            if (!row) return;

            // Use existing start/end dates or fall back to created/uat
            const origStart = row.startDate ? new Date(row.startDate) : new Date(row.createdDate);
            const origEnd = row.endDate ? new Date(row.endDate) : new Date(row.uatDate);

            const newStart = new Date(origStart.getTime() + daysDelta * MS_PER_DAY);
            const newEnd = new Date(origEnd.getTime() + daysDelta * MS_PER_DAY);

            const startStr = this._formatDate(newStart);
            const endStr = this._formatDate(newEnd);

            updateWorkItemDates({ workItemId: workItemId, startDate: startStr, endDate: endStr })
                .then(() => {
                    this.dispatchEvent(new ShowToastEvent({
                        title: 'Dates Updated',
                        message: startStr + ' to ' + endStr,
                        variant: 'success'
                    }));
                    refreshApex(this._wiredGanttResult);
                })
                .catch(err => {
                    this.dispatchEvent(new ShowToastEvent({
                        title: 'Error',
                        message: err.body ? err.body.message : err.message,
                        variant: 'error'
                    }));
                    refreshApex(this._wiredGanttResult);
                });
        };

        document.addEventListener('mousemove', onMove);
        document.addEventListener('mouseup', onEnd);
        document.addEventListener('touchmove', onMove);
        document.addEventListener('touchend', onEnd);
    }

    // ── Quick-edit modal handlers ──────────────────────────────────────────────

    handleQuickEditSave() {
        this.showQuickEdit = false;
        this.selectedWorkItemId = null;
        this.isLoading = true;
        Promise.all([
            refreshApex(this._wiredGanttResult),
            refreshApex(this._wiredDepsResult)
        ]).then(() => {
            this.isLoading = false;
        });
    }

    handleQuickEditClose() {
        this.showQuickEdit = false;
        this.selectedWorkItemId = null;
    }

    // ── Summary stats ──────────────────────────────────────────────────────────

    get summaryStats() {
        const rows = this.filteredRows;
        const today = new Date();
        today.setHours(0, 0, 0, 0);
        const todayMs = today.getTime();

        let overdue = 0;
        let dueSoon = 0;
        let onTrack = 0;
        let assigned = 0;

        rows.forEach(r => {
            const uatMs = new Date(r.uatDate).getTime();
            const daysToUat = (uatMs - todayMs) / MS_PER_DAY;
            if (uatMs < todayMs) { overdue++; }
            else if (daysToUat < 7) { dueSoon++; }
            else { onTrack++; }
            if (r.developerName) { assigned++; }
        });

        return { total: rows.length, overdue, dueSoon, onTrack, assigned };
    }

    get hasSummaryOverdue() { return this.summaryStats.overdue > 0; }
    get hasSummaryDueSoon() { return this.summaryStats.dueSoon > 0; }

    // ── State flags ───────────────────────────────────────────────────────────

    get hasError() { return !this.isLoading && !!this.errorMessage; }
    get isEmpty()  { return !this.isLoading && !this.errorMessage && this.filteredRows.length === 0; }
    get hasRows()  { return !this.isLoading && !this.errorMessage && this.filteredRows.length > 0; }

    // ── Helpers ───────────────────────────────────────────────────────────────

    fmtDate(d) {
        return d.toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
    }

    /** Formats a Date as ISO YYYY-MM-DD string for Apex */
    _formatDate(d) {
        const yyyy = d.getFullYear();
        const mm = String(d.getMonth() + 1).padStart(2, '0');
        const dd = String(d.getDate()).padStart(2, '0');
        return yyyy + '-' + mm + '-' + dd;
    }
}

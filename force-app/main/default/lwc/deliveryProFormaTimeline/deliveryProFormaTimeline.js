/**
 * @name         Delivery Hub — deliveryProFormaTimeline
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Priority-grouped delivery timeline powered by nimbus-gantt's
 *               PriorityGroupingPlugin. Ports the cloudnimbusllc.com v5/v7 page
 *               (/mf/delivery-timeline-v5) to a DH LWC that consumes real
 *               WorkItem__c records via DeliveryGanttController.getProFormaTimelineData.
 *
 *               Buckets: NOW (top-priority) · NEXT (active) · PLANNED (follow-on) ·
 *               PROPOSED (proposed) · HOLD (deferred). Assignment reads
 *               WorkItem__c.PriorityGroupPk__c first; falls back to server-side
 *               derivation when the picklist is blank.
 *
 *               Set standalone=true (e.g. on the VF standalone page) to suppress
 *               the SLDS toolbar and render a minimal custom bar instead.
 * @author Cloud Nimbus LLC
 */
import { LightningElement, api } from 'lwc';
import { loadScript } from 'lightning/platformResourceLoader';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import NIMBUS_GANTT from '@salesforce/resourceUrl/nimbusgantt';
import getProFormaTimelineData from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryGanttController.getProFormaTimelineData';
import getGanttDependencies from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryGanttController.getGanttDependencies';
import updateWorkItemDates from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryGanttController.updateWorkItemDates';
import updateWorkItemPriorityGroup from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryGanttController.updateWorkItemPriorityGroup';

// ─── Bucket palette — bold solid colors match cloudnimbusllc.com v5 GROUP_BG ─
const PRIORITY_BUCKETS = [
    { id: 'top-priority', label: 'NOW',      color: '#dc2626', bgTint: '#ef4444', order: 0 },
    { id: 'active',       label: 'NEXT',     color: '#d97706', bgTint: '#f59e0b', order: 1 },
    { id: 'follow-on',    label: 'PLANNED',  color: '#059669', bgTint: '#10b981', order: 2 },
    { id: 'proposed',     label: 'PROPOSED', color: '#2563eb', bgTint: '#3b82f6', order: 3 },
    { id: 'deferred',     label: 'HOLD',     color: '#94a3b8', bgTint: '#94a3b8', order: 4 },
];

const STAGE_COLORS = {
    'Backlog':                  '#64748b',
    'Scoping In Progress':      '#64748b',
    'Ready for Sizing':         '#3b82f6',
    'Ready for Development':    '#22c55e',
    'In Development':           '#22c55e',
    'Ready for QA':             '#a855f7',
    'QA In Progress':           '#a855f7',
    'Ready for Client UAT':     '#14b8a6',
    'In Client UAT':            '#14b8a6',
    'Ready for UAT Sign-off':   '#14b8a6',
    'Ready for Deployment':     '#f97316',
    'Deploying':                '#f97316',
    'Done':                     '#9ca3af',
    'Deployed to Prod':         '#9ca3af',
    'Cancelled':                '#cbd5e1',
    'Paused':                   '#94a3b8',
    'On Hold':                  '#94a3b8',
    'Blocked':                  '#ef4444',
};

// ─── Theme — matches cloudnimbusllc.com v5 V3_MATCH_THEME exactly ─────────────
const V3_MATCH_THEME = {
    timelineBg:         '#ffffff',
    timelineGridColor:  '#e5e7eb',
    timelineHeaderBg:   '#f3f4f6',
    timelineHeaderText: '#1f2937',
    timelineWeekendBg:  'rgba(229,231,235,0.4)',
    todayLineColor:     '#ef4444',
    todayBg:            'rgba(239,68,68,0.08)',
    barDefaultColor:    '#94a3b8',
    barBorderRadius:    4,
    barTextColor:       '#ffffff',
    barSelectedBorder:  '#3b82f6',
    gridBg:             '#ffffff',
    gridAltRowBg:       'rgba(255,255,255,0)',
    gridBorderColor:    '#e5e7eb',
    gridTextColor:      '#1f2937',
    gridHeaderBg:       '#f3f4f6',
    gridHeaderText:     '#1f2937',
    gridHoverBg:        'rgba(229,231,235,0.3)',
    dependencyColor:    '#3b82f6',
    dependencyWidth:    2,
    fontFamily:         "-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif",
    fontSize:           12,
    selectionColor:     '#3b82f6',
};

// ─── CSS overrides — v7 parity using data-task-id attribute selectors ─────────
// NimbusGantt renders each row as <tr data-task-id="..."> — there is NO
// ng-group-row class in the IIFE (the old selectors never matched anything).
// We target bucket headers via [data-task-id^="__bucket_header__"] and entity
// group rows via [data-task-id^="__entity__"].
const V5_GANTT_STYLES = `
  .ng-grid {
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif !important;
    font-size: 12px !important; color: #1f2937 !important; letter-spacing: -0.01em;
  }
  .ng-grid table { border-collapse: collapse !important; border-spacing: 0 !important; }
  .ng-grid-header { background: #f3f4f6 !important; visibility: hidden !important; }
  .ng-grid-th { font-size: 12px !important; font-weight: 700 !important; color: #1f2937 !important; padding: 0 6px !important; border-right: none !important; }
  .ng-grid-cell { padding-top: 0 !important; padding-right: 6px !important; padding-bottom: 0 !important; padding-left: 6px; border-right: none !important; }
  .ng-grid-row { border: none !important; box-shadow: inset 0 -1px 0 #f3f4f6; box-sizing: border-box !important; height: 32px !important; }
  .ng-grid-row td { border: none !important; box-sizing: border-box !important; }
  /* Task rows */
  .ng-grid-row:not([data-task-id^="__bucket_header__"]):not([data-task-id^="__entity__"]) { cursor: grab; }
  .ng-grid-row:not([data-task-id^="__bucket_header__"]):not([data-task-id^="__entity__"]):active { cursor: grabbing; }
  .ng-row-alt:not([data-task-id^="__bucket_header__"]):not([data-task-id^="__entity__"]) { background: unset; }
  .ng-row-selected:not([data-task-id^="__bucket_header__"]):not([data-task-id^="__entity__"]) { background: rgba(59, 130, 246, 0.06) !important; box-shadow: inset 3px 0 0 #3b82f6 !important; }
  /* Bucket header rows */
  .ng-grid-row[data-task-id^="__bucket_header__"] { font-weight: 700 !important; font-size: 12px !important; letter-spacing: 0.02em; box-sizing: border-box !important; box-shadow: none !important; color: #fff !important; height: 32px !important; cursor: pointer; }
  .ng-grid-row[data-task-id^="__bucket_header__"] .ng-grid-cell-text { font-weight: 700 !important; font-size: 12px !important; color: #fff !important; letter-spacing: 0.02em; text-transform: uppercase; }
  .ng-grid-row[data-task-id^="__bucket_header__"] .ng-expand-icon { color: rgba(255,255,255,0.8) !important; opacity: 1 !important; }
  .ng-grid-row[data-task-id^="__bucket_header__"] .ng-expand-spacer { display: none !important; }
  /* Bucket-specific background colors */
  .ng-grid-row[data-task-id="__bucket_header__top-priority"] { background: #dc2626 !important; }
  .ng-grid-row[data-task-id="__bucket_header__active"]       { background: #d97706 !important; }
  .ng-grid-row[data-task-id="__bucket_header__follow-on"]    { background: #059669 !important; }
  .ng-grid-row[data-task-id="__bucket_header__proposed"]     { background: #2563eb !important; }
  .ng-grid-row[data-task-id="__bucket_header__deferred"]     { background: #94a3b8 !important; }
  /* Entity group rows (client / project sub-headers within each bucket) */
  .ng-grid-row[data-task-id^="__entity__"] { font-weight: 600 !important; background: #f1f5f9 !important; box-shadow: inset 0 -1px 0 #e2e8f0 !important; cursor: pointer; }
  .ng-grid-row[data-task-id^="__entity__"] .ng-grid-cell-text { font-weight: 600 !important; font-size: 12px !important; color: #374151 !important; }
  .ng-grid-row[data-task-id^="__entity__"] .ng-expand-icon { color: #6b7280 !important; opacity: 0.8 !important; }
  /* Compact tree-cell indentation — depth 0 (bucket)=8px, depth 1 (entity)=8px, depth 2 (task)=18px */
  .ng-grid-row:not([data-task-id^="__bucket_header__"]) .ng-tree-cell[style*="padding-left: 28px"] { padding-left: 8px  !important; }
  .ng-grid-row:not([data-task-id^="__bucket_header__"]) .ng-tree-cell[style*="padding-left: 48px"] { padding-left: 18px !important; }
  .ng-grid-row:not([data-task-id^="__bucket_header__"]) .ng-tree-cell[style*="padding-left: 68px"] { padding-left: 28px !important; }
  .ng-grid-row:not([data-task-id^="__bucket_header__"]) .ng-tree-cell[style*="padding-left: 88px"] { padding-left: 38px !important; }
  .ng-expand-spacer { width: 0 !important; min-width: 0 !important; }
  .ng-expand-icon { font-size: 9px !important; opacity: 0.5 !important; color: #6b7280 !important; width: 14px !important; min-width: 14px !important; }
  .ng-expand-icon:hover { opacity: 1 !important; }
`;

// ─── Grid columns — two-column layout matching v7's nimbusColumns ────────────
const GANTT_COLUMNS = [
    { field: 'title',      header: '', width: 240, tree: true },
    { field: 'hoursLabel', header: '', width: 95,  align: 'right' },
];

const ZOOM_LEVELS = ['day', 'week', 'month', 'quarter'];

export default class DeliveryProFormaTimeline extends LightningElement {
    @api showCompleted = false;
    /**
     * Standalone mode: render a minimal plain-HTML toolbar instead of SLDS components.
     * Pass standalone=true on the VF page (DeliveryGanttStandalone) where there is no
     * Salesforce chrome. Cannot default to true per LWC1503 — false is the correct default.
     */
    @api standalone = false;

    isLoading = true;
    errorMessage = null;
    rows = [];

    _gantt = null;
    _scriptLoaded = false;
    _zoomLevel = 'week';
    _deps = [];

    get zoomOptions() {
        return ZOOM_LEVELS.map((level) => ({
            level,
            label: level.charAt(0).toUpperCase() + level.slice(1),
            isActive: level === this._zoomLevel,
        }));
    }

    get isEmpty() {
        return !this.isLoading && !this.errorMessage && this.rows.length === 0;
    }

    async connectedCallback() {
        try {
            await loadScript(this, NIMBUS_GANTT);
            this._scriptLoaded = true;
            await this.loadData();
        } catch (error) {
            this.handleError('Failed to load nimbus-gantt static resource', error);
        }
    }

    disconnectedCallback() {
        if (this._gantt) {
            try { this._gantt.destroy(); } catch (e) { /* swallow */ }
            this._gantt = null;
        }
    }

    async loadData() {
        this.isLoading = true;
        this.errorMessage = null;
        try {
            const [data, deps] = await Promise.all([
                getProFormaTimelineData({ showCompleted: this.showCompleted }),
                getGanttDependencies({ showCompleted: this.showCompleted }),
            ]);
            this.rows = data || [];
            this._deps = deps || [];
            Promise.resolve().then(() => this.renderGantt());
        } catch (error) {
            this.handleError('Failed to load work items', error);
        } finally {
            this.isLoading = false;
        }
    }

    renderGantt() {
        const container = this.refs.ganttContainer;
        if (!container || !window.NimbusGantt) return;

        if (this._gantt) {
            try { this._gantt.destroy(); } catch (e) { /* swallow */ }
            this._gantt = null;
        }

        if (this.rows.length === 0) {
            container.innerHTML = '';
            return;
        }

        const dependencies = this._deps.map((d) => ({
            id: d.id, source: d.source, target: d.target, type: d.dependencyType || 'FS',
        }));

        // ── Step 1: Build leaf task objects ──────────────────────────────────
        const leafTasks = this.rows.map((row) => {
            const hrs    = row.estimatedHours != null ? Math.round(Number(row.estimatedHours)) : 0;
            const logged = row.loggedHours    != null ? Number(row.loggedHours) : 0;
            const pct    = hrs > 0 ? Math.round((logged / hrs) * 100) : 0;
            return {
                id:         row.id,
                title:      row.title || row.name,
                name:       row.title || row.name,
                hoursLabel: hrs > 0 ? (logged > 0 ? `${hrs}h (${pct}%)` : `${hrs}h`) : '',
                startDate:  row.startDate,
                endDate:    row.endDate,
                progress:   row.progress != null ? Number(row.progress) : 0,
                status:     row.stage,
                priority:   row.priority,
                assignee:   row.developerName || '',
                // parentId from sub-tasks — will be overwritten below for root-level tasks
                parentId:   row.parentWorkItemId || undefined,
                color:      STAGE_COLORS[row.stage] || undefined,
                metadata: {
                    priorityGroup: row.priorityGroup,
                    hoursHigh:     hrs,
                    hoursLogged:   logged,
                    entityId:      row.entityId,
                    entityName:    row.entityName,
                },
            };
        });

        // ── Step 2: Aggregate per (bucket, entity) pair ───────────────────────
        // Key: `${bucketId}||${entityId}` → entity aggregate data
        const entityDataMap = new Map();

        leafTasks.forEach((task) => {
            const bucketId   = task.metadata.priorityGroup;
            if (!bucketId) return;
            const entityId   = task.metadata.entityId   || '__none__';
            const entityName = task.metadata.entityName || 'Other';
            const key        = `${bucketId}||${entityId}`;

            if (!entityDataMap.has(key)) {
                entityDataMap.set(key, {
                    key, bucketId, entityId, entityName,
                    tasks: [], totalHours: 0, totalLogged: 0,
                    minStart: null, maxEnd: null,
                });
            }
            const eg = entityDataMap.get(key);
            eg.tasks.push(task);
            eg.totalHours  += task.metadata.hoursHigh   || 0;
            eg.totalLogged += task.metadata.hoursLogged || 0;
            if (task.startDate && (!eg.minStart || task.startDate < eg.minStart)) eg.minStart = task.startDate;
            if (task.endDate   && (!eg.maxEnd   || task.endDate   > eg.maxEnd))   eg.maxEnd   = task.endDate;
        });

        // ── Step 3: Build bucket header synthetic rows ────────────────────────
        const bucketHeaderRows = [];

        PRIORITY_BUCKETS.forEach((bucket) => {
            const bTasks = leafTasks.filter((t) => t.metadata.priorityGroup === bucket.id);
            if (bTasks.length === 0) return;

            const totalHours  = bTasks.reduce((s, t) => s + (t.metadata.hoursHigh   || 0), 0);
            const totalLogged = bTasks.reduce((s, t) => s + (t.metadata.hoursLogged || 0), 0);
            const minStart    = bTasks.filter((t) => t.startDate)
                                      .reduce((mn, t) => (!mn || t.startDate < mn ? t.startDate : mn), null);
            const maxEnd      = bTasks.filter((t) => t.endDate)
                                      .reduce((mx, t) => (!mx || t.endDate   > mx ? t.endDate   : mx), null);
            if (!minStart || !maxEnd) return; // need valid date range for timeline bar

            bucketHeaderRows.push({
                id:         `__bucket_header__${bucket.id}`,
                title:      bucket.label,
                name:       bucket.label,
                hoursLabel: `${bTasks.length} · ${totalHours}h`,
                startDate:  minStart,
                endDate:    maxEnd,
                progress:   totalHours > 0 ? totalLogged / totalHours : 0,
                color:      bucket.color,
                sortOrder:  bucket.order,
                metadata:   { __bucketHeader: true, bucketId: bucket.id, hoursHigh: totalHours },
            });
        });

        // ── Step 4: Build entity group rows + assign task parentIds ───────────
        const entityGroupRows = [];

        entityDataMap.forEach((eg) => {
            const bucket = PRIORITY_BUCKETS.find((b) => b.id === eg.bucketId);
            if (!bucket) return;

            // Only create entity row if there's a valid date range for the bar
            const hasDates = eg.minStart && eg.maxEnd;
            const entityRowId = `__entity__${eg.key}`;

            if (hasDates) {
                entityGroupRows.push({
                    id:         entityRowId,
                    title:      eg.entityName,
                    name:       eg.entityName,
                    hoursLabel: eg.totalHours > 0 ? `${eg.totalHours}h` : '',
                    startDate:  eg.minStart,
                    endDate:    eg.maxEnd,
                    progress:   eg.totalHours > 0 ? eg.totalLogged / eg.totalHours : 0,
                    color:      bucket.bgTint,
                    parentId:   `__bucket_header__${eg.bucketId}`,
                    metadata:   { entityId: eg.entityId, bucketId: eg.bucketId, hoursHigh: eg.totalHours },
                });
            }

            // Assign root-level tasks (no existing parentWorkItemId) to entity row
            // Sub-tasks that already have parentId pointing to another task keep that relationship.
            eg.tasks.forEach((task) => {
                if (!task.parentId) {
                    task.parentId = hasDates
                        ? entityRowId
                        : `__bucket_header__${eg.bucketId}`;
                }
            });
        });

        // ── Step 5: Combine and render — no PriorityGroupingPlugin ────────────
        // PriorityGroupingPlugin would overwrite ALL parentIds, destroying the
        // Bucket → Entity → Task hierarchy built above.
        const allTasks = [...bucketHeaderRows, ...entityGroupRows, ...leafTasks];

        const { NimbusGantt } = window.NimbusGantt;

        this._gantt = new NimbusGantt(container, {
            tasks:         allTasks,
            dependencies,
            columns:       GANTT_COLUMNS,
            theme:         V3_MATCH_THEME,
            rowHeight:     32,
            barHeight:     20,
            headerHeight:  32,
            gridWidth:     335,
            zoomLevel:     this._zoomLevel,
            showToday:     true,
            showWeekends:  true,
            showProgress:  true,
            colorMap:      STAGE_COLORS,
            readOnly:      false,
            onTaskClick:   (task) => this.handleTaskClick(task),
            onTaskMove:    (task, startDate, endDate) => this.handleTaskDateChange(task, startDate, endDate),
            onTaskResize:  (task, startDate, endDate) => this.handleTaskDateChange(task, startDate, endDate),
        });

        this._gantt.setData(allTasks, dependencies);
        try { this._gantt.expandAll(); } catch (e) { /* swallow */ }

        // Inject v5 CSS overrides into the container's light DOM so they win
        // over nimbus-gantt's injected defaults.
        this.injectV5Styles(container);
    }

    injectV5Styles(container) {
        const existing = container.querySelector('#ng-v5-overrides');
        if (existing) existing.remove();
        const style = document.createElement('style');
        style.id = 'ng-v5-overrides';
        style.textContent = V5_GANTT_STYLES;
        container.appendChild(style);
    }

    handleTaskClick(task) {
        if (!task || !task.id) return;
        if (task.id.startsWith('__bucket_header__') || task.id.startsWith('__entity__')) return;
        // Use 'ganttnavigate' (not 'navigate') to avoid collision with platform
        // Lightning Out global handlers that intercept the bare 'navigate' event
        // and attempt a page redirect (causing Salesforce's redirect-block page).
        this.dispatchEvent(new CustomEvent('ganttnavigate', {
            bubbles: true, composed: true,
            detail: { recordId: task.id, objectApiName: 'WorkItem__c' },
        }));
    }

    handleShowCompletedChange(event) {
        this.showCompleted = event.target.checked;
        if (this._scriptLoaded) this.loadData();
    }

    handleRefresh() {
        if (this._scriptLoaded) this.loadData();
    }

    async handleTaskDateChange(task, startDate, endDate) {
        if (!task || !task.id) return;
        if (task.id.startsWith('__bucket_header__') || task.id.startsWith('__entity__')) return;
        try {
            await updateWorkItemDates({ workItemId: task.id, startDate, endDate });
            if (this._scriptLoaded) await this.loadData();
        } catch (error) {
            this.handleError('Failed to save date change', error);
        }
    }

    async handleBucketChange(task, newBucketId) {
        if (!task || !task.id) return;
        if (task.id.startsWith('__bucket_header__') || task.id.startsWith('__entity__')) return;
        try {
            await updateWorkItemPriorityGroup({ workItemId: task.id, priorityGroup: newBucketId });
            if (this._scriptLoaded) await this.loadData();
        } catch (error) {
            this.handleError('Failed to save priority group change', error);
        }
    }

    handleZoomChange(event) {
        const level = event.currentTarget.dataset.zoom;
        if (!level || level === this._zoomLevel) return;
        this._zoomLevel = level;
        if (this._gantt) this._gantt.setZoom(level);
    }

    handleError(prefix, error) {
        const msg = (error && error.body && error.body.message) || (error && error.message) || 'Unknown error';
        this.errorMessage = `${prefix}: ${msg}`;
        this.isLoading = false;
        // eslint-disable-next-line no-console
        console.error('[deliveryProFormaTimeline]', prefix, error);
        this.dispatchEvent(new ShowToastEvent({
            title: 'Timeline error', message: this.errorMessage, variant: 'error',
        }));
    }
}

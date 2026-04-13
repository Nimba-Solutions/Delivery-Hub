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
 *               Root items (no parentWorkItemId) get a groupId that tells the
 *               PriorityGroupingPlugin which bucket to place them in. Sub-items
 *               return null from getBucket so the plugin leaves their parentId
 *               intact, letting them nest under their parent category task naturally.
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
import updateWorkItemSortOrder from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryGanttController.updateWorkItemSortOrder';
import updateWorkItemParent from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryGanttController.updateWorkItemParent';

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

// ─── CSS overrides — full v5/v8 match using class selectors ──────────────────
const V5_GANTT_STYLES = `
  .ng-grid {
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif !important;
    font-size: 12px !important; color: #1f2937 !important; letter-spacing: -0.01em;
  }
  .ng-grid table { border-collapse: collapse !important; border-spacing: 0 !important; }
  .ng-grid-header { background: #f3f4f6 !important; visibility: hidden !important; }
  .ng-grid-th { font-size: 12px !important; font-weight: 700 !important; color: #1f2937 !important; padding: 0 6px !important; border-right: none !important; }
  .ng-grid-cell { padding-top: 0 !important; padding-right: 6px !important; padding-bottom: 0 !important; padding-left: 6px; border-right: none !important; line-height: 32px !important; }
  .ng-grid-row { border: none !important; box-shadow: inset 0 -1px 0 #f3f4f6; box-sizing: border-box !important; }
  .ng-grid-row td { border: none !important; box-sizing: border-box !important; }
  /* Parent rows — bold text */
  .ng-grid-row:not(.ng-group-row) .ng-tree-cell .ng-expand-icon + .ng-grid-cell-text { font-weight: 700 !important; color: #1f2937 !important; }
  /* Child/leaf rows — muted text */
  .ng-grid-row .ng-tree-cell .ng-expand-spacer + .ng-grid-cell-text { font-weight: 400 !important; color: #6b7280 !important; font-size: 11px !important; }
  /* Non-group rows: grab cursor + hover tint */
  .ng-grid-row:not(.ng-group-row) { cursor: grab; }
  .ng-grid-row:not(.ng-group-row):hover { background: rgba(59,130,246,0.04) !important; outline: 1px solid rgba(59,130,246,0.12) !important; outline-offset: -1px; }
  .ng-grid-row:not(.ng-group-row):active { cursor: grabbing; }
  /* Kill alternating row bg — depth shading handles backgrounds */
  .ng-row-alt:not(.ng-group-row) { background: unset; }
  /* Bucket header rows */
  .ng-group-row { font-weight: 700; font-size: 11px; letter-spacing: 0.03em; box-sizing: border-box !important; box-shadow: none !important; color: #fff !important; }
  .ng-group-row .ng-grid-cell-text { font-weight: 700 !important; font-size: 12px !important; color: #fff !important; letter-spacing: 0.02em; text-transform: uppercase; }
  .ng-group-row .ng-expand-icon { color: inherit !important; opacity: 0.5 !important; }
  .ng-group-row .ng-grid-cell[data-field="hoursLabel"] { font-weight: 600 !important; font-size: 11px !important; color: inherit !important; opacity: 0.75; white-space: nowrap !important; overflow: visible !important; text-overflow: unset !important; }
  /* Hours column — monospace, muted */
  .ng-grid-cell[data-field="hoursLabel"] { font-family: 'SF Mono', 'Cascadia Code', 'Consolas', monospace; font-size: 10px; color: #94a3b8; font-weight: 400; }
  /* Selected rows */
  .ng-row-selected:not(.ng-group-row) { background: rgba(59,130,246,0.06) !important; box-shadow: inset 3px 0 0 #3b82f6 !important; }
  .ng-row-selected.ng-group-row { box-shadow: inset 0 2px 0 currentColor, inset 3px 0 0 currentColor, inset 0 -1px 0 #f3f4f6 !important; }
  /* Drag handle */
  .ng-drag-handle { display:inline-flex; align-items:center; justify-content:center; cursor:grab; opacity:0.3; font-size:11px; color:#94a3b8; vertical-align:middle; user-select:none; width:14px; height:14px; flex-shrink:0; margin-left:-5px !important; margin-right:4px; }
  .ng-grid-row:hover .ng-drag-handle { opacity:0.6; color:#64748b; }
  .ng-drag-handle:active { cursor:grabbing; opacity:1; }
  /* Canvas sticky */
  .ng-scroll-content > canvas { position: sticky !important; left: 0 !important; }
  /* Expand icon */
  .ng-expand-spacer { width: 0 !important; min-width: 0 !important; }
  .ng-expand-icon { font-size: 9px !important; opacity: 0.5 !important; color: #6b7280 !important; width: 14px !important; min-width: 14px !important; }
  .ng-expand-icon:hover { opacity: 1 !important; }
  /* Depth indentation — maps library 28/48/68/88px to compact 8/18/28/38px */
  .ng-grid-row:not(.ng-group-row) .ng-tree-cell[style*="padding-left: 28px"] { padding-left: 8px  !important; }
  .ng-grid-row:not(.ng-group-row) .ng-tree-cell[style*="padding-left: 48px"] { padding-left: 18px !important; }
  .ng-grid-row:not(.ng-group-row) .ng-tree-cell[style*="padding-left: 68px"] { padding-left: 28px !important; }
  .ng-grid-row:not(.ng-group-row) .ng-tree-cell[style*="padding-left: 88px"] { padding-left: 38px !important; }
`;

// ─── Grid columns — two-column layout matching v7's nimbusColumns ────────────
const GANTT_COLUMNS = [
    { field: 'title',      header: '', width: 160, tree: true },
    { field: 'hoursLabel', header: '', width: 60,  align: 'right' },
];

const ZOOM_LEVELS = ['day', 'week', 'month', 'quarter'];

export default class DeliveryProFormaTimeline extends LightningElement {
    @api showCompleted = false;

    isLoading = true;
    errorMessage = null;
    rows = [];

    _gantt = null;
    _scriptLoaded = false;
    _zoomLevel = 'week';
    _deps = [];
    _dragCleanup = null;
    _shadingCleanup = null;
    _depthMap = new Map();
    _viewMode = 'gantt';     // 'gantt' | 'list'
    _filterEntityId = null;  // null = all, string = filter by entity id
    _selectedTask = null;    // task object for floating detail panel

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

    get hasRows() {
        return this.rows.length > 0;
    }

    get stats() {
        const active = this.rows.filter(r => !r.isInactive);
        const logged = active.reduce((s, r) => s + (Number(r.loggedHours) || 0), 0);
        const estimated = active.reduce((s, r) => s + (Number(r.estimatedHours) || 0), 0);
        const remaining = Math.max(0, estimated - logged);
        const monthsLow = remaining > 0 ? (remaining / 160).toFixed(1) : '—';
        const monthsHigh = remaining > 0 ? (remaining / 120).toFixed(1) : '—';
        return {
            items: active.length,
            hoursLogged: logged % 1 === 0 ? logged : logged.toFixed(1),
            hoursRemaining: Math.round(remaining),
            months: monthsLow === monthsHigh ? monthsLow : `${monthsLow}–${monthsHigh}`,
        };
    }

    get entityFilters() {
        const seen = new Map();
        this.rows.forEach(r => {
            if (r.entityId && !seen.has(r.entityId)) {
                seen.set(r.entityId, r.entityName || r.entityId);
            }
        });
        const all = [{ id: 'null', label: 'All', isActive: this._filterEntityId === null }];
        seen.forEach((label, id) => {
            all.push({ id, label, isActive: this._filterEntityId === id });
        });
        return all;
    }

    get filteredRows() {
        if (!this._filterEntityId) return this.rows;
        return this.rows.filter(r => r.entityId === this._filterEntityId);
    }

    get isGanttMode() { return this._viewMode === 'gantt'; }
    get isListMode()  { return this._viewMode === 'list'; }

    get listGroups() {
        const bucketOrder = ['top-priority', 'active', 'follow-on', 'proposed', 'deferred'];
        const bucketLabels = {
            'top-priority': 'NOW',
            'active': 'NEXT',
            'follow-on': 'PLANNED',
            'proposed': 'PROPOSED',
            'deferred': 'HOLD',
        };
        const bucketColors = {
            'top-priority': '#ef4444',
            'active': '#f59e0b',
            'follow-on': '#10b981',
            'proposed': '#3b82f6',
            'deferred': '#94a3b8',
        };
        const groups = new Map();
        this.filteredRows.forEach(r => {
            const b = r.priorityGroup || 'follow-on';
            if (!groups.has(b)) groups.set(b, []);
            groups.get(b).push(r);
        });
        return bucketOrder.filter(b => groups.has(b)).map(b => ({
            id: b,
            label: bucketLabels[b],
            color: bucketColors[b],
            headerStyle: `background:${bucketColors[b]};color:#fff;padding:0.5rem 1rem;font-size:0.75rem;font-weight:700;letter-spacing:0.05em;text-transform:uppercase`,
            items: groups.get(b).map(r => ({
                id: r.id,
                title: r.title || r.name,
                stage: r.stage || '—',
                priority: r.priority || '—',
                developer: r.developerName || '—',
                entity: r.entityName || '—',
                hours: r.estimatedHours ? `${Math.round(r.estimatedHours)}h` : '—',
                startDate: r.startDate || '—',
                endDate: r.endDate || '—',
            })),
        }));
    }

    get legendItems() {
        const seenColors = new Set();
        const stages = [
            { label: 'Backlog / Scoping', color: '#64748b' },
            { label: 'Sizing / Dev Ready', color: '#3b82f6' },
            { label: 'In Development', color: '#22c55e' },
            { label: 'QA', color: '#a855f7' },
            { label: 'Client UAT', color: '#14b8a6' },
            { label: 'Deployment', color: '#f97316' },
            { label: 'Done', color: '#9ca3af' },
            { label: 'Blocked', color: '#ef4444' },
        ];
        return stages.filter(s => {
            if (seenColors.has(s.color)) return false;
            seenColors.add(s.color);
            return true;
        }).map(s => ({
            label: s.label,
            color: s.color,
            dotStyle: `background:${s.color};width:10px;height:10px;border-radius:2px;display:inline-block`,
        }));
    }

    get hasSelectedTask() { return !!this._selectedTask; }

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
        if (this._dragCleanup) { this._dragCleanup(); this._dragCleanup = null; }
        if (this._shadingCleanup) { this._shadingCleanup(); this._shadingCleanup = null; }
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

        const source = this.filteredRows;
        if (source.length === 0) {
            container.innerHTML = '';
            return;
        }

        const dependencies = this._deps.map((d) => ({
            id: d.id, source: d.source, target: d.target, type: d.dependencyType || 'FS',
        }));

        // ── Step 1: Build task objects from filteredRows ──────────────────────
        // Only root items (no parentWorkItemId) get a groupId — this tells the
        // PriorityGroupingPlugin to bucket them. Sub-items return null from
        // getBucket so the plugin leaves their parentId intact, letting them
        // nest under their parent category task naturally.
        const tasks = source.map((row) => {
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
                // Root items get a groupId (tells the plugin which bucket to place them in)
                // Sub-items (have a real parentId) get null → plugin ignores them
                groupId:    row.parentWorkItemId ? null : (row.priorityGroup || null),
                parentId:   row.parentWorkItemId || undefined,
                color:      STAGE_COLORS[row.stage] || undefined,
                metadata: {
                    priorityGroup: row.parentWorkItemId ? null : row.priorityGroup,
                    hoursHigh:     hrs,
                    hoursLogged:   logged,
                    entityId:      row.entityId,
                    entityName:    row.entityName,
                },
            };
        });

        const allTasks = tasks;

        const { NimbusGantt, PriorityGroupingPlugin, hoursWeightedProgress } = window.NimbusGantt;

        this._gantt = new NimbusGantt(container, {
            tasks,
            dependencies,
            columns:      GANTT_COLUMNS,
            theme:        V3_MATCH_THEME,
            rowHeight:    32,
            barHeight:    20,
            headerHeight: 32,
            gridWidth:    220,
            zoomLevel:    this._zoomLevel,
            showToday:    true,
            showWeekends: true,
            showProgress: true,
            colorMap:     STAGE_COLORS,
            readOnly:     false,
            onTaskClick:  (task) => this.handleTaskClick(task),
            onTaskMove:   (task, startDate, endDate) => this.handleTaskDateChange(task, startDate, endDate),
            onTaskResize: (task, startDate, endDate) => this.handleTaskDateChange(task, startDate, endDate),
        });

        this._gantt.use(
            PriorityGroupingPlugin({
                buckets: PRIORITY_BUCKETS,
                getBucket: (task) => {
                    // Sub-items (with a real parentId pointing to another task, not a bucket header)
                    // return null so the plugin leaves their parentId intact.
                    if (task.parentId && !task.parentId.startsWith('__bucket_header__')) return null;
                    return (task.metadata && task.metadata.priorityGroup) || task.groupId || null;
                },
                getBucketProgress: hoursWeightedProgress,
            })
        );

        this._gantt.setData(allTasks, dependencies);
        try { this._gantt.expandAll(); } catch (e) { /* swallow */ }

        // Inject v5 CSS overrides into document.head so they reach nimbus-gantt's
        // DOM children past LWC synthetic shadow boundaries.
        this.injectV5Styles();

        // Apply depth-based tint shading with MutationObserver
        if (this._shadingCleanup) { this._shadingCleanup(); this._shadingCleanup = null; }
        Promise.resolve().then(() => {
            this._shadingCleanup = this._applyDepthShading(container);
        });

        // Initialize drag-to-reparent after gantt renders
        if (this._dragCleanup) { this._dragCleanup(); this._dragCleanup = null; }
        this._buildDepthMap();
        this._dragCleanup = this._initDragManager(container);
    }

    injectV5Styles() {
        const STYLE_ID = 'ng-v5-overrides-dh';
        let el = document.getElementById(STYLE_ID);
        if (!el) {
            el = document.createElement('style');
            el.id = STYLE_ID;
            document.head.appendChild(el);
        }
        el.textContent = V5_GANTT_STYLES;
    }

    handleTaskClick(task) {
        if (!task || !task.id) return;
        if (task.id.startsWith('__bucket_header__') || task.id.startsWith('__entity__')) return;
        // Find the source row for details
        const row = this.rows.find(r => r.id === task.id);
        if (!row) return;
        const hrs = row.estimatedHours ? Math.round(Number(row.estimatedHours)) : 0;
        const logged = row.loggedHours ? Number(row.loggedHours) : 0;
        const pct = hrs > 0 ? Math.round((logged / hrs) * 100) : 0;
        this._selectedTask = {
            id: row.id,
            title: row.title || row.name,
            stage: row.stage || '—',
            priority: row.priority || '—',
            developer: row.developerName || '—',
            entity: row.entityName || '—',
            hours: hrs > 0 ? `${logged}h / ${hrs}h (${pct}%)` : '—',
            startDate: row.startDate || '—',
            endDate: row.endDate || '—',
            recordUrl: `/lightning/r/WorkItem__c/${row.id}/view`,
        };
    }

    handleViewMode(event) {
        const mode = event.currentTarget.dataset.mode;
        if (mode === this._viewMode) return;
        this._viewMode = mode;
        if (mode === 'gantt' && this._scriptLoaded) {
            // Re-render the gantt after switching back
            Promise.resolve().then(() => this.renderGantt());
        }
    }

    handleEntityFilter(event) {
        const id = event.currentTarget.dataset.id;
        this._filterEntityId = (id === 'null' || id === null) ? null : id;
        if (this._scriptLoaded) Promise.resolve().then(() => this.renderGantt());
    }

    handleDetailClose() {
        this._selectedTask = null;
    }

    handleDetailNavigate() {
        if (!this._selectedTask) return;
        this.dispatchEvent(new CustomEvent('ganttnavigate', {
            bubbles: true, composed: true,
            detail: { recordId: this._selectedTask.id, objectApiName: 'WorkItem__c' },
        }));
        this._selectedTask = null;
    }

    stopPropagation(event) {
        event.stopPropagation();
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

    // ─── Drag-to-reparent — ported from cloudnimbusllc.com v5/v8 ─────────────

    _buildDepthMap() {
        const map = new Map();
        const rowMap = new Map(this.rows.map(r => [r.id, r]));
        const compute = (id) => {
            if (map.has(id)) return map.get(id);
            const row = rowMap.get(id);
            if (!row || !row.parentWorkItemId || !rowMap.has(row.parentWorkItemId)) {
                map.set(id, 0); return 0;
            }
            const d = 1 + compute(row.parentWorkItemId);
            map.set(id, d); return d;
        };
        this.rows.forEach(r => compute(r.id));
        this._depthMap = map;
    }

    _applyDepthShading(container) {
        if (!container) return;
        const applied = new Map();
        let isApplying = false;

        // Parse inline background "rgba(r,g,b,...)" or "#rrggbb" → {r,g,b}
        const parseRgb = (s) => {
            const m = s.match(/(\d+)\s*,\s*(\d+)\s*,\s*(\d+)/);
            return m ? { r: +m[1], g: +m[2], b: +m[3] } : null;
        };

        const hexToRgb = (hex) => {
            const h = hex.replace('#', '');
            return { r: parseInt(h.substring(0,2), 16), g: parseInt(h.substring(2,4), 16), b: parseInt(h.substring(4,6), 16) };
        };

        // Pre-build bucket RGB map from PRIORITY_BUCKETS bgTint values
        const bucketRgbMap = new Map();
        for (const b of PRIORITY_BUCKETS) {
            bucketRgbMap.set(b.id, hexToRgb(b.bgTint));
        }

        const scrollContent = container.querySelector('.ng-scroll-content');
        let lastGrad = '';

        const apply = () => {
            if (isApplying) return;
            isApplying = true;

            const rows = container.querySelectorAll('.ng-grid-row');
            let bucketRgb = null;
            const stripes = [];

            for (const row of rows) {
                const el = row;
                if (el.classList.contains('ng-group-row')) {
                    // Get RGB from inline background or from data-task-id → bucketRgbMap
                    const taskId = el.getAttribute('data-task-id') || '';
                    const bucketId = taskId.replace('__bucket_header__', '');
                    bucketRgb = bucketRgbMap.get(bucketId) || parseRgb(el.style.background || '');
                    if (bucketRgb) {
                        stripes.push({ top: el.offsetTop, height: el.offsetHeight, color: `rgba(${bucketRgb.r},${bucketRgb.g},${bucketRgb.b},0.18)` });
                    }
                    continue;
                }

                const taskId = el.getAttribute('data-task-id') || '';
                const depth = this._depthMap.get(taskId) || 0;
                let target = '';
                if (bucketRgb) {
                    const alpha = Math.max(0.03, 0.12 - depth * 0.04);
                    target = `rgba(${bucketRgb.r},${bucketRgb.g},${bucketRgb.b},${alpha})`;
                    stripes.push({ top: el.offsetTop, height: el.offsetHeight, color: target });
                }
                if (applied.get(el) !== target) {
                    applied.set(el, target);
                    if (target) el.style.setProperty('background', target, 'important');
                    else el.style.removeProperty('background');
                }
            }

            // Canvas-side: apply background-image gradient to .ng-scroll-content
            if (scrollContent && stripes.length > 0) {
                const liveCanvas = scrollContent.querySelector('canvas');
                if (liveCanvas) {
                    const cw = liveCanvas.offsetWidth || liveCanvas.width;
                    if (cw > 0) {
                        scrollContent.style.backgroundSize = cw + 'px 100%';
                        scrollContent.style.backgroundRepeat = 'no-repeat';
                    }
                }
                const totalHeight = scrollContent.scrollHeight || 2000;
                const stops = [];
                let lastEnd = 0;
                for (const s of stripes) {
                    if (s.top > lastEnd) stops.push(`transparent ${lastEnd}px`, `transparent ${s.top}px`);
                    stops.push(`${s.color} ${s.top}px`, `${s.color} ${s.top + s.height}px`);
                    lastEnd = s.top + s.height;
                }
                if (lastEnd < totalHeight) stops.push(`transparent ${lastEnd}px`, `transparent ${totalHeight}px`);
                const grad = `linear-gradient(to bottom, ${stops.join(', ')})`;
                if (grad !== lastGrad) { lastGrad = grad; scrollContent.style.backgroundImage = grad; }
            }

            isApplying = false;
        };

        // Run immediately via rAF, then watch for DOM mutations
        const raf = requestAnimationFrame(apply);
        let debounce = null;
        const obs = new MutationObserver(() => {
            if (isApplying) return;
            if (debounce) clearTimeout(debounce);
            debounce = setTimeout(apply, 50);
        });
        obs.observe(container, { childList: true, subtree: true });

        // Return cleanup function
        return () => {
            cancelAnimationFrame(raf);
            if (debounce) clearTimeout(debounce);
            obs.disconnect();
            if (scrollContent) {
                scrollContent.style.backgroundImage = '';
                scrollContent.style.backgroundSize = '';
                scrollContent.style.backgroundRepeat = '';
            }
        };
    }

    _getTaskGroup(taskId) {
        const row = this.rows.find(r => r.id === taskId);
        return row ? (row.priorityGroup || null) : null;
    }

    _initDragManager(container) {
        const self = this;
        const DRAG_THRESHOLD = 5;
        const LEAF_STEP = 10;
        const INDENT_BASE = 8;

        let dragTaskId = null, dragSourceGroup = null, dragRow = null;
        let startX = 0, startY = 0, dragStartX = 0, dragStartDepth = 0;
        let hasMoved = false, didDrag = false, pendingIP = null;
        let ghost = null, spacer = null;
        let autoScrollRAF = null, autoScrollVelocity = 0;
        let lastClickId = null, lastClickTime = 0;

        const findScrollEl = () => container.querySelector('.ng-scroll-wrapper');

        const tickAutoScroll = () => {
            const el = findScrollEl();
            if (!el || !dragTaskId || autoScrollVelocity === 0) { autoScrollRAF = null; return; }
            el.scrollTop = Math.max(0, Math.min(el.scrollHeight - el.clientHeight, el.scrollTop + autoScrollVelocity));
            autoScrollRAF = requestAnimationFrame(tickAutoScroll);
        };

        const groupFromRowId = (rowId) => {
            if (rowId.startsWith('__bucket_header__')) return rowId.slice('__bucket_header__'.length);
            if (rowId.startsWith('group-')) return rowId.slice(6);
            return null;
        };

        const getGroupAtY = (clientY) => {
            const groupRows = Array.from(container.querySelectorAll('.ng-group-row'));
            let current = null;
            for (const row of groupRows) {
                const rect = row.getBoundingClientRect();
                if (rect.top <= clientY) {
                    const tid = row.getAttribute('data-task-id');
                    if (tid) current = groupFromRowId(tid);
                }
            }
            return current;
        };

        const getInsertionPoint = (clientY, clientX) => {
            const allRows = Array.from(container.querySelectorAll('.ng-grid-row:not(.ng-group-row)')).filter(r => r !== dragRow && r !== spacer);
            let rowAbove = null, rowBelow = null;
            for (const row of allRows) {
                const rect = row.getBoundingClientRect();
                if (clientY < rect.top + rect.height / 2) { rowBelow = row; break; }
                rowAbove = row;
            }
            const aboveId = rowAbove ? rowAbove.getAttribute('data-task-id') : null;
            const belowId = rowBelow ? rowBelow.getAttribute('data-task-id') : null;
            const aboveDepth = aboveId != null ? (self._depthMap.get(aboveId) || 0) : -1;
            const aboveHasExpand = !!(rowAbove && rowAbove.querySelector('.ng-expand-icon'));
            const maxDepth = rowAbove == null ? 0 : (aboveHasExpand ? aboveDepth + 1 : aboveDepth);
            const depthDelta = Math.round((clientX - dragStartX) / 25);
            const desiredDepth = Math.max(0, Math.min(maxDepth, dragStartDepth + depthDelta));

            let parentId = null;
            if (desiredDepth > 0 && aboveId) {
                let curId = aboveId;
                while (curId) {
                    const d = self._depthMap.get(curId) || 0;
                    if (d === desiredDepth - 1) { parentId = curId; break; }
                    const row = self.rows.find(r => r.id === curId);
                    curId = row ? row.parentWorkItemId : null;
                }
            }

            const aboveRow = aboveId ? self.rows.find(r => r.id === aboveId) : null;
            const belowRow = belowId ? self.rows.find(r => r.id === belowId) : null;
            const sortAbove = aboveRow ? (aboveRow.sortOrder || 0) : 0;
            const sortBelow = belowRow ? (belowRow.sortOrder || sortAbove + 2) : sortAbove + 2;
            const targetSortOrder = (sortAbove + sortBelow) / 2;
            const targetBucket = getGroupAtY(clientY) || dragSourceGroup || '';

            return { parentId, depth: desiredDepth, targetBucket, targetSortOrder, insertBeforeRow: rowBelow };
        };

        const cleanupDrag = () => {
            if (ghost) { ghost.remove(); ghost = null; }
            if (spacer) { spacer.remove(); spacer = null; }
            if (dragRow) { dragRow.style.opacity = ''; dragRow.style.visibility = ''; dragRow.style.outline = ''; }
            document.body.style.cursor = '';
            dragTaskId = null; dragSourceGroup = null; dragRow = null;
            hasMoved = false; pendingIP = null;
            autoScrollVelocity = 0;
            if (autoScrollRAF != null) { cancelAnimationFrame(autoScrollRAF); autoScrollRAF = null; }
        };

        const onClickCapture = (e) => {
            if (didDrag) { e.preventDefault(); e.stopPropagation(); e.stopImmediatePropagation(); didDrag = false; }
        };

        const onMouseDown = (e) => {
            const row = e.target.closest('.ng-grid-row:not(.ng-group-row)');
            if (!row) return;
            const tag = e.target.tagName.toLowerCase();
            if (tag === 'input' || tag === 'button' || tag === 'select') return;
            const taskId = row.getAttribute('data-task-id');
            if (!taskId) return;
            const groupId = self._getTaskGroup(taskId);
            if (!groupId) return;
            e.preventDefault(); e.stopPropagation(); e.stopImmediatePropagation();
            dragTaskId = taskId; dragSourceGroup = groupId; dragRow = row;
            startX = e.clientX; startY = e.clientY;
            dragStartX = e.clientX;
            dragStartDepth = self._depthMap.get(taskId) || 0;
            hasMoved = false; didDrag = false; pendingIP = null;
            document.body.style.cursor = 'grabbing';
            row.style.outline = '2px solid #3b82f6';
        };

        const onMouseMove = (e) => {
            if (!dragTaskId || !dragRow) return;
            const dx = e.clientX - startX, dy = e.clientY - startY;
            if (!hasMoved && (Math.abs(dy) > DRAG_THRESHOLD || Math.abs(dx) > DRAG_THRESHOLD)) {
                hasMoved = true; didDrag = true;
                // Ghost
                const firstCell = dragRow.querySelector('td');
                ghost = document.createElement('div');
                ghost.style.cssText = [
                    'position:fixed;z-index:10000;pointer-events:none;',
                    `left:${e.clientX - 16}px;top:${e.clientY - 18}px;`,
                    `width:${Math.min(firstCell ? firstCell.offsetWidth : 200, 320)}px;`,
                    'background:#dbeafe;border:2px solid #2563eb;border-radius:8px;',
                    'box-shadow:0 16px 40px rgba(37,99,235,0.45);',
                    'padding:6px 12px;font-size:12px;font-weight:700;color:#1d4ed8;',
                    'white-space:nowrap;overflow:hidden;text-overflow:ellipsis;',
                    'cursor:grabbing;display:flex;align-items:center;gap:8px;',
                    'transform:rotate(-1.5deg) scale(1.04);',
                ].join('');
                ghost.innerHTML = `<span style="font-size:14px;opacity:0.6">⠿</span><span style="flex:1;overflow:hidden;text-overflow:ellipsis">${(firstCell ? firstCell.innerText : '').replace(/\s+/g,' ').slice(0,60)}</span>`;
                document.body.appendChild(ghost);
                // Spacer
                const tbody = dragRow.parentElement;
                if (tbody) {
                    spacer = document.createElement('tr');
                    spacer.setAttribute('data-drag-spacer','1');
                    spacer.style.cssText = 'pointer-events:none;';
                    const numCols = dragRow.querySelectorAll('td').length || 6;
                    const td = document.createElement('td');
                    td.setAttribute('colspan', String(numCols));
                    td.style.cssText = 'padding:0;height:34px;background:rgba(59,130,246,0.07);border-top:2px solid #3b82f6;border-bottom:2px solid rgba(59,130,246,0.3);';
                    const span = document.createElement('span');
                    span.style.cssText = 'display:flex;align-items:center;height:100%;padding-left:10px;font-size:10px;font-weight:700;color:#3b82f6;letter-spacing:0.05em;opacity:0.7;';
                    span.textContent = '↓ drop here';
                    td.appendChild(span); spacer.appendChild(td);
                    tbody.insertBefore(spacer, dragRow.nextSibling);
                }
                dragRow.style.opacity = '0.25'; dragRow.style.outline = '';
            }
            if (!hasMoved) return;
            if (ghost) { ghost.style.left = `${e.clientX - 12}px`; ghost.style.top = `${e.clientY - 14}px`; }
            // Auto-scroll
            const scrollEl = findScrollEl();
            if (scrollEl) {
                const srect = scrollEl.getBoundingClientRect();
                const EDGE = 60, MAX_SPEED = 18;
                let v = 0;
                if (e.clientY < srect.top + EDGE) v = -Math.ceil(MAX_SPEED * Math.min(1, (srect.top + EDGE - e.clientY) / EDGE));
                else if (e.clientY > srect.bottom - EDGE) v = Math.ceil(MAX_SPEED * Math.min(1, (e.clientY - (srect.bottom - EDGE)) / EDGE));
                autoScrollVelocity = v;
                if (v !== 0 && autoScrollRAF == null) autoScrollRAF = requestAnimationFrame(tickAutoScroll);
            }
            // Insertion point + spacer position
            const ip = getInsertionPoint(e.clientY, e.clientX);
            pendingIP = ip;
            if (spacer) {
                const tbody = dragRow && dragRow.parentElement;
                if (tbody) {
                    if (ip.insertBeforeRow && ip.insertBeforeRow !== spacer) tbody.insertBefore(spacer, ip.insertBeforeRow);
                    else if (!ip.insertBeforeRow) tbody.appendChild(spacer);
                }
                const indent = INDENT_BASE + ip.depth * LEAF_STEP;
                const label = spacer.querySelector('td span');
                if (label) label.style.paddingLeft = `${indent + 8}px`;
            }
        };

        const onMouseUp = async (e) => {
            autoScrollVelocity = 0;
            if (autoScrollRAF != null) { cancelAnimationFrame(autoScrollRAF); autoScrollRAF = null; }
            const savedId = dragTaskId, savedGroup = dragSourceGroup, savedMoved = hasMoved;
            const ip = pendingIP;
            cleanupDrag();
            if (!savedId || !savedGroup) return;
            if (!savedMoved) {
                // Treat as click — show detail panel
                const row = self.rows.find(r => r.id === savedId);
                if (row) {
                    const now = Date.now();
                    if (lastClickId === savedId && (now - lastClickTime) < 350) {
                        // Double-click: navigate to record
                        self.dispatchEvent(new CustomEvent('ganttnavigate', { bubbles: true, composed: true, detail: { recordId: savedId, objectApiName: 'WorkItem__c' } }));
                    }
                    lastClickId = savedId; lastClickTime = now;
                    // Show detail panel (same as handleTaskClick)
                    self.handleTaskClick({ id: savedId });
                }
                return;
            }
            if (!ip) return;
            // Apply the move via Apex
            const currentRow = self.rows.find(r => r.id === savedId);
            const promises = [];
            // Sort order always updates
            promises.push(updateWorkItemSortOrder({ workItemId: savedId, sortOrder: ip.targetSortOrder }));
            // Parent changed
            if (currentRow && (currentRow.parentWorkItemId || null) !== ip.parentId) {
                promises.push(updateWorkItemParent({ workItemId: savedId, parentId: ip.parentId || '' }));
            }
            // Bucket changed
            if (ip.targetBucket && ip.targetBucket !== savedGroup) {
                promises.push(updateWorkItemPriorityGroup({ workItemId: savedId, priorityGroup: ip.targetBucket }));
            }
            try {
                await Promise.all(promises);
            } catch (err) {
                self.handleError('Failed to save drag', err);
            }
            // Rebuild depth map and refresh
            self._buildDepthMap();
            if (self._scriptLoaded) await self.loadData();
        };

        container.addEventListener('click', onClickCapture, true);
        container.addEventListener('mousedown', onMouseDown, true);
        window.addEventListener('mousemove', onMouseMove, true);
        window.addEventListener('mouseup', onMouseUp, true);

        return () => {
            container.removeEventListener('click', onClickCapture, true);
            container.removeEventListener('mousedown', onMouseDown, true);
            window.removeEventListener('mousemove', onMouseMove, true);
            window.removeEventListener('mouseup', onMouseUp, true);
            cleanupDrag();
        };
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

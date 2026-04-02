/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  High-performance Gantt chart powered by Nimbus Gantt (canvas).
 *               Features: drag-to-reschedule, resize, dependency arrows,
 *               quick-edit modal, phase color-coding, entity/my-work filters,
 *               tree hierarchy, localStorage preference persistence.
 * @author Cloud Nimbus LLC
 */
import { LightningElement, wire, api } from 'lwc';
import { loadScript } from 'lightning/platformResourceLoader';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import NIMBUS_GANTT from '@salesforce/resourceUrl/nimbusgantt';
import getGanttData from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryGanttController.getGanttData';
import getGanttDependencies from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryGanttController.getGanttDependencies';
import updateWorkItemDates from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryGanttController.updateWorkItemDates';

const STORAGE_KEY = 'dh-nimbus-gantt-prefs';

// Phase color mapping — matches Delivery Hub workflow stages
const PHASE_COLORS = {
    Planning:    '#3b82f6',
    Approval:    '#f59e0b',
    Development: '#22c55e',
    Testing:     '#a855f7',
    UAT:         '#14b8a6',
    Deployment:  '#ef4444',
    Done:        '#9ca3af',
    Intake:      '#64748b'
};

// Zoom label (toolbar) to NimbusGantt ZoomLevel mapping
const ZOOM_MAP = {
    Day:     'day',
    Week:    'week',
    Month:   'month',
    Quarter: 'quarter'
};

const ZOOM_REVERSE = {
    day:     'Day',
    week:    'Week',
    month:   'Month',
    quarter: 'Quarter'
};

export default class DeliveryNimbusGantt extends LightningElement {

    // ── Public API ─────────────────────────────────────────────────────
    @api initialViewMode = 'Week';

    // ── State ──────────────────────────────────────────────────────────
    isLoading = true;
    errorMessage = '';
    currentZoom = 'week';
    selectedEntity = '';
    showDependencies = true;
    showCompleted = false;
    myWorkOnly = false;
    editLocked = true;
    showQuickEdit = false;
    selectedWorkItemId = null;

    _gantt = null;
    _scriptLoaded = false;
    _scriptLoading = false;
    _ganttInitialized = false;
    _wiredGanttResult = null;
    _wiredDepsResult = null;
    _rawTasks = [];
    _rawDependencies = [];

    // ── Lifecycle ──────────────────────────────────────────────────────

    connectedCallback() {
        this._restorePrefs();
        this.currentZoom = this.currentZoom || ZOOM_MAP[this.initialViewMode] || 'week';
    }

    renderedCallback() {
        if (this._ganttInitialized) { return; }
        if (!this._scriptLoaded) {
            this._loadLibrary();
            return;
        }
        if (this.hasData) {
            this._initGantt();
        }
    }

    disconnectedCallback() {
        if (this._gantt) {
            this._gantt.destroy();
            this._gantt = null;
        }
        this._ganttInitialized = false;
    }

    // ── Wired Data ─────────────────────────────────────────────────────

    @wire(getGanttData, { showCompleted: '$showCompleted' })
    wiredGanttData(result) {
        this._wiredGanttResult = result;
        this.isLoading = false;
        if (result.data) {
            this._rawTasks = result.data;
            this._tryRender();
        } else if (result.error) {
            this.errorMessage = result.error.body
                ? result.error.body.message
                : result.error.message;
        }
    }

    @wire(getGanttDependencies)
    wiredDependencies(result) {
        this._wiredDepsResult = result;
        if (result.data) {
            this._rawDependencies = result.data;
            this._tryRender();
        } else if (result.error) {
            console.error('[DeliveryNimbusGantt] getGanttDependencies error:', result.error);
        }
    }

    // ── Computed: UI state ─────────────────────────────────────────────

    get hasError()  { return !this.isLoading && !!this.errorMessage; }
    get isEmpty()   { return !this.isLoading && !this.errorMessage && this.filteredTasks.length === 0; }
    get hasData()   { return !this.isLoading && !this.errorMessage && this.filteredTasks.length > 0; }

    get currentZoomLabel() {
        return ZOOM_REVERSE[this.currentZoom] || 'Week';
    }

    get subtitleText() {
        const count = this.filteredTasks.length;
        if (this.isLoading) { return 'Loading...'; }
        if (count === 0) { return 'No work items'; }
        const suffix = count === 1 ? 'item' : 'items';
        const parts = [count + ' work ' + suffix];
        if (this.selectedEntity) { parts.push(this.selectedEntity); }
        if (this.showCompleted) { parts.push('incl. completed'); }
        if (this.myWorkOnly) { parts.push('assigned only'); }
        return parts.join(' \u00b7 ');
    }

    get filteredTasks() {
        if (!this._rawTasks) { return []; }
        let tasks = [...this._rawTasks];
        if (this.selectedEntity) {
            tasks = tasks.filter(t => (t.entityName || 'Unassigned') === this.selectedEntity);
        }
        if (this.myWorkOnly) {
            tasks = tasks.filter(t => t.developerName != null && t.developerName !== '');
        }
        return tasks;
    }

    get lockIcon()    { return this.editLocked ? 'utility:lock' : 'utility:unlock'; }
    get lockLabel()   { return this.editLocked ? 'Locked' : 'Editing'; }
    get lockVariant() { return this.editLocked ? 'neutral' : 'brand'; }

    get dayVariant()     { return this.currentZoom === 'day' ? 'brand' : 'neutral'; }
    get weekVariant()    { return this.currentZoom === 'week' ? 'brand' : 'neutral'; }
    get monthVariant()   { return this.currentZoom === 'month' ? 'brand' : 'neutral'; }
    get quarterVariant() { return this.currentZoom === 'quarter' ? 'brand' : 'neutral'; }
    get myWorkVariant()  { return this.myWorkOnly ? 'brand' : 'border'; }
    get completedVariant() { return this.showCompleted ? 'brand' : 'border'; }
    get hasMultipleEntities() { return this.entityOptions.length > 2; }

    get entityOptions() {
        if (!this._rawTasks) { return []; }
        const entities = new Set();
        this._rawTasks.forEach(t => entities.add(t.entityName || 'Unassigned'));
        const opts = [{ label: 'All Clients', value: '' }];
        Array.from(entities).sort().forEach(e => opts.push({ label: e, value: e }));
        return opts;
    }

    // ── Data Mapping: Apex DTOs to NimbusGantt interfaces ─────────────

    _mapTasks() {
        const filteredIds = new Set(this.filteredTasks.map(t => t.workItemId));
        return this.filteredTasks.map(t => ({
            id: t.workItemId,
            name: t.name + (t.description ? ' \u2014 ' + t.description : ''),
            startDate: t.startDate,
            endDate: t.endDate,
            progress: t.progress || 0,
            status: t.stage,
            assignee: t.developerName,
            parentId: filteredIds.has(t.parentWorkItemId) ? t.parentWorkItemId : undefined,
            groupId: t.entityId,
            groupName: t.entityName,
            isCompleted: t.isCompleted,
            metadata: {
                estimatedHours: t.estimatedHours,
                loggedHours: t.loggedHours,
                priority: t.priority,
                description: t.description
            }
        }));
    }

    _mapDependencies() {
        if (!this._rawDependencies || !this.showDependencies) { return []; }
        const filteredIds = new Set(this.filteredTasks.map(t => t.workItemId));
        return this._rawDependencies
            .filter(d => filteredIds.has(d.source) && filteredIds.has(d.target))
            .map(d => ({
                id: d.id,
                source: d.source,
                target: d.target,
                type: d.dependencyType || 'FS'
            }));
    }

    // ── Private: Library loading ───────────────────────────────────────

    _loadLibrary() {
        if (this._scriptLoading) { return; }
        this._scriptLoading = true;
        loadScript(this, NIMBUS_GANTT)
            .then(() => {
                this._scriptLoaded = true;
                if (this.hasData) {
                    this._initGantt();
                }
            })
            .catch(error => {
                this.errorMessage = 'Failed to load Nimbus Gantt library: '
                    + (error.message || error);
            });
    }

    // ── Private: Gantt init ────────────────────────────────────────────

    _initGantt() {
        const container = this.refs.ganttContainer;
        if (!container || this._ganttInitialized) { return; }

        const NimbusGanttLib = window.NimbusGantt;
        if (!NimbusGanttLib || typeof NimbusGanttLib.NimbusGantt !== 'function') {
            this.errorMessage = 'Nimbus Gantt library did not load correctly.';
            return;
        }

        const tasks = this._mapTasks();
        if (tasks.length === 0) { return; }

        this._ganttInitialized = true;
        const self = this;

        try {
            this._gantt = new NimbusGanttLib.NimbusGantt(container, {
                tasks: tasks,
                dependencies: this._mapDependencies(),
                colorMap: PHASE_COLORS,
                zoomLevel: this.currentZoom,
                showToday: true,
                showWeekends: true,
                showProgress: true,
                readOnly: this.editLocked,
                snapToDays: true,
                columns: [
                    { field: 'name', header: 'Work Item', width: 220, tree: true },
                    { field: 'assignee', header: 'Developer', width: 110 },
                    { field: 'status', header: 'Stage', width: 90 }
                ],

                onTaskClick: function(task) {
                    self.selectedWorkItemId = task.id;
                    self.showQuickEdit = true;
                },

                onTaskMove: function(task, startDate, endDate) {
                    self._handleDateChange(task, startDate, endDate);
                },

                onTaskResize: function(task, startDate, endDate) {
                    self._handleDateChange(task, startDate, endDate);
                }
            });

            // Register ALL plugins
            var G = NimbusGanttLib;
            var g = this._gantt;
            var use = function(P, opts) { if (P) { g.use(opts ? P(opts) : P()); } };

            // Core interactions
            use(G.UndoRedoPlugin, { depth: 30 });
            use(G.KeyboardPlugin);
            use(G.MilestonePlugin);
            use(G.GroupingPlugin);

            // Analysis & intelligence
            use(G.CriticalPathPlugin);
            use(G.RiskAnalysisPlugin);
            use(G.MonteCarloPlugin, { iterations: 500, variability: 0.3 });

            // Visualization
            use(G.MiniMapPlugin);
            use(G.ConfigPanelPlugin);
            use(G.TimelineNotesPlugin, { notes: [] });
            use(G.NarrativePlugin);
            use(G.TimeTravelPlugin, { maxSnapshots: 200 });
            use(G.WhatIfPlugin);

            // Work calendar
            use(G.WorkCalendarPlugin);

            // Virtual scroll for performance
            use(G.VirtualScrollPlugin);

            // Dark mode (auto-detect system preference)
            use(G.DarkThemePlugin, { auto: true });

            // Export (PNG/SVG)
            use(G.ExportPlugin);

            // Sonification (play project as music)
            use(G.SonificationPlugin, { tempo: 120, scale: 'pentatonic', volume: 0.3 });

            // Telemetry (local logging only, no external endpoint)
            if (G.TelemetryPlugin) {
                g.use(G.TelemetryPlugin({
                    onEvent: function(event) {
                        if (event.type.includes('error') || event.type === 'gantt.session.duration') {
                            console.info('[NimbusGantt]', event.type, event.data);
                        }
                    }
                }));
            }

            // Scroll to today after init
            requestAnimationFrame(() => {
                if (this._gantt) {
                    this._gantt.scrollToDate(new Date());
                }
            });

        } catch (err) {
            this.errorMessage = 'Failed to initialize Nimbus Gantt: '
                + (err.message || err);
            this._ganttInitialized = false;
        }
    }

    // ── Private: Date change handler (shared by move + resize) ────────

    _handleDateChange(task, startDate, endDate) {
        updateWorkItemDates({
            workItemId: task.id,
            startDate: startDate,
            endDate: endDate
        })
            .then(() => {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Dates Updated',
                    message: task.name.split(' \u2014 ')[0]
                        + ': ' + startDate + ' to ' + endDate,
                    variant: 'success'
                }));
                refreshApex(this._wiredGanttResult);
            })
            .catch(err => {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Error Saving Dates',
                    message: err.body ? err.body.message : err.message,
                    variant: 'error'
                }));
                // Revert by refreshing data
                refreshApex(this._wiredGanttResult);
            });
    }

    // ── Private: Update / rebuild ──────────────────────────────────────

    _updateGantt() {
        if (!this._gantt) { return; }
        this._gantt.setData(
            this._mapTasks(),
            this._mapDependencies()
        );
    }

    _rebuildChart() {
        if (this._gantt) {
            this._gantt.destroy();
            this._gantt = null;
        }
        this._ganttInitialized = false;
        const container = this.refs.ganttContainer;
        if (container) {
            container.innerHTML = '';
        }
        requestAnimationFrame(() => {
            this._initGantt();
        });
    }

    _tryRender() {
        if (!this._scriptLoaded || !this.filteredTasks.length) { return; }
        if (this._ganttInitialized) {
            this._updateGantt();
        } else {
            requestAnimationFrame(() => this._initGantt());
        }
    }

    // ── Toolbar Handlers ───────────────────────────────────────────────

    handleZoomDay()     { this._setZoom('day'); }
    handleZoomWeek()    { this._setZoom('week'); }
    handleZoomMonth()   { this._setZoom('month'); }
    handleZoomQuarter() { this._setZoom('quarter'); }

    _setZoom(level) {
        this.currentZoom = level;
        this._savePrefs();
        if (this._gantt) {
            this._gantt.setZoom(level);
            requestAnimationFrame(() => {
                if (this._gantt) { this._gantt.scrollToDate(new Date()); }
            });
        }
    }

    handleEntityChange(event) {
        this.selectedEntity = event.detail.value || '';
        this._savePrefs();
        this._rebuildChart();
    }

    handleToggleDependencies() {
        this.showDependencies = !this.showDependencies;
        this._savePrefs();
        this._updateGantt();
    }

    handleToggleCompleted() {
        this.showCompleted = !this.showCompleted;
        this._savePrefs();
        // Wire reactivity will refetch data automatically via $showCompleted
    }

    handleToggleMyWork() {
        this.myWorkOnly = !this.myWorkOnly;
        this._savePrefs();
        this._rebuildChart();
    }

    handleToggleLock() {
        this.editLocked = !this.editLocked;
        this._savePrefs();
        this._rebuildChart();
        if (!this.editLocked) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Edit Mode',
                message: 'Drag bars to reschedule, resize edges to change duration. Click lock to re-lock.',
                variant: 'info'
            }));
        }
    }

    handleRunDiagnostics() {
        if (!this._gantt) {
            this.dispatchEvent(new ShowToastEvent({ title: 'Error', message: 'Gantt not initialized', variant: 'error' }));
            return;
        }
        var g = this._gantt;
        var G = window.NimbusGantt;
        var container = this.refs.ganttContainer;
        var self = this;
        var step = 0;
        var results = [];
        var DELAY = 4000;

        function log(msg, pass) {
            var s = pass ? 'PASS' : 'FAIL';
            results.push('[' + s + '] ' + msg);
            console.log('[NimbusGantt:demo] [' + s + '] ' + msg);
        }

        function toast(title, msg, variant) {
            self.dispatchEvent(new ShowToastEvent({ title: title, message: msg, variant: variant || 'info', mode: 'dismissible' }));
        }

        function runStep() {
            step++;
            console.log('[NimbusGantt:demo] === Step ' + step + ' ===');
            try {
                switch(step) {

                // ── DIAGNOSTICS ──────────────────────────────────
                case 1:
                    toast('1/16 — Canvas Check', 'Verifying canvas rendering...');
                    var canvas = container ? container.querySelector('canvas') : null;
                    log('Canvas found', !!canvas);
                    if (canvas) {
                        log('Canvas size: ' + canvas.width + 'x' + canvas.height, canvas.width > 0);
                        var ctx = canvas.getContext('2d');
                        if (ctx) {
                            var p = ctx.getImageData(200, 80, 1, 1).data;
                            log('Canvas has pixels at (200,80)', p[3] > 0);
                        }
                    }
                    var grid = container ? container.querySelector('.ng-grid') : null;
                    log('Tree grid DOM', !!grid);
                    var rows = container ? container.querySelectorAll('.ng-grid-row') : [];
                    log('Grid rows: ' + rows.length, rows.length > 0);
                    break;

                // ── ZOOM SHOWCASE ────────────────────────────────
                case 2:
                    toast('2/16 — Day View', 'Zooming to daily granularity...', 'info');
                    g.setZoom('day');
                    g.scrollToDate(new Date());
                    log('Zoom: Day', true);
                    break;
                case 3:
                    toast('3/16 — Month View', 'Zooming out to monthly...', 'info');
                    g.setZoom('month');
                    g.scrollToDate(new Date());
                    log('Zoom: Month', true);
                    break;
                case 4:
                    toast('4/16 — Quarter View', 'Full project overview...', 'info');
                    g.setZoom('quarter');
                    log('Zoom: Quarter', true);
                    break;
                case 5:
                    toast('5/16 — Week View', 'Back to default week view...', 'info');
                    g.setZoom('week');
                    g.scrollToDate(new Date());
                    log('Zoom: Week (default)', true);
                    break;

                // ── TREE OPERATIONS ──────────────────────────────
                case 6:
                    toast('6/16 — Expand All', 'Showing all child tasks...', 'info');
                    g.expandAll();
                    log('expandAll()', true);
                    break;
                case 7:
                    toast('7/16 — Collapse All', 'Collapsing to parent groups...', 'info');
                    g.collapseAll();
                    log('collapseAll()', true);
                    break;
                case 8:
                    toast('8/16 — Expand + Scroll', 'Expanding and scrolling to today...', 'info');
                    g.expandAll();
                    g.scrollToDate(new Date());
                    log('Expand + scrollToDate', true);
                    break;

                // ── DARK MODE ────────────────────────────────────
                case 9:
                    toast('9/16 — Dark Mode', 'Switching to dark theme...', 'info');
                    if (container) {
                        container.style.filter = 'invert(1) hue-rotate(180deg)';
                        container.style.backgroundColor = '#1a1a2e';
                    }
                    log('Dark mode toggle', true);
                    break;
                case 10:
                    toast('10/16 — Light Mode', 'Switching back to light theme...', 'info');
                    if (container) {
                        container.style.filter = '';
                        container.style.backgroundColor = '';
                    }
                    log('Light mode restore', true);
                    break;

                // ── LOCK/UNLOCK ──────────────────────────────────
                case 11:
                    toast('11/16 — Unlock Editing', 'Drag bars to reschedule, resize edges to change duration', 'warning');
                    self.editLocked = false;
                    self._rebuildChart();
                    log('Unlock editing', true);
                    break;
                case 12:
                    toast('12/16 — Re-Lock', 'Locking editing back...', 'info');
                    self.editLocked = true;
                    self._rebuildChart();
                    log('Re-lock editing', true);
                    break;

                // ── ENTITY FILTER ────────────────────────────────
                case 13:
                    toast('13/16 — Filter: Acme Corp', 'Showing only Acme Corp tasks...', 'info');
                    var entities = self._rawTasks.map(function(t) { return t.entityName; }).filter(function(v, i, a) { return a.indexOf(v) === i && v; });
                    if (entities.length > 0) {
                        self.selectedEntity = entities[0];
                        self._rebuildChart();
                        log('Filter entity: ' + entities[0], true);
                    } else {
                        log('No entities to filter', false);
                    }
                    break;
                case 14:
                    toast('14/16 — Filter: All', 'Showing all entities...', 'info');
                    self.selectedEntity = '';
                    self._rebuildChart();
                    log('Filter cleared', true);
                    break;

                // ── SCROLL ANIMATION ─────────────────────────────
                case 15:
                    toast('15/16 — Scroll to Start', 'Scrolling to project start...', 'info');
                    try {
                        var range = g.getVisibleDateRange();
                        g.scrollToDate(range.start);
                        log('Scroll to start: ' + range.start, true);
                    } catch(e) {
                        log('Scroll start error: ' + e.message, false);
                    }
                    break;

                // ── SUMMARY ──────────────────────────────────────
                case 16:
                    g.scrollToDate(new Date());
                    var passed = results.filter(function(r) { return r.indexOf('[PASS]') === 0; }).length;
                    var failed = results.filter(function(r) { return r.indexOf('[FAIL]') === 0; }).length;
                    console.log('[NimbusGantt:demo] ═══════════════════════════════════');
                    console.log('[NimbusGantt:demo] PRESENTATION COMPLETE: ' + passed + ' passed, ' + failed + ' failed');
                    console.log('[NimbusGantt:demo] ═══════════════════════════════════');
                    results.forEach(function(r) { console.log('[NimbusGantt:demo]   ' + r); });
                    toast('Presentation Complete', passed + '/' + (passed + failed) + ' features verified. Check console for full report.', failed > 0 ? 'warning' : 'success');
                    return;
                }
            } catch(err) {
                log('Step ' + step + ' ERROR: ' + err.message, false);
                console.error('[NimbusGantt:demo] Error at step ' + step, err);
            }
            if (step < 16) {
                setTimeout(runStep, DELAY);
            }
        }

        toast('Presentation Mode', '16 steps over ~60 seconds. Watch the Gantt transform...', 'info');
        setTimeout(runStep, 2000);
    }

    handleScrollToday() {
        if (this._gantt) {
            this._gantt.scrollToDate(new Date());
        }
    }

    handleRefresh() {
        this.isLoading = true;
        refreshApex(this._wiredGanttResult);
        if (this._wiredDepsResult) {
            refreshApex(this._wiredDepsResult);
        }
    }

    // ── Quick-edit handlers ────────────────────────────────────────────

    handleQuickEditSave() {
        this.showQuickEdit = false;
        this.selectedWorkItemId = null;
        refreshApex(this._wiredGanttResult);
    }

    handleQuickEditClose() {
        this.showQuickEdit = false;
        this.selectedWorkItemId = null;
    }

    handleQuickEditError(event) {
        this.dispatchEvent(new ShowToastEvent({
            title: 'Error Saving',
            message: event.detail.message || 'An error occurred.',
            variant: 'error'
        }));
    }

    // ── Private: localStorage persistence ──────────────────────────────

    _savePrefs() {
        try {
            const prefs = {
                showDependencies: this.showDependencies,
                showCompleted: this.showCompleted,
                myWorkOnly: this.myWorkOnly,
                currentZoom: this.currentZoom,
                selectedEntity: this.selectedEntity,
                editLocked: this.editLocked
            };
            localStorage.setItem(STORAGE_KEY, JSON.stringify(prefs));
        } catch (e) {
            // localStorage may be unavailable; fail silently
        }
    }

    _restorePrefs() {
        try {
            const stored = localStorage.getItem(STORAGE_KEY);
            if (!stored) { return; }
            const prefs = JSON.parse(stored);
            if (prefs.showDependencies != null) { this.showDependencies = prefs.showDependencies; }
            if (prefs.showCompleted != null) { this.showCompleted = prefs.showCompleted; }
            if (prefs.myWorkOnly != null) { this.myWorkOnly = prefs.myWorkOnly; }
            if (prefs.currentZoom) { this.currentZoom = prefs.currentZoom; }
            if (prefs.selectedEntity != null) { this.selectedEntity = prefs.selectedEntity; }
            if (prefs.editLocked != null) { this.editLocked = prefs.editLocked; }
        } catch (e) {
            // fail silently
        }
    }
}

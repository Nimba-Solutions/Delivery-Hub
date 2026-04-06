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
import { subscribe, unsubscribe, onError } from 'lightning/empApi';
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

// Ordered zoom levels for swipe zoom in/out
const ZOOM_LEVELS = ['day', 'week', 'month', 'quarter'];

// Platform Event channel for phone remote control
const REMOTE_EVENT_CHANNEL = '/event/%%%NAMESPACE_DOT%%%GanttRemoteEvent__e';

export default class DeliveryNimbusGantt extends LightningElement {

    // ── Public API ─────────────────────────────────────────────────────
    @api recordId;
    @api initialViewMode = 'Week';

    // ── State ──────────────────────────────────────────────────────────
    isLoading = true;
    errorMessage = '';
    currentZoom = 'week';
    selectedEntity = '';
    showDependencies = true;
    showCompleted = false;
    showOverdue = false;
    myWorkOnly = false;
    editLocked = true;
    currentView = 'gantt';
    showQuickEdit = false;
    selectedWorkItemId = null;
    _selectedTaskIndex = -1;

    // ── Demo state ───────────────────────────────────────────────────
    isDemoRunning = false;
    demoStepLabel = '';
    demoStepDescription = '';
    _demoTimer = null;

    // ── Remote control state ──────────────────────────────────────────
    showRemoteModal = false;
    _remoteSessionId = '';
    _remoteSubscription = null;
    _remoteLinkCopied = false;

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
        if (!this.recordId) {
            this._generateRemoteSessionId();
            this._subscribeRemoteEvents();
        }
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
        if (this._resizeObserver) {
            this._resizeObserver.disconnect();
            this._resizeObserver = null;
        }
        if (this._gantt) {
            this._gantt.destroy();
            this._gantt = null;
        }
        this._ganttInitialized = false;
        this._unsubscribeRemoteEvents();
    }

    // ── Wired Data ─────────────────────────────────────────────────────

    @wire(getGanttData, { showCompleted: '$showCompleted' })
    wiredGanttData(result) {
        this._wiredGanttResult = result;
        this.isLoading = false;
        if (result.data) {
            this._rawTasks = result.data;
            // In compact/record page mode, auto-filter to the current record's entity
            if (this.recordId && !this.selectedEntity) {
                const match = result.data.find(t => t.workItemId === this.recordId);
                if (match && match.entityName) {
                    this.selectedEntity = match.entityName;
                }
            }
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

    get isCompactMode() { return !!this.recordId; }
    get isFullMode()    { return !this.recordId; }
    get hasError()  { return !this.isLoading && !!this.errorMessage; }
    get isEmpty()   { return !this.isLoading && !this.errorMessage && this.filteredTasks.length === 0; }
    get hasData()   { return !this.isLoading && !this.errorMessage && this.filteredTasks.length > 0; }

    get currentZoomLabel() {
        return ZOOM_REVERSE[this.currentZoom] || 'Week';
    }

    get toolbarClass() {
        return this.isCompactMode ? 'gantt-toolbar gantt-toolbar--compact' : 'gantt-toolbar';
    }

    get toolbarTitle() {
        return this.isCompactMode ? 'Related Timeline' : 'Project Timeline';
    }

    get subtitleText() {
        const count = this.filteredTasks.length;
        if (this.isLoading) { return 'Loading...'; }
        if (count === 0) { return 'No work items'; }
        const suffix = count === 1 ? 'item' : 'items';
        const parts = [count + ' work ' + suffix];
        if (this.selectedEntity) { parts.push(this.selectedEntity); }
        if (this.showCompleted) { parts.push('incl. completed'); }
        if (this.showOverdue) { parts.push('overdue only'); }
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
        if (this.showOverdue) {
            var now = Date.now();
            tasks = tasks.filter(function(t) {
                if (t.isCompleted) { return false; }
                if (!t.endDate) { return false; }
                return new Date(t.endDate).getTime() < now;
            });
        }
        return tasks;
    }

    get isGanttView()       { return this.currentView === 'gantt'; }
    get isAltView()         { return this.currentView !== 'gantt'; }
    get ganttViewVariant()  { return this.currentView === 'gantt' ? 'brand' : 'neutral'; }
    get treemapViewVariant() { return this.currentView === 'treemap' ? 'brand' : 'neutral'; }
    get bubblesViewVariant() { return this.currentView === 'bubbles' ? 'brand' : 'neutral'; }
    get calendarViewVariant() { return this.currentView === 'calendar' ? 'brand' : 'neutral'; }
    get flowViewVariant()   { return this.currentView === 'flow' ? 'brand' : 'neutral'; }
    get networkViewVariant() { return this.currentView === 'network' ? 'brand' : 'neutral'; }
    get sankeyViewVariant() { return this.currentView === 'sankey' ? 'brand' : 'neutral'; }

    get lockIcon()    { return this.editLocked ? 'utility:lock' : 'utility:unlock'; }
    get lockLabel()   { return this.editLocked ? 'Locked' : 'Editing'; }
    get lockVariant() { return this.editLocked ? 'neutral' : 'brand'; }

    get dayVariant()     { return this.currentZoom === 'day' ? 'brand' : 'neutral'; }
    get weekVariant()    { return this.currentZoom === 'week' ? 'brand' : 'neutral'; }
    get monthVariant()   { return this.currentZoom === 'month' ? 'brand' : 'neutral'; }
    get quarterVariant() { return this.currentZoom === 'quarter' ? 'brand' : 'neutral'; }
    get myWorkVariant()  { return this.myWorkOnly ? 'brand' : 'border'; }
    get completedVariant() { return this.showCompleted ? 'brand' : 'border'; }
    get overdueVariant() { return this.showOverdue ? 'brand' : 'border'; }
    get dependenciesVariant() { return this.showDependencies ? 'brand' : 'border'; }

    get hasActiveFilters() {
        return !!this.selectedEntity || this.myWorkOnly || this.showOverdue || this.showCompleted;
    }

    get activeFilterText() {
        var parts = [];
        if (this.selectedEntity) { parts.push(this.selectedEntity); }
        if (this.myWorkOnly) { parts.push('My Work'); }
        if (this.showOverdue) { parts.push('Overdue Only'); }
        if (this.showCompleted) { parts.push('Incl. Completed'); }
        return parts.join(' \u00b7 ');
    }

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

            // Observe container resize to reinit Gantt at new dimensions
            // ResizeObserver may not exist in Lightning Locker — degrade gracefully
            try {
                if (!this._resizeObserver) {
                    let resizeTimeout;
                    this._resizeObserver = new ResizeObserver(() => {
                        clearTimeout(resizeTimeout);
                        // eslint-disable-next-line @lwc/lwc/no-async-operation
                        resizeTimeout = setTimeout(() => {
                            if (this._gantt) {
                                this._gantt.destroy();
                                this._gantt = null;
                                this._ganttInitialized = false;
                                this._initGantt();
                            }
                        }, 300);
                    });
                    this._resizeObserver.observe(container);
                }
            } catch (_ignored) {
                // ResizeObserver unavailable — Gantt still works, just won't auto-resize
            }

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

    handleToggleOverdue() {
        this.showOverdue = !this.showOverdue;
        this._savePrefs();
        this._rebuildChart();
    }

    handleClearFilters() {
        this.selectedEntity = '';
        this.myWorkOnly = false;
        this.showOverdue = false;
        this.showCompleted = false;
        this._savePrefs();
        this._rebuildChart();
    }

    handleStopDemo() {
        this.isDemoRunning = false;
        this.demoStepLabel = '';
        this.demoStepDescription = '';
        if (this._demoTimer) {
            clearTimeout(this._demoTimer);
            this._demoTimer = null;
        }
    }

    // ── View Switching ──────────────────────────────────────────────
    handleViewGantt()    { this.currentView = 'gantt'; this._rebuildChart(); }
    handleViewTreemap()  { this.currentView = 'treemap'; this._renderAltViz(); }
    handleViewBubbles()  { this.currentView = 'bubbles'; this._renderAltViz(); }
    handleViewCalendar() { this.currentView = 'calendar'; this._renderAltViz(); }
    handleViewFlow()     { this.currentView = 'flow'; this._renderAltViz(); }
    handleViewNetwork()  { this.currentView = 'network'; this._renderAltViz(); }
    handleViewSankey()   { this.currentView = 'sankey'; this._renderAltViz(); }

    _renderAltViz() {
        var self = this;
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        requestAnimationFrame(function() {
            var canvas = self.refs.altCanvas;
            if (!canvas) { return; }
            var container = canvas.parentElement;
            var w = container.clientWidth || 900;
            var h = container.clientHeight || 500;
            var dpr = window.devicePixelRatio || 1;
            canvas.width = w * dpr;
            canvas.height = h * dpr;
            canvas.style.width = w + 'px';
            canvas.style.height = h + 'px';
            var ctx = canvas.getContext('2d');
            ctx.scale(dpr, dpr);
            ctx.clearRect(0, 0, w, h);

            var tasks = self.filteredTasks;
            var colors = { Submitted: '#3b82f6', 'In Development': '#22c55e', 'Code Review': '#a855f7', 'UAT Ready': '#14b8a6', Deployment: '#f97316', Done: '#6b7280', Backlog: '#64748b' };

            // Capture previous positions for animation
            var prevPositions = self._vizPositions || null;
            var prevView = self._vizPrevView || null;
            self._vizPrevView = self.currentView;

            // Draw the new view (this populates self._vizPositions)
            switch(self.currentView) {
                case 'treemap': self._drawTreemap(ctx, w, h, tasks, colors); break;
                case 'bubbles': self._drawBubbles(ctx, w, h, tasks, colors); break;
                case 'calendar': self._drawCalendar(ctx, w, h, tasks, colors); break;
                case 'flow': self._drawFlow(ctx, w, h, tasks, colors); break;
                case 'network': self._drawNetwork(ctx, w, h, tasks, colors); break;
                case 'sankey': self._drawSankey(ctx, w, h, tasks, colors); break;
            }

            // Animate transition if we have previous positions from a different view
            if (prevPositions && prevView && prevView !== self.currentView && self._vizPositions) {
                self._animateTransition(ctx, w, h, dpr, prevPositions, self._vizPositions, canvas);
            }
        });
    }

    _animateTransition(ctx, w, h, dpr, fromPos, toPos, canvas) {
        var duration = 450;
        var startTime = performance.now();
        var self = this;

        function ease(t) { return 1 - Math.pow(1 - t, 3); }

        function drawFrame(now) {
            var elapsed = now - startTime;
            var progress = Math.min(elapsed / duration, 1);
            var t = ease(progress);

            ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
            ctx.clearRect(0, 0, w, h);
            ctx.fillStyle = '#f8fafc';
            ctx.fillRect(0, 0, w, h);

            // Interpolate each task's position
            var allIds = new Set();
            Object.keys(fromPos).forEach(function(id) { allIds.add(id); });
            Object.keys(toPos).forEach(function(id) { allIds.add(id); });

            allIds.forEach(function(id) {
                var a = fromPos[id];
                var b = toPos[id];
                if (!a && !b) { return; }
                if (!a) { a = b; }
                if (!b) { b = a; }

                var cx = a.x + (b.x - a.x) * t;
                var cy = a.y + (b.y - a.y) * t;
                var cw = (a.w || 20) + ((b.w || 20) - (a.w || 20)) * t;
                var ch = (a.h || 20) + ((b.h || 20) - (a.h || 20)) * t;
                var cr = (a.r || 0) + ((b.r || 0) - (a.r || 0)) * t;
                var color = b.color || a.color || '#94a3b8';
                var alpha = 0.5 + 0.5 * t;

                ctx.globalAlpha = alpha;
                ctx.fillStyle = color;

                if (cr > cw * 0.4) {
                    // Draw as circle
                    ctx.beginPath();
                    ctx.arc(cx + cw / 2, cy + ch / 2, cr, 0, Math.PI * 2);
                    ctx.fill();
                } else {
                    // Draw as rounded rect
                    var radius = Math.min(cw, ch) * 0.15 * (1 - t) + Math.min(cw, ch) * 0.15 * t;
                    ctx.beginPath();
                    ctx.roundRect(cx, cy, Math.max(cw, 4), Math.max(ch, 4), Math.max(radius, 2));
                    ctx.fill();
                }
                ctx.globalAlpha = 1;
            });

            if (progress < 1) {
                // eslint-disable-next-line @lwc/lwc/no-async-operation
                requestAnimationFrame(drawFrame);
            } else {
                // Final frame: redraw the actual view cleanly
                ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
                ctx.clearRect(0, 0, w, h);
                var tasks = self.filteredTasks;
                var colors2 = { Submitted: '#3b82f6', 'In Development': '#22c55e', 'Code Review': '#a855f7', 'UAT Ready': '#14b8a6', Deployment: '#f97316', Done: '#6b7280', Backlog: '#64748b' };
                switch(self.currentView) {
                    case 'treemap': self._drawTreemap(ctx, w, h, tasks, colors2); break;
                    case 'bubbles': self._drawBubbles(ctx, w, h, tasks, colors2); break;
                    case 'calendar': self._drawCalendar(ctx, w, h, tasks, colors2); break;
                    case 'flow': self._drawFlow(ctx, w, h, tasks, colors2); break;
                    case 'network': self._drawNetwork(ctx, w, h, tasks, colors2); break;
                    case 'sankey': self._drawSankey(ctx, w, h, tasks, colors2); break;
                }
            }
        }

        // eslint-disable-next-line @lwc/lwc/no-async-operation
        requestAnimationFrame(drawFrame);
    }

    _drawTreemap(ctx, w, h, tasks, colors) {
        ctx.fillStyle = '#f8fafc';
        ctx.fillRect(0, 0, w, h);
        ctx.fillStyle = '#111827';
        ctx.font = 'bold 16px -apple-system, sans-serif';
        ctx.fillText('Treemap — Size = Estimated Hours, Color = Stage', 20, 30);

        var total = 0;
        tasks.forEach(function(t) { total += (t.estimatedHours || 1); });
        if (total === 0) { total = 1; }

        var sorted = tasks.slice().sort(function(a, b) { return (b.estimatedHours || 1) - (a.estimatedHours || 1); });

        // --- Squarified treemap layout ---
        function worstRatio(row, sideLen) {
            var s = 0;
            row.forEach(function(v) { s += v; });
            if (s === 0 || sideLen === 0) { return Infinity; }
            var s2 = s * s;
            var maxV = -Infinity; var minV = Infinity;
            row.forEach(function(v) { if (v > maxV) { maxV = v; } if (v < minV) { minV = v; } });
            var r1 = (sideLen * sideLen * maxV) / s2;
            var r2 = s2 / (sideLen * sideLen * minV);
            return Math.max(r1, r2);
        }

        function squarify(items, rect) {
            if (items.length === 0) { return []; }
            if (items.length === 1) {
                return [{ x: rect.x, y: rect.y, w: rect.w, h: rect.h, task: items[0].task }];
            }
            var totalArea = 0;
            items.forEach(function(it) { totalArea += it.area; });
            if (totalArea === 0) { totalArea = 1; }

            var results = [];
            var remaining = items.slice();
            var cx = rect.x; var cy = rect.y; var cw = rect.w; var ch = rect.h;

            while (remaining.length > 0) {
                var isHorizontal = cw >= ch;
                var sideLen = isHorizontal ? ch : cw;
                var row = [];
                var rowAreas = [];
                var remTotal = 0;
                remaining.forEach(function(it) { remTotal += it.area; });
                var scaleFactor = (cw * ch) / (remTotal || 1);

                row.push(remaining[0]);
                rowAreas.push(remaining[0].area * scaleFactor);
                var best = worstRatio(rowAreas, sideLen);
                var idx = 1;

                while (idx < remaining.length) {
                    var testAreas = rowAreas.slice();
                    testAreas.push(remaining[idx].area * scaleFactor);
                    var testRatio = worstRatio(testAreas, sideLen);
                    if (testRatio <= best) {
                        row.push(remaining[idx]);
                        rowAreas.push(remaining[idx].area * scaleFactor);
                        best = testRatio;
                        idx++;
                    } else {
                        break;
                    }
                }

                remaining = remaining.slice(idx);
                var rowTotal = 0;
                rowAreas.forEach(function(a) { rowTotal += a; });

                if (isHorizontal) {
                    var rowW = rowTotal / (sideLen || 1);
                    var oy = cy;
                    row.forEach(function(item, ri) {
                        var itemH = rowAreas[ri] / (rowW || 1);
                        results.push({ x: cx, y: oy, w: rowW - 2, h: itemH - 2, task: item.task });
                        oy += itemH;
                    });
                    cx += rowW;
                    cw -= rowW;
                } else {
                    var rowH = rowTotal / (sideLen || 1);
                    var ox = cx;
                    row.forEach(function(item, ri) {
                        var itemW = rowAreas[ri] / (rowH || 1);
                        results.push({ x: ox, y: cy, w: itemW - 2, h: rowH - 2, task: item.task });
                        ox += itemW;
                    });
                    cy += rowH;
                    ch -= rowH;
                }
            }
            return results;
        }

        var legendH = 40;
        var areaRect = { x: 10, y: 50, w: w - 20, h: h - 60 - legendH };
        var items = sorted.map(function(t) { return { task: t, area: t.estimatedHours || 1 }; });
        var rects = squarify(items, areaRect);

        // Find largest rect for glow highlight
        var largestIdx = 0; var largestArea = 0;
        rects.forEach(function(r, i) {
            var a = r.w * r.h;
            if (a > largestArea) { largestArea = a; largestIdx = i; }
        });

        var today = new Date();

        rects.forEach(function(r, i) {
            var color = colors[r.task.stage] || '#94a3b8';
            var rw = Math.max(r.w, 4); var rh = Math.max(r.h, 4);

            // Gradient fill (top lighter, bottom darker)
            var grad = ctx.createLinearGradient(r.x, r.y, r.x, r.y + rh);
            grad.addColorStop(0, color);
            grad.addColorStop(1, color + 'b0');
            ctx.fillStyle = grad;
            ctx.beginPath();
            ctx.roundRect(r.x, r.y, rw, rh, 6);
            ctx.fill();

            // Overdue red tint overlay
            var endMs = r.task.endDate ? new Date(r.task.endDate).getTime() : 0;
            if (endMs > 0 && endMs < today.getTime() && !r.task.isCompleted) {
                ctx.fillStyle = 'rgba(239, 68, 68, 0.18)';
                ctx.beginPath();
                ctx.roundRect(r.x, r.y, rw, rh, 6);
                ctx.fill();
            }

            // Inner shadow: darker border on bottom-right
            ctx.save();
            ctx.beginPath();
            ctx.roundRect(r.x, r.y, rw, rh, 6);
            ctx.clip();
            ctx.strokeStyle = 'rgba(0,0,0,0.25)';
            ctx.lineWidth = 1.5;
            ctx.beginPath();
            ctx.moveTo(r.x + rw, r.y + 4);
            ctx.lineTo(r.x + rw, r.y + rh);
            ctx.lineTo(r.x + 4, r.y + rh);
            ctx.stroke();
            // Top-left highlight
            ctx.strokeStyle = 'rgba(255,255,255,0.25)';
            ctx.lineWidth = 1;
            ctx.beginPath();
            ctx.moveTo(r.x, r.y + rh - 4);
            ctx.lineTo(r.x, r.y);
            ctx.lineTo(r.x + rw - 4, r.y);
            ctx.stroke();
            ctx.restore();

            // Glow on largest rect
            if (i === largestIdx) {
                ctx.save();
                ctx.shadowColor = color;
                ctx.shadowBlur = 12;
                ctx.strokeStyle = color;
                ctx.lineWidth = 2;
                ctx.beginPath();
                ctx.roundRect(r.x, r.y, rw, rh, 6);
                ctx.stroke();
                ctx.restore();
            }

            // Text layout
            if (rw > 60 && rh > 30) {
                ctx.fillStyle = '#ffffff';
                ctx.font = 'bold 11px -apple-system, sans-serif';
                var label = r.task.name + (r.task.description ? ' \u2014 ' + r.task.description : '');
                var maxChars = Math.floor(rw / 7);
                if (label.length > maxChars) { label = label.substring(0, maxChars) + '\u2026'; }
                ctx.fillText(label, r.x + 8, r.y + 18);

                // Line 2: hours + stage badge
                var hours = (r.task.estimatedHours || 0) + 'h';
                var stage = r.task.stage || '';
                ctx.font = '10px -apple-system, sans-serif';
                ctx.fillText(hours, r.x + 8, r.y + 32);

                if (stage && rw > 100) {
                    var badgeX = r.x + 8 + ctx.measureText(hours + '  ').width;
                    var badgeW = ctx.measureText(stage).width + 10;
                    ctx.fillStyle = 'rgba(255,255,255,0.25)';
                    ctx.beginPath();
                    ctx.roundRect(badgeX, r.y + 23, badgeW, 14, 3);
                    ctx.fill();
                    ctx.fillStyle = '#ffffff';
                    ctx.font = '9px -apple-system, sans-serif';
                    ctx.fillText(stage, badgeX + 5, r.y + 33);
                }
            }
        });

        // Legend bar at bottom
        var ly = h - legendH + 5;
        var lx = 10;
        ctx.fillStyle = '#6b7280';
        ctx.font = '11px -apple-system, sans-serif';
        ctx.fillText('Stages:', lx, ly + 12);
        lx += 52;
        var stagesSeen = {};
        tasks.forEach(function(t) { if (t.stage) { stagesSeen[t.stage] = true; } });
        Object.keys(stagesSeen).forEach(function(s) {
            var c = colors[s] || '#94a3b8';
            ctx.fillStyle = c;
            ctx.beginPath();
            ctx.roundRect(lx, ly, 12, 12, 2);
            ctx.fill();
            ctx.fillStyle = '#374151';
            ctx.font = '10px -apple-system, sans-serif';
            ctx.fillText(s, lx + 16, ly + 10);
            lx += ctx.measureText(s).width + 30;
        });

        // Cache positions for animated transitions
        var positions = {};
        rects.forEach(function(r) {
            positions[r.task.workItemId] = { x: r.x, y: r.y, w: r.w, h: r.h, r: 0, color: colors[r.task.stage] || '#94a3b8' };
        });
        this._vizPositions = positions;
    }

    _drawBubbles(ctx, w, h, tasks, colors) {
        ctx.fillStyle = '#f8fafc';
        ctx.fillRect(0, 0, w, h);
        ctx.fillStyle = '#111827';
        ctx.font = 'bold 16px -apple-system, sans-serif';
        ctx.fillText('Bubble Chart \u2014 Size = Hours, X = Timeline, Y = Entity, Color = Stage', 20, 30);

        var today = new Date();
        var entities = [];
        tasks.forEach(function(t) {
            var en = t.entityName || 'Unassigned';
            if (entities.indexOf(en) === -1) { entities.push(en); }
        });

        var padL = 140; var padR = 40; var padT = 60; var padB = 50;
        var plotW = w - padL - padR;
        var plotH = h - padT - padB;

        // Find date range
        var minDate = Infinity; var maxDate = -Infinity;
        tasks.forEach(function(t) {
            if (t.startDate) { var d = new Date(t.startDate).getTime(); if (d < minDate) { minDate = d; } }
            if (t.endDate) { var d2 = new Date(t.endDate).getTime(); if (d2 > maxDate) { maxDate = d2; } }
        });
        if (minDate === Infinity) { minDate = today.getTime() - 30 * 86400000; maxDate = today.getTime() + 30 * 86400000; }
        var dateSpan = maxDate - minDate || 1;

        // Dashed gridlines (vertical, time-based)
        var numVLines = Math.min(Math.floor(plotW / 80), 10);
        ctx.setLineDash([3, 4]);
        ctx.strokeStyle = '#e5e7eb';
        ctx.lineWidth = 0.5;
        for (var vi = 0; vi <= numVLines; vi++) {
            var gx = padL + (vi / numVLines) * plotW;
            ctx.beginPath();
            ctx.moveTo(gx, padT);
            ctx.lineTo(gx, h - padB);
            ctx.stroke();
        }
        ctx.setLineDash([]);

        // X-axis tick marks + date labels
        ctx.fillStyle = '#9ca3af';
        ctx.font = '10px -apple-system, sans-serif';
        ctx.textAlign = 'center';
        for (var ti = 0; ti <= numVLines; ti++) {
            var tx = padL + (ti / numVLines) * plotW;
            var tickDate = new Date(minDate + (ti / numVLines) * dateSpan);
            var tickLabel = (tickDate.getUTCMonth() + 1) + '/' + tickDate.getUTCDate();
            ctx.beginPath();
            ctx.moveTo(tx, h - padB);
            ctx.lineTo(tx, h - padB + 5);
            ctx.strokeStyle = '#9ca3af';
            ctx.lineWidth = 1;
            ctx.stroke();
            ctx.fillText(tickLabel, tx, h - padB + 16);
        }
        ctx.textAlign = 'left';

        // Y axis labels with horizontal gridlines (dashed)
        ctx.fillStyle = '#374151';
        ctx.font = '12px -apple-system, sans-serif';
        entities.forEach(function(e, i) {
            var y = padT + (i + 0.5) * (plotH / entities.length);
            ctx.fillText(e, 10, y + 4);
            // Y-axis tick
            ctx.strokeStyle = '#9ca3af';
            ctx.lineWidth = 1;
            ctx.beginPath();
            ctx.moveTo(padL - 4, y);
            ctx.lineTo(padL, y);
            ctx.stroke();
            // Dashed gridline
            ctx.setLineDash([3, 4]);
            ctx.strokeStyle = '#e5e7eb';
            ctx.lineWidth = 0.5;
            ctx.beginPath();
            ctx.moveTo(padL, y);
            ctx.lineTo(w - padR, y);
            ctx.stroke();
            ctx.setLineDash([]);
        });

        // Axes border
        ctx.strokeStyle = '#d1d5db';
        ctx.lineWidth = 1;
        ctx.beginPath();
        ctx.moveTo(padL, padT);
        ctx.lineTo(padL, h - padB);
        ctx.lineTo(w - padR, h - padB);
        ctx.stroke();

        // Today line
        var todayX = padL + ((today.getTime() - minDate) / dateSpan) * plotW;
        ctx.strokeStyle = '#ef4444';
        ctx.lineWidth = 1.5;
        ctx.setLineDash([4, 4]);
        ctx.beginPath();
        ctx.moveTo(todayX, padT);
        ctx.lineTo(todayX, h - padB);
        ctx.stroke();
        ctx.setLineDash([]);
        ctx.fillStyle = '#ef4444';
        ctx.font = 'bold 10px -apple-system, sans-serif';
        ctx.textAlign = 'center';
        ctx.fillText('Today', todayX, h - padB + 16);
        ctx.textAlign = 'left';

        // Build bubble positions for dependency lines
        var bubblePos = {};
        tasks.forEach(function(t, idx) {
            if (!t.startDate) { return; }
            var startMs = new Date(t.startDate).getTime();
            var endMs = t.endDate ? new Date(t.endDate).getTime() : startMs + 14 * 86400000;
            var midMs = (startMs + endMs) / 2;
            var bx = padL + ((midMs - minDate) / dateSpan) * plotW;
            var entityIdx = entities.indexOf(t.entityName || 'Unassigned');
            var by = padT + (entityIdx + 0.5) * (plotH / entities.length);
            // Subtle floating: randomize Y by +/-3px based on index
            by += ((idx % 7) - 3) * 1;
            var hours = t.estimatedHours || 5;
            var radius = Math.max(Math.min(Math.sqrt(hours) * 4, 40), 8);
            bubblePos[t.workItemId] = { x: bx, y: by, radius: radius };
        });

        // Dependency connecting lines (thin, curved)
        if (this._rawDependencies) {
            ctx.strokeStyle = 'rgba(100,116,139,0.35)';
            ctx.lineWidth = 1;
            this._rawDependencies.forEach(function(dep) {
                var src = bubblePos[dep.source];
                var tgt = bubblePos[dep.target];
                if (src && tgt) {
                    ctx.beginPath();
                    var cpX = (src.x + tgt.x) / 2;
                    var cpY = Math.min(src.y, tgt.y) - 20;
                    ctx.moveTo(src.x + src.radius, src.y);
                    ctx.quadraticCurveTo(cpX, cpY, tgt.x - tgt.radius, tgt.y);
                    ctx.stroke();
                    // Small arrowhead
                    var angle = Math.atan2(tgt.y - cpY, tgt.x - tgt.radius - cpX);
                    ctx.fillStyle = 'rgba(100,116,139,0.5)';
                    ctx.beginPath();
                    ctx.moveTo(tgt.x - tgt.radius, tgt.y);
                    ctx.lineTo(tgt.x - tgt.radius - 6 * Math.cos(angle - 0.4), tgt.y - 6 * Math.sin(angle - 0.4));
                    ctx.lineTo(tgt.x - tgt.radius - 6 * Math.cos(angle + 0.4), tgt.y - 6 * Math.sin(angle + 0.4));
                    ctx.closePath();
                    ctx.fill();
                }
            });
        }

        // Draw bubbles
        tasks.forEach(function(t, idx) {
            if (!t.startDate) { return; }
            var bp = bubblePos[t.workItemId];
            if (!bp) { return; }
            var bx = bp.x; var by = bp.y; var radius = bp.radius;
            var hours = t.estimatedHours || 5;
            var color = colors[t.stage] || '#94a3b8';
            var endMs = t.endDate ? new Date(t.endDate).getTime() : 0;
            var overdue = endMs > 0 && endMs < today.getTime();

            // Drop shadow
            ctx.save();
            ctx.shadowColor = 'rgba(0,0,0,0.15)';
            ctx.shadowBlur = 4;
            ctx.shadowOffsetX = 2;
            ctx.shadowOffsetY = 2;
            ctx.fillStyle = color;
            ctx.beginPath();
            ctx.arc(bx, by, radius, 0, Math.PI * 2);
            ctx.fill();
            ctx.restore();

            // Radial gradient fill (center lighter, edge darker)
            var radGrad = ctx.createRadialGradient(bx - radius * 0.3, by - radius * 0.3, radius * 0.1, bx, by, radius);
            radGrad.addColorStop(0, color + 'dd');
            radGrad.addColorStop(0.5, color);
            radGrad.addColorStop(1, color + '99');
            ctx.globalAlpha = 0.85;
            ctx.fillStyle = radGrad;
            ctx.beginPath();
            ctx.arc(bx, by, radius, 0, Math.PI * 2);
            ctx.fill();
            ctx.globalAlpha = 1;

            // Progress ring
            var progress = t.progress || 0;
            if (progress > 0) {
                ctx.strokeStyle = 'rgba(255,255,255,0.85)';
                ctx.lineWidth = 2.5;
                ctx.beginPath();
                ctx.arc(bx, by, radius + 3, -Math.PI / 2, -Math.PI / 2 + (progress / 100) * Math.PI * 2);
                ctx.stroke();
                // Track (dimmer full ring)
                ctx.strokeStyle = 'rgba(255,255,255,0.2)';
                ctx.lineWidth = 2;
                ctx.beginPath();
                ctx.arc(bx, by, radius + 3, 0, Math.PI * 2);
                ctx.stroke();
            }

            // Overdue ring
            if (overdue) {
                ctx.strokeStyle = '#ef4444';
                ctx.lineWidth = 2.5;
                ctx.beginPath();
                ctx.arc(bx, by, radius + (progress > 0 ? 6 : 3), 0, Math.PI * 2);
                ctx.stroke();
            }

            // White border
            ctx.strokeStyle = 'rgba(255,255,255,0.7)';
            ctx.lineWidth = 1;
            ctx.beginPath();
            ctx.arc(bx, by, radius, 0, Math.PI * 2);
            ctx.stroke();

            // Labels
            if (radius > 12) {
                ctx.fillStyle = '#ffffff';
                ctx.font = 'bold 9px -apple-system, sans-serif';
                ctx.textAlign = 'center';
                var name = t.name;
                var maxLen = Math.floor(radius * 2 / 6);
                if (name.length > maxLen) { name = name.substring(0, maxLen) + '\u2026'; }
                ctx.fillText(name, bx, by - 2);
                ctx.font = '8px -apple-system, sans-serif';
                ctx.fillText(hours + 'h', bx, by + 9);
                ctx.textAlign = 'left';
            }
        });

        // Cache positions for animated transitions
        var bPositions = {};
        tasks.forEach(function(t2) {
            var bp2 = bubblePos[t2.workItemId];
            if (bp2) {
                bPositions[t2.workItemId] = { x: bp2.x - bp2.radius, y: bp2.y - bp2.radius, w: bp2.radius * 2, h: bp2.radius * 2, r: bp2.radius, color: colors[t2.stage] || '#94a3b8' };
            }
        });
        this._vizPositions = bPositions;
    }

    _drawCalendar(ctx, w, h, tasks, colors) {
        ctx.fillStyle = '#f8fafc';
        ctx.fillRect(0, 0, w, h);
        ctx.fillStyle = '#111827';
        ctx.font = 'bold 16px -apple-system, sans-serif';
        ctx.fillText('Calendar Heatmap \u2014 Task density per day', 20, 30);

        var today = new Date();
        var todayKey = today.toISOString().slice(0, 10);
        var minDate = Infinity; var maxDate = -Infinity;
        tasks.forEach(function(t) {
            if (t.startDate) { var d = new Date(t.startDate).getTime(); if (d < minDate) { minDate = d; } }
            if (t.endDate) { var d2 = new Date(t.endDate).getTime(); if (d2 > maxDate) { maxDate = d2; } }
        });
        if (minDate === Infinity) { return; }

        // Build day counts
        var dayCounts = {};
        var MS_DAY = 86400000;
        tasks.forEach(function(t) {
            if (!t.startDate || !t.endDate) { return; }
            var s = new Date(t.startDate).getTime();
            var e = new Date(t.endDate).getTime();
            for (var d = s; d <= e; d += MS_DAY) {
                var key = new Date(d).toISOString().slice(0, 10);
                dayCounts[key] = (dayCounts[key] || 0) + 1;
            }
        });

        var maxCount = 0;
        Object.keys(dayCounts).forEach(function(k) { if (dayCounts[k] > maxCount) { maxCount = dayCounts[k]; } });
        if (maxCount === 0) { maxCount = 1; }

        // Larger cells
        var cellSize = 22;
        var gap = 3;
        var padL = 80;
        var padT = 65;
        var startDate = new Date(minDate);
        startDate.setUTCDate(startDate.getUTCDate() - startDate.getUTCDay()); // align to Sunday

        // Day name labels
        var dayNames = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
        dayNames.forEach(function(d, i) {
            ctx.fillStyle = '#6b7280';
            ctx.font = '10px -apple-system, sans-serif';
            ctx.textAlign = 'right';
            ctx.fillText(d, padL - 8, padT + i * (cellSize + gap) + 15);
        });
        ctx.textAlign = 'left';

        var col = 0;
        var current = new Date(startDate);
        var endDt = new Date(maxDate);
        endDt.setUTCDate(endDt.getUTCDate() + 7);
        var todayCellX = 0; var todayCellY = 0; var foundToday = false;

        // Track week numbers for left axis
        var drawnWeeks = {};

        while (current <= endDt) {
            var key = current.toISOString().slice(0, 10);
            var dow = current.getUTCDay();
            var count = dayCounts[key] || 0;
            var x = padL + col * (cellSize + gap);
            var y = padT + dow * (cellSize + gap);

            // Week number label on left (first time we see this week)
            if (dow === 0) {
                var oneJan = new Date(Date.UTC(current.getUTCFullYear(), 0, 1));
                var weekNum = Math.ceil(((current.getTime() - oneJan.getTime()) / MS_DAY + oneJan.getUTCDay() + 1) / 7);
                var weekKey = current.getUTCFullYear() + '-W' + weekNum;
                if (!drawnWeeks[weekKey] && col > 0) {
                    ctx.fillStyle = '#9ca3af';
                    ctx.font = '9px -apple-system, sans-serif';
                    ctx.textAlign = 'center';
                    ctx.fillText('W' + weekNum, x + cellSize / 2, padT - 22);
                    ctx.textAlign = 'left';
                    drawnWeeks[weekKey] = true;
                }
            }

            if (dow === 0 && col > 0) {
                // Month label on first Sunday of month - larger and bolder
                if (current.getUTCDate() <= 7) {
                    var months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
                    ctx.fillStyle = '#1f2937';
                    ctx.font = 'bold 13px -apple-system, sans-serif';
                    ctx.fillText(months[current.getUTCMonth()], x, padT - 10);
                }
            }

            // Blue color ramp: gray -> light blue -> blue -> dark blue
            var intensity = count / maxCount;
            var cr, cg, cb;
            if (count === 0) {
                cr = 235; cg = 238; cb = 241; // gray
            } else if (intensity < 0.25) {
                cr = 191; cg = 219; cb = 254; // light blue
            } else if (intensity < 0.5) {
                cr = 96; cg = 165; cb = 250; // medium blue
            } else if (intensity < 0.75) {
                cr = 59; cg = 130; cb = 246; // blue
            } else {
                cr = 29; cg = 78; cb = 216; // dark blue
            }

            ctx.fillStyle = 'rgb(' + cr + ',' + cg + ',' + cb + ')';
            ctx.beginPath();
            ctx.roundRect(x, y, cellSize, cellSize, 3);
            ctx.fill();

            // Subtle cell border
            ctx.strokeStyle = count === 0 ? 'rgba(209,213,219,0.5)' : 'rgba(59,130,246,0.3)';
            ctx.lineWidth = 0.5;
            ctx.beginPath();
            ctx.roundRect(x, y, cellSize, cellSize, 3);
            ctx.stroke();

            // Count number inside cells with 3+ tasks
            if (count >= 3) {
                ctx.fillStyle = '#ffffff';
                ctx.font = 'bold 10px -apple-system, sans-serif';
                ctx.textAlign = 'center';
                ctx.fillText(count.toString(), x + cellSize / 2, y + cellSize / 2 + 4);
                ctx.textAlign = 'left';
            }

            // Today highlight
            if (key === todayKey) {
                ctx.save();
                ctx.shadowColor = '#ef4444';
                ctx.shadowBlur = 6;
                ctx.strokeStyle = '#ef4444';
                ctx.lineWidth = 2;
                ctx.beginPath();
                ctx.roundRect(x - 1, y - 1, cellSize + 2, cellSize + 2, 4);
                ctx.stroke();
                ctx.restore();
                todayCellX = x;
                todayCellY = y;
                foundToday = true;
            }

            current.setUTCDate(current.getUTCDate() + 1);
            if (dow === 6) { col++; }
        }

        // Today label below highlighted cell
        if (foundToday) {
            ctx.fillStyle = '#ef4444';
            ctx.font = 'bold 9px -apple-system, sans-serif';
            ctx.textAlign = 'center';
            ctx.fillText('Today', todayCellX + cellSize / 2, todayCellY + cellSize + 12);
            ctx.textAlign = 'left';
        }

        // Legend with blue ramp
        var lx = padL;
        var ly = padT + 7 * (cellSize + gap) + 25;
        ctx.fillStyle = '#6b7280';
        ctx.font = '11px -apple-system, sans-serif';
        ctx.fillText('Less', lx, ly + 14);
        var legendColors = ['#ebedf1', '#bfdbfe', '#60a5fa', '#3b82f6', '#1d4ed8'];
        legendColors.forEach(function(c, i) {
            ctx.fillStyle = c;
            ctx.beginPath();
            ctx.roundRect(lx + 36 + i * (cellSize + 3), ly, cellSize, cellSize, 3);
            ctx.fill();
            ctx.strokeStyle = 'rgba(0,0,0,0.1)';
            ctx.lineWidth = 0.5;
            ctx.stroke();
        });
        ctx.fillStyle = '#6b7280';
        ctx.fillText('More', lx + 36 + 5 * (cellSize + 3) + 4, ly + 14);
    }

    _drawFlow(ctx, w, h, tasks, colors) {
        ctx.fillStyle = '#f8fafc';
        ctx.fillRect(0, 0, w, h);
        ctx.fillStyle = '#111827';
        ctx.font = 'bold 16px -apple-system, sans-serif';
        ctx.fillText('Stage Flow \u2014 Tasks flowing through workflow stages', 20, 30);

        // Count tasks per stage
        var stages = ['Backlog', 'Submitted', 'In Development', 'Code Review', 'UAT Ready', 'Deployment', 'Done'];
        var stageCounts = {};
        stages.forEach(function(s) { stageCounts[s] = 0; });
        var totalTasks = 0;
        tasks.forEach(function(t) {
            var s = t.stage || 'Backlog';
            if (stageCounts[s] !== undefined) { stageCounts[s]++; }
            else { stageCounts[s] = 1; stages.push(s); }
            totalTasks++;
        });
        if (totalTasks === 0) { totalTasks = 1; }

        var padL = 30; var padR = 30; var padT = 70; var padB = 70;
        var plotW = w - padL - padR;
        var plotH = h - padT - padB;
        var colW = plotW / stages.length;
        var maxCount = 0;
        var maxStageIdx = 0;
        stages.forEach(function(s, i) {
            if (stageCounts[s] > maxCount) { maxCount = stageCounts[s]; maxStageIdx = i; }
        });
        if (maxCount === 0) { maxCount = 1; }

        // Detect bottleneck: stage with most non-Done tasks accumulating
        var bottleneckIdx = -1;
        var bottleneckMax = 0;
        stages.forEach(function(s, i) {
            if (s !== 'Done' && s !== 'Backlog' && stageCounts[s] > bottleneckMax) {
                bottleneckMax = stageCounts[s];
                bottleneckIdx = i;
            }
        });
        // Only mark as bottleneck if it has at least 3 tasks and is the clear leader
        if (bottleneckMax < 3) { bottleneckIdx = -1; }

        // Draw curved Bezier flow lines between stages first (behind bars)
        stages.forEach(function(s, i) {
            if (i >= stages.length - 1) { return; }
            var count = stageCounts[s];
            var nextCount = stageCounts[stages[i + 1]];
            var flowCount = Math.min(count, nextCount);
            if (flowCount === 0 && count === 0) { return; }

            var x1 = padL + i * colW + colW - 8;
            var x2 = padL + (i + 1) * colW + 8;
            var barH1 = (count / maxCount) * plotH;
            var barH2 = (nextCount / maxCount) * plotH;
            var midY1 = padT + plotH - barH1 / 2;
            var midY2 = padT + plotH - barH2 / 2;

            var lineW = Math.max(1.5, Math.min(Math.max(count, nextCount) * 1.5, 8));
            var cpOffset = (x2 - x1) * 0.45;
            var color1 = colors[s] || '#94a3b8';
            var color2 = colors[stages[i + 1]] || '#94a3b8';

            // Gradient along the curve
            var lineGrad = ctx.createLinearGradient(x1, 0, x2, 0);
            lineGrad.addColorStop(0, color1 + '80');
            lineGrad.addColorStop(1, color2 + '80');

            ctx.strokeStyle = lineGrad;
            ctx.lineWidth = lineW;
            ctx.lineCap = 'round';
            ctx.beginPath();
            ctx.moveTo(x1, midY1);
            ctx.bezierCurveTo(x1 + cpOffset, midY1, x2 - cpOffset, midY2, x2, midY2);
            ctx.stroke();

            // Subtle arrowhead at end
            ctx.fillStyle = color2 + '90';
            var angle = Math.atan2(midY2 - midY1, x2 - x1 + cpOffset);
            ctx.beginPath();
            ctx.moveTo(x2, midY2);
            ctx.lineTo(x2 - 8, midY2 - 5);
            ctx.lineTo(x2 - 8, midY2 + 5);
            ctx.closePath();
            ctx.fill();
        });

        // Draw pill-shaped bars
        stages.forEach(function(s, i) {
            var x = padL + i * colW;
            var count = stageCounts[s];
            var barH = Math.max((count / maxCount) * plotH, count > 0 ? 20 : 0);
            var barY = padT + plotH - barH;
            var color = colors[s] || '#94a3b8';
            var barW = colW - 20;
            var barX = x + 10;
            var pillRadius = Math.min(barW / 2, 14);

            // Gradient fill (top lighter, bottom darker)
            var barGrad = ctx.createLinearGradient(barX, barY, barX, barY + barH);
            barGrad.addColorStop(0, color);
            barGrad.addColorStop(1, color + 'a0');

            // Pulsing glow on stage with most tasks
            if (i === maxStageIdx && count > 0) {
                ctx.save();
                ctx.shadowColor = color;
                ctx.shadowBlur = 14;
                ctx.fillStyle = color + '30';
                ctx.beginPath();
                ctx.roundRect(barX - 4, barY - 4, barW + 8, barH + 8, pillRadius + 4);
                ctx.fill();
                ctx.restore();
            }

            // Pill bar
            ctx.fillStyle = barGrad;
            ctx.beginPath();
            ctx.roundRect(barX, barY, barW, barH, pillRadius);
            ctx.fill();

            // Light top highlight
            if (barH > 10) {
                ctx.fillStyle = 'rgba(255,255,255,0.15)';
                ctx.beginPath();
                ctx.roundRect(barX + 2, barY + 1, barW - 4, Math.min(barH * 0.4, 20), [pillRadius - 1, pillRadius - 1, 0, 0]);
                ctx.fill();
            }

            // Bottleneck indicator (red outline)
            if (i === bottleneckIdx) {
                ctx.save();
                ctx.shadowColor = '#ef4444';
                ctx.shadowBlur = 6;
                ctx.strokeStyle = '#ef4444';
                ctx.lineWidth = 2;
                ctx.setLineDash([4, 3]);
                ctx.beginPath();
                ctx.roundRect(barX - 2, barY - 2, barW + 4, barH + 4, pillRadius + 2);
                ctx.stroke();
                ctx.setLineDash([]);
                ctx.restore();

                // Bottleneck label
                ctx.fillStyle = '#ef4444';
                ctx.font = 'bold 9px -apple-system, sans-serif';
                ctx.textAlign = 'center';
                ctx.fillText('BOTTLENECK', x + colW / 2, barY - 8);
            }

            // Percentage label inside bar
            var pct = Math.round((count / totalTasks) * 100);
            if (barH > 40) {
                ctx.fillStyle = '#ffffff';
                ctx.font = 'bold 18px -apple-system, sans-serif';
                ctx.textAlign = 'center';
                ctx.fillText(count.toString(), x + colW / 2, barY + barH / 2 + 2);
                ctx.font = '11px -apple-system, sans-serif';
                ctx.fillStyle = 'rgba(255,255,255,0.85)';
                ctx.fillText(pct + '%', x + colW / 2, barY + barH / 2 + 18);
            } else if (barH > 20) {
                ctx.fillStyle = '#ffffff';
                ctx.font = 'bold 13px -apple-system, sans-serif';
                ctx.textAlign = 'center';
                ctx.fillText(count.toString(), x + colW / 2, barY + barH / 2 + 5);
            }

            // Stage label below
            ctx.fillStyle = '#374151';
            ctx.font = '11px -apple-system, sans-serif';
            var label = s;
            if (label.length > 12) { label = label.substring(0, 11) + '\u2026'; }
            ctx.fillText(label, x + colW / 2, h - padB + 16);
            ctx.textAlign = 'left';
        });

        // Percentage strip at bottom with rounded ends
        var stripY = h - 30;
        var stripH = 14;
        var stripX = padL;
        var stripRadius = stripH / 2;

        // Draw full rounded background
        ctx.fillStyle = '#e5e7eb';
        ctx.beginPath();
        ctx.roundRect(padL, stripY, plotW, stripH, stripRadius);
        ctx.fill();

        // Draw segments clipped to the rounded rect
        ctx.save();
        ctx.beginPath();
        ctx.roundRect(padL, stripY, plotW, stripH, stripRadius);
        ctx.clip();
        var segX = padL;
        stages.forEach(function(s) {
            var pct = stageCounts[s] / totalTasks;
            var segW = pct * plotW;
            if (segW > 0) {
                ctx.fillStyle = colors[s] || '#94a3b8';
                ctx.fillRect(segX, stripY, segW, stripH);
                segX += segW;
            }
        });
        ctx.restore();

        // Strip border
        ctx.strokeStyle = 'rgba(0,0,0,0.1)';
        ctx.lineWidth = 1;
        ctx.beginPath();
        ctx.roundRect(padL, stripY, plotW, stripH, stripRadius);
        ctx.stroke();
    }

    // ── Network Graph — Force-directed dependency visualization ──────

    _drawNetwork(ctx, w, h, tasks, colors) {
        ctx.fillStyle = '#f8fafc';
        ctx.fillRect(0, 0, w, h);
        ctx.fillStyle = '#111827';
        ctx.font = 'bold 16px -apple-system, sans-serif';
        ctx.fillText('Dependency Network \u2014 Force-directed layout, drag to rearrange', 20, 30);

        if (tasks.length === 0) {
            ctx.fillStyle = '#9ca3af';
            ctx.font = '14px -apple-system, sans-serif';
            ctx.fillText('No tasks to display', w / 2 - 60, h / 2);
            return;
        }

        var padL = 40; var padR = 40; var padT = 50; var padB = 40;
        var plotW = w - padL - padR;
        var plotH = h - padT - padB;
        var centerX = padL + plotW / 2;
        var centerY = padT + plotH / 2;

        // Build node map
        var nodes = [];
        var nodeMap = {};
        tasks.forEach(function(t, i) {
            var angle = (2 * Math.PI * i) / tasks.length;
            var radius = Math.min(plotW, plotH) * 0.35;
            var node = {
                id: t.workItemId,
                x: centerX + radius * Math.cos(angle),
                y: centerY + radius * Math.sin(angle),
                vx: 0, vy: 0,
                name: t.name || '',
                stage: t.stage || 'Backlog',
                hours: t.estimatedHours || 0,
                assignee: t.developerName || '',
                color: colors[t.stage] || '#94a3b8'
            };
            nodes.push(node);
            nodeMap[t.workItemId] = node;
        });

        // Build edges from dependencies
        var edges = [];
        if (this._rawDependencies) {
            this._rawDependencies.forEach(function(dep) {
                if (nodeMap[dep.source] && nodeMap[dep.target]) {
                    edges.push({ source: nodeMap[dep.source], target: nodeMap[dep.target] });
                }
            });
        }

        // Fruchterman-Reingold force simulation
        var k = Math.sqrt((plotW * plotH) / Math.max(nodes.length, 1)) * 0.8;
        var temperature = Math.min(plotW, plotH) * 0.1;
        var iterations = 150;

        for (var iter = 0; iter < iterations; iter++) {
            // Repulsive forces between all pairs
            for (var i = 0; i < nodes.length; i++) {
                nodes[i].vx = 0;
                nodes[i].vy = 0;
                for (var j = 0; j < nodes.length; j++) {
                    if (i === j) { continue; }
                    var dx = nodes[i].x - nodes[j].x;
                    var dy = nodes[i].y - nodes[j].y;
                    var dist = Math.sqrt(dx * dx + dy * dy) || 1;
                    var repForce = (k * k) / dist;
                    nodes[i].vx += (dx / dist) * repForce;
                    nodes[i].vy += (dy / dist) * repForce;
                }
            }

            // Attractive forces along edges
            edges.forEach(function(e) {
                var dx = e.target.x - e.source.x;
                var dy = e.target.y - e.source.y;
                var dist = Math.sqrt(dx * dx + dy * dy) || 1;
                var attForce = (dist * dist) / k;
                var fx = (dx / dist) * attForce;
                var fy = (dy / dist) * attForce;
                e.source.vx += fx;
                e.source.vy += fy;
                e.target.vx -= fx;
                e.target.vy -= fy;
            });

            // Center gravity
            nodes.forEach(function(n) {
                var dx = centerX - n.x;
                var dy = centerY - n.y;
                n.vx += dx * 0.01;
                n.vy += dy * 0.01;
            });

            // Apply with temperature damping
            var t2 = temperature * (1 - iter / iterations);
            nodes.forEach(function(n) {
                var mag = Math.sqrt(n.vx * n.vx + n.vy * n.vy) || 1;
                n.x += (n.vx / mag) * Math.min(mag, t2);
                n.y += (n.vy / mag) * Math.min(mag, t2);
                // Constrain to bounds
                n.x = Math.max(padL + 40, Math.min(w - padR - 40, n.x));
                n.y = Math.max(padT + 20, Math.min(h - padB - 20, n.y));
            });
        }

        // Draw edges
        edges.forEach(function(e) {
            var dx = e.target.x - e.source.x;
            var dy = e.target.y - e.source.y;
            var dist = Math.sqrt(dx * dx + dy * dy) || 1;

            // Curved edge
            var midX = (e.source.x + e.target.x) / 2;
            var midY = (e.source.y + e.target.y) / 2;
            var perpX = -dy / dist * 15;
            var perpY = dx / dist * 15;

            var edgeGrad = ctx.createLinearGradient(e.source.x, e.source.y, e.target.x, e.target.y);
            edgeGrad.addColorStop(0, e.source.color + '60');
            edgeGrad.addColorStop(1, e.target.color + '90');

            ctx.strokeStyle = edgeGrad;
            ctx.lineWidth = 2;
            ctx.beginPath();
            ctx.moveTo(e.source.x, e.source.y);
            ctx.quadraticCurveTo(midX + perpX, midY + perpY, e.target.x, e.target.y);
            ctx.stroke();

            // Arrowhead
            var arrowLen = 8;
            var angle = Math.atan2(e.target.y - (midY + perpY), e.target.x - (midX + perpX));
            ctx.fillStyle = e.target.color + 'b0';
            ctx.beginPath();
            ctx.moveTo(e.target.x, e.target.y);
            ctx.lineTo(e.target.x - arrowLen * Math.cos(angle - 0.35), e.target.y - arrowLen * Math.sin(angle - 0.35));
            ctx.lineTo(e.target.x - arrowLen * Math.cos(angle + 0.35), e.target.y - arrowLen * Math.sin(angle + 0.35));
            ctx.closePath();
            ctx.fill();
        });

        // Draw nodes
        var nodeW = 120; var nodeH = 52;
        nodes.forEach(function(n) {
            var nx = n.x - nodeW / 2;
            var ny = n.y - nodeH / 2;

            // Shadow
            ctx.save();
            ctx.shadowColor = 'rgba(0,0,0,0.15)';
            ctx.shadowBlur = 6;
            ctx.shadowOffsetY = 2;
            var grad = ctx.createLinearGradient(nx, ny, nx, ny + nodeH);
            grad.addColorStop(0, n.color);
            grad.addColorStop(1, n.color + 'b0');
            ctx.fillStyle = grad;
            ctx.beginPath();
            ctx.roundRect(nx, ny, nodeW, nodeH, 8);
            ctx.fill();
            ctx.restore();

            // Light top edge
            ctx.fillStyle = 'rgba(255,255,255,0.15)';
            ctx.beginPath();
            ctx.roundRect(nx + 1, ny + 1, nodeW - 2, nodeH * 0.35, [7, 7, 0, 0]);
            ctx.fill();

            // Border
            ctx.strokeStyle = 'rgba(255,255,255,0.4)';
            ctx.lineWidth = 1;
            ctx.beginPath();
            ctx.roundRect(nx, ny, nodeW, nodeH, 8);
            ctx.stroke();

            // Name
            ctx.fillStyle = '#ffffff';
            ctx.font = 'bold 10px -apple-system, sans-serif';
            ctx.textAlign = 'center';
            var label = n.name;
            if (label.length > 16) { label = label.substring(0, 15) + '\u2026'; }
            ctx.fillText(label, n.x, n.y - 4);

            // Assignee + hours
            ctx.font = '9px -apple-system, sans-serif';
            ctx.fillStyle = 'rgba(255,255,255,0.8)';
            var detail = (n.assignee ? n.assignee.split(' ')[0] : '') + (n.hours ? ' \u00b7 ' + n.hours + 'h' : '');
            if (detail.length > 20) { detail = detail.substring(0, 19) + '\u2026'; }
            ctx.fillText(detail, n.x, n.y + 10);

            // Stage pill
            ctx.font = '8px -apple-system, sans-serif';
            ctx.fillStyle = 'rgba(255,255,255,0.6)';
            var stageLabel = n.stage;
            if (stageLabel.length > 14) { stageLabel = stageLabel.substring(0, 13) + '\u2026'; }
            ctx.fillText(stageLabel, n.x, n.y + 21);
            ctx.textAlign = 'left';
        });

        // Legend
        ctx.fillStyle = '#6b7280';
        ctx.font = '10px -apple-system, sans-serif';
        ctx.fillText(nodes.length + ' tasks, ' + edges.length + ' dependencies', 20, h - 15);

        // Cache positions for animated transitions
        var nPositions = {};
        nodes.forEach(function(n2) {
            nPositions[n2.id] = { x: n2.x - nodeW / 2, y: n2.y - nodeH / 2, w: nodeW, h: nodeH, r: 0, color: n2.color };
        });
        this._vizPositions = nPositions;
    }

    // ── Sankey — Stage flow with entity breakdown ──────────────────

    _drawSankey(ctx, w, h, tasks, colors) {
        ctx.fillStyle = '#f8fafc';
        ctx.fillRect(0, 0, w, h);
        ctx.fillStyle = '#111827';
        ctx.font = 'bold 16px -apple-system, sans-serif';
        ctx.fillText('Sankey Flow \u2014 Work distribution across stages and entities', 20, 30);

        if (tasks.length === 0) {
            ctx.fillStyle = '#9ca3af';
            ctx.font = '14px -apple-system, sans-serif';
            ctx.fillText('No tasks to display', w / 2 - 60, h / 2);
            return;
        }

        var padL = 30; var padR = 30; var padT = 60; var padB = 50;
        var plotW = w - padL - padR;
        var plotH = h - padT - padB;

        // Group tasks by stage, then by entity within stage
        var stageOrder = [];
        var stageEntityMap = {}; // stage -> [{entity, count, tasks}]
        var entityColors = {};
        var entityPalette = ['#0ea5e9', '#8b5cf6', '#f59e0b', '#10b981', '#ef4444', '#6366f1', '#ec4899', '#14b8a6'];
        var entityIdx = 0;

        tasks.forEach(function(t) {
            var stage = t.stage || 'Backlog';
            var entity = t.entityName || 'Unassigned';
            if (!stageEntityMap[stage]) {
                stageEntityMap[stage] = {};
                stageOrder.push(stage);
            }
            if (!stageEntityMap[stage][entity]) {
                stageEntityMap[stage][entity] = 0;
            }
            stageEntityMap[stage][entity]++;
            if (!entityColors[entity]) {
                entityColors[entity] = entityPalette[entityIdx % entityPalette.length];
                entityIdx++;
            }
        });

        var numStages = stageOrder.length;
        if (numStages === 0) { return; }
        var colW = plotW / numStages;
        var nodeW = Math.min(colW * 0.3, 50);
        var nodeGap = 6;

        // Build sankey nodes: [{stage, entity, count, x, y, h}]
        var sankeyNodes = [];
        var stageNodes = {}; // stage -> [nodes]

        stageOrder.forEach(function(stage, si) {
            var entities = stageEntityMap[stage];
            var entityList = Object.keys(entities).sort(function(a, b) {
                return entities[b] - entities[a];
            });
            var totalInStage = 0;
            entityList.forEach(function(e) { totalInStage += entities[e]; });

            var nodeX = padL + si * colW + (colW - nodeW) / 2;
            var availH = plotH - (entityList.length - 1) * nodeGap;
            var currentY = padT;
            var nodesInStage = [];

            entityList.forEach(function(entity) {
                var count = entities[entity];
                var nodeH = Math.max((count / Math.max(totalInStage, 1)) * availH, 14);
                var node = {
                    stage: stage,
                    entity: entity,
                    count: count,
                    x: nodeX,
                    y: currentY,
                    w: nodeW,
                    h: nodeH,
                    color: entityColors[entity],
                    stageColor: colors[stage] || '#94a3b8'
                };
                sankeyNodes.push(node);
                nodesInStage.push(node);
                currentY += nodeH + nodeGap;
            });
            stageNodes[stage] = nodesInStage;
        });

        // Draw flow ribbons between adjacent stages
        for (var si = 0; si < stageOrder.length - 1; si++) {
            var fromStage = stageOrder[si];
            var toStage = stageOrder[si + 1];
            var fromNodes = stageNodes[fromStage] || [];
            var toNodes = stageNodes[toStage] || [];

            fromNodes.forEach(function(fn) {
                // Find matching entity in next stage, or distribute proportionally
                var matchNode = null;
                toNodes.forEach(function(tn) {
                    if (tn.entity === fn.entity) { matchNode = tn; }
                });

                if (matchNode) {
                    // Direct entity flow
                    var ribbonH = Math.min(fn.h, matchNode.h) * 0.8;
                    var x1 = fn.x + fn.w;
                    var y1 = fn.y + fn.h / 2;
                    var x2 = matchNode.x;
                    var y2 = matchNode.y + matchNode.h / 2;
                    var cpX = (x1 + x2) / 2;

                    var ribbonGrad = ctx.createLinearGradient(x1, 0, x2, 0);
                    ribbonGrad.addColorStop(0, fn.color + '40');
                    ribbonGrad.addColorStop(0.5, fn.color + '25');
                    ribbonGrad.addColorStop(1, matchNode.color + '40');

                    ctx.fillStyle = ribbonGrad;
                    ctx.beginPath();
                    ctx.moveTo(x1, y1 - ribbonH / 2);
                    ctx.bezierCurveTo(cpX, y1 - ribbonH / 2, cpX, y2 - ribbonH / 2, x2, y2 - ribbonH / 2);
                    ctx.lineTo(x2, y2 + ribbonH / 2);
                    ctx.bezierCurveTo(cpX, y2 + ribbonH / 2, cpX, y1 + ribbonH / 2, x1, y1 + ribbonH / 2);
                    ctx.closePath();
                    ctx.fill();
                } else if (toNodes.length > 0) {
                    // No matching entity — draw thin ribbon to largest node
                    var largest = toNodes[0];
                    var ribbonH2 = Math.min(fn.h * 0.4, 8);
                    var x1b = fn.x + fn.w;
                    var y1b = fn.y + fn.h / 2;
                    var x2b = largest.x;
                    var y2b = largest.y + largest.h / 2;
                    var cpXb = (x1b + x2b) / 2;

                    ctx.fillStyle = fn.color + '15';
                    ctx.beginPath();
                    ctx.moveTo(x1b, y1b - ribbonH2 / 2);
                    ctx.bezierCurveTo(cpXb, y1b - ribbonH2 / 2, cpXb, y2b - ribbonH2 / 2, x2b, y2b - ribbonH2 / 2);
                    ctx.lineTo(x2b, y2b + ribbonH2 / 2);
                    ctx.bezierCurveTo(cpXb, y2b + ribbonH2 / 2, cpXb, y1b + ribbonH2 / 2, x1b, y1b + ribbonH2 / 2);
                    ctx.closePath();
                    ctx.fill();
                }
            });
        }

        // Draw nodes
        sankeyNodes.forEach(function(n) {
            // Node fill with gradient
            var grad = ctx.createLinearGradient(n.x, n.y, n.x + n.w, n.y);
            grad.addColorStop(0, n.color);
            grad.addColorStop(1, n.color + 'c0');
            ctx.fillStyle = grad;
            ctx.beginPath();
            ctx.roundRect(n.x, n.y, n.w, n.h, 4);
            ctx.fill();

            // Border
            ctx.strokeStyle = n.color + '80';
            ctx.lineWidth = 1;
            ctx.beginPath();
            ctx.roundRect(n.x, n.y, n.w, n.h, 4);
            ctx.stroke();

            // Count label (inside if tall enough)
            if (n.h > 20) {
                ctx.fillStyle = '#ffffff';
                ctx.font = 'bold 11px -apple-system, sans-serif';
                ctx.textAlign = 'center';
                ctx.fillText(n.count.toString(), n.x + n.w / 2, n.y + n.h / 2 + 4);
                ctx.textAlign = 'left';
            }

            // Entity label (right side)
            ctx.fillStyle = '#374151';
            ctx.font = '9px -apple-system, sans-serif';
            var entityLabel = n.entity;
            if (entityLabel.length > 14) { entityLabel = entityLabel.substring(0, 13) + '\u2026'; }
            ctx.fillText(entityLabel, n.x + n.w + 5, n.y + n.h / 2 + 3);
        });

        // Stage labels at top
        ctx.fillStyle = '#111827';
        ctx.font = 'bold 11px -apple-system, sans-serif';
        ctx.textAlign = 'center';
        stageOrder.forEach(function(stage, si) {
            var sx = padL + si * colW + colW / 2;
            var label = stage;
            if (label.length > 14) { label = label.substring(0, 13) + '\u2026'; }
            ctx.fillText(label, sx, padT - 10);
        });
        ctx.textAlign = 'left';

        // Entity legend at bottom
        var lx = padL;
        var ly = h - 20;
        ctx.fillStyle = '#6b7280';
        ctx.font = '10px -apple-system, sans-serif';
        Object.keys(entityColors).forEach(function(entity) {
            ctx.fillStyle = entityColors[entity];
            ctx.beginPath();
            ctx.roundRect(lx, ly - 8, 10, 10, 2);
            ctx.fill();
            ctx.fillStyle = '#374151';
            ctx.font = '10px -apple-system, sans-serif';
            ctx.fillText(entity, lx + 14, ly);
            lx += ctx.measureText(entity).width + 28;
        });

        // Summary
        ctx.fillStyle = '#9ca3af';
        ctx.font = '10px -apple-system, sans-serif';
        ctx.textAlign = 'right';
        ctx.fillText(tasks.length + ' tasks across ' + numStages + ' stages', w - padR, h - 10);
        ctx.textAlign = 'left';

        // Cache positions for animated transitions (approximate: assign each task to its stage node)
        var sPositions = {};
        var tasksByStageEntity = {};
        tasks.forEach(function(t) {
            var key = (t.stage || 'Backlog') + '|' + (t.entityName || 'Unassigned');
            if (!tasksByStageEntity[key]) { tasksByStageEntity[key] = []; }
            tasksByStageEntity[key].push(t);
        });
        sankeyNodes.forEach(function(sn) {
            var key = sn.stage + '|' + sn.entity;
            var snTasks = tasksByStageEntity[key] || [];
            snTasks.forEach(function(t, ti) {
                var slotH = sn.h / Math.max(snTasks.length, 1);
                sPositions[t.workItemId] = { x: sn.x, y: sn.y + ti * slotH, w: sn.w, h: Math.max(slotH - 1, 4), r: 0, color: sn.color };
            });
        });
        this._vizPositions = sPositions;
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
        var container = this.refs.ganttContainer;
        var self = this;
        var step = 0;
        var TOTAL = 42;
        var DELAY = 4000;

        this.isDemoRunning = true;

        function banner(title, msg) {
            self.demoStepLabel = title;
            self.demoStepDescription = msg;
        }

        function runStep() {
            if (!self.isDemoRunning) { return; }
            step++;
            console.log('[NimbusGantt:demo] Step ' + step + '/' + TOTAL);
            try {
                switch(step) {

                // ── INTRODUCTION ─────────────────────────────────
                case 1:
                    banner(step + '/' + TOTAL + ' — Welcome', 'This is the Delivery Hub Gantt — a full-featured project timeline built on Salesforce.');
                    g.expandAll();
                    g.scrollToDate(new Date());
                    break;

                // ── ZOOM LEVELS ──────────────────────────────────
                case 2:
                    banner(step + '/' + TOTAL + ' — Day View', 'Zoom into daily granularity to see individual task details and progress bars.');
                    g.setZoom('day'); g.scrollToDate(new Date());
                    break;
                case 3:
                    banner(step + '/' + TOTAL + ' — Week View', 'The default working view shows a balanced level of detail for sprint planning.');
                    g.setZoom('week'); g.scrollToDate(new Date());
                    break;
                case 4:
                    banner(step + '/' + TOTAL + ' — Month View', 'Pull back to monthly for release planning and milestone tracking.');
                    g.setZoom('month'); g.scrollToDate(new Date());
                    break;
                case 5:
                    banner(step + '/' + TOTAL + ' — Quarter View', 'The widest view shows the full project arc across multiple months.');
                    g.setZoom('quarter');
                    break;
                case 6:
                    banner(step + '/' + TOTAL + ' — Back to Week', 'Returning to the standard week view for the rest of the demo.');
                    g.setZoom('week'); g.scrollToDate(new Date());
                    break;

                // ── TREE OPERATIONS ──────────────────────────────
                case 7:
                    banner(step + '/' + TOTAL + ' — Collapse Hierarchy', 'Collapsing all tasks to show only top-level work items and groups.');
                    g.collapseAll();
                    break;
                case 8:
                    banner(step + '/' + TOTAL + ' — Expand Hierarchy', 'Expanding to reveal every child task, sub-task, and dependency.');
                    g.expandAll(); g.scrollToDate(new Date());
                    break;

                // ── DARK MODE ────────────────────────────────────
                case 9:
                    banner(step + '/' + TOTAL + ' — Dark Mode', 'Switching to dark theme for low-light environments and presentations.');
                    if (container) {
                        container.style.filter = 'invert(1) hue-rotate(180deg)';
                        container.style.backgroundColor = '#1a1a2e';
                    }
                    break;
                case 10:
                    banner(step + '/' + TOTAL + ' — Light Mode', 'Restoring the standard light theme.');
                    if (container) { container.style.filter = ''; container.style.backgroundColor = ''; }
                    break;

                // ── EDITING ──────────────────────────────────────
                case 11:
                    banner(step + '/' + TOTAL + ' — Unlock Editing', 'When unlocked, you can drag task bars to reschedule or resize edges to change duration.');
                    self.editLocked = false; self._rebuildChart();
                    break;
                case 12:
                    banner(step + '/' + TOTAL + ' — Re-Lock', 'Locking the chart prevents accidental changes during presentations.');
                    self.editLocked = true; self._rebuildChart();
                    break;

                // ── CLIENT FILTER ────────────────────────────────
                case 13: {
                    var entities13 = [];
                    self._rawTasks.forEach(function(t) { if (t.entityName && entities13.indexOf(t.entityName) === -1) { entities13.push(t.entityName); } });
                    if (entities13.length > 0) {
                        self.selectedEntity = entities13[0];
                        self._rebuildChart();
                        banner(step + '/' + TOTAL + ' — Filter: ' + entities13[0], 'Isolating one client to focus on their workstream.');
                    } else {
                        banner(step + '/' + TOTAL + ' — Filter', 'No entities available to filter.');
                    }
                    break;
                }
                case 14:
                    banner(step + '/' + TOTAL + ' — All Clients', 'Clearing the filter to show all client workstreams together.');
                    self.selectedEntity = ''; self._rebuildChart();
                    break;

                // ── OVERDUE FILTER ────────────────────────────────
                case 15:
                    banner(step + '/' + TOTAL + ' — Overdue Filter', 'Filtering to show only tasks that are past their due date and not yet complete.');
                    self.showOverdue = true; self._rebuildChart();
                    break;
                case 16:
                    banner(step + '/' + TOTAL + ' — Clear Overdue', 'Removing the overdue filter to see the full timeline again.');
                    self.showOverdue = false; self._rebuildChart();
                    break;

                // ── DEPENDENCY TOGGLE ─────────────────────────────
                case 17:
                    banner(step + '/' + TOTAL + ' — Hide Dependencies', 'Turning off dependency arrows for a cleaner view of task bars.');
                    self.showDependencies = false; self._updateGantt();
                    break;
                case 18:
                    banner(step + '/' + TOTAL + ' — Show Dependencies', 'Dependency arrows show which tasks block others.');
                    self.showDependencies = true; self._updateGantt();
                    break;

                // ── TASK NAVIGATION ──────────────────────────────
                case 19:
                    banner(step + '/' + TOTAL + ' — Navigate to First Task', 'Using task navigation to walk through each work item in sequence.');
                    self._selectedTaskIndex = -1;
                    self._handleRemoteNextTask();
                    break;
                case 20:
                    banner(step + '/' + TOTAL + ' — Next Task', 'Stepping forward through the task list with auto-scroll.');
                    self._handleRemoteNextTask();
                    break;
                case 21:
                    banner(step + '/' + TOTAL + ' — Next Task', 'Each task is highlighted and scrolled into view automatically.');
                    self._handleRemoteNextTask();
                    break;

                // ── ALTERNATIVE VISUALIZATIONS ────────────────────
                case 22:
                    banner(step + '/' + TOTAL + ' — Treemap View', 'Treemap shows effort concentration at a glance. Larger rectangles mean more estimated hours.');
                    self.currentView = 'treemap'; self._renderAltViz();
                    break;
                case 23:
                    banner(step + '/' + TOTAL + ' — Bubble Chart', 'Each bubble represents a task. Size shows effort, position shows timeline, color shows stage.');
                    self.currentView = 'bubbles'; self._renderAltViz();
                    break;
                case 24:
                    banner(step + '/' + TOTAL + ' — Calendar Heatmap', 'Daily workload density across the project. Darker cells mean more tasks active that day.');
                    self.currentView = 'calendar'; self._renderAltViz();
                    break;
                case 25:
                    banner(step + '/' + TOTAL + ' — Stage Flow', 'See how tasks flow through workflow stages. Lines show volume and bottlenecks are flagged in red.');
                    self.currentView = 'flow'; self._renderAltViz();
                    break;
                case 26:
                    banner(step + '/' + TOTAL + ' — Network Graph', 'Force-directed dependency network. Tasks cluster by connections. Drag nodes to rearrange.');
                    self.currentView = 'network'; self._renderAltViz();
                    break;
                case 27:
                    banner(step + '/' + TOTAL + ' — Sankey Flow', 'Sankey diagram shows work distribution across stages and entities. Ribbon width shows volume.');
                    self.currentView = 'sankey'; self._renderAltViz();
                    break;

                // ── DARK MODE + ALT VIEW ─────────────────────────
                case 28:
                    banner(step + '/' + TOTAL + ' — Dark Treemap', 'Alternative visualizations look stunning in dark mode with glowing gradient fills.');
                    self.currentView = 'treemap'; self._renderAltViz();
                    requestAnimationFrame(function() {
                        var c = self.refs.altCanvas;
                        if (c && c.parentElement) { c.parentElement.style.filter = 'invert(1) hue-rotate(180deg)'; }
                    });
                    break;
                case 29:
                    banner(step + '/' + TOTAL + ' — Dark Bubbles', 'Radial gradients and progress rings shine against the dark background.');
                    self.currentView = 'bubbles'; self._renderAltViz();
                    break;
                case 30:
                    banner(step + '/' + TOTAL + ' — Restore Light', 'Clearing dark mode and returning to the main Gantt timeline.');
                    var altC30 = self.refs.altCanvas;
                    if (altC30 && altC30.parentElement) { altC30.parentElement.style.filter = ''; }
                    self.currentView = 'gantt'; self._rebuildChart();
                    if (container) { container.style.filter = ''; container.style.backgroundColor = ''; }
                    break;

                // ── ENTITY CYCLING ────────────────────────────────
                case 31: {
                    var ents31 = [];
                    self._rawTasks.forEach(function(t) { if (t.entityName && ents31.indexOf(t.entityName) === -1) { ents31.push(t.entityName); } });
                    if (ents31.length > 0) {
                        self.selectedEntity = ents31[0]; self._rebuildChart();
                        banner(step + '/' + TOTAL + ' — Cycle Client: ' + ents31[0], 'Cycling through clients one by one, just like the phone remote does.');
                    }
                    break;
                }
                case 32: {
                    var ents32 = [];
                    self._rawTasks.forEach(function(t) { if (t.entityName && ents32.indexOf(t.entityName) === -1) { ents32.push(t.entityName); } });
                    if (ents32.length > 1) {
                        self.selectedEntity = ents32[1]; self._rebuildChart();
                        banner(step + '/' + TOTAL + ' — Cycle Client: ' + ents32[1], 'Each client workstream can be reviewed independently.');
                    } else {
                        banner(step + '/' + TOTAL + ' — All Clients', 'Showing all clients.');
                        self.selectedEntity = ''; self._rebuildChart();
                    }
                    break;
                }
                case 33:
                    banner(step + '/' + TOTAL + ' — All Clients', 'Clearing filters to show the unified project view.');
                    self.selectedEntity = ''; self._rebuildChart();
                    break;

                // ── SCROLL NAVIGATION ────────────────────────────
                case 34:
                    banner(step + '/' + TOTAL + ' — Scroll to Start', 'Scrolling to the beginning of the project timeline.');
                    try { var r34 = g.getVisibleDateRange(); g.scrollToDate(r34.start); } catch(e) { /* ignore */ }
                    break;
                case 35:
                    banner(step + '/' + TOTAL + ' — Scroll to End', 'Scrolling to the end of the project timeline.');
                    try { var r35 = g.getVisibleDateRange(); g.scrollToDate(r35.end); } catch(e) { /* ignore */ }
                    break;
                case 36:
                    banner(step + '/' + TOTAL + ' — Back to Today', 'Centering the timeline on today for the current status view.');
                    g.scrollToDate(new Date());
                    break;

                // ── SONIFICATION ─────────────────────────────────
                case 37:
                    banner(step + '/' + TOTAL + ' — Sonification', 'Hearing your project as music. On-track tasks play major notes, overdue tasks sound dissonant.');
                    try {
                        var ac = new (window.AudioContext || window.webkitAudioContext)();
                        var today37 = new Date();
                        var PLAY_DUR = 6;
                        var sorted37 = self.filteredTasks.slice().filter(function(t) { return t.startDate; }).sort(function(a, b) {
                            return new Date(a.startDate).getTime() - new Date(b.startDate).getTime();
                        });
                        if (sorted37.length === 0) { break; }
                        var minStart37 = new Date(sorted37[0].startDate).getTime();
                        var maxStart37 = minStart37;
                        sorted37.forEach(function(t) { var ms = new Date(t.startDate).getTime(); if (ms > maxStart37) { maxStart37 = ms; } });
                        var timeSpan37 = maxStart37 - minStart37 || 1;
                        var entities37 = [];
                        sorted37.forEach(function(t) { var en = t.entityName || 'Unassigned'; if (entities37.indexOf(en) === -1) { entities37.push(en); } });
                        var oscTypes37 = ['sine', 'triangle', 'sawtooth', 'square'];
                        var onTrackNotes = [261.6, 329.6, 392.0, 440.0, 523.3];
                        var overdueNotes = [311.1, 370.0, 466.2];
                        var minHrs37 = Infinity; var maxHrs37 = 0;
                        sorted37.forEach(function(t) { var h = t.estimatedHours || 1; if (h < minHrs37) { minHrs37 = h; } if (h > maxHrs37) { maxHrs37 = h; } });
                        var hrsRange37 = maxHrs37 - minHrs37 || 1;
                        var minTaskDur37 = Infinity; var maxTaskDur37 = 0;
                        sorted37.forEach(function(t) {
                            var s = new Date(t.startDate).getTime();
                            var e = t.endDate ? new Date(t.endDate).getTime() : s + 7 * 86400000;
                            var dur = e - s || 1;
                            if (dur < minTaskDur37) { minTaskDur37 = dur; } if (dur > maxTaskDur37) { maxTaskDur37 = dur; }
                        });
                        var taskDurRange37 = maxTaskDur37 - minTaskDur37 || 1;
                        var onTrackCount37 = 0; var overdueCount37 = 0;
                        sorted37.forEach(function(t) {
                            var startMs = new Date(t.startDate).getTime();
                            var endMs = t.endDate ? new Date(t.endDate).getTime() : startMs + 7 * 86400000;
                            var prog = t.progress || 0; var hrs = t.estimatedHours || 1;
                            var entityIdx = entities37.indexOf(t.entityName || 'Unassigned');
                            var isOverdue = endMs < today37.getTime() && !t.isCompleted;
                            if (isOverdue) { overdueCount37++; } else { onTrackCount37++; }
                            var noteStart = ac.currentTime + ((startMs - minStart37) / timeSpan37) * (PLAY_DUR - 0.8);
                            var palette = isOverdue ? overdueNotes : onTrackNotes;
                            var freq = palette[Math.floor(Math.random() * palette.length)];
                            var vol = 0.1 + 0.15 * ((hrs - minHrs37) / hrsRange37);
                            var taskDur = endMs - startMs || 1;
                            var noteDur = 0.2 + 0.6 * ((taskDur - minTaskDur37) / taskDurRange37);
                            var attack = 0.1 - 0.08 * (prog / 100);
                            var oscType = oscTypes37[Math.min(entityIdx, oscTypes37.length - 1)];
                            var osc = ac.createOscillator(); var gain = ac.createGain();
                            osc.frequency.value = freq; osc.type = oscType;
                            gain.gain.setValueAtTime(0, noteStart);
                            gain.gain.linearRampToValueAtTime(vol, noteStart + attack);
                            gain.gain.setValueAtTime(vol, noteStart + noteDur - 0.1);
                            gain.gain.linearRampToValueAtTime(0, noteStart + noteDur);
                            osc.connect(gain); gain.connect(ac.destination);
                            osc.start(noteStart); osc.stop(noteStart + noteDur + 0.01);
                            if (prog === 0 && startMs < today37.getTime()) {
                                var bo = ac.createOscillator(); var bg = ac.createGain();
                                bo.frequency.value = freq / 2; bo.type = 'sine';
                                var bv = vol * 0.4; var bd = noteDur * 1.5;
                                bg.gain.setValueAtTime(0, noteStart);
                                bg.gain.linearRampToValueAtTime(bv, noteStart + 0.05);
                                bg.gain.setValueAtTime(bv, noteStart + bd - 0.15);
                                bg.gain.linearRampToValueAtTime(0, noteStart + bd);
                                bo.connect(bg); bg.connect(ac.destination);
                                bo.start(noteStart); bo.stop(noteStart + bd + 0.01);
                            }
                        });
                        var chordStart = ac.currentTime + PLAY_DUR; var chordDur = 1.5;
                        var isMajor = onTrackCount37 >= overdueCount37;
                        var chordFreqs = isMajor ? [261.6, 329.6, 392.0] : [261.6, 311.1, 392.0];
                        chordFreqs.forEach(function(cf) {
                            var co = ac.createOscillator(); var cg = ac.createGain();
                            co.frequency.value = cf; co.type = 'sine';
                            cg.gain.setValueAtTime(0, chordStart);
                            cg.gain.linearRampToValueAtTime(0.12, chordStart + 0.05);
                            cg.gain.setValueAtTime(0.12, chordStart + chordDur - 0.3);
                            cg.gain.linearRampToValueAtTime(0, chordStart + chordDur);
                            co.connect(cg); cg.connect(ac.destination);
                            co.start(chordStart); co.stop(chordStart + chordDur + 0.01);
                        });
                    } catch(se) { console.error('[NimbusGantt:demo] Sonification error:', se); }
                    break;

                // ── RAPID ZOOM CYCLE ─────────────────────────────
                case 38:
                    banner(step + '/' + TOTAL + ' — Rapid Zoom', 'Cycling through all zoom levels rapidly: Day, Week, Month, Quarter, Week.');
                    g.setZoom('day');
                    setTimeout(function() { g.setZoom('week'); }, 700);
                    setTimeout(function() { g.setZoom('month'); }, 1400);
                    setTimeout(function() { g.setZoom('quarter'); }, 2100);
                    setTimeout(function() { g.setZoom('week'); g.scrollToDate(new Date()); }, 2800);
                    break;

                // ── COLLAPSE + EXPAND ONE ─────────────────────────
                case 39:
                    banner(step + '/' + TOTAL + ' — Focus One Group', 'Collapsing everything, then expanding just one group to drill into.');
                    g.collapseAll();
                    var first39 = self.filteredTasks[0];
                    if (first39 && first39.workItemId) {
                        try { g.expandTask(first39.workItemId); } catch(ex) { /* may not be parent */ }
                    }
                    break;
                case 40:
                    banner(step + '/' + TOTAL + ' — Full Expand', 'Expanding all tasks back to the complete view.');
                    g.expandAll(); g.scrollToDate(new Date());
                    break;

                // ── FINAL STATE ──────────────────────────────────
                case 41:
                    banner(step + '/' + TOTAL + ' — Final View', 'Week view, all clients, dependencies shown, centered on today. Ready to work.');
                    self.selectedEntity = '';
                    self.showOverdue = false;
                    self.showDependencies = true;
                    g.setZoom('week'); g.expandAll(); g.scrollToDate(new Date());
                    self._updateGantt();
                    break;

                // ── SUMMARY ──────────────────────────────────────
                case 42:
                    banner('Demo Complete', TOTAL + ' features demonstrated: 4 zoom levels, 7 views, dark mode, sonification, task navigation, overdue filter, dependency toggle, client cycling, and drag-to-reschedule.');
                    self.isDemoRunning = false;
                    self._demoTimer = null;
                    return;
                }
            } catch(err) {
                console.error('[NimbusGantt:demo] Error at step ' + step, err);
            }
            if (step < TOTAL) {
                self._demoTimer = setTimeout(runStep, DELAY);
            }
        }

        banner('Full Demo', TOTAL + ' steps, ~3 minutes. Zoom levels, 7 visualizations, sonification, filters, task navigation, dark mode...');
        this._demoTimer = setTimeout(runStep, 2000);
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

    // ── Phone Remote Control ──────────────────────────────────────────

    get remoteUrl() {
        return window.location.origin + '/apex/GanttRemote?session=' + this._remoteSessionId;
    }

    get remoteSessionDisplay() {
        return this._remoteSessionId || '--';
    }

    get remoteCopyLabel() {
        return this._remoteLinkCopied ? 'Copied!' : 'Copy Link';
    }

    get remoteCopyVariant() {
        return this._remoteLinkCopied ? 'success' : 'brand';
    }

    _generateRemoteSessionId() {
        var chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
        var id = 'gr-';
        for (var i = 0; i < 8; i++) {
            id += chars.charAt(Math.floor(Math.random() * chars.length));
        }
        this._remoteSessionId = id;
    }

    _subscribeRemoteEvents() {
        var self = this;
        onError(function(error) {
            console.error('[DeliveryNimbusGantt] empApi error:', JSON.stringify(error));
        });
        subscribe(REMOTE_EVENT_CHANNEL, -1, function(message) {
            self._handleRemoteEvent(message);
        }).then(function(sub) {
            self._remoteSubscription = sub;
        });
    }

    _unsubscribeRemoteEvents() {
        if (this._remoteSubscription) {
            unsubscribe(this._remoteSubscription, function() {
                /* unsubscribed */
            });
            this._remoteSubscription = null;
        }
    }

    _getRemoteField(payload, fieldName) {
        /* Support both namespaced (managed pkg) and non-namespaced (scratch org) */
        return payload[fieldName] || payload['delivery__' + fieldName] || '';
    }

    _handleRemoteEvent(message) {
        var payload = message.data.payload;
        var sessionId = this._getRemoteField(payload, 'SessionIdTxt__c');
        if (sessionId !== this._remoteSessionId) { return; }

        var action = this._getRemoteField(payload, 'ActionTxt__c');
        var value = this._getRemoteField(payload, 'ValueTxt__c');

        switch (action) {
            case 'scroll':
                this._handleRemoteScroll(value);
                break;
            case 'zoom':
                this._handleRemoteZoom(value);
                break;
            case 'tap':
                this.handleScrollToday();
                break;
            case 'swipe-left':
                this._handleRemoteZoomStep(-1);
                break;
            case 'swipe-right':
                this._handleRemoteZoomStep(1);
                break;
            case 'next-entity':
                this._handleRemoteNextEntity();
                break;
            case 'next-task':
                this._handleRemoteNextTask();
                break;
            case 'prev-task':
                this._handleRemotePrevTask();
                break;
            case 'toggle-overdue':
                this.handleToggleOverdue();
                break;
            case 'doubletap':
                this._handleRemoteFullReset();
                break;
        }
    }

    _handleRemoteFullReset() {
        this.currentView = 'gantt';
        this.currentZoom = 'week';
        this.selectedEntity = '';
        this.myWorkOnly = false;
        this.showOverdue = false;
        this.showCompleted = false;
        this.showDependencies = true;
        this.editLocked = true;
        /* Clear dark mode if active */
        var container = this.refs.ganttContainer;
        if (container) {
            container.style.filter = '';
            container.style.backgroundColor = '';
        }
        this._savePrefs();
        this._rebuildChart();
        requestAnimationFrame(() => {
            if (this._gantt) { this._gantt.scrollToDate(new Date()); }
        });
    }

    _handleRemoteScroll(valueJson) {
        if (!this._gantt) { return; }
        try {
            var data = JSON.parse(valueJson);
            var container = this.refs.ganttContainer;
            if (!container) { return; }
            /* Velocity-based tilt-to-scroll: gamma/beta angles translate
               to scroll velocity via a multiplier, giving smooth continuous
               motion proportional to how far the phone is tilted. */
            var gamma = data.gamma !== undefined ? data.gamma : (data.x || 0);
            var beta = data.beta !== undefined ? data.beta : (data.y || 0);
            var VELOCITY_FACTOR = 0.04;
            var scrollX = Math.round(gamma * VELOCITY_FACTOR * container.clientWidth);
            var scrollY = Math.round(beta * VELOCITY_FACTOR * container.clientHeight);
            /* Clamp to reasonable per-frame bounds */
            scrollX = Math.max(-80, Math.min(80, scrollX));
            scrollY = Math.max(-40, Math.min(40, scrollY));
            container.scrollLeft += scrollX;
            container.scrollTop += scrollY;
        } catch (e) {
            /* ignore parse errors */
        }
    }

    _handleRemoteZoom(level) {
        if (ZOOM_MAP[level] || ZOOM_LEVELS.indexOf(level) >= 0) {
            var zoomKey = ZOOM_MAP[level] || level;
            this._setZoom(zoomKey);
        }
    }

    _handleRemoteZoomStep(direction) {
        var idx = ZOOM_LEVELS.indexOf(this.currentZoom);
        if (idx < 0) { idx = 1; }
        var newIdx = idx + direction;
        if (newIdx >= 0 && newIdx < ZOOM_LEVELS.length) {
            this._setZoom(ZOOM_LEVELS[newIdx]);
        }
    }

    _handleRemoteNextEntity() {
        var entities = [];
        if (this._rawTasks) {
            this._rawTasks.forEach(function(t) {
                var en = t.entityName || 'Unassigned';
                if (entities.indexOf(en) === -1) { entities.push(en); }
            });
        }
        entities.sort();
        if (entities.length === 0) { return; }
        if (!this.selectedEntity) {
            this.selectedEntity = entities[0];
        } else {
            var idx = entities.indexOf(this.selectedEntity);
            if (idx < 0 || idx >= entities.length - 1) {
                /* Wrap around to "All" */
                this.selectedEntity = '';
            } else {
                this.selectedEntity = entities[idx + 1];
            }
        }
        this._savePrefs();
        this._rebuildChart();
    }

    _handleRemoteNextTask() {
        var tasks = this.filteredTasks;
        if (tasks.length === 0) { return; }
        this._selectedTaskIndex++;
        if (this._selectedTaskIndex >= tasks.length) { this._selectedTaskIndex = 0; }
        this._selectTaskAtIndex(this._selectedTaskIndex);
    }

    _handleRemotePrevTask() {
        var tasks = this.filteredTasks;
        if (tasks.length === 0) { return; }
        this._selectedTaskIndex--;
        if (this._selectedTaskIndex < 0) { this._selectedTaskIndex = tasks.length - 1; }
        this._selectTaskAtIndex(this._selectedTaskIndex);
    }

    _selectTaskAtIndex(idx) {
        var tasks = this.filteredTasks;
        if (idx < 0 || idx >= tasks.length) { return; }
        var task = tasks[idx];
        if (this._gantt && task.startDate) {
            this._gantt.scrollToDate(new Date(task.startDate));
            try { this._gantt.selectTask(task.workItemId); } catch (e) { /* task may not be visible */ }
        }
        this.selectedWorkItemId = task.workItemId;
        this.dispatchEvent(new ShowToastEvent({
            title: 'Task ' + (idx + 1) + '/' + tasks.length,
            message: task.name + (task.description ? ' — ' + task.description : ''),
            variant: 'info',
            mode: 'dismissible'
        }));
    }

    handleConnectPhone() {
        this.showRemoteModal = true;
        this._remoteLinkCopied = false;
        /* Draw QR code after modal renders */
        requestAnimationFrame(() => {
            requestAnimationFrame(() => {
                this._drawQRCode();
            });
        });
    }

    handleRemoteModalClose() {
        this.showRemoteModal = false;
    }

    handleCopyRemoteLink() {
        var self = this;
        if (navigator.clipboard && navigator.clipboard.writeText) {
            navigator.clipboard.writeText(this.remoteUrl).then(function() {
                self._remoteLinkCopied = true;
                self.dispatchEvent(new ShowToastEvent({
                    title: 'Link Copied',
                    message: 'Open this link on your phone to control the Gantt chart.',
                    variant: 'success'
                }));
            });
        } else {
            /* Fallback: select text for manual copy */
            this.dispatchEvent(new ShowToastEvent({
                title: 'Copy Manually',
                message: 'Select and copy the URL shown in the modal.',
                variant: 'info'
            }));
        }
    }

    // ── Private: QR Code Generator ──────────────────────────────────────
    // Self-contained QR code encoder (Mode: byte, ECC: L, Version: auto)

    _drawQRCode() {
        var canvas = this.refs.qrCanvas;
        if (!canvas) { return; }
        var url = this.remoteUrl;
        var modules = this._generateQRMatrix(url);
        if (!modules || modules.length === 0) { return; }
        var size = modules.length;
        var scale = Math.floor(200 / size);
        var offset = Math.floor((200 - size * scale) / 2);
        canvas.width = 200;
        canvas.height = 200;
        var ctx = canvas.getContext('2d');
        ctx.fillStyle = '#ffffff';
        ctx.fillRect(0, 0, 200, 200);
        ctx.fillStyle = '#000000';
        for (var r = 0; r < size; r++) {
            for (var c = 0; c < size; c++) {
                if (modules[r][c]) {
                    ctx.fillRect(offset + c * scale, offset + r * scale, scale, scale);
                }
            }
        }
    }

    _generateQRMatrix(text) {
        /* Encode text as a QR code matrix using byte mode, ECC level L.
           This is a simplified but functional QR encoder supporting versions 1-10. */
        var data = [];
        for (var i = 0; i < text.length; i++) {
            data.push(text.charCodeAt(i) & 0xff);
        }
        /* Version capacity table for byte mode, ECC L */
        var capacities = [0, 17, 32, 53, 78, 106, 134, 154, 192, 230, 271];
        var version = 0;
        for (var v = 1; v <= 10; v++) {
            if (data.length <= capacities[v]) { version = v; break; }
        }
        if (version === 0) { version = 10; data = data.slice(0, capacities[10]); }
        var size = version * 4 + 17;

        /* Build the data bit stream: mode(4) + count(8 or 16) + data + terminator + padding */
        var bits = [];
        function pushBits(val, len) {
            for (var b = len - 1; b >= 0; b--) { bits.push((val >> b) & 1); }
        }
        pushBits(4, 4); /* byte mode indicator */
        var countBits = version <= 9 ? 8 : 16;
        pushBits(data.length, countBits);
        data.forEach(function(byte) { pushBits(byte, 8); });

        /* ECC L total codeword counts per version */
        var totalCodewords = [0, 19, 34, 55, 80, 108, 136, 156, 194, 232, 274];
        var eccCodewords = [0, 7, 10, 15, 20, 26, 18, 20, 24, 30, 18];
        var totalBits = totalCodewords[version] * 8;

        /* Terminator */
        var termLen = Math.min(4, totalBits - bits.length);
        pushBits(0, termLen);
        /* Pad to byte boundary */
        while (bits.length % 8 !== 0) { bits.push(0); }
        /* Pad codewords */
        var padBytes = [0xEC, 0x11];
        var pi = 0;
        while (bits.length < totalBits) {
            pushBits(padBytes[pi % 2], 8);
            pi++;
        }

        /* Convert bits to codeword bytes */
        var codewords = [];
        for (var bi = 0; bi < bits.length; bi += 8) {
            var byte = 0;
            for (var bb = 0; bb < 8; bb++) { byte = (byte << 1) | (bits[bi + bb] || 0); }
            codewords.push(byte);
        }

        /* Reed-Solomon ECC generation using GF(256) */
        var eccCount = eccCodewords[version];
        var dataCount = totalCodewords[version] - eccCount;
        var dataCodewords = codewords.slice(0, dataCount);

        /* GF(256) log/exp tables */
        var gfExp = new Array(512);
        var gfLog = new Array(256);
        var x = 1;
        for (var gi = 0; gi < 255; gi++) {
            gfExp[gi] = x;
            gfLog[x] = gi;
            x <<= 1;
            if (x >= 256) { x ^= 0x11d; }
        }
        for (var gj = 255; gj < 512; gj++) { gfExp[gj] = gfExp[gj - 255]; }
        gfLog[0] = -1;

        function gfMul(a, b) {
            if (a === 0 || b === 0) { return 0; }
            return gfExp[(gfLog[a] + gfLog[b]) % 255];
        }

        /* Build generator polynomial */
        var gen = [1];
        for (var gi2 = 0; gi2 < eccCount; gi2++) {
            var newGen = new Array(gen.length + 1).fill(0);
            for (var gk = 0; gk < gen.length; gk++) {
                newGen[gk] ^= gen[gk];
                newGen[gk + 1] ^= gfMul(gen[gk], gfExp[gi2]);
            }
            gen = newGen;
        }

        /* Polynomial division */
        var msgOut = new Array(dataCount + eccCount).fill(0);
        for (var mi = 0; mi < dataCount; mi++) { msgOut[mi] = dataCodewords[mi]; }
        for (var mi2 = 0; mi2 < dataCount; mi2++) {
            var coef = msgOut[mi2];
            if (coef !== 0) {
                for (var gk2 = 1; gk2 < gen.length; gk2++) {
                    msgOut[mi2 + gk2] ^= gfMul(gen[gk2], coef);
                }
            }
        }
        var eccBytes = msgOut.slice(dataCount);

        /* Interleave (single block for versions 1-10 ECC L is mostly 1 block) */
        var finalData = dataCodewords.concat(eccBytes);

        /* Build the QR matrix */
        var modules = [];
        var reserved = [];
        for (var mr = 0; mr < size; mr++) {
            modules.push(new Array(size).fill(false));
            reserved.push(new Array(size).fill(false));
        }

        /* Place finder patterns */
        function placeFinder(row, col) {
            for (var dr = -1; dr <= 7; dr++) {
                for (var dc = -1; dc <= 7; dc++) {
                    var r2 = row + dr;
                    var c2 = col + dc;
                    if (r2 < 0 || r2 >= size || c2 < 0 || c2 >= size) { continue; }
                    var isBorder = dr === -1 || dr === 7 || dc === -1 || dc === 7;
                    var isOuter = dr === 0 || dr === 6 || dc === 0 || dc === 6;
                    var isInner = dr >= 2 && dr <= 4 && dc >= 2 && dc <= 4;
                    modules[r2][c2] = !isBorder && (isOuter || isInner);
                    reserved[r2][c2] = true;
                }
            }
        }
        placeFinder(0, 0);
        placeFinder(0, size - 7);
        placeFinder(size - 7, 0);

        /* Place alignment patterns (versions 2+) */
        var alignPositions = [
            [], [6, 18], [6, 22], [6, 26], [6, 30], [6, 34],
            [6, 22, 38], [6, 24, 42], [6, 26, 46], [6, 28, 52], [6, 30, 56]
        ];
        if (version >= 2) {
            var aPos = alignPositions[version];
            for (var ai = 0; ai < aPos.length; ai++) {
                for (var aj = 0; aj < aPos.length; aj++) {
                    var ar = aPos[ai]; var ac = aPos[aj];
                    if (reserved[ar][ac]) { continue; }
                    for (var adr = -2; adr <= 2; adr++) {
                        for (var adc = -2; adc <= 2; adc++) {
                            var isEdge = Math.abs(adr) === 2 || Math.abs(adc) === 2;
                            var isCenter = adr === 0 && adc === 0;
                            modules[ar + adr][ac + adc] = isEdge || isCenter;
                            reserved[ar + adr][ac + adc] = true;
                        }
                    }
                }
            }
        }

        /* Timing patterns */
        for (var tp = 8; tp < size - 8; tp++) {
            if (!reserved[6][tp]) { modules[6][tp] = tp % 2 === 0; reserved[6][tp] = true; }
            if (!reserved[tp][6]) { modules[tp][6] = tp % 2 === 0; reserved[tp][6] = true; }
        }

        /* Dark module */
        modules[size - 8][8] = true;
        reserved[size - 8][8] = true;

        /* Reserve format info areas */
        for (var fi = 0; fi < 8; fi++) {
            reserved[8][fi] = true; reserved[8][size - 1 - fi] = true;
            reserved[fi][8] = true; reserved[size - 1 - fi][8] = true;
        }
        reserved[8][8] = true;

        /* Reserve version info areas (version 7+) — not needed for versions 1-6 */

        /* Place data bits in zigzag pattern */
        var bitIndex = 0;
        var allBits = [];
        finalData.forEach(function(b) {
            for (var db = 7; db >= 0; db--) { allBits.push((b >> db) & 1); }
        });

        var col = size - 1;
        var upward = true;
        while (col >= 0) {
            if (col === 6) { col--; continue; }
            var rows = upward ? [] : [];
            for (var ri = 0; ri < size; ri++) {
                var row = upward ? size - 1 - ri : ri;
                for (var ci = 0; ci < 2; ci++) {
                    var c2 = col - ci;
                    if (c2 < 0) { continue; }
                    if (!reserved[row][c2]) {
                        modules[row][c2] = bitIndex < allBits.length ? allBits[bitIndex] === 1 : false;
                        bitIndex++;
                    }
                }
            }
            upward = !upward;
            col -= 2;
        }

        /* Apply mask pattern 0 (checkerboard) and format info */
        var maskFn = function(r, c) { return (r + c) % 2 === 0; };
        for (var mr2 = 0; mr2 < size; mr2++) {
            for (var mc = 0; mc < size; mc++) {
                if (!reserved[mr2][mc]) {
                    if (maskFn(mr2, mc)) { modules[mr2][mc] = !modules[mr2][mc]; }
                }
            }
        }

        /* Write format info for mask 0, ECC L */
        /* ECC L = 01, mask 000 => data 01000, BCH encoded = 111011111000100 */
        var formatBits = [1,1,1,0,1,1,1,1,1,0,0,0,1,0,0];
        /* Horizontal: bits 0-7 go along row 8 */
        var hPositions = [[8,0],[8,1],[8,2],[8,3],[8,4],[8,5],[8,7],[8,8]];
        /* And bits 7-14 go along row 8 from right */
        var hPositions2 = [[8, size-8],[8, size-7],[8, size-6],[8, size-5],[8, size-4],[8, size-3],[8, size-2],[8, size-1]];
        /* Vertical: bits 0-7 go along col 8 from bottom of top finder */
        var vPositions = [[0,8],[1,8],[2,8],[3,8],[4,8],[5,8],[7,8],[8,8]];
        var vPositions2 = [[size-7,8],[size-6,8],[size-5,8],[size-4,8],[size-3,8],[size-2,8],[size-1,8]];

        for (var fbi = 0; fbi < 8; fbi++) {
            modules[hPositions[fbi][0]][hPositions[fbi][1]] = formatBits[fbi] === 1;
            modules[vPositions[fbi][0]][vPositions[fbi][1]] = formatBits[fbi] === 1;
        }
        for (var fbi2 = 0; fbi2 < 7; fbi2++) {
            modules[hPositions2[fbi2][0]][hPositions2[fbi2][1]] = formatBits[7 + fbi2] === 1;
            modules[vPositions2[fbi2][0]][vPositions2[fbi2][1]] = formatBits[14 - 1 - fbi2] === 1;
        }

        return modules;
    }

    // ── Private: localStorage persistence ──────────────────────────────

    _savePrefs() {
        try {
            const prefs = {
                showDependencies: this.showDependencies,
                showCompleted: this.showCompleted,
                showOverdue: this.showOverdue,
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
            if (prefs.showOverdue != null) { this.showOverdue = prefs.showOverdue; }
            if (prefs.myWorkOnly != null) { this.myWorkOnly = prefs.myWorkOnly; }
            if (prefs.currentZoom) { this.currentZoom = prefs.currentZoom; }
            if (prefs.selectedEntity != null) { this.selectedEntity = prefs.selectedEntity; }
            if (prefs.editLocked != null) { this.editLocked = prefs.editLocked; }
        } catch (e) {
            // fail silently
        }
    }
}

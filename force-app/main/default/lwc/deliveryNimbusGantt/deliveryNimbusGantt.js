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
    currentView = 'gantt';
    showQuickEdit = false;
    selectedWorkItemId = null;

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
        this._generateRemoteSessionId();
        this._subscribeRemoteEvents();
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
        this._unsubscribeRemoteEvents();
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

    get isGanttView()       { return this.currentView === 'gantt'; }
    get isAltView()         { return this.currentView !== 'gantt'; }
    get ganttViewVariant()  { return this.currentView === 'gantt' ? 'brand' : 'neutral'; }
    get treemapViewVariant() { return this.currentView === 'treemap' ? 'brand' : 'neutral'; }
    get bubblesViewVariant() { return this.currentView === 'bubbles' ? 'brand' : 'neutral'; }
    get calendarViewVariant() { return this.currentView === 'calendar' ? 'brand' : 'neutral'; }
    get flowViewVariant()   { return this.currentView === 'flow' ? 'brand' : 'neutral'; }

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

    // ── View Switching ──────────────────────────────────────────────
    handleViewGantt()    { this.currentView = 'gantt'; this._rebuildChart(); }
    handleViewTreemap()  { this.currentView = 'treemap'; this._renderAltViz(); }
    handleViewBubbles()  { this.currentView = 'bubbles'; this._renderAltViz(); }
    handleViewCalendar() { this.currentView = 'calendar'; this._renderAltViz(); }
    handleViewFlow()     { this.currentView = 'flow'; this._renderAltViz(); }

    _renderAltViz() {
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        requestAnimationFrame(() => {
            var canvas = this.refs.altCanvas;
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

            var tasks = this.filteredTasks;
            var colors = { Submitted: '#3b82f6', 'In Development': '#22c55e', 'Code Review': '#a855f7', 'UAT Ready': '#14b8a6', Deployment: '#f97316', Done: '#6b7280', Backlog: '#64748b' };

            switch(this.currentView) {
                case 'treemap': this._drawTreemap(ctx, w, h, tasks, colors); break;
                case 'bubbles': this._drawBubbles(ctx, w, h, tasks, colors); break;
                case 'calendar': this._drawCalendar(ctx, w, h, tasks, colors); break;
                case 'flow': this._drawFlow(ctx, w, h, tasks, colors); break;
            }
        });
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
                    toast('1/35 — Canvas Check', 'Verifying canvas rendering...');
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
                    toast('2/35 — Day View', 'Zooming to daily granularity...', 'info');
                    g.setZoom('day');
                    g.scrollToDate(new Date());
                    log('Zoom: Day', true);
                    break;
                case 3:
                    toast('3/35 — Month View', 'Zooming out to monthly...', 'info');
                    g.setZoom('month');
                    g.scrollToDate(new Date());
                    log('Zoom: Month', true);
                    break;
                case 4:
                    toast('4/35 — Quarter View', 'Full project overview...', 'info');
                    g.setZoom('quarter');
                    log('Zoom: Quarter', true);
                    break;
                case 5:
                    toast('5/35 — Week View', 'Back to default week view...', 'info');
                    g.setZoom('week');
                    g.scrollToDate(new Date());
                    log('Zoom: Week (default)', true);
                    break;

                // ── TREE OPERATIONS ──────────────────────────────
                case 6:
                    toast('6/35 — Expand All', 'Showing all child tasks...', 'info');
                    g.expandAll();
                    log('expandAll()', true);
                    break;
                case 7:
                    toast('7/35 — Collapse All', 'Collapsing to parent groups...', 'info');
                    g.collapseAll();
                    log('collapseAll()', true);
                    break;
                case 8:
                    toast('8/35 — Expand + Scroll', 'Expanding and scrolling to today...', 'info');
                    g.expandAll();
                    g.scrollToDate(new Date());
                    log('Expand + scrollToDate', true);
                    break;

                // ── DARK MODE ────────────────────────────────────
                case 9:
                    toast('9/35 — Dark Mode', 'Switching to dark theme...', 'info');
                    if (container) {
                        container.style.filter = 'invert(1) hue-rotate(180deg)';
                        container.style.backgroundColor = '#1a1a2e';
                    }
                    log('Dark mode toggle', true);
                    break;
                case 10:
                    toast('10/35 — Light Mode', 'Switching back to light theme...', 'info');
                    if (container) {
                        container.style.filter = '';
                        container.style.backgroundColor = '';
                    }
                    log('Light mode restore', true);
                    break;

                // ── LOCK/UNLOCK ──────────────────────────────────
                case 11:
                    toast('11/35 — Unlock Editing', 'Drag bars to reschedule, resize edges to change duration', 'warning');
                    self.editLocked = false;
                    self._rebuildChart();
                    log('Unlock editing', true);
                    break;
                case 12:
                    toast('12/35 — Re-Lock', 'Locking editing back...', 'info');
                    self.editLocked = true;
                    self._rebuildChart();
                    log('Re-lock editing', true);
                    break;

                // ── ENTITY FILTER ────────────────────────────────
                case 13:
                    toast('13/35 — Filter: Acme Corp', 'Showing only Acme Corp tasks...', 'info');
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
                    toast('14/35 — Filter: All', 'Showing all entities...', 'info');
                    self.selectedEntity = '';
                    self._rebuildChart();
                    log('Filter cleared', true);
                    break;

                // ── ALTERNATIVE VISUALIZATIONS ────────────────────
                case 15:
                    toast('15/35 — Treemap', 'Treemap — effort concentration at a glance, squarified layout with gradient fills', 'info');
                    self.currentView = 'treemap'; self._renderAltViz();
                    log('Treemap rendered', true); break;
                case 16:
                    toast('16/35 — Bubble Chart', 'Bubble Chart — timeline galaxy with progress rings and dependency arcs', 'info');
                    self.currentView = 'bubbles'; self._renderAltViz();
                    log('Bubble chart rendered', true); break;
                case 17:
                    toast('17/35 — Calendar Heatmap', 'Calendar Heatmap — daily workload density, blue intensity ramp with week numbers', 'info');
                    self.currentView = 'calendar'; self._renderAltViz();
                    log('Calendar heatmap rendered', true); break;
                case 18:
                    toast('18/35 — Stage Flow', 'Stage Flow — Bezier flow lines, bottleneck detection, and percentage breakdowns', 'info');
                    self.currentView = 'flow'; self._renderAltViz();
                    log('Stage flow rendered', true); break;

                // ── BACK TO GANTT FOR PLUGIN DEMOS ───────────────
                case 19:
                    toast('19/35 — Back to Gantt', 'Returning to timeline for plugin demos...', 'info');
                    self.currentView = 'gantt'; self._rebuildChart();
                    log('Gantt restored', true); break;

                // ── PLUGIN SHOWCASES ─────────────────────────────
                case 20:
                    toast('20/35 — Scroll Entity by Entity', 'Scrolling to each client group...', 'info');
                    var ents = self._rawTasks.map(function(t) { return t.entityName; }).filter(function(v, i, a) { return a.indexOf(v) === i && v; });
                    if (ents.length > 1 && self._gantt) {
                        self.selectedEntity = ents[0]; self._rebuildChart();
                        setTimeout(function() {
                            if (ents.length > 1) { self.selectedEntity = ents[1]; self._rebuildChart(); }
                        }, 1500);
                        setTimeout(function() {
                            if (ents.length > 2) { self.selectedEntity = ents[2]; self._rebuildChart(); }
                        }, 3000);
                    }
                    log('Entity scroll: ' + ents.join(', '), true); break;
                case 21:
                    toast('21/35 — All Entities', 'Showing full project view...', 'info');
                    self.selectedEntity = ''; self._rebuildChart();
                    log('All entities', true); break;
                case 22:
                    toast('22/35 — Scroll to Project Start', 'Beginning of the timeline...', 'info');
                    try { var r2 = g.getVisibleDateRange(); g.scrollToDate(r2.start); log('Scroll start', true); }
                    catch(e2) { log('Scroll start: ' + e2.message, false); }
                    break;
                case 23:
                    toast('23/35 — Scroll to Project End', 'End of the timeline...', 'info');
                    try { var r3 = g.getVisibleDateRange(); g.scrollToDate(r3.end); log('Scroll end', true); }
                    catch(e3) { log('Scroll end: ' + e3.message, false); }
                    break;
                case 24:
                    toast('24/35 — Scroll to Today', 'Centering on today...', 'info');
                    g.scrollToDate(new Date());
                    log('Scroll today', true); break;

                // ── SONIFICATION ─────────────────────────────────
                case 25:
                    toast('25/35 — Sonification', '♫ Hearing your project health — consonant = on track, dissonant = overdue, volume = effort', 'warning');
                    try {
                        var ac = new (window.AudioContext || window.webkitAudioContext)();
                        var today25 = new Date();
                        var PLAY_DUR = 6;

                        // Sort tasks by start date for chronological playback
                        var sorted25 = self.filteredTasks.slice().filter(function(t) { return t.startDate; }).sort(function(a, b) {
                            return new Date(a.startDate).getTime() - new Date(b.startDate).getTime();
                        });

                        if (sorted25.length === 0) { log('Sonification: no tasks with dates', false); break; }

                        // Compute timeline bounds
                        var minStart25 = new Date(sorted25[0].startDate).getTime();
                        var maxStart25 = minStart25;
                        sorted25.forEach(function(t) {
                            var ms = new Date(t.startDate).getTime();
                            if (ms > maxStart25) { maxStart25 = ms; }
                        });
                        var timeSpan25 = maxStart25 - minStart25 || 1;

                        // Build unique entity list for oscillator type mapping
                        var entities25 = [];
                        sorted25.forEach(function(t) {
                            var en = t.entityName || 'Unassigned';
                            if (entities25.indexOf(en) === -1) { entities25.push(en); }
                        });
                        var oscTypes25 = ['sine', 'triangle', 'sawtooth', 'square'];

                        // Pitch palettes
                        var onTrackNotes = [261.6, 329.6, 392.0, 440.0, 523.3]; // C major pentatonic
                        var overdueNotes = [311.1, 370.0, 466.2];                // Eb, Gb, Bb — dissonant

                        // Find hours range for volume mapping
                        var minHrs25 = Infinity; var maxHrs25 = 0;
                        sorted25.forEach(function(t) {
                            var h = t.estimatedHours || 1;
                            if (h < minHrs25) { minHrs25 = h; }
                            if (h > maxHrs25) { maxHrs25 = h; }
                        });
                        var hrsRange25 = maxHrs25 - minHrs25 || 1;

                        // Find task-duration range for note-duration mapping
                        var minTaskDur25 = Infinity; var maxTaskDur25 = 0;
                        sorted25.forEach(function(t) {
                            var s = new Date(t.startDate).getTime();
                            var e = t.endDate ? new Date(t.endDate).getTime() : s + 7 * 86400000;
                            var dur = e - s || 1;
                            if (dur < minTaskDur25) { minTaskDur25 = dur; }
                            if (dur > maxTaskDur25) { maxTaskDur25 = dur; }
                        });
                        var taskDurRange25 = maxTaskDur25 - minTaskDur25 || 1;

                        var onTrackCount = 0; var overdueCount = 0;

                        // Play each task
                        sorted25.forEach(function(t) {
                            var startMs = new Date(t.startDate).getTime();
                            var endMs = t.endDate ? new Date(t.endDate).getTime() : startMs + 7 * 86400000;
                            var prog = t.progress || 0;
                            var hrs = t.estimatedHours || 1;
                            var entityIdx = entities25.indexOf(t.entityName || 'Unassigned');

                            // Determine health: on-track vs overdue
                            var isOverdue = endMs < today25.getTime() && !t.isCompleted;
                            if (isOverdue) { overdueCount++; } else { onTrackCount++; }

                            // Time position in playback window (0 to PLAY_DUR seconds)
                            var noteStart = ac.currentTime + ((startMs - minStart25) / timeSpan25) * (PLAY_DUR - 0.8);

                            // Pitch from health palette
                            var palette = isOverdue ? overdueNotes : onTrackNotes;
                            var freq = palette[Math.floor(Math.random() * palette.length)];

                            // Volume maps to hours (0.1 to 0.25)
                            var vol = 0.1 + 0.15 * ((hrs - minHrs25) / hrsRange25);

                            // Note duration maps to task duration (0.2s to 0.8s)
                            var taskDur = endMs - startMs || 1;
                            var noteDur = 0.2 + 0.6 * ((taskDur - minTaskDur25) / taskDurRange25);

                            // Attack: high progress = sharp (0.02s), low progress = fade in (0.1s)
                            var attack = 0.1 - 0.08 * (prog / 100);

                            // Oscillator type by entity
                            var oscType = oscTypes25[Math.min(entityIdx, oscTypes25.length - 1)];

                            // Create and play the note
                            var osc = ac.createOscillator();
                            var gain = ac.createGain();
                            osc.frequency.value = freq;
                            osc.type = oscType;
                            gain.gain.setValueAtTime(0, noteStart);
                            gain.gain.linearRampToValueAtTime(vol, noteStart + attack);
                            gain.gain.setValueAtTime(vol, noteStart + noteDur - 0.1);
                            gain.gain.linearRampToValueAtTime(0, noteStart + noteDur);
                            osc.connect(gain); gain.connect(ac.destination);
                            osc.start(noteStart);
                            osc.stop(noteStart + noteDur + 0.01);

                            // Critical path bass note: no progress and past start date
                            if (prog === 0 && startMs < today25.getTime()) {
                                var bassOsc = ac.createOscillator();
                                var bassGain = ac.createGain();
                                bassOsc.frequency.value = freq / 2;
                                bassOsc.type = 'sine';
                                var bassVol = vol * 0.4;
                                var bassDur = noteDur * 1.5;
                                bassGain.gain.setValueAtTime(0, noteStart);
                                bassGain.gain.linearRampToValueAtTime(bassVol, noteStart + 0.05);
                                bassGain.gain.setValueAtTime(bassVol, noteStart + bassDur - 0.15);
                                bassGain.gain.linearRampToValueAtTime(0, noteStart + bassDur);
                                bassOsc.connect(bassGain); bassGain.connect(ac.destination);
                                bassOsc.start(noteStart);
                                bassOsc.stop(noteStart + bassDur + 0.01);
                            }
                        });

                        // Final resolution chord at 6s mark
                        var chordStart = ac.currentTime + PLAY_DUR;
                        var chordDur = 1.5;
                        var isMajor = onTrackCount >= overdueCount;
                        // Major: C-E-G (261.6, 329.6, 392.0) — triumphant
                        // Minor: C-Eb-G (261.6, 311.1, 392.0) — ominous
                        var chordFreqs = isMajor ? [261.6, 329.6, 392.0] : [261.6, 311.1, 392.0];
                        chordFreqs.forEach(function(cf) {
                            var co = ac.createOscillator();
                            var cg = ac.createGain();
                            co.frequency.value = cf;
                            co.type = 'sine';
                            cg.gain.setValueAtTime(0, chordStart);
                            cg.gain.linearRampToValueAtTime(0.12, chordStart + 0.05);
                            cg.gain.setValueAtTime(0.12, chordStart + chordDur - 0.3);
                            cg.gain.linearRampToValueAtTime(0, chordStart + chordDur);
                            co.connect(cg); cg.connect(ac.destination);
                            co.start(chordStart);
                            co.stop(chordStart + chordDur + 0.01);
                        });

                        log('Sonification: played ' + sorted25.length + ' tasks (' + onTrackCount + ' on-track, ' + overdueCount + ' overdue) → ' + (isMajor ? 'major' : 'minor') + ' resolution', true);
                    } catch(se) { log('Sonification: ' + se.message, false); }
                    break;

                // ── RAPID ZOOM CYCLE ─────────────────────────────
                case 26:
                    toast('26/35 — Rapid Zoom Cycle', 'Day → Week → Month → Quarter → Week', 'info');
                    g.setZoom('day');
                    setTimeout(function() { g.setZoom('week'); }, 700);
                    setTimeout(function() { g.setZoom('month'); }, 1400);
                    setTimeout(function() { g.setZoom('quarter'); }, 2100);
                    setTimeout(function() { g.setZoom('week'); g.scrollToDate(new Date()); }, 2800);
                    log('Rapid zoom cycle', true); break;

                // ── DARK MODE + ALT VIEWS ────────────────────────
                case 27:
                    toast('27/35 — Dark Treemap', 'Treemap with inverted palette — gradient fills glow in dark mode', 'info');
                    self.currentView = 'treemap'; self._renderAltViz();
                    requestAnimationFrame(function() {
                        var c = self.refs.altCanvas;
                        if (c && c.parentElement) { c.parentElement.style.filter = 'invert(1) hue-rotate(180deg)'; }
                    });
                    log('Dark treemap', true); break;
                case 28:
                    toast('28/35 — Dark Bubbles', 'Bubble galaxy in dark mode — radial gradients and progress rings shine', 'info');
                    self.currentView = 'bubbles'; self._renderAltViz();
                    log('Dark bubbles', true); break;
                case 29:
                    toast('29/35 — Light Mode Restore', 'Clearing dark mode...', 'info');
                    var altC = self.refs.altCanvas;
                    if (altC && altC.parentElement) { altC.parentElement.style.filter = ''; }
                    self.currentView = 'gantt'; self._rebuildChart();
                    if (container) { container.style.filter = ''; container.style.backgroundColor = ''; }
                    log('Light restore', true); break;

                // ── EXPAND + COLLAPSE INDIVIDUAL ──────────────────
                case 30:
                    toast('30/35 — Collapse All → Expand One', 'Focusing on one group...', 'info');
                    g.collapseAll();
                    var firstTask = self.filteredTasks[0];
                    if (firstTask && firstTask.workItemId) {
                        try { g.expandTask(firstTask.workItemId); } catch(ex) { /* may not be parent */ }
                    }
                    log('Collapse + expand one', true); break;
                case 31:
                    toast('31/35 — Expand All Again', 'Full view restored...', 'info');
                    g.expandAll(); g.scrollToDate(new Date());
                    log('Full expand', true); break;

                // ── SECOND ENTITY FILTER CYCLE ───────────────────
                case 32:
                    toast('32/35 — Filter Second Entity', 'Isolating another client...', 'info');
                    var ents2 = self._rawTasks.map(function(t) { return t.entityName; }).filter(function(v, i, a) { return a.indexOf(v) === i && v; });
                    if (ents2.length > 1) { self.selectedEntity = ents2[1]; self._rebuildChart(); }
                    log('Filter entity 2', true); break;
                case 33:
                    toast('33/35 — Clear Filter', 'All entities visible...', 'info');
                    self.selectedEntity = ''; self._rebuildChart();
                    log('Filter cleared', true); break;

                // ── FINAL FLOURISH ───────────────────────────────
                case 34:
                    toast('34/35 — Final View', 'Week view, all tasks, centered on today', 'info');
                    g.setZoom('week'); g.expandAll(); g.scrollToDate(new Date());
                    log('Final view set', true); break;

                // ── SUMMARY ──────────────────────────────────────
                case 35:
                    var passed = results.filter(function(r) { return r.indexOf('[PASS]') === 0; }).length;
                    var failed = results.filter(function(r) { return r.indexOf('[FAIL]') === 0; }).length;
                    console.log('[NimbusGantt:demo] ═══════════════════════════════════════════');
                    console.log('[NimbusGantt:demo] FULL PRESENTATION: ' + passed + ' passed, ' + failed + ' failed');
                    console.log('[NimbusGantt:demo] ═══════════════════════════════════════════');
                    results.forEach(function(r) { console.log('[NimbusGantt:demo]   ' + r); });
                    toast('Demo Complete ✓', passed + '/' + (passed + failed) + ' features demonstrated across 5 views, ' + self.filteredTasks.length + ' tasks. Full report in console.', failed > 0 ? 'warning' : 'success');
                    return;
                }
            } catch(err) {
                log('Step ' + step + ' ERROR: ' + err.message, false);
                console.error('[NimbusGantt:demo] Error at step ' + step, err);
            }
            if (step < 35) {
                setTimeout(runStep, DELAY);
            }
        }

        toast('Full Demo', '35 steps, ~2.5 minutes. 5 visualization modes, sonification, entity cycling, zoom, dark mode, expand/collapse...', 'info');
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
        }
    }

    _handleRemoteScroll(valueJson) {
        if (!this._gantt) { return; }
        try {
            var data = JSON.parse(valueJson);
            var container = this.refs.ganttContainer;
            if (container) {
                container.scrollLeft += (data.x || 0);
                container.scrollTop += (data.y || 0);
            }
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

    handleConnectPhone() {
        this.showRemoteModal = true;
        this._remoteLinkCopied = false;
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

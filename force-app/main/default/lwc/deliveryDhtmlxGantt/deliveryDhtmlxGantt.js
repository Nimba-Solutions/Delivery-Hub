/* eslint-disable @lwc/lwc/no-async-operation, no-unused-vars */
/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Power-user Gantt chart powered by DHTMLX Gantt v9 (GPL).
 *               Full drag support (move, resize, progress, links), dependency
 *               arrows, tree hierarchy by entity + parent work item, quick-edit
 *               modal, rich tooltips, phase color coding, today marker, zoom
 *               presets, entity/my-work/completed filters, summary stats,
 *               undo/redo, and localStorage preference persistence.
 * @author Cloud Nimbus LLC
 */
import { LightningElement, wire, track, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { loadScript, loadStyle } from 'lightning/platformResourceLoader';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import GANTT_RES from '@salesforce/resourceUrl/dhtmlxgantt';
import getGanttData from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryGanttController.getGanttData';
import getGanttDependencies from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryGanttController.getGanttDependencies';
import updateWorkItemDates from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryGanttController.updateWorkItemDates';
import getWorkflowConfig from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryWorkflowConfigService.getWorkflowConfig';
import createDependency from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryHubBoardController.createDependency';
import removeDependency from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryHubBoardController.removeDependency';
import USER_ID from '@salesforce/user/Id';

// ── Phase color mapping ──────────────────────────────────────────────────────
const PHASE_COLORS = {
    'Planning':    '#3b82f6',
    'Approval':    '#f59e0b',
    'Development': '#22c55e',
    'Testing':     '#a855f7',
    'UAT':         '#14b8a6',
    'Deployment':  '#ef4444',
    'Done':        '#9ca3af'
};
const DEFAULT_COLOR = '#6b7280';

// ── Zoom presets ─────────────────────────────────────────────────────────────
const ZOOM_CONFIGS = {
    Day: {
        scales: [
            { unit: 'month', step: 1, format: '%F %Y' },
            { unit: 'day',   step: 1, format: '%j %D' }
        ],
        min_column_width: 40
    },
    Week: {
        scales: [
            { unit: 'month', step: 1, format: '%F %Y' },
            { unit: 'week',  step: 1, format: 'Week %W' }
        ],
        min_column_width: 80
    },
    Month: {
        scales: [
            { unit: 'year',  step: 1, format: '%Y' },
            { unit: 'month', step: 1, format: '%M' }
        ],
        min_column_width: 60
    },
    Quarter: {
        scales: [
            { unit: 'year',  step: 1, format: '%Y' },
            {
                unit: 'month', step: 3,
                format: function(date) { return 'Q' + (Math.floor(date.getMonth() / 3) + 1); }
            }
        ],
        min_column_width: 100
    }
};

const PREFS_KEY = 'dh-dhtmlx-gantt-prefs';

// ── Dependency type map: DHTMLX link types ───────────────────────────────────
// 0 = finish-to-start, 1 = start-to-start, 2 = finish-to-finish, 3 = start-to-finish
const LINK_TYPE_FS = '0';

export default class DeliveryDhtmlxGantt extends NavigationMixin(LightningElement) {

    // ── Public API ───────────────────────────────────────────────────────────
    @api showCompleted = false;
    @api initialZoom = 'Month';

    // ── Tracked state ────────────────────────────────────────────────────────
    @track isLoading = true;
    @track errorMessage = '';
    @track rawTasks = [];
    @track rawDependencies = [];
    @track workflowConfig = null;
    @track currentZoom = 'Month';
    @track _showCompleted = false;
    @track _showDependencies = true;
    @track _showMyWork = false;
    @track selectedEntity = '';
    @track summaryStats = { total: 0, onTrack: 0, overdue: 0 };
    @track quickEditRecordId = null;

    // ── Private state ────────────────────────────────────────────────────────
    _ganttInitialized = false;
    _scriptsLoaded = false;
    _scriptsLoading = false;
    _wiredGanttResult = null;
    _wiredDepsResult = null;
    _eventIds = [];
    _linkSfIdMap = {};       // dhtmlx link id → SF dependency Id
    _taskSfIdMap = {};       // dhtmlx task id → SF work item Id (for project rows: null)
    _sfToGanttIdMap = {};    // SF work item Id → dhtmlx task id
    _currentUserId = USER_ID;

    // ── Lifecycle ────────────────────────────────────────────────────────────

    connectedCallback() {
        this._loadPrefs();
        if (!this.currentZoom) {
            this.currentZoom = this.initialZoom || 'Month';
        }
        if (this._showCompleted === undefined || this._showCompleted === null) {
            this._showCompleted = this.showCompleted;
        }
    }

    renderedCallback() {
        if (this._ganttInitialized) { return; }
        if (!this._scriptsLoaded) {
            this._loadLibrary();
            return;
        }
        if (this._hasDataReady) {
            this._initGantt();
        }
    }

    disconnectedCallback() {
        this._destroyGantt();
    }

    // ── Wires ────────────────────────────────────────────────────────────────

    @wire(getWorkflowConfig, { workflowTypeName: 'Software_Delivery' })
    wiredConfig({ data, error }) {
        if (data) {
            this.workflowConfig = data;
            this._tryRender();
        } else if (error) {
            console.error('[DeliveryDhtmlxGantt] getWorkflowConfig error:', error);
        }
    }

    @wire(getGanttData, { showCompleted: '$_showCompleted' })
    wiredGanttData(result) {
        this._wiredGanttResult = result;
        this.isLoading = false;
        if (result.data) {
            this.rawTasks = result.data;
            this._computeSummary();
            this._tryRender();
        } else if (result.error) {
            this.errorMessage = result.error.body ? result.error.body.message : result.error.message;
        }
    }

    @wire(getGanttDependencies)
    wiredDependencies(result) {
        this._wiredDepsResult = result;
        if (result.data) {
            this.rawDependencies = result.data;
            this._tryRender();
        } else if (result.error) {
            console.error('[DeliveryDhtmlxGantt] getGanttDependencies error:', result.error);
        }
    }

    // ── Computed state ───────────────────────────────────────────────────────

    get hasError()  { return !this.isLoading && !!this.errorMessage; }
    get isEmpty()   { return !this.isLoading && !this.errorMessage && this.filteredTasks.length === 0; }
    get hasData()   { return !this.isLoading && !this.errorMessage && this.filteredTasks.length > 0; }
    get _hasDataReady() { return this.rawTasks.length > 0 && this.workflowConfig; }

    get showQuickEdit() { return !!this.quickEditRecordId; }

    get filteredTasks() {
        if (!this.rawTasks) { return []; }
        let tasks = this.rawTasks;
        if (this.selectedEntity) {
            tasks = tasks.filter(t => (t.entityName || 'Unassigned') === this.selectedEntity);
        }
        if (this._showMyWork) {
            tasks = tasks.filter(t => t.developerName && this._currentUserId);
        }
        return tasks;
    }

    get subtitleText() {
        const count = this.filteredTasks.length;
        if (this.isLoading) { return 'Loading...'; }
        if (count === 0) { return 'No work items'; }
        const suffix = count === 1 ? 'item' : 'items';
        const parts = [count + ' work ' + suffix];
        if (this.selectedEntity) { parts.push(this.selectedEntity); }
        if (this._showCompleted) { parts.push('incl. completed'); }
        if (this._showMyWork) { parts.push('my work'); }
        return parts.join(' \u00b7 ');
    }

    get entityOptions() {
        if (!this.rawTasks) { return []; }
        const entities = new Set();
        this.rawTasks.forEach(t => entities.add(t.entityName || 'Unassigned'));
        const opts = [{ label: 'All Clients', value: '' }];
        Array.from(entities).sort().forEach(e => opts.push({ label: e, value: e }));
        return opts;
    }

    get legendItems() {
        const usedPhases = new Set();
        if (this.workflowConfig && this.workflowConfig.stages) {
            this.filteredTasks.forEach(t => {
                const phase = this._stagePhaseMap[t.stage] || 'Development';
                usedPhases.add(phase);
            });
        }
        const phases = usedPhases.size > 0 ? Array.from(usedPhases) : Object.keys(PHASE_COLORS);
        return phases.map(phase => ({
            phase,
            dotStyle: 'background-color: ' + PHASE_COLORS[phase] + ';'
        }));
    }

    get hasSummaryStats() { return this.summaryStats.total > 0; }

    // ── Stage-to-phase mapping ───────────────────────────────────────────────

    get _stagePhaseMap() {
        if (!this.workflowConfig || !this.workflowConfig.stages) { return {}; }
        const map = {};
        this.workflowConfig.stages.forEach(s => {
            map[s.apiValue] = s.phase || 'Development';
        });
        return map;
    }

    _getColorForStage(stageName) {
        const phase = this._stagePhaseMap[stageName] || 'Development';
        return PHASE_COLORS[phase] || DEFAULT_COLOR;
    }

    // ── Summary computation ──────────────────────────────────────────────────

    _computeSummary() {
        const today = new Date();
        today.setHours(0, 0, 0, 0);
        let onTrack = 0;
        let overdue = 0;

        this.rawTasks.forEach(t => {
            if (t.isCompleted) { return; }
            if (!t.endDate) { onTrack++; return; }
            const end = new Date(t.endDate + 'T00:00:00');
            if (end < today) {
                overdue++;
            } else {
                onTrack++;
            }
        });

        this.summaryStats = {
            total: this.rawTasks.length,
            onTrack,
            overdue
        };
    }

    // ── Toolbar event handlers ───────────────────────────────────────────────

    handleZoomChange(event) {
        const zoom = event.detail.value;
        this.currentZoom = zoom;
        this._savePrefs();
        if (this._ganttInitialized && window.gantt) {
            this._applyZoom(window.gantt);
            window.gantt.render();
        }
    }

    handleEntityChange(event) {
        this.selectedEntity = event.detail.value;
        this._savePrefs();
        this._rebuildGantt();
    }

    handleToggleDependencies() {
        this._showDependencies = !this._showDependencies;
        this._savePrefs();
        if (this._ganttInitialized && window.gantt) {
            window.gantt.config.show_links = this._showDependencies;
            window.gantt.render();
        }
    }

    handleToggleCompleted() {
        this._showCompleted = !this._showCompleted;
        this._savePrefs();
        // Wire will re-fire with new _showCompleted param
    }

    handleToggleMyWork() {
        this._showMyWork = !this._showMyWork;
        this._savePrefs();
        this._rebuildGantt();
    }

    handleScrollToday() {
        if (this._ganttInitialized && window.gantt) {
            window.gantt.showDate(new Date());
        }
    }

    handleRefresh() {
        this.isLoading = true;
        refreshApex(this._wiredGanttResult);
        refreshApex(this._wiredDepsResult);
    }

    // ── Quick-edit handlers ──────────────────────────────────────────────────

    handleQuickEditSave() {
        this.quickEditRecordId = null;
        this.handleRefresh();
    }

    handleQuickEditClose() {
        this.quickEditRecordId = null;
    }

    // ── Keyboard shortcuts ───────────────────────────────────────────────────

    _keyHandler = null;

    _attachKeyboard() {
        this._keyHandler = (e) => {
            // Ctrl+Z = undo, Ctrl+Shift+Z = redo
            if (!window.gantt || !this._ganttInitialized) { return; }
            if (e.ctrlKey && e.key === 'z' && !e.shiftKey) {
                e.preventDefault();
                window.gantt.undo();
            } else if (e.ctrlKey && e.key === 'z' && e.shiftKey) {
                e.preventDefault();
                window.gantt.redo();
            } else if (e.ctrlKey && e.key === 'y') {
                e.preventDefault();
                window.gantt.redo();
            }
        };
        window.addEventListener('keydown', this._keyHandler);
    }

    _detachKeyboard() {
        if (this._keyHandler) {
            window.removeEventListener('keydown', this._keyHandler);
            this._keyHandler = null;
        }
    }

    // ── Library loading ──────────────────────────────────────────────────────

    _loadLibrary() {
        if (this._scriptsLoading) { return; }
        this._scriptsLoading = true;
        Promise.all([
            loadScript(this, GANTT_RES + '/dhtmlxgantt.js'),
            loadStyle(this, GANTT_RES + '/dhtmlxgantt.css')
        ])
        .then(() => {
            this._scriptsLoaded = true;
            if (this._hasDataReady) {
                this._initGantt();
            }
        })
        .catch(error => {
            this.errorMessage = 'Failed to load Gantt library: ' + (error.message || error);
            console.error('[DeliveryDhtmlxGantt] loadScript/loadStyle error:', error);
        });
    }

    // ── Gantt initialization ─────────────────────────────────────────────────

    _initGantt() {
        const container = this.refs.ganttContainer;
        if (!container || this._ganttInitialized || !window.gantt) { return; }

        this._ganttInitialized = true;
        const g = window.gantt;

        // Reset
        g.clearAll();

        // ── Plugins ──────────────────────────────────────────────────────────
        g.plugins({ marker: true, tooltip: true, undo: true });

        // ── Core config ──────────────────────────────────────────────────────
        g.config.date_format = '%Y-%m-%d';
        g.config.readonly = false;
        g.config.drag_move = true;
        g.config.drag_resize = true;
        g.config.drag_progress = true;
        g.config.drag_links = true;
        g.config.details_on_create = false;
        g.config.details_on_dblclick = false;
        g.config.show_links = this._showDependencies;
        g.config.show_progress = true;
        g.config.fit_tasks = true;
        g.config.auto_scheduling = false;
        g.config.open_tree_initially = true;
        g.config.row_height = 38;
        g.config.bar_height = 26;
        g.config.scale_height = 56;
        g.config.grid_width = 460;
        g.config.sort = true;
        g.config.undo_steps = 20;
        g.config.show_task_cells = true;
        g.config.smart_rendering = true;
        g.config.show_errors = false;

        // ── Grid columns ─────────────────────────────────────────────────────
        g.config.columns = [
            {
                name: 'text',
                label: 'Work Item',
                tree: true,
                width: 200,
                resize: true,
                template: function(task) {
                    if (task.$virtual || task.type === g.config.types.project) {
                        return '<span class="dg-project-label">' + _escHtml(task.text) + '</span>';
                    }
                    return '<span class="dg-task-name">' + _escHtml(task.text) + '</span>';
                }
            },
            {
                name: 'stage',
                label: 'Stage',
                width: 100,
                resize: true,
                template: function(task) {
                    if (task.$virtual || task.type === g.config.types.project || !task.stage) { return ''; }
                    var color = task.color || '#e5e7eb';
                    return '<span class="dg-stage-pill" style="background:' + color + ';color:#fff;">'
                        + _escHtml(task.stage) + '</span>';
                }
            },
            {
                name: 'developer',
                label: 'Dev',
                width: 80,
                resize: true,
                template: function(task) {
                    if (task.$virtual || task.type === g.config.types.project || !task.developerName) { return ''; }
                    var firstName = task.developerName.split(' ')[0];
                    return '<span class="dg-dev-name">' + _escHtml(firstName) + '</span>';
                }
            },
            {
                name: 'hours',
                label: 'Hours',
                width: 80,
                resize: true,
                template: function(task) {
                    if (task.$virtual || task.type === g.config.types.project) { return ''; }
                    if (task.estimatedHours == null || task.estimatedHours === 0) { return ''; }
                    var logged = task.loggedHours || 0;
                    return '<span class="dg-hours">' + logged.toFixed(1) + '/' + task.estimatedHours.toFixed(1) + 'h</span>';
                }
            }
        ];

        // ── Zoom ─────────────────────────────────────────────────────────────
        this._applyZoom(g);

        // ── Today marker ─────────────────────────────────────────────────────
        g.addMarker({
            start_date: new Date(),
            css: 'dg-today-marker',
            text: 'Today',
            title: 'Today: ' + new Date().toLocaleDateString()
        });

        // ── Templates ────────────────────────────────────────────────────────
        const self = this;

        g.templates.task_class = function(start, end, task) {
            var cls = [];
            if (task.isCompleted) { cls.push('dg-completed'); }
            if (task.phase) { cls.push('dg-phase-' + task.phase.toLowerCase()); }
            return cls.join(' ');
        };

        g.templates.task_text = function(start, end, task) {
            if (task.$virtual || task.type === g.config.types.project) { return ''; }
            if (task.estimatedHours != null && task.estimatedHours > 0) {
                var logged = task.loggedHours || 0;
                return '<span class="dg-bar-text">' + logged.toFixed(1) + '/' + task.estimatedHours.toFixed(1) + 'h</span>';
            }
            return '';
        };

        g.templates.progress_text = function() { return ''; };

        g.templates.grid_row_class = function(start, end, task) {
            if (task.isCompleted) { return 'dg-row-completed'; }
            return '';
        };

        g.templates.link_class = function(link) {
            return 'dg-link';
        };

        // ── Tooltip ──────────────────────────────────────────────────────────
        g.templates.tooltip_text = function(start, end, task) {
            if (task.$virtual || task.type === g.config.types.project) {
                return '<div class="dg-tip"><b>' + _escHtml(task.text) + '</b>'
                    + '<div class="dg-tip-row">' + (task.childCount || 0) + ' work item(s)</div></div>';
            }

            var html = '<div class="dg-tip">';
            html += '<div class="dg-tip-title">' + _escHtml(task.text) + '</div>';

            if (task.description) {
                html += '<div class="dg-tip-desc">' + _escHtml(task.description) + '</div>';
            }

            // Stage + Priority badges
            html += '<div class="dg-tip-badges">';
            if (task.stage) {
                html += '<span class="dg-tip-badge" style="background:' + (task.color || '#6b7280') + ';">'
                    + _escHtml(task.stage) + '</span>';
            }
            if (task.priority) {
                var priClass = 'dg-pri-' + (task.priority || '').toLowerCase();
                html += '<span class="dg-tip-badge ' + priClass + '">' + _escHtml(task.priority) + '</span>';
            }
            html += '</div>';

            // Developer + Client
            if (task.developerName) {
                html += '<div class="dg-tip-row"><span class="dg-tip-label">Developer:</span> ' + _escHtml(task.developerName) + '</div>';
            }
            if (task.entityName) {
                html += '<div class="dg-tip-row"><span class="dg-tip-label">Client:</span> ' + _escHtml(task.entityName) + '</div>';
            }

            // Hours + Progress bar
            if (task.estimatedHours != null && task.estimatedHours > 0) {
                var logged = task.loggedHours || 0;
                var pct = Math.min(Math.round((logged / task.estimatedHours) * 100), 100);
                html += '<div class="dg-tip-row"><span class="dg-tip-label">Hours:</span> '
                    + logged.toFixed(1) + ' / ' + task.estimatedHours.toFixed(1) + 'h (' + pct + '%)</div>';
                html += '<div class="dg-tip-progress-track"><div class="dg-tip-progress-fill" style="width:' + pct + '%;background:' + (task.color || '#22c55e') + ';"></div></div>';
            }

            // Date range
            var fmt = g.date.date_to_str('%M %j, %Y');
            html += '<div class="dg-tip-dates">' + fmt(start) + '  \u2192  ' + fmt(end) + '</div>';

            // Days remaining / overdue
            var today = new Date();
            today.setHours(0, 0, 0, 0);
            var daysLeft = Math.ceil((end - today) / (1000 * 60 * 60 * 24));
            if (daysLeft < 0 && !task.isCompleted) {
                html += '<div class="dg-tip-overdue">' + Math.abs(daysLeft) + ' days overdue</div>';
            } else if (daysLeft >= 0 && daysLeft <= 7 && !task.isCompleted) {
                html += '<div class="dg-tip-warning">' + daysLeft + ' days remaining</div>';
            }

            html += '<div class="dg-tip-hint">Click to edit \u00b7 Double-click to open \u00b7 Drag to reschedule</div>';
            html += '</div>';
            return html;
        };

        // ── Event: Task drag (move/resize) ───────────────────────────────────
        this._attachEvent(g, 'onAfterTaskDrag', function(id, mode) {
            var task = g.getTask(id);
            if (!task || !task.sfId) { return; }
            var startStr = self._formatDate(task.start_date);
            var endStr = self._formatDate(task.end_date);

            updateWorkItemDates({ workItemId: task.sfId, startDate: startStr, endDate: endStr })
                .then(function() {
                    self._toast('Dates Updated', task.text + ': ' + startStr + ' to ' + endStr, 'success');
                })
                .catch(function(err) {
                    self._toast('Error Saving Dates', err.body ? err.body.message : err.message, 'error');
                    self.handleRefresh();
                });
        });

        // ── Event: Progress drag ─────────────────────────────────────────────
        // Progress is calculated from hours, so we don't save it — just show feedback
        this._attachEvent(g, 'onAfterTaskDrag', function(id, mode) {
            if (mode === 'progress') {
                var task = g.getTask(id);
                // Reset progress to actual hours-based value
                if (task && task.sfId && task.actualProgress !== undefined) {
                    task.progress = task.actualProgress;
                    g.refreshTask(id);
                }
            }
        });

        // ── Event: Link added (dependency created) ───────────────────────────
        this._attachEvent(g, 'onAfterLinkAdd', function(id, link) {
            var sourceTask = g.getTask(link.source);
            var targetTask = g.getTask(link.target);
            if (!sourceTask || !targetTask || !sourceTask.sfId || !targetTask.sfId) {
                // Remove the link if it connects project rows
                g.deleteLink(id);
                return;
            }

            createDependency({
                blockedWorkItemId: targetTask.sfId,
                blockingWorkItemId: sourceTask.sfId
            })
                .then(function(result) {
                    // Map the DHTMLX link id to the SF dependency Id
                    self._linkSfIdMap[id] = result.Id;
                    self._toast('Dependency Created',
                        sourceTask.text + ' blocks ' + targetTask.text, 'success');
                })
                .catch(function(err) {
                    g.deleteLink(id);
                    self._toast('Error Creating Dependency', err.body ? err.body.message : err.message, 'error');
                });
        });

        // ── Event: Link deleted (dependency removed) ─────────────────────────
        this._attachEvent(g, 'onAfterLinkDelete', function(id, link) {
            var sfId = self._linkSfIdMap[id];
            if (!sfId) { return; }

            removeDependency({ dependencyId: sfId })
                .then(function() {
                    delete self._linkSfIdMap[id];
                    self._toast('Dependency Removed', 'Link removed successfully.', 'success');
                })
                .catch(function(err) {
                    self._toast('Error Removing Dependency', err.body ? err.body.message : err.message, 'error');
                    self.handleRefresh();
                });
        });

        // ── Event: Single click → Quick Edit ─────────────────────────────────
        this._attachEvent(g, 'onTaskClick', function(id) {
            var task = g.getTask(id);
            if (task && task.sfId && task.type !== g.config.types.project) {
                self.quickEditRecordId = task.sfId;
            }
            return true;
        });

        // ── Event: Double click → Navigate to record ─────────────────────────
        this._attachEvent(g, 'onTaskDblClick', function(id) {
            var task = g.getTask(id);
            if (task && task.sfId && task.type !== g.config.types.project) {
                self[NavigationMixin.Navigate]({
                    type: 'standard__recordPage',
                    attributes: {
                        recordId: task.sfId,
                        objectApiName: 'WorkItem__c',
                        actionName: 'view'
                    }
                });
            }
            return false; // prevent default lightbox
        });

        // Prevent lightbox on any event
        this._attachEvent(g, 'onBeforeLightbox', function() { return false; });

        // ── Initialize ───────────────────────────────────────────────────────
        g.init(container);
        this._loadGanttData(g);
        this._attachKeyboard();

        // Scroll to today after initial render
        requestAnimationFrame(function() {
            g.showDate(new Date());
        });
    }

    // ── Data loading ─────────────────────────────────────────────────────────

    _loadGanttData(g) {
        if (!g) { g = window.gantt; }
        if (!g || !this._ganttInitialized) { return; }

        g.clearAll();

        // Re-add today marker after clearAll
        g.addMarker({
            start_date: new Date(),
            css: 'dg-today-marker',
            text: 'Today',
            title: 'Today: ' + new Date().toLocaleDateString()
        });

        this._linkSfIdMap = {};
        this._taskSfIdMap = {};
        this._sfToGanttIdMap = {};

        var data = [];
        var links = [];
        var entityMap = {};
        var projectCounter = 1000000;
        var filteredTasks = this.filteredTasks;
        // Build a set of IDs in the current dataset for parent resolution
        var taskIdSet = new Set(filteredTasks.map(function(t) { return t.workItemId; }));

        // ── Build entity project rows ────────────────────────────────────────
        filteredTasks.forEach(function(item) {
            var entityName = item.entityName || 'Unassigned';
            var entityKey = item.entityId || 'unassigned';
            if (!entityMap[entityKey]) {
                projectCounter++;
                entityMap[entityKey] = {
                    id: 'proj_' + projectCounter,
                    text: entityName,
                    type: g.config.types.project,
                    open: true,
                    childCount: 0,
                    render: 'split'
                };
            }
            entityMap[entityKey].childCount++;
        });

        // Add project rows
        Object.values(entityMap).forEach(function(project) {
            data.push(project);
        });

        // ── Build task rows ──────────────────────────────────────────────────
        var self = this;
        filteredTasks.forEach(function(item) {
            var entityKey = item.entityId || 'unassigned';
            var entityProject = entityMap[entityKey];
            var color = self._getColorForStage(item.stage);
            var phase = self._stagePhaseMap[item.stage] || 'Development';

            // Determine parent: use actual parent if in dataset, otherwise entity project
            var parentId = entityProject ? entityProject.id : 0;
            if (item.parentWorkItemId && taskIdSet.has(item.parentWorkItemId)) {
                parentId = item.parentWorkItemId;
            }

            var task = {
                id: item.workItemId,
                sfId: item.workItemId,
                text: item.name,
                start_date: item.startDate,
                end_date: item.endDate,
                progress: item.progress || 0,
                actualProgress: item.progress || 0,
                parent: parentId,
                color: color,
                progressColor: self._darkenColor(color, 40),
                phase: phase,
                stage: item.stage,
                priority: item.priority,
                description: item.description,
                developerName: item.developerName,
                entityName: item.entityName,
                estimatedHours: item.estimatedHours,
                loggedHours: item.loggedHours,
                isCompleted: item.isCompleted,
                open: true
            };

            data.push(task);
            self._taskSfIdMap[item.workItemId] = item.workItemId;
            self._sfToGanttIdMap[item.workItemId] = item.workItemId;
        });

        // ── Build dependency links ───────────────────────────────────────────
        if (this._showDependencies && this.rawDependencies) {
            this.rawDependencies.forEach(function(dep) {
                // Only add links where both source and target are in the dataset
                if (taskIdSet.has(dep.source) && taskIdSet.has(dep.target)) {
                    var linkId = 'link_' + dep.id;
                    links.push({
                        id: linkId,
                        source: dep.source,
                        target: dep.target,
                        type: LINK_TYPE_FS
                    });
                    self._linkSfIdMap[linkId] = dep.id;
                }
            });
        }

        g.parse({ data: data, links: links });
    }

    // ── Zoom control ─────────────────────────────────────────────────────────

    _applyZoom(g) {
        var zoom = ZOOM_CONFIGS[this.currentZoom] || ZOOM_CONFIGS.Month;
        g.config.scales = zoom.scales;
        g.config.min_column_width = zoom.min_column_width;
    }

    // ── Re-render ────────────────────────────────────────────────────────────

    _tryRender() {
        if (!this._scriptsLoaded || !this._hasDataReady) { return; }
        if (this._ganttInitialized) {
            this._loadGanttData(window.gantt);
        } else {
            requestAnimationFrame(() => this._initGantt());
        }
    }

    _rebuildGantt() {
        if (!this._ganttInitialized || !window.gantt) { return; }
        this._loadGanttData(window.gantt);
    }

    // ── Cleanup ──────────────────────────────────────────────────────────────

    _destroyGantt() {
        this._detachKeyboard();
        if (window.gantt && this._ganttInitialized) {
            this._eventIds.forEach(function(evId) {
                try { window.gantt.detachEvent(evId); } catch (e) { /* noop */ }
            });
            this._eventIds = [];
            try { window.gantt.clearAll(); } catch (e) { /* noop */ }
            this._ganttInitialized = false;
        }
    }

    _attachEvent(g, name, fn) {
        var evId = g.attachEvent(name, fn);
        this._eventIds.push(evId);
        return evId;
    }

    // ── localStorage prefs ───────────────────────────────────────────────────

    _loadPrefs() {
        try {
            var raw = localStorage.getItem(PREFS_KEY);
            if (raw) {
                var prefs = JSON.parse(raw);
                if (prefs.currentZoom) { this.currentZoom = prefs.currentZoom; }
                if (prefs.selectedEntity !== undefined) { this.selectedEntity = prefs.selectedEntity; }
                if (prefs._showDependencies !== undefined) { this._showDependencies = prefs._showDependencies; }
                if (prefs._showCompleted !== undefined) { this._showCompleted = prefs._showCompleted; }
                if (prefs._showMyWork !== undefined) { this._showMyWork = prefs._showMyWork; }
            }
        } catch (e) {
            // localStorage unavailable or corrupt — use defaults
        }
    }

    _savePrefs() {
        try {
            localStorage.setItem(PREFS_KEY, JSON.stringify({
                currentZoom: this.currentZoom,
                selectedEntity: this.selectedEntity,
                _showDependencies: this._showDependencies,
                _showCompleted: this._showCompleted,
                _showMyWork: this._showMyWork
            }));
        } catch (e) {
            // localStorage unavailable — fail silently
        }
    }

    // ── Utilities ────────────────────────────────────────────────────────────

    _formatDate(d) {
        if (!d) { return ''; }
        if (typeof d === 'string') { return d; }
        var year = d.getFullYear();
        var month = String(d.getMonth() + 1).padStart(2, '0');
        var day = String(d.getDate()).padStart(2, '0');
        return year + '-' + month + '-' + day;
    }

    _darkenColor(hex, amount) {
        if (!hex || hex.charAt(0) !== '#') { return hex; }
        amount = amount || 30;
        var r = Math.max(0, parseInt(hex.slice(1, 3), 16) - amount);
        var g = Math.max(0, parseInt(hex.slice(3, 5), 16) - amount);
        var b = Math.max(0, parseInt(hex.slice(5, 7), 16) - amount);
        return '#' + r.toString(16).padStart(2, '0')
                   + g.toString(16).padStart(2, '0')
                   + b.toString(16).padStart(2, '0');
    }

    _toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title: title, message: message, variant: variant }));
    }
}

// ── Module-level utility ─────────────────────────────────────────────────────

function _escHtml(str) {
    if (!str) { return ''; }
    return String(str)
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;');
}

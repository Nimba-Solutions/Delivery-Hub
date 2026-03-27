/* eslint-disable */
/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Interactive Gantt chart powered by DHTMLX Gantt (GPL).
 *               Shows work items grouped by client (NetworkEntity), with
 *               progress bars based on logged vs estimated hours, color-coded
 *               by workflow stage phase, and zoom controls (day/week/month/quarter).
 * @author Cloud Nimbus LLC
 */
import { LightningElement, wire, track, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { loadScript, loadStyle } from 'lightning/platformResourceLoader';
import GANTT_RES from '@salesforce/resourceUrl/dhtmlxgantt';
import getGanttData from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryGanttController.getGanttData';
import getWorkflowConfig from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryWorkflowConfigService.getWorkflowConfig';

// Phase → color mapping for task bars
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

// Zoom level presets for DHTMLX Gantt
const ZOOM_LEVELS = {
    day:     { scales: [{ unit: 'month', step: 1, format: '%F %Y' }, { unit: 'day', step: 1, format: '%j' }], min_column_width: 30, subscale_height: 28 },
    week:    { scales: [{ unit: 'month', step: 1, format: '%F %Y' }, { unit: 'week', step: 1, format: 'Week %W' }], min_column_width: 60, subscale_height: 28 },
    month:   { scales: [{ unit: 'year', step: 1, format: '%Y' }, { unit: 'month', step: 1, format: '%M' }], min_column_width: 50, subscale_height: 28 },
    quarter: { scales: [{ unit: 'year', step: 1, format: '%Y' }, { unit: 'month', step: 3, format: function(date) { return 'Q' + (Math.floor(date.getMonth() / 3) + 1); } }], min_column_width: 80, subscale_height: 28 }
};

export default class DeliveryGanttChart extends NavigationMixin(LightningElement) {
    // ── Public API properties ────────────────────────────────────────────────

    /** When true, includes completed (inactive) work items */
    @api showCompleted = false;

    /** Initial zoom level: day, week, month, quarter */
    @api initialZoom = 'month';

    // ── Tracked state ────────────────────────────────────────────────────────

    @track isLoading = true;
    @track errorMessage = '';
    @track rawTasks = [];
    @track workflowConfig = null;
    @track currentZoom = 'month';
    @track _showCompleted = false;

    _ganttInitialized = false;
    _scriptsLoaded = false;
    _scriptsLoading = false;
    _taskClickHandler = null;

    // ── Lifecycle ────────────────────────────────────────────────────────────

    connectedCallback() {
        this.currentZoom = this.initialZoom || 'month';
        this._showCompleted = this.showCompleted;
    }

    renderedCallback() {
        if (this._ganttInitialized) {
            return;
        }
        if (!this._scriptsLoaded) {
            this._loadLibrary();
            return;
        }
        if (this.hasData) {
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
            console.error('[DeliveryGanttChart] getWorkflowConfig error:', error);
        }
    }

    @wire(getGanttData, { showCompleted: '$_showCompleted' })
    wiredGanttData({ data, error }) {
        this.isLoading = false;
        if (data) {
            this.rawTasks = data;
            this._tryRender();
        } else if (error) {
            this.errorMessage = error.body ? error.body.message : error.message;
        }
    }

    // ── Computed UI state ────────────────────────────────────────────────────

    get hasError() { return !this.isLoading && !!this.errorMessage; }
    get isEmpty()  { return !this.isLoading && !this.errorMessage && this.rawTasks.length === 0; }
    get hasData()  { return !this.isLoading && !this.errorMessage && this.rawTasks.length > 0; }

    get subtitleText() {
        const count = this.rawTasks.length;
        if (this.isLoading) { return 'Loading...'; }
        if (count === 0) { return 'No work items'; }
        const suffix = count === 1 ? 'item' : 'items';
        const completed = this._showCompleted ? ' (including completed)' : '';
        return count + ' work ' + suffix + completed;
    }

    get btnDayVariant()     { return this.currentZoom === 'day' ? 'brand' : 'neutral'; }
    get btnWeekVariant()    { return this.currentZoom === 'week' ? 'brand' : 'neutral'; }
    get btnMonthVariant()   { return this.currentZoom === 'month' ? 'brand' : 'neutral'; }
    get btnQuarterVariant() { return this.currentZoom === 'quarter' ? 'brand' : 'neutral'; }

    get completedToggleTitle() {
        return this._showCompleted ? 'Hide completed items' : 'Show completed items';
    }
    get completedToggleVariant() {
        return this._showCompleted ? 'brand' : 'border';
    }

    get legendItems() {
        const phases = Object.keys(PHASE_COLORS);
        return phases.map(phase => ({
            phase,
            dotStyle: 'background-color: ' + PHASE_COLORS[phase] + ';'
        }));
    }

    // ── Stage → phase color mapping ──────────────────────────────────────────

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

    // ── Handlers ─────────────────────────────────────────────────────────────

    handleZoomDay()     { this._setZoom('day'); }
    handleZoomWeek()    { this._setZoom('week'); }
    handleZoomMonth()   { this._setZoom('month'); }
    handleZoomQuarter() { this._setZoom('quarter'); }

    handleToggleCompleted() {
        this._showCompleted = !this._showCompleted;
        // Wire will re-fire with new param and _tryRender will update the chart
    }

    // ── Private: Library loading ─────────────────────────────────────────────

    _loadLibrary() {
        if (this._scriptsLoading) { return; }
        this._scriptsLoading = true;
        Promise.all([
            loadScript(this, GANTT_RES + '/dhtmlxgantt.js'),
            loadStyle(this, GANTT_RES + '/dhtmlxgantt.css')
        ])
        .then(() => {
            this._scriptsLoaded = true;
            if (this.hasData) {
                this._initGantt();
            }
        })
        .catch(error => {
            this.errorMessage = 'Failed to load Gantt library: ' + (error.message || error);
            console.error('[DeliveryGanttChart] loadScript/loadStyle error:', error);
        });
    }

    // ── Private: Gantt initialization ────────────────────────────────────────

    _initGantt() {
        const container = this.refs.ganttContainer;
        if (!container || this._ganttInitialized || !window.gantt) {
            return;
        }

        this._ganttInitialized = true;
        const ganttInstance = window.gantt;

        // Reset any previous state
        ganttInstance.clearAll();

        // ── Configuration ────────────────────────────────────────────────────
        ganttInstance.config.date_format = '%Y-%m-%d';
        ganttInstance.config.readonly = true;
        ganttInstance.config.drag_move = false;
        ganttInstance.config.drag_resize = false;
        ganttInstance.config.drag_progress = false;
        ganttInstance.config.drag_links = false;
        ganttInstance.config.details_on_create = false;
        ganttInstance.config.details_on_dblclick = false;
        ganttInstance.config.show_links = false;
        ganttInstance.config.show_progress = true;
        ganttInstance.config.fit_tasks = true;
        ganttInstance.config.auto_scheduling = false;
        ganttInstance.config.open_tree_initially = true;
        ganttInstance.config.row_height = 36;
        ganttInstance.config.bar_height = 24;
        ganttInstance.config.scale_height = 56;
        ganttInstance.config.grid_width = 350;
        ganttInstance.config.sort = true;

        // Grid columns
        ganttInstance.config.columns = [
            {
                name: 'text',
                label: 'Work Item',
                tree: true,
                width: 220,
                resize: true,
                template: function(task) {
                    if (task.type === ganttInstance.config.types.project) {
                        return '<span class="gantt-project-label">' + task.text + '</span>';
                    }
                    return '<span class="gantt-task-name">' + task.text + '</span>';
                }
            },
            {
                name: 'stage',
                label: 'Stage',
                width: 110,
                resize: true,
                template: function(task) {
                    if (task.type === ganttInstance.config.types.project) { return ''; }
                    return '<span class="gantt-stage-pill">' + (task.stage || '') + '</span>';
                }
            }
        ];

        // Apply zoom level
        this._applyZoom(ganttInstance);

        // Today marker
        ganttInstance.plugins({ marker: true });
        ganttInstance.addMarker({
            start_date: new Date(),
            css: 'gantt-today-marker',
            text: 'Today',
            title: 'Today: ' + new Date().toLocaleDateString()
        });

        // Task bar template — apply color from stage phase
        const self = this;
        ganttInstance.templates.task_class = function(start, end, task) {
            if (task.isCompleted) { return 'gantt-task-completed'; }
            return '';
        };

        ganttInstance.templates.task_text = function(start, end, task) {
            if (task.type === ganttInstance.config.types.project) { return ''; }
            const hours = task.loggedHours != null && task.estimatedHours != null
                ? task.loggedHours + '/' + task.estimatedHours + 'h'
                : '';
            return '<span class="gantt-bar-text">' + hours + '</span>';
        };

        ganttInstance.templates.progress_text = function() {
            return '';
        };

        // Tooltip
        ganttInstance.plugins({ tooltip: true });
        ganttInstance.templates.tooltip_text = function(start, end, task) {
            if (task.type === ganttInstance.config.types.project) {
                return '<b>' + task.text + '</b><br/>' + task.childCount + ' work item(s)';
            }
            let tip = '<b>' + task.text + '</b>';
            if (task.description) { tip += '<br/>' + task.description; }
            tip += '<br/>Stage: ' + (task.stage || 'N/A');
            if (task.priority) { tip += '<br/>Priority: ' + task.priority; }
            if (task.developerName) { tip += '<br/>Developer: ' + task.developerName; }
            tip += '<br/>Start: ' + ganttInstance.templates.tooltip_date_format(start);
            tip += '<br/>End: ' + ganttInstance.templates.tooltip_date_format(end);
            if (task.estimatedHours != null) {
                tip += '<br/>Hours: ' + (task.loggedHours || 0) + ' / ' + task.estimatedHours;
            }
            if (task.progress != null) {
                tip += '<br/>Progress: ' + Math.round(task.progress * 100) + '%';
            }
            return tip;
        };

        // Task click → navigate to record
        if (this._taskClickHandler) {
            ganttInstance.detachEvent(this._taskClickHandler);
        }
        this._taskClickHandler = ganttInstance.attachEvent('onTaskClick', function(id) {
            const task = ganttInstance.getTask(id);
            if (task && task.sfId && task.type !== ganttInstance.config.types.project) {
                self[NavigationMixin.Navigate]({
                    type: 'standard__recordPage',
                    attributes: {
                        recordId: task.sfId,
                        objectApiName: 'WorkItem__c',
                        actionName: 'view'
                    }
                });
            }
            return true;
        });

        // Initialize
        ganttInstance.init(container);

        // Load data
        this._loadGanttData(ganttInstance);
    }

    // ── Private: Load data into Gantt ────────────────────────────────────────

    _loadGanttData(ganttInstance) {
        if (!ganttInstance) {
            ganttInstance = window.gantt;
        }
        if (!ganttInstance || !this._ganttInitialized) { return; }

        ganttInstance.clearAll();

        // Re-add today marker after clearAll
        ganttInstance.addMarker({
            start_date: new Date(),
            css: 'gantt-today-marker',
            text: 'Today',
            title: 'Today: ' + new Date().toLocaleDateString()
        });

        const tasks = [];
        const entityMap = {};
        let projectId = 1000000;

        // Group tasks by entity
        this.rawTasks.forEach(item => {
            const entityName = item.entityName || 'Unassigned';
            const entityKey = item.entityId || 'unassigned';

            if (!entityMap[entityKey]) {
                projectId++;
                entityMap[entityKey] = {
                    id: 'project_' + projectId,
                    text: entityName,
                    type: ganttInstance.config.types.project,
                    open: true,
                    childCount: 0
                };
            }
            entityMap[entityKey].childCount++;

            const color = this._getColorForStage(item.stage);

            tasks.push({
                id: item.workItemId,
                sfId: item.workItemId,
                text: item.name + (item.description ? ' — ' + item.description : ''),
                start_date: item.startDate,
                end_date: item.endDate,
                progress: item.progress || 0,
                parent: entityMap[entityKey].id,
                color: color,
                progressColor: this._darkenColor(color),
                stage: item.stage,
                priority: item.priority,
                description: item.description,
                developerName: item.developerName,
                estimatedHours: item.estimatedHours,
                loggedHours: item.loggedHours,
                isCompleted: item.isCompleted
            });
        });

        // Build data structure
        const data = [];
        Object.values(entityMap).forEach(project => {
            data.push(project);
        });
        data.push(...tasks);

        ganttInstance.parse({ data: data, links: [] });
    }

    // ── Private: Zoom control ────────────────────────────────────────────────

    _setZoom(level) {
        this.currentZoom = level;
        if (this._ganttInitialized && window.gantt) {
            this._applyZoom(window.gantt);
            window.gantt.render();
        }
    }

    _applyZoom(ganttInstance) {
        const zoom = ZOOM_LEVELS[this.currentZoom] || ZOOM_LEVELS.month;
        ganttInstance.config.scales = zoom.scales;
        ganttInstance.config.min_column_width = zoom.min_column_width;
        ganttInstance.config.subscale_height = zoom.subscale_height;
    }

    // ── Private: Re-render when data changes ─────────────────────────────────

    _tryRender() {
        if (!this._ganttInitialized || !window.gantt || !this.rawTasks.length) {
            return;
        }
        this._loadGanttData(window.gantt);
    }

    // ── Private: Cleanup ─────────────────────────────────────────────────────

    _destroyGantt() {
        if (window.gantt && this._ganttInitialized) {
            if (this._taskClickHandler) {
                window.gantt.detachEvent(this._taskClickHandler);
                this._taskClickHandler = null;
            }
            try {
                window.gantt.destructor();
            } catch (e) {
                // Gantt destructor can throw if DOM is already gone
            }
            this._ganttInitialized = false;
        }
    }

    // ── Private: Color utilities ─────────────────────────────────────────────

    _darkenColor(hex) {
        if (!hex || hex.charAt(0) !== '#') { return hex; }
        const r = Math.max(0, parseInt(hex.slice(1, 3), 16) - 30);
        const g = Math.max(0, parseInt(hex.slice(3, 5), 16) - 30);
        const b = Math.max(0, parseInt(hex.slice(5, 7), 16) - 30);
        return '#' + r.toString(16).padStart(2, '0')
                   + g.toString(16).padStart(2, '0')
                   + b.toString(16).padStart(2, '0');
    }
}

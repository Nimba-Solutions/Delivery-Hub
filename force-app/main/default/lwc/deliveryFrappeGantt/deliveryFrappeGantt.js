/* eslint-disable @lwc/lwc/no-async-operation, no-unused-vars */
/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Interactive Gantt chart powered by Frappe Gantt (MIT).
 *               Shows work items with progress bars color-coded by workflow
 *               stage phase, view mode controls (Quarter Day / Half Day / Day /
 *               Week / Month), and click-to-navigate to work item records.
 * @author Cloud Nimbus LLC
 */
import { LightningElement, wire, track, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { loadScript, loadStyle } from 'lightning/platformResourceLoader';
import FRAPPE_RES from '@salesforce/resourceUrl/frappegantt';
import getGanttData from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryGanttController.getGanttData';
import getWorkflowConfig from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryWorkflowConfigService.getWorkflowConfig';

// Phase -> CSS class mapping for Frappe Gantt task bars
const PHASE_CSS_MAP = {
    'Planning':    'bar-planning',
    'Approval':    'bar-approval',
    'Development': 'bar-development',
    'Testing':     'bar-testing',
    'UAT':         'bar-uat',
    'Deployment':  'bar-deployment',
    'Done':        'bar-done'
};

const PHASE_COLORS = {
    'Planning':    '#3b82f6',
    'Approval':    '#f59e0b',
    'Development': '#22c55e',
    'Testing':     '#a855f7',
    'UAT':         '#14b8a6',
    'Deployment':  '#ef4444',
    'Done':        '#9ca3af'
};

const DEFAULT_CSS_CLASS = 'bar-development';

export default class DeliveryFrappeGantt extends NavigationMixin(LightningElement) {
    // -- Public API properties ------------------------------------------------

    /** When true, includes completed (inactive) work items */
    @api showCompleted = false;

    /** Initial view mode: Day, Week, Month */
    @api initialViewMode = 'Week';

    // -- Tracked state --------------------------------------------------------

    @track isLoading = true;
    @track errorMessage = '';
    @track rawTasks = [];
    @track workflowConfig = null;
    @track currentViewMode = 'Week';
    @track _showCompleted = false;

    _ganttInitialized = false;
    _scriptsLoaded = false;
    _scriptsLoading = false;
    _ganttInstance = null;
    _taskMap = {}; // Frappe task id -> SF record id

    // -- Lifecycle ------------------------------------------------------------

    connectedCallback() {
        this.currentViewMode = this.initialViewMode || 'Week';
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
        this._ganttInstance = null;
        this._ganttInitialized = false;
    }

    // -- Wires ----------------------------------------------------------------

    @wire(getWorkflowConfig, { workflowTypeName: 'Software_Delivery' })
    wiredConfig({ data, error }) {
        if (data) {
            this.workflowConfig = data;
            this._tryRender();
        } else if (error) {
            console.error('[DeliveryFrappeGantt] getWorkflowConfig error:', error);
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

    // -- Computed UI state ----------------------------------------------------

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

    get btnQuarterDayVariant() { return this.currentViewMode === 'Quarter Day' ? 'brand' : 'neutral'; }
    get btnHalfDayVariant()    { return this.currentViewMode === 'Half Day' ? 'brand' : 'neutral'; }
    get btnDayVariant()        { return this.currentViewMode === 'Day' ? 'brand' : 'neutral'; }
    get btnWeekVariant()       { return this.currentViewMode === 'Week' ? 'brand' : 'neutral'; }
    get btnMonthVariant()      { return this.currentViewMode === 'Month' ? 'brand' : 'neutral'; }

    get completedToggleTitle() {
        return this._showCompleted ? 'Hide completed items' : 'Show completed items';
    }
    get completedToggleVariant() {
        return this._showCompleted ? 'brand' : 'border';
    }

    get legendItems() {
        return Object.keys(PHASE_COLORS).map(phase => ({
            phase,
            dotStyle: 'background-color: ' + PHASE_COLORS[phase] + ';'
        }));
    }

    // -- Stage -> phase mapping -----------------------------------------------

    get _stagePhaseMap() {
        if (!this.workflowConfig || !this.workflowConfig.stages) { return {}; }
        const map = {};
        this.workflowConfig.stages.forEach(s => {
            map[s.apiValue] = s.phase || 'Development';
        });
        return map;
    }

    _getCssClassForStage(stageName) {
        const phase = this._stagePhaseMap[stageName] || 'Development';
        return PHASE_CSS_MAP[phase] || DEFAULT_CSS_CLASS;
    }

    // -- Handlers -------------------------------------------------------------

    handleViewQuarterDay() { this._setViewMode('Quarter Day'); }
    handleViewHalfDay()    { this._setViewMode('Half Day'); }
    handleViewDay()        { this._setViewMode('Day'); }
    handleViewWeek()       { this._setViewMode('Week'); }
    handleViewMonth()      { this._setViewMode('Month'); }

    handleToggleCompleted() {
        this._showCompleted = !this._showCompleted;
        // Wire will re-fire with new param; _tryRender will rebuild the chart
    }

    // -- Private: Library loading ---------------------------------------------

    _loadLibrary() {
        if (this._scriptsLoading) { return; }
        this._scriptsLoading = true;
        Promise.all([
            loadScript(this, FRAPPE_RES + '/frappe-gantt.min.js'),
            loadStyle(this, FRAPPE_RES + '/frappe-gantt.min.css')
        ])
        .then(() => {
            this._scriptsLoaded = true;
            if (this.hasData) {
                this._initGantt();
            }
        })
        .catch(error => {
            this.errorMessage = 'Failed to load Frappe Gantt library: ' + (error.message || error);
            console.error('[DeliveryFrappeGantt] loadScript/loadStyle error:', error);
        });
    }

    // -- Private: Build Frappe Gantt tasks from Apex data ---------------------

    _buildTasks() {
        this._taskMap = {};
        const tasks = [];

        this.rawTasks.forEach(item => {
            const taskId = 'task_' + item.workItemId;
            this._taskMap[taskId] = item.workItemId;

            const label = item.name + (item.description ? ' - ' + item.description : '');
            const cssClass = this._getCssClassForStage(item.stage);

            tasks.push({
                id: taskId,
                name: label,
                start: item.startDate,
                end: item.endDate,
                progress: item.progress != null ? Math.round(item.progress * 100) : 0,
                custom_class: cssClass,
                dependencies: ''
            });
        });

        return tasks;
    }

    // -- Private: Gantt initialization ----------------------------------------

    _initGantt() {
        const svgEl = this.refs.ganttSvg;
        if (!svgEl || this._ganttInitialized) {
            return;
        }

        // Frappe Gantt v0.6.1 attaches to window.Gantt
        if (typeof window.Gantt !== 'function') {
            this.errorMessage = 'Frappe Gantt library did not load correctly.';
            return;
        }

        const tasks = this._buildTasks();
        if (tasks.length === 0) { return; }

        this._ganttInitialized = true;
        const self = this;

        try {
            this._ganttInstance = new window.Gantt(svgEl, tasks, {
                view_mode: this.currentViewMode,
                date_format: 'YYYY-MM-DD',
                bar_height: 24,
                bar_corner_radius: 4,
                arrow_curve: 5,
                padding: 18,
                on_click: function(task) {
                    const sfId = self._taskMap[task.id];
                    if (sfId) {
                        self[NavigationMixin.Navigate]({
                            type: 'standard__recordPage',
                            attributes: {
                                recordId: sfId,
                                objectApiName: 'WorkItem__c',
                                actionName: 'view'
                            }
                        });
                    }
                },
                on_date_change: function() {
                    // Read-only — no date change handling
                },
                custom_popup_html: function(task) {
                    const sfId = self._taskMap[task.id];
                    const item = self.rawTasks.find(t => t.workItemId === sfId);
                    let html = '<div class="frappe-popup">';
                    html += '<div class="frappe-popup-title">' + self._escapeHtml(task.name) + '</div>';
                    if (item) {
                        if (item.stage) {
                            html += '<div class="frappe-popup-row">Stage: <b>' + self._escapeHtml(item.stage) + '</b></div>';
                        }
                        if (item.priority) {
                            html += '<div class="frappe-popup-row">Priority: ' + self._escapeHtml(item.priority) + '</div>';
                        }
                        if (item.entityName) {
                            html += '<div class="frappe-popup-row">Client: ' + self._escapeHtml(item.entityName) + '</div>';
                        }
                        if (item.developerName) {
                            html += '<div class="frappe-popup-row">Developer: ' + self._escapeHtml(item.developerName) + '</div>';
                        }
                        if (item.estimatedHours != null) {
                            const logged = item.loggedHours || 0;
                            html += '<div class="frappe-popup-row">Hours: ' + logged + ' / ' + item.estimatedHours + '</div>';
                        }
                        if (item.progress != null) {
                            html += '<div class="frappe-popup-row">Progress: ' + Math.round(item.progress * 100) + '%</div>';
                        }
                    }
                    html += '<div class="frappe-popup-row frappe-popup-dates">' + task._start.toLocaleDateString() + ' - ' + task._end.toLocaleDateString() + '</div>';
                    html += '</div>';
                    return html;
                }
            });
        } catch (err) {
            this.errorMessage = 'Failed to initialize Frappe Gantt: ' + (err.message || err);
            console.error('[DeliveryFrappeGantt] init error:', err);
            this._ganttInitialized = false;
        }
    }

    // -- Private: View mode control -------------------------------------------

    _setViewMode(mode) {
        this.currentViewMode = mode;
        if (this._ganttInstance) {
            try {
                this._ganttInstance.change_view_mode(mode);
            } catch (err) {
                console.error('[DeliveryFrappeGantt] change_view_mode error:', err);
            }
        }
    }

    // -- Private: Re-render when data changes ---------------------------------

    _tryRender() {
        if (!this._scriptsLoaded || !this.rawTasks.length) {
            return;
        }
        if (this._ganttInitialized && this._ganttInstance) {
            // Rebuild from scratch — Frappe Gantt doesn't have a clean data-update API
            this._ganttInitialized = false;
            this._ganttInstance = null;
            // Clear the SVG contents so Frappe can re-render
            const svgEl = this.refs.ganttSvg;
            if (svgEl) {
                svgEl.innerHTML = '';
            }
        }
        // Schedule re-init on next frame so the DOM is ready
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        requestAnimationFrame(() => {
            this._initGantt();
        });
    }

    // -- Private: HTML escaping -----------------------------------------------

    _escapeHtml(str) {
        if (!str) { return ''; }
        return String(str)
            .replace(/&/g, '&amp;')
            .replace(/</g, '&lt;')
            .replace(/>/g, '&gt;')
            .replace(/"/g, '&quot;');
    }
}

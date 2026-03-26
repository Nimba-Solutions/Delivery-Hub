/* eslint-disable @lwc/lwc/no-async-operation, no-unused-vars */
/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Interactive Gantt chart powered by Frappe Gantt (MIT).
 *               Features: drag-to-reschedule, progress bars by hours,
 *               color-coded by workflow stage phase, view mode controls,
 *               entity grouping, developer names, scroll-to-today,
 *               and click-to-navigate to work item records.
 * @author Cloud Nimbus LLC
 */
import { LightningElement, wire, track, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { loadScript, loadStyle } from 'lightning/platformResourceLoader';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import FRAPPE_RES from '@salesforce/resourceUrl/frappegantt';
import getGanttData from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryGanttController.getGanttData';
import updateWorkItemDates from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryGanttController.updateWorkItemDates';
import getWorkflowConfig from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryWorkflowConfigService.getWorkflowConfig';

const PHASE_COLORS = {
    'Planning':    '#3b82f6',
    'Approval':    '#f59e0b',
    'Development': '#22c55e',
    'Testing':     '#a855f7',
    'UAT':         '#14b8a6',
    'Deployment':  '#ef4444',
    'Done':        '#9ca3af'
};

const PHASE_CSS_MAP = {
    'Planning':    'bar-planning',
    'Approval':    'bar-approval',
    'Development': 'bar-development',
    'Testing':     'bar-testing',
    'UAT':         'bar-uat',
    'Deployment':  'bar-deployment',
    'Done':        'bar-done'
};

const DEFAULT_CSS_CLASS = 'bar-development';

export default class DeliveryFrappeGantt extends NavigationMixin(LightningElement) {

    // ── Public API ──────────────────────────────────────────────────────
    @api showCompleted = false;
    @api initialViewMode = 'Week';

    // ── Tracked state ───────────────────────────────────────────────────
    @track isLoading = true;
    @track errorMessage = '';
    @track rawTasks = [];
    @track workflowConfig = null;
    @track currentViewMode = 'Week';
    @track _showCompleted = false;
    @track selectedEntity = '';
    @track summaryStats = { total: 0, onTrack: 0, overdue: 0, unscheduled: 0 };

    _ganttInitialized = false;
    _scriptsLoaded = false;
    _scriptsLoading = false;
    _ganttInstance = null;
    _taskMap = {};
    _wiredGanttResult = null;

    // ── Lifecycle ───────────────────────────────────────────────────────

    connectedCallback() {
        this.currentViewMode = this.initialViewMode || 'Week';
        this._showCompleted = this.showCompleted;
    }

    renderedCallback() {
        if (this._ganttInitialized) { return; }
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

    // ── Wires ───────────────────────────────────────────────────────────

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

    // ── Computed UI state ───────────────────────────────────────────────

    get hasError()  { return !this.isLoading && !!this.errorMessage; }
    get isEmpty()   { return !this.isLoading && !this.errorMessage && this.filteredTasks.length === 0; }
    get hasData()   { return !this.isLoading && !this.errorMessage && this.filteredTasks.length > 0; }

    get filteredTasks() {
        if (!this.rawTasks) { return []; }
        if (!this.selectedEntity) { return this.rawTasks; }
        return this.rawTasks.filter(t =>
            (t.entityName || 'Unassigned') === this.selectedEntity
        );
    }

    get subtitleText() {
        const count = this.filteredTasks.length;
        if (this.isLoading) { return 'Loading...'; }
        if (count === 0) { return 'No work items'; }
        const suffix = count === 1 ? 'item' : 'items';
        const filter = this.selectedEntity ? ' (' + this.selectedEntity + ')' : '';
        const completed = this._showCompleted ? ' incl. completed' : '';
        return count + ' work ' + suffix + filter + completed;
    }

    get entityOptions() {
        if (!this.rawTasks) { return []; }
        const entities = new Set();
        this.rawTasks.forEach(t => entities.add(t.entityName || 'Unassigned'));
        const opts = [{ label: 'All Clients', value: '' }];
        Array.from(entities).sort().forEach(e => opts.push({ label: e, value: e }));
        return opts;
    }

    get showEntityFilter() {
        return this.entityOptions.length > 2;
    }

    // View mode button variants
    get btnDayVariant()   { return this.currentViewMode === 'Day' ? 'brand' : 'neutral'; }
    get btnWeekVariant()  { return this.currentViewMode === 'Week' ? 'brand' : 'neutral'; }
    get btnMonthVariant() { return this.currentViewMode === 'Month' ? 'brand' : 'neutral'; }

    get completedToggleTitle() {
        return this._showCompleted ? 'Hide completed items' : 'Show completed items';
    }
    get completedToggleVariant() {
        return this._showCompleted ? 'brand' : 'border';
    }
    get completedToggleIcon() {
        return this._showCompleted ? 'utility:check' : 'utility:filterList';
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

    get hasSummaryStats() {
        return this.summaryStats.total > 0;
    }

    // ── Stage → phase mapping ───────────────────────────────────────────

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

    // ── Summary stats ───────────────────────────────────────────────────

    _computeSummary() {
        const today = new Date();
        today.setHours(0, 0, 0, 0);
        let onTrack = 0;
        let overdue = 0;
        let unscheduled = 0;

        this.rawTasks.forEach(t => {
            if (!t.startDate || !t.endDate) {
                unscheduled++;
                return;
            }
            const end = new Date(t.endDate + 'T00:00:00');
            if (end < today && !t.isCompleted) {
                overdue++;
            } else {
                onTrack++;
            }
        });

        this.summaryStats = {
            total: this.rawTasks.length,
            onTrack,
            overdue,
            unscheduled
        };
    }

    // ── Handlers ────────────────────────────────────────────────────────

    handleViewDay()   { this._setViewMode('Day'); }
    handleViewWeek()  { this._setViewMode('Week'); }
    handleViewMonth() { this._setViewMode('Month'); }

    handleToggleCompleted() {
        this._showCompleted = !this._showCompleted;
    }

    handleEntityChange(event) {
        this.selectedEntity = event.detail.value;
        this._rebuildChart();
    }

    handleScrollToToday() {
        if (!this._ganttInstance) { return; }
        const container = this.refs.ganttContainer;
        if (!container) { return; }
        const todayEl = container.querySelector('.today-highlight');
        if (todayEl) {
            todayEl.scrollIntoView({ behavior: 'smooth', inline: 'center', block: 'nearest' });
        }
    }

    handleRefresh() {
        this.isLoading = true;
        refreshApex(this._wiredGanttResult);
    }

    // ── Private: Library loading ────────────────────────────────────────

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
        });
    }

    // ── Private: Build Frappe tasks ─────────────────────────────────────

    _buildTasks() {
        this._taskMap = {};
        const tasks = [];

        this.filteredTasks.forEach(item => {
            const taskId = 'task_' + item.workItemId;
            this._taskMap[taskId] = item.workItemId;

            const entityPrefix = item.entityName ? '[' + item.entityName + '] ' : '';
            const devSuffix = item.developerName ? ' (' + item.developerName + ')' : '';
            const label = item.name + (item.description ? ' — ' + item.description : '') + devSuffix;

            const cssClass = this._getCssClassForStage(item.stage);

            // Calculate progress from hours
            let progress = 0;
            if (item.progress != null) {
                progress = Math.round(item.progress * 100);
            }

            tasks.push({
                id: taskId,
                name: label,
                start: item.startDate,
                end: item.endDate,
                progress: progress,
                custom_class: cssClass + (item.isCompleted ? ' bar-completed' : ''),
                dependencies: ''
            });
        });

        return tasks;
    }

    // ── Private: Gantt init ─────────────────────────────────────────────

    _initGantt() {
        const svgEl = this.refs.ganttSvg;
        if (!svgEl || this._ganttInitialized) { return; }

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
                bar_height: 28,
                bar_corner_radius: 5,
                arrow_curve: 5,
                padding: 20,

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

                on_date_change: function(task, start, end) {
                    const sfId = self._taskMap[task.id];
                    if (!sfId) { return; }
                    const startStr = self._formatDate(start);
                    const endStr = self._formatDate(end);

                    updateWorkItemDates({ workItemId: sfId, startDate: startStr, endDate: endStr })
                        .then(() => {
                            self.dispatchEvent(new ShowToastEvent({
                                title: 'Dates Updated',
                                message: task.name.split(' — ')[0] + ': ' + startStr + ' to ' + endStr,
                                variant: 'success'
                            }));
                            refreshApex(self._wiredGanttResult);
                        })
                        .catch(err => {
                            self.dispatchEvent(new ShowToastEvent({
                                title: 'Error Saving Dates',
                                message: err.body ? err.body.message : err.message,
                                variant: 'error'
                            }));
                            self._rebuildChart();
                        });
                },

                on_progress_change: function() {
                    // Read-only progress (calculated from hours)
                },

                custom_popup_html: function(task) {
                    const sfId = self._taskMap[task.id];
                    const item = self.rawTasks.find(t => t.workItemId === sfId);

                    let html = '<div class="frappe-popup">';
                    html += '<div class="frappe-popup-title">' + self._escapeHtml(task.name.split(' (')[0]) + '</div>';

                    if (item) {
                        // Stage + Priority row
                        const stageBadge = item.stage
                            ? '<span class="popup-stage-badge">' + self._escapeHtml(item.stage) + '</span>'
                            : '';
                        const priBadge = item.priority
                            ? '<span class="popup-priority-badge popup-pri-' + (item.priority || '').toLowerCase() + '">'
                              + self._escapeHtml(item.priority) + '</span>'
                            : '';
                        if (stageBadge || priBadge) {
                            html += '<div class="frappe-popup-badges">' + stageBadge + priBadge + '</div>';
                        }

                        // Entity / Developer
                        if (item.entityName) {
                            html += '<div class="frappe-popup-row"><span class="popup-label">Client:</span> ' + self._escapeHtml(item.entityName) + '</div>';
                        }
                        if (item.developerName) {
                            html += '<div class="frappe-popup-row"><span class="popup-label">Developer:</span> ' + self._escapeHtml(item.developerName) + '</div>';
                        }

                        // Hours + Progress bar
                        if (item.estimatedHours != null && item.estimatedHours > 0) {
                            const logged = item.loggedHours || 0;
                            const pct = Math.min(Math.round((logged / item.estimatedHours) * 100), 100);
                            html += '<div class="frappe-popup-row"><span class="popup-label">Hours:</span> '
                                + logged.toFixed(1) + ' / ' + item.estimatedHours.toFixed(1) + 'h'
                                + ' (' + pct + '%)</div>';
                            html += '<div class="popup-progress-track"><div class="popup-progress-fill" style="width:' + pct + '%"></div></div>';
                        }

                        // Dates
                        const startD = task._start ? task._start.toLocaleDateString() : item.startDate;
                        const endD = task._end ? task._end.toLocaleDateString() : item.endDate;
                        html += '<div class="frappe-popup-dates">' + startD + '  →  ' + endD + '</div>';

                        // Days remaining
                        if (task._end) {
                            const today = new Date();
                            today.setHours(0, 0, 0, 0);
                            const daysLeft = Math.ceil((task._end - today) / (1000 * 60 * 60 * 24));
                            if (daysLeft < 0 && !item.isCompleted) {
                                html += '<div class="popup-overdue">' + Math.abs(daysLeft) + ' days overdue</div>';
                            } else if (daysLeft >= 0 && daysLeft <= 7 && !item.isCompleted) {
                                html += '<div class="popup-warning">' + daysLeft + ' days remaining</div>';
                            }
                        }
                    }

                    html += '<div class="popup-hint">Click to open &middot; Drag to reschedule</div>';
                    html += '</div>';
                    return html;
                }
            });

            // Scroll to today after a short delay
            requestAnimationFrame(() => {
                this._scrollToToday();
            });

        } catch (err) {
            this.errorMessage = 'Failed to initialize Frappe Gantt: ' + (err.message || err);
            this._ganttInitialized = false;
        }
    }

    // ── Private: View mode ──────────────────────────────────────────────

    _setViewMode(mode) {
        this.currentViewMode = mode;
        if (this._ganttInstance) {
            try {
                this._ganttInstance.change_view_mode(mode);
                requestAnimationFrame(() => this._scrollToToday());
            } catch (err) {
                console.error('[DeliveryFrappeGantt] change_view_mode error:', err);
            }
        }
    }

    // ── Private: Rebuild chart ──────────────────────────────────────────

    _rebuildChart() {
        this._ganttInitialized = false;
        this._ganttInstance = null;
        const svgEl = this.refs.ganttSvg;
        if (svgEl) {
            svgEl.innerHTML = '';
        }
        requestAnimationFrame(() => {
            this._initGantt();
        });
    }

    _tryRender() {
        if (!this._scriptsLoaded || !this.rawTasks.length) { return; }
        if (this._ganttInitialized) {
            this._rebuildChart();
        } else {
            requestAnimationFrame(() => this._initGantt());
        }
    }

    // ── Private: Scroll to today ────────────────────────────────────────

    _scrollToToday() {
        const container = this.refs.ganttContainer;
        if (!container) { return; }
        const todayHighlight = container.querySelector('.today-highlight');
        if (todayHighlight) {
            todayHighlight.scrollIntoView({ behavior: 'smooth', inline: 'center', block: 'nearest' });
        }
    }

    // ── Private: Utilities ──────────────────────────────────────────────

    _formatDate(d) {
        if (!d) { return ''; }
        const year = d.getFullYear();
        const month = String(d.getMonth() + 1).padStart(2, '0');
        const day = String(d.getDate()).padStart(2, '0');
        return year + '-' + month + '-' + day;
    }

    _escapeHtml(str) {
        if (!str) { return ''; }
        return String(str)
            .replace(/&/g, '&amp;')
            .replace(/</g, '&lt;')
            .replace(/>/g, '&gt;')
            .replace(/"/g, '&quot;');
    }
}

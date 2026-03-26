/* eslint-disable @lwc/lwc/no-async-operation, no-unused-vars */
/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Interactive Gantt chart powered by Frappe Gantt (MIT).
 *               Features: drag-to-reschedule, dependency arrows, quick-edit
 *               modal, phase color-coding, milestone markers, entity/my-work
 *               filters, localStorage persistence, rich custom popups.
 * @author Cloud Nimbus LLC
 */
import { LightningElement, wire, track, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { loadScript, loadStyle } from 'lightning/platformResourceLoader';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import FRAPPE_RES from '@salesforce/resourceUrl/frappegantt';
import USER_ID from '@salesforce/user/Id';
import getGanttData from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryGanttController.getGanttData';
import getGanttDependencies from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryGanttController.getGanttDependencies';
import updateWorkItemDates from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryGanttController.updateWorkItemDates';
import getWorkflowConfig from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryWorkflowConfigService.getWorkflowConfig';

const STORAGE_KEY = 'dh-frappe-gantt-prefs';

const PHASE_COLORS = {
    Planning:    '#3b82f6',
    Approval:    '#f59e0b',
    Development: '#22c55e',
    Testing:     '#a855f7',
    UAT:         '#14b8a6',
    Deployment:  '#ef4444',
    Done:        '#9ca3af'
};

const PHASE_CSS_MAP = {
    Planning:    'bar-planning',
    Approval:    'bar-approval',
    Development: 'bar-development',
    Testing:     'bar-testing',
    UAT:         'bar-uat',
    Deployment:  'bar-deployment',
    Done:        'bar-done'
};

const DEFAULT_CSS_CLASS = 'bar-development';

export default class DeliveryFrappeGantt extends NavigationMixin(LightningElement) {

    // ── Public API ─────────────────────────────────────────────────────
    @api showCompleted = false;
    @api initialViewMode = 'Week';

    // ── Tracked state ──────────────────────────────────────────────────
    @track isLoading = true;
    @track errorMessage = '';
    @track rawTasks = [];
    @track rawDependencies = [];
    @track workflowConfig = null;
    @track currentViewMode = 'Week';
    @track _showCompleted = false;
    @track showDependencies = true;
    @track myWorkOnly = false;
    @track selectedEntity = '';
    @track summaryStats = { total: 0, onTrack: 0, overdue: 0, unscheduled: 0 };
    @track showQuickEdit = false;
    @track selectedWorkItemId = null;

    currentUserId = USER_ID;

    _ganttInitialized = false;
    _scriptsLoaded = false;
    _scriptsLoading = false;
    _ganttInstance = null;
    _taskMap = {};
    _wiredGanttResult = null;
    _wiredDepsResult = null;
    _terminalStages = new Set();

    // ── Lifecycle ──────────────────────────────────────────────────────

    connectedCallback() {
        this._restorePrefs();
        this.currentViewMode = this.currentViewMode || this.initialViewMode || 'Week';
        if (!this._showCompleted && this.showCompleted) {
            this._showCompleted = this.showCompleted;
        }
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

    // ── Wires ──────────────────────────────────────────────────────────

    @wire(getWorkflowConfig, { workflowTypeName: 'Software_Delivery' })
    wiredConfig({ data, error }) {
        if (data) {
            this.workflowConfig = data;
            this._buildTerminalStages();
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

    @wire(getGanttDependencies)
    wiredDependencies(result) {
        this._wiredDepsResult = result;
        if (result.data) {
            this.rawDependencies = result.data;
            this._tryRender();
        } else if (result.error) {
            console.error('[DeliveryFrappeGantt] getGanttDependencies error:', result.error);
        }
    }

    // ── Computed: UI state ─────────────────────────────────────────────

    get hasError()  { return !this.isLoading && !!this.errorMessage; }
    get isEmpty()   { return !this.isLoading && !this.errorMessage && this.filteredTasks.length === 0; }
    get hasData()   { return !this.isLoading && !this.errorMessage && this.filteredTasks.length > 0; }

    get filteredTasks() {
        if (!this.rawTasks) { return []; }
        let tasks = [...this.rawTasks];
        if (this.selectedEntity) {
            tasks = tasks.filter(t => (t.entityName || 'Unassigned') === this.selectedEntity);
        }
        if (this.myWorkOnly) {
            tasks = tasks.filter(t => t.developerName != null && t.developerName !== '');
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
        if (this.myWorkOnly) { parts.push('assigned only'); }
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

    get hasSummaryStats() {
        return this.summaryStats.total > 0;
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
            dotStyle: 'background-color: ' + (PHASE_COLORS[phase] || '#9ca3af') + ';'
        }));
    }

    // ── Computed: stage/phase mapping ──────────────────────────────────

    get _stagePhaseMap() {
        if (!this.workflowConfig || !this.workflowConfig.stages) { return {}; }
        const map = {};
        this.workflowConfig.stages.forEach(s => {
            map[s.apiValue] = s.phase || 'Development';
        });
        return map;
    }

    _buildTerminalStages() {
        this._terminalStages = new Set();
        if (this.workflowConfig && this.workflowConfig.stages) {
            this.workflowConfig.stages.forEach(s => {
                if (s.isTerminal) {
                    this._terminalStages.add(s.apiValue);
                }
            });
        }
    }

    _getCssClassForStage(stageName) {
        const phase = this._stagePhaseMap[stageName] || 'Development';
        return PHASE_CSS_MAP[phase] || DEFAULT_CSS_CLASS;
    }

    _isTerminalStage(stageName) {
        return this._terminalStages.has(stageName);
    }

    // ── Summary stats ──────────────────────────────────────────────────

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

    // ── Toolbar event handlers ─────────────────────────────────────────

    handleZoomChange(event) {
        const mode = event.detail.value;
        this.currentViewMode = mode;
        this._savePrefs();
        if (this._ganttInstance) {
            try {
                this._ganttInstance.change_view_mode(mode);
                requestAnimationFrame(() => this._scrollToToday());
            } catch (err) {
                console.error('[DeliveryFrappeGantt] change_view_mode error:', err);
            }
        }
    }

    handleEntityChange(event) {
        this.selectedEntity = event.detail.value;
        this._savePrefs();
        this._rebuildChart();
    }

    handleToggleDependencies() {
        this.showDependencies = !this.showDependencies;
        this._savePrefs();
        this._rebuildChart();
    }

    handleToggleCompleted() {
        this._showCompleted = !this._showCompleted;
        this._savePrefs();
        // Wire reactivity will refetch data automatically
    }

    handleToggleMyWork() {
        this.myWorkOnly = !this.myWorkOnly;
        this._savePrefs();
        this._rebuildChart();
    }

    handleScrollToToday() {
        this._scrollToToday();
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

    // ── Private: Library loading ───────────────────────────────────────

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

    // ── Private: Build dependency map ──────────────────────────────────

    _buildDependencyMap() {
        // Map: targetWorkItemId → [sourceWorkItemIds]
        const depMap = {};
        if (!this.rawDependencies || !this.showDependencies) { return depMap; }
        this.rawDependencies.forEach(d => {
            if (!depMap[d.target]) {
                depMap[d.target] = [];
            }
            depMap[d.target].push(d.source);
        });
        return depMap;
    }

    // ── Private: Build Frappe tasks ────────────────────────────────────

    _buildTasks() {
        this._taskMap = {};
        const tasks = [];
        const depMap = this._buildDependencyMap();
        // Build a set of all work item IDs in the current filtered set for dep filtering
        const filteredIds = new Set(this.filteredTasks.map(t => t.workItemId));

        this.filteredTasks.forEach(item => {
            const taskId = 'task_' + item.workItemId;
            this._taskMap[taskId] = item.workItemId;

            const devSuffix = item.developerName ? ' (' + item.developerName + ')' : '';
            const label = item.name + (item.description ? ' \u2014 ' + item.description : '') + devSuffix;

            const cssClass = this._getCssClassForStage(item.stage);
            const isMilestone = this._isTerminalStage(item.stage);

            // Calculate progress from hours
            let progress = 0;
            if (item.progress != null) {
                progress = Math.round(item.progress * 100);
            }

            // Build dependencies string — only include sources that are in the filtered set
            let depsStr = '';
            if (depMap[item.workItemId]) {
                const validDeps = depMap[item.workItemId]
                    .filter(srcId => filteredIds.has(srcId))
                    .map(srcId => 'task_' + srcId);
                depsStr = validDeps.join(', ');
            }

            const classes = [cssClass];
            if (item.isCompleted) { classes.push('bar-completed'); }
            if (isMilestone) { classes.push('bar-milestone'); }

            tasks.push({
                id: taskId,
                name: label,
                start: item.startDate,
                end: item.endDate,
                progress: progress,
                custom_class: classes.join(' '),
                dependencies: depsStr
            });
        });

        return tasks;
    }

    // ── Private: Gantt init ────────────────────────────────────────────

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
                        self.selectedWorkItemId = sfId;
                        self.showQuickEdit = true;
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
                                message: task.name.split(' \u2014 ')[0] + ': ' + startStr + ' to ' + endStr,
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
                    html += '<div class="frappe-popup-title">' + self._escapeHtml(task.name.split(' (')[0].split(' \u2014 ')[0]) + '</div>';

                    if (item) {
                        // Stage + Priority badges
                        const phase = self._stagePhaseMap[item.stage] || 'Development';
                        const phaseColor = PHASE_COLORS[phase] || '#9ca3af';
                        const stageBadge = item.stage
                            ? '<span class="popup-stage-badge" style="background:' + phaseColor + '44;color:' + phaseColor + '">'
                              + self._escapeHtml(item.stage) + '</span>'
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

                        // Hours + mini progress bar
                        if (item.estimatedHours != null && item.estimatedHours > 0) {
                            const logged = item.loggedHours || 0;
                            const pct = Math.min(Math.round((logged / item.estimatedHours) * 100), 100);
                            html += '<div class="frappe-popup-row"><span class="popup-label">Hours:</span> '
                                + logged.toFixed(1) + ' / ' + item.estimatedHours.toFixed(1) + 'h'
                                + ' (' + pct + '%)</div>';
                            html += '<div class="popup-progress-track"><div class="popup-progress-fill" style="width:' + pct + '%"></div></div>';
                        }

                        // Dates + days remaining/overdue
                        const startD = task._start ? task._start.toLocaleDateString() : item.startDate;
                        const endD = task._end ? task._end.toLocaleDateString() : item.endDate;
                        html += '<div class="frappe-popup-dates">' + startD + '  \u2192  ' + endD;

                        if (task._end) {
                            const today = new Date();
                            today.setHours(0, 0, 0, 0);
                            const daysLeft = Math.ceil((task._end - today) / (1000 * 60 * 60 * 24));
                            if (daysLeft < 0 && !item.isCompleted) {
                                html += ' <span class="popup-overdue-inline">' + Math.abs(daysLeft) + 'd overdue</span>';
                            } else if (daysLeft >= 0 && daysLeft <= 7 && !item.isCompleted) {
                                html += ' <span class="popup-warning-inline">' + daysLeft + 'd left</span>';
                            }
                        }
                        html += '</div>';

                        // View Record link
                        html += '<div class="popup-view-link">View Record \u2197</div>';
                    }

                    html += '<div class="popup-hint">Click to edit \u00b7 Drag to reschedule</div>';
                    html += '</div>';
                    return html;
                }
            });

            // Scroll to today after init
            requestAnimationFrame(() => {
                this._scrollToToday();
            });

        } catch (err) {
            this.errorMessage = 'Failed to initialize Frappe Gantt: ' + (err.message || err);
            this._ganttInitialized = false;
        }
    }

    // ── Private: Rebuild / re-render ───────────────────────────────────

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

    // ── Private: Scroll to today ───────────────────────────────────────

    _scrollToToday() {
        const container = this.refs.ganttContainer;
        if (!container) { return; }
        const todayHighlight = container.querySelector('.today-highlight');
        if (todayHighlight) {
            todayHighlight.scrollIntoView({ behavior: 'smooth', inline: 'center', block: 'nearest' });
        }
    }

    // ── Private: localStorage persistence ──────────────────────────────

    _savePrefs() {
        try {
            const prefs = {
                showDependencies: this.showDependencies,
                showCompleted: this._showCompleted,
                myWorkOnly: this.myWorkOnly,
                currentViewMode: this.currentViewMode,
                selectedEntity: this.selectedEntity
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
            if (prefs.showCompleted != null) { this._showCompleted = prefs.showCompleted; }
            if (prefs.myWorkOnly != null) { this.myWorkOnly = prefs.myWorkOnly; }
            if (prefs.currentViewMode) { this.currentViewMode = prefs.currentViewMode; }
            if (prefs.selectedEntity != null) { this.selectedEntity = prefs.selectedEntity; }
        } catch (e) {
            // fail silently
        }
    }

    // ── Private: Utilities ─────────────────────────────────────────────

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

/**
 * @name         Delivery Hub — deliveryProFormaTimeline
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Priority-grouped delivery timeline powered by nimbus-gantt's
 *               PriorityGroupingPlugin. Ports the cloudnimbusllc.com v5 page
 *               (/mf/delivery-timeline-v5) to a DH LWC that consumes real
 *               WorkItem__c records via DeliveryGanttController.getProFormaTimelineData.
 *
 *               Buckets: NOW (top-priority) · NEXT (active) · PLANNED (follow-on) ·
 *               PROPOSED (proposed) · HOLD (deferred). Assignment reads
 *               WorkItem__c.PriorityGroupPk__c first; falls back to server-side
 *               derivation when the picklist is blank. Users can override the
 *               derived bucket by setting the picklist directly on the record.
 *
 *               Replaces the throwaway deliveryNimbusGantt demo LWC on
 *               DeliveryHubHome.flexipage + DeliveryHubAdminHome.flexipage.
 * @author Cloud Nimbus LLC
 */
import { LightningElement, api } from 'lwc';
import { loadScript } from 'lightning/platformResourceLoader';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import NIMBUS_GANTT from '@salesforce/resourceUrl/nimbusgantt';
import getProFormaTimelineData from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryGanttController.getProFormaTimelineData';

// ─── Bucket palette — must match CLOUD_NIMBUS_PRIORITY_BUCKETS in ───────────
// nimbus-gantt/packages/core/src/plugins/PriorityGroupingPlugin.ts and in
// cloudnimbusllc.com/src/lib/nimbus-gantt/PriorityGroupingPlugin.ts. Kept
// inline so the LWC doesn't need to import from the static resource's
// exported constants (we instantiate the plugin through window.NimbusGantt).
const PRIORITY_BUCKETS = [
    { id: 'top-priority', label: 'NOW',      color: '#dc2626', bgTint: '#fef2f2', order: 0 },
    { id: 'active',       label: 'NEXT',     color: '#d97706', bgTint: '#fffbeb', order: 1 },
    { id: 'follow-on',    label: 'PLANNED',  color: '#059669', bgTint: '#ecfdf5', order: 2 },
    { id: 'proposed',     label: 'PROPOSED', color: '#2563eb', bgTint: '#eff6ff', order: 3 },
    { id: 'deferred',     label: 'HOLD',     color: '#94a3b8', bgTint: '#f8fafc', order: 4 },
];

// Stage color map for real task bars (non-header). Mirrors the subset of
// stages v5 colors. Unmapped stages fall back to the framework default.
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

export default class DeliveryProFormaTimeline extends LightningElement {
    @api showCompleted = false;

    isLoading = true;
    errorMessage = null;
    rows = [];

    /** Live NimbusGantt instance — null until the static resource loads. */
    _gantt = null;
    /** Tracks whether loadScript has resolved so we don't double-construct. */
    _scriptLoaded = false;

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
            const data = await getProFormaTimelineData({ showCompleted: this.showCompleted });
            this.rows = data || [];
            // Render in next microtask so the container div exists in the DOM
            // (template rerenders on isLoading flip).
            Promise.resolve().then(() => this.renderGantt());
        } catch (error) {
            this.handleError('Failed to load work items', error);
        } finally {
            this.isLoading = false;
        }
    }

    renderGantt() {
        const container = this.refs.ganttContainer;
        if (!container || !window.NimbusGantt) {
            return;
        }

        // Tear down any previous instance before re-rendering
        if (this._gantt) {
            try { this._gantt.destroy(); } catch (e) { /* swallow */ }
            this._gantt = null;
        }

        if (this.rows.length === 0) {
            container.innerHTML = '';
            return;
        }

        // Map DTO rows → GanttTask[] with plugin-aware metadata
        const tasks = this.rows.map((row) => ({
            id: row.id,
            name: row.title || row.name,
            startDate: row.startDate,
            endDate: row.endDate,
            progress: row.progress != null ? Number(row.progress) : 0,
            status: row.stage,
            priority: row.priority,
            // groupId is the plugin's default read; we use the metadata path
            // instead so the bucket comes from PriorityGroupPk__c (with fallback)
            groupId: row.priorityGroup || null,
            assignee: row.developerName || '',
            parentId: row.parentWorkItemId || undefined,
            color: STAGE_COLORS[row.stage] || undefined,
            metadata: {
                priorityGroup: row.priorityGroup,
                hoursHigh: row.estimatedHours != null ? Number(row.estimatedHours) : 0,
                hoursLogged: row.loggedHours != null ? Number(row.loggedHours) : 0,
                entityId: row.entityId,
                entityName: row.entityName,
            },
        }));

        const { NimbusGantt, PriorityGroupingPlugin, hoursWeightedProgress } = window.NimbusGantt;

        this._gantt = new NimbusGantt(container, {
            tasks,
            dependencies: [],
            rowHeight: 32,
            barHeight: 20,
            headerHeight: 32,
            gridWidth: 295,
            zoomLevel: 'week',
            showToday: true,
            showWeekends: true,
            showProgress: true,
            colorMap: STAGE_COLORS,
            readOnly: false,
            onTaskClick: (task) => this.handleTaskClick(task),
        });

        // Install the priority grouping plugin — reads PriorityGroupPk__c from
        // metadata, falls back to derived bucket via task.groupId (populated
        // server-side). Hours-weighted progress reads metadata.hoursHigh +
        // hoursLogged.
        this._gantt.use(
            PriorityGroupingPlugin({
                buckets: PRIORITY_BUCKETS,
                getBucket: (task) =>
                    (task.metadata && task.metadata.priorityGroup) || task.groupId || null,
                getBucketProgress: hoursWeightedProgress,
            })
        );

        // Re-dispatch data after plugin install so middleware processes the
        // initial load — same gotcha as cloudnimbusllc.com's NimbusGanttChart
        // wrapper (see reference_nimbus_gantt_plugin_rowinjection.md).
        this._gantt.setData(tasks, []);
        try { this._gantt.expandAll(); } catch (e) { /* swallow */ }
    }

    handleTaskClick(task) {
        if (!task || !task.id) return;
        // Synthetic bucket headers are handled by the plugin (collapse toggle)
        if (task.id.startsWith('__bucket_header__')) return;
        // Real task → navigate to the WorkItem__c record
        const navigateEvent = new CustomEvent('navigate', {
            bubbles: true,
            composed: true,
            detail: { recordId: task.id, objectApiName: 'WorkItem__c' },
        });
        this.dispatchEvent(navigateEvent);
    }

    handleShowCompletedChange(event) {
        this.showCompleted = event.target.checked;
        if (this._scriptLoaded) {
            this.loadData();
        }
    }

    handleRefresh() {
        if (this._scriptLoaded) {
            this.loadData();
        }
    }

    handleError(prefix, error) {
        const msg = (error && error.body && error.body.message) || (error && error.message) || 'Unknown error';
        this.errorMessage = `${prefix}: ${msg}`;
        this.isLoading = false;
        // eslint-disable-next-line no-console
        console.error('[deliveryProFormaTimeline]', prefix, error);
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Timeline error',
                message: this.errorMessage,
                variant: 'error',
            })
        );
    }
}

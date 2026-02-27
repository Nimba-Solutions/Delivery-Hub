/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @author Cloud Nimbus LLC
 */
import { LightningElement, wire, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getWorkItemsForGantt from '@salesforce/apex/DeliveryGanttController.getWorkItemsForGantt';
import getWorkflowConfig from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryWorkflowConfigService.getWorkflowConfig';

const MS_PER_DAY = 86400000;

export default class DeliveryGanttChart extends NavigationMixin(LightningElement) {
    @track windowDays = 60;
    @track isLoading = true;
    @track errorMessage = '';
    @track rawRows = [];
    @track workflowConfig = null;

    // ── Wires ─────────────────────────────────────────────────────────────────

    @wire(getWorkItemsForGantt)
    wiredWorkItems({ data, error }) {
        this.isLoading = false;
        if (data) {
            this.rawRows = data;
        } else if (error) {
            this.errorMessage = error.body ? error.body.message : error.message;
        }
    }

    // Static workflowTypeName: Gantt is Software_Delivery only for now
    @wire(getWorkflowConfig, { workflowTypeName: 'Software_Delivery' })
    wiredConfig({ data, error }) {
        if (data) { this.workflowConfig = data; }
        else if (error) { console.error('[DeliveryGanttChart] getWorkflowConfig error:', error); }
    }

    // CMT-driven stage → card color lookup
    get _stageColorMap() {
        if (!this.workflowConfig?.stages) return {};
        const map = {};
        this.workflowConfig.stages.forEach(s => { map[s.apiValue] = s.cardColor; });
        return map;
    }

    // ── Window controls ───────────────────────────────────────────────────────

    handleWindow30() { this.windowDays = 30; }
    handleWindow60() { this.windowDays = 60; }
    handleWindow90() { this.windowDays = 90; }

    get btn30Variant() { return this.windowDays === 30 ? 'brand' : 'neutral'; }
    get btn60Variant() { return this.windowDays === 60 ? 'brand' : 'neutral'; }
    get btn90Variant() { return this.windowDays === 90 ? 'brand' : 'neutral'; }

    get windowLabel() {
        const start = new Date();
        start.setHours(0, 0, 0, 0);
        const end = new Date(start.getTime() + this.windowDays * MS_PER_DAY);
        return `${this.fmtDate(start)} – ${this.fmtDate(end)}`;
    }

    // ── Computed chart data ───────────────────────────────────────────────────

    get ganttRows() {
        const today = new Date();
        today.setHours(0, 0, 0, 0);
        const windowEnd = new Date(today.getTime() + this.windowDays * MS_PER_DAY);

        return this.rawRows.map(r => {
            const uatMs   = new Date(r.uatDate).getTime();
            const startMs = new Date(r.createdDate).getTime();
            const winMs   = this.windowDays * MS_PER_DAY;
            const todayMs = today.getTime();

            // Clamp bar to [today - windowDays/2, today + windowDays] range
            const windowStartMs = todayMs - Math.round(winMs * 0.2); // 20% before today

            const left = Math.max(0, Math.min(100, ((startMs - windowStartMs) / (winMs * 1.2)) * 100));
            const right = Math.max(0, Math.min(100, ((uatMs  - windowStartMs) / (winMs * 1.2)) * 100));
            const width = Math.max(0.5, right - left); // minimum sliver

            const daysToUat = (uatMs - todayMs) / MS_PER_DAY;
            let barClass = 'gantt-bar';
            if (uatMs < todayMs) {
                barClass += ' gantt-bar--overdue';
            } else if (daysToUat < 7) {
                barClass += ' gantt-bar--warning';
            } else if (startMs > windowEnd.getTime()) {
                barClass += ' gantt-bar--future';
            }

            const stageColor = this._stageColorMap[r.stage] || 'var(--gantt-gray)';
            const barStyle = `left:${left.toFixed(1)}%; width:${width.toFixed(1)}%; background:${stageColor};`;

            let stageBadgeClass = 'gantt-stage-badge';
            if (uatMs < todayMs) { stageBadgeClass += ' badge--overdue'; }

            const desc = r.description || '';
            const descShort = desc.length > 45 ? desc.substring(0, 45) + '…' : desc;
            const daysToUatRounded = Math.round(daysToUat);
            const daysStr = daysToUat >= 0
                ? `${daysToUatRounded} day${daysToUatRounded === 1 ? '' : 's'} remaining`
                : `${Math.abs(daysToUatRounded)} day${Math.abs(daysToUatRounded) === 1 ? '' : 's'} overdue`;
            const barTooltip = [
                desc || r.name,
                `Stage: ${r.stage}${r.priority ? ' | Priority: ' + r.priority : ''}`,
                `UAT: ${r.uatDate} (${daysStr})`
            ].join('\n');

            return {
                workItemId:       r.workItemId,
                name:           r.name,
                description:    desc,
                descShort,
                stage:          r.stage,
                priority:       r.priority,
                uatDate:        r.uatDate,
                barClass,
                barStyle,
                stageBadgeClass,
                barTooltip
            };
        });
    }

    get dateLabels() {
        const today = new Date();
        today.setHours(0, 0, 0, 0);
        const winMs   = this.windowDays * MS_PER_DAY;
        const windowStartMs = today.getTime() - Math.round(winMs * 0.2);
        const totalMs = winMs * 1.2;

        const labels = [];
        const count  = Math.min(this.windowDays <= 30 ? 5 : 6, 7);
        for (let i = 0; i <= count; i++) {
            const t = new Date(windowStartMs + (totalMs * i) / count);
            const leftPct = ((i / count) * 100).toFixed(1);
            labels.push({
                key:   `dl-${i}`,
                label: this.fmtDate(t),
                style: `left:${leftPct}%`
            });
        }
        return labels;
    }

    get todayLineStyle() {
        const today = new Date();
        today.setHours(0, 0, 0, 0);
        const winMs   = this.windowDays * MS_PER_DAY;
        const windowStartMs = today.getTime() - Math.round(winMs * 0.2);
        const totalMs = winMs * 1.2;
        const pct = (((today.getTime() - windowStartMs) / totalMs) * 100).toFixed(1);
        return `left:${pct}%`;
    }

    handleRowClick(event) {
        const recordId = event.currentTarget.dataset.id;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: recordId,
                objectApiName: 'WorkItem__c',
                actionName: 'view'
            }
        });
    }

    // ── State flags ───────────────────────────────────────────────────────────

    get hasError() { return !this.isLoading && !!this.errorMessage; }
    get isEmpty()  { return !this.isLoading && !this.errorMessage && this.rawRows.length === 0; }
    get hasRows()  { return !this.isLoading && !this.errorMessage && this.rawRows.length > 0; }

    // ── Helpers ───────────────────────────────────────────────────────────────

    fmtDate(d) {
        return d.toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
    }
}

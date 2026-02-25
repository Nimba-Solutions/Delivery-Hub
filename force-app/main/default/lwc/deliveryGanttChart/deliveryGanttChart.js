/**
 * @author Cloud Nimbus LLC
 */
import { LightningElement, wire, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getTicketsForGantt from '@salesforce/apex/DeliveryGanttController.getTicketsForGantt';

const MS_PER_DAY = 86400000;
const STAGE_COLORS = {
    'Backlog':           'var(--gantt-gray)',
    'In Development':   'var(--gantt-blue)',
    'Ready for QA':     'var(--gantt-indigo)',
    'In QA':            'var(--gantt-purple)',
    'UAT':              'var(--gantt-teal)',
    'Done':             'var(--gantt-green)',
    'Deployed to Prod': 'var(--gantt-emerald)',
    'Blocked':          'var(--gantt-red)',
};

export default class DeliveryGanttChart extends NavigationMixin(LightningElement) {
    @track windowDays = 60;
    @track isLoading = true;
    @track errorMessage = '';
    @track rawRows = [];

    // ── Wire ──────────────────────────────────────────────────────────────────

    @wire(getTicketsForGantt)
    wiredTickets({ data, error }) {
        this.isLoading = false;
        if (data) {
            this.rawRows = data;
        } else if (error) {
            this.errorMessage = error.body ? error.body.message : error.message;
        }
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

            const stageColor = STAGE_COLORS[r.stage] || 'var(--gantt-gray)';
            const barStyle = `left:${left.toFixed(1)}%; width:${width.toFixed(1)}%; background:${stageColor};`;

            let stageBadgeClass = 'gantt-stage-badge';
            if (uatMs < todayMs) { stageBadgeClass += ' badge--overdue'; }

            return {
                ticketId:       r.ticketId,
                name:           r.name,
                description:    r.description || r.name,
                stage:          r.stage,
                priority:       r.priority,
                uatDate:        r.uatDate,
                barClass,
                barStyle,
                stageBadgeClass,
                barTooltip:     `${r.name}: ${r.stage} — UAT ${r.uatDate}`,
                recordUrl:      `/lightning/r/Ticket__c/${r.ticketId}/view`
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

    // ── State flags ───────────────────────────────────────────────────────────

    get hasError() { return !this.isLoading && !!this.errorMessage; }
    get isEmpty()  { return !this.isLoading && !this.errorMessage && this.rawRows.length === 0; }
    get hasRows()  { return !this.isLoading && !this.errorMessage && this.rawRows.length > 0; }

    // ── Helpers ───────────────────────────────────────────────────────────────

    fmtDate(d) {
        return d.toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
    }
}

/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Board Metrics dashboard component. Displays velocity, throughput,
 *               WIP gauge, stage distribution, aging alerts, priority breakdown,
 *               and completion rate. Supports compact and full display modes.
 * @author Cloud Nimbus LLC
 */
import { LightningElement, api, wire, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { refreshApex } from '@salesforce/apex';
import getBoardMetrics from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryMetricsService.getBoardMetrics';

// Phase color mapping for stacked bar segments
const PHASE_COLORS = {
    'Planning':    '#6366f1',
    'Approval':    '#0ea5e9',
    'Development': '#8b5cf6',
    'Testing':     '#f59e0b',
    'UAT':         '#10b981',
    'Deployment':  '#ef4444',
    'Other':       '#94a3b8'
};

// Priority color mapping for pie chart segments
const PRIORITY_COLORS = {
    'High':   '#ef4444',
    'Medium': '#f59e0b',
    'Low':    '#10b981',
    'Unset':  '#cbd5e1'
};

export default class DeliveryBoardMetrics extends NavigationMixin(LightningElement) {
    @api displayMode = 'full';

    @track metrics = null;
    @track isLoading = true;
    @track error = null;

    _wiredResult;

    @wire(getBoardMetrics)
    wiredMetrics(result) {
        this._wiredResult = result;
        const { data, error } = result;
        if (data) {
            this.metrics = data;
            this.isLoading = false;
            this.error = null;
        } else if (error) {
            console.error('[DeliveryBoardMetrics] getBoardMetrics error:', error);
            this.error = error;
            this.isLoading = false;
        }
    }

    // ── Mode getters ──

    get isCompact() {
        return this.displayMode === 'compact';
    }

    get isFull() {
        return this.displayMode === 'full';
    }

    get isLoaded() {
        return !this.isLoading;
    }

    get hasError() {
        return this.error != null;
    }

    get hasMetrics() {
        return this.metrics != null;
    }

    get cardTitle() {
        return this.isCompact ? 'Metrics' : 'Board Metrics';
    }

    get cardIconName() {
        return 'standard:dashboard';
    }

    // ── Velocity (sparkline) ──

    get velocityBars() {
        if (!this.metrics?.velocity) return [];
        const max = Math.max(...this.metrics.velocity.map(v => v.count), 1);
        return this.metrics.velocity.map(v => ({
            weekLabel: v.weekLabel,
            count: v.count,
            title: `${v.weekLabel}: ${v.count}`,
            heightPercent: Math.round((v.count / max) * 100),
            barStyle: `height: ${Math.max(Math.round((v.count / max) * 100), 4)}%`,
            barClass: v.count > 0 ? 'sparkline-bar sparkline-bar--active' : 'sparkline-bar sparkline-bar--empty'
        }));
    }

    get totalVelocity() {
        if (!this.metrics?.velocity) return 0;
        return this.metrics.velocity.reduce((sum, v) => sum + v.count, 0);
    }

    get avgVelocity() {
        if (!this.metrics?.velocity || this.metrics.velocity.length === 0) return '0';
        const total = this.metrics.velocity.reduce((sum, v) => sum + v.count, 0);
        return (total / this.metrics.velocity.length).toFixed(1);
    }

    // ── Throughput ──

    get throughputValue() {
        if (!this.metrics) return '0';
        return this.metrics.avgThroughputDays != null ? String(this.metrics.avgThroughputDays) : '0';
    }

    get throughputTrend() {
        if (!this.metrics || this.metrics.prevAvgThroughputDays == null || this.metrics.prevAvgThroughputDays === 0) {
            return 'neutral';
        }
        const curr = this.metrics.avgThroughputDays || 0;
        const prev = this.metrics.prevAvgThroughputDays;
        if (curr < prev) return 'improving';
        if (curr > prev) return 'worsening';
        return 'neutral';
    }

    get throughputArrow() {
        const trend = this.throughputTrend;
        if (trend === 'improving') return 'utility:arrowdown';
        if (trend === 'worsening') return 'utility:arrowup';
        return 'utility:dash';
    }

    get throughputTrendClass() {
        const trend = this.throughputTrend;
        if (trend === 'improving') return 'trend-indicator trend-indicator--good';
        if (trend === 'worsening') return 'trend-indicator trend-indicator--bad';
        return 'trend-indicator trend-indicator--neutral';
    }

    get throughputTrendLabel() {
        const trend = this.throughputTrend;
        if (trend === 'improving') return 'Faster than last period';
        if (trend === 'worsening') return 'Slower than last period';
        return 'Same as last period';
    }

    // ── WIP Gauge ──

    get wipCount() {
        return this.metrics?.wipCount || 0;
    }

    get wipGaugeClass() {
        const wip = this.wipCount;
        if (wip > 20) return 'gauge-value gauge-value--red';
        if (wip >= 10) return 'gauge-value gauge-value--yellow';
        return 'gauge-value gauge-value--green';
    }

    get wipLabel() {
        const wip = this.wipCount;
        if (wip > 20) return 'High WIP';
        if (wip >= 10) return 'Moderate WIP';
        return 'Healthy WIP';
    }

    get wipGaugeBarStyle() {
        // Cap at 40 for visual scaling
        const pct = Math.min(Math.round((this.wipCount / 40) * 100), 100);
        return `width: ${pct}%`;
    }

    get wipGaugeBarClass() {
        const wip = this.wipCount;
        if (wip > 20) return 'gauge-bar-fill gauge-bar-fill--red';
        if (wip >= 10) return 'gauge-bar-fill gauge-bar-fill--yellow';
        return 'gauge-bar-fill gauge-bar-fill--green';
    }

    // ── Stage Distribution (stacked bar) ──

    get phaseDistribution() {
        if (!this.metrics?.stageDistribution) return [];
        // Aggregate by phase
        const phaseMap = {};
        let total = 0;
        for (const sc of this.metrics.stageDistribution) {
            const phase = sc.phase || 'Other';
            if (!phaseMap[phase]) {
                phaseMap[phase] = 0;
            }
            phaseMap[phase] += sc.count;
            total += sc.count;
        }

        if (total === 0) return [];

        // Build segments in a consistent order
        const phaseOrder = ['Planning', 'Approval', 'Development', 'Testing', 'UAT', 'Deployment', 'Other'];
        const segments = [];
        for (const phase of phaseOrder) {
            const count = phaseMap[phase];
            if (count && count > 0) {
                const pct = Math.round((count / total) * 100);
                segments.push({
                    phase,
                    count,
                    title: `${phase}: ${count}`,
                    percent: pct,
                    segmentStyle: `width: ${Math.max(pct, 2)}%; background-color: ${PHASE_COLORS[phase] || PHASE_COLORS['Other']}`,
                    legendColor: `background-color: ${PHASE_COLORS[phase] || PHASE_COLORS['Other']}`
                });
            }
        }
        return segments;
    }

    get hasStageDistribution() {
        return this.phaseDistribution.length > 0;
    }

    // ── Aging Alerts ──

    get agingCount() {
        return this.metrics?.agingItemCount || 0;
    }

    get hasAgingItems() {
        return this.agingCount > 0;
    }

    get agingBadgeClass() {
        return this.agingCount > 5
            ? 'aging-badge aging-badge--critical'
            : 'aging-badge aging-badge--warning';
    }

    get agingItems() {
        return this.metrics?.agingItems || [];
    }

    get topAgingItems() {
        // Show top 5 in full mode
        return this.agingItems.slice(0, 5);
    }

    // ── Priority Pie ──

    get prioritySegments() {
        if (!this.metrics?.priorityBreakdown) return [];
        let total = 0;
        for (const p of this.metrics.priorityBreakdown) {
            total += p.count;
        }
        if (total === 0) return [];

        const priorityOrder = ['High', 'Medium', 'Low', 'Unset'];
        const segments = [];
        for (const prio of priorityOrder) {
            const entry = this.metrics.priorityBreakdown.find(p => p.priority === prio);
            if (entry && entry.count > 0) {
                const pct = Math.round((entry.count / total) * 100);
                segments.push({
                    priority: prio,
                    count: entry.count,
                    percent: pct,
                    barStyle: `width: ${Math.max(pct, 2)}%; background-color: ${PRIORITY_COLORS[prio] || PRIORITY_COLORS['Unset']}`,
                    legendColor: `background-color: ${PRIORITY_COLORS[prio] || PRIORITY_COLORS['Unset']}`
                });
            }
        }
        return segments;
    }

    get hasPriorityData() {
        return this.prioritySegments.length > 0;
    }

    // ── Completion Rate ──

    get completionRate() {
        if (!this.metrics) return '0';
        return this.metrics.completionRate != null ? String(this.metrics.completionRate) : '0';
    }

    get completedCount() {
        return this.metrics?.completedLast30 || 0;
    }

    get totalCount() {
        return this.metrics?.totalLast30 || 0;
    }

    get completionBarStyle() {
        const rate = this.metrics?.completionRate || 0;
        return `width: ${Math.min(rate, 100)}%`;
    }

    get completionBarClass() {
        const rate = this.metrics?.completionRate || 0;
        if (rate >= 70) return 'completion-bar-fill completion-bar-fill--good';
        if (rate >= 40) return 'completion-bar-fill completion-bar-fill--ok';
        return 'completion-bar-fill completion-bar-fill--low';
    }

    // ── Compact mode summaries ──

    get compactVelocity() {
        return this.avgVelocity;
    }

    // ── Handlers ──

    handleRefresh() {
        this.isLoading = true;
        refreshApex(this._wiredResult).then(() => {
            this.isLoading = false;
        });
    }

    handleViewAgingItems() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: {
                objectApiName: 'WorkItem__c',
                actionName: 'list'
            }
        });
    }
}

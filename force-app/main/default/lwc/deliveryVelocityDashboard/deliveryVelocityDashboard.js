/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Velocity and capacity planning dashboard. Shows team velocity chart,
 *               developer utilization, projected completion dates, and what-if analysis.
 * @author Cloud Nimbus LLC
 */
import { LightningElement, track, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import getVelocityDashboard from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryVelocityService.getVelocityDashboard';

const BAR_MAX_HEIGHT = 120;
const BAR_MIN_HEIGHT = 4;
const FULL_PERCENT = 100;
const DAYS_PER_WEEK = 7;
const BAR_COLOR_PRIMARY = '#0176d3';
const BAR_COLOR_EMPTY = '#e2e8f0';

export default class DeliveryVelocityDashboard extends LightningElement {
    @track activeWorkflowType = 'Software_Delivery';
    @track weeklyVelocity = [];
    @track projection = null;
    @track capacity = null;
    @track isLoading = true;
    @track whatIfItems = 0;

    wiredDashboardResult;

    @wire(getVelocityDashboard, { workflowType: '$activeWorkflowType' })
    wiredDashboard(result) {
        this.wiredDashboardResult = result;
        if (result.data) {
            this.processData(result.data);
            this.isLoading = false;
        } else if (result.error) {
            this.isLoading = false;
        }
    }

    processData(data) {
        // Velocity chart data
        const velocityItems = data.weeklyVelocity || [];
        const maxCount = Math.max(...velocityItems.map(wk => wk.completedCount), 1);
        this.weeklyVelocity = velocityItems.map((wk, idx) => {
            const height = wk.completedCount > 0
                ? Math.max(Math.round((wk.completedCount / maxCount) * BAR_MAX_HEIGHT), BAR_MIN_HEIGHT)
                : BAR_MIN_HEIGHT;
            const color = wk.completedCount > 0 ? BAR_COLOR_PRIMARY : BAR_COLOR_EMPTY;
            return {
                barStyle: `height: ${height}px; width: 100%; border-radius: 3px 3px 0 0; background: ${color};`,
                completedCount: wk.completedCount,
                key: `week-${idx}`,
                label: wk.weekLabel
            };
        });

        // Projection
        if (data.projection) {
            this.projection = {
                averageVelocity: data.projection.averageVelocity
                    ? data.projection.averageVelocity.toFixed(1)
                    : '0',
                estimatedWeeks: data.projection.estimatedWeeks || 0,
                projectedDate: data.projection.projectedCompletionDate || null,
                remainingItems: data.projection.remainingItems || 0
            };
        }

        // Capacity
        if (data.capacity) {
            const cap = data.capacity;
            this.capacity = {
                allocatedHours: cap.allocatedHours || 0,
                developerCount: cap.developerCount || 0,
                developers: (cap.developers || []).map((dev, idx) => {
                    const pct = dev.weeklyCapacityHours > 0
                        ? Math.round((dev.allocatedHours / dev.weeklyCapacityHours) * FULL_PERCENT)
                        : 0;
                    return {
                        activeItemCount: dev.activeItemCount,
                        allocatedHours: dev.allocatedHours,
                        barStyle: `width: ${pct}%; height: 8px; border-radius: 4px; background: ${BAR_COLOR_PRIMARY};`,
                        key: `dev-${idx}`,
                        name: dev.developerName,
                        utilizationPct: pct,
                        weeklyCapacity: dev.weeklyCapacityHours
                    };
                }),
                totalCapacityHours: cap.totalCapacityHours || 0,
                utilizationPercent: cap.utilizationPercent
                    ? Math.round(cap.utilizationPercent)
                    : 0
            };
        }
    }

    // Getters
    get isLoaded() {
        return !this.isLoading;
    }

    get hasVelocityData() {
        return this.weeklyVelocity.length > 0;
    }

    get hasProjection() {
        return this.projection !== null && this.projection !== undefined;
    }

    get hasCapacity() {
        return this.capacity !== null && this.capacity !== undefined;
    }

    get hasDevelopers() {
        return this.capacity && this.capacity.developers && this.capacity.developers.length > 0;
    }

    get projectedDateFormatted() {
        if (!this.projection?.projectedDate) {
            return 'N/A (no velocity data)';
        }
        return this.projection.projectedDate;
    }

    get whatIfProjection() {
        if (!this.projection || !this.projection.averageVelocity) {
            return null;
        }
        const avgVelocity = parseFloat(this.projection.averageVelocity);
        if (avgVelocity <= 0) {
            return null;
        }
        const additionalItems = parseInt(this.whatIfItems, 10) || 0;
        const totalItems = this.projection.remainingItems + additionalItems;
        const weeks = Math.ceil(totalItems / avgVelocity);
        const shiftDays = (weeks - this.projection.estimatedWeeks) * DAYS_PER_WEEK;
        return {
            newEstimatedWeeks: weeks,
            shiftDays,
            totalItems
        };
    }

    get hasWhatIfResult() {
        return this.whatIfProjection !== null && this.whatIfProjection !== undefined;
    }

    // Handlers
    handleWhatIfChange(event) {
        this.whatIfItems = event.target.value;
    }

    handleRefresh() {
        this.isLoading = true;
        refreshApex(this.wiredDashboardResult).then(() => {
            this.isLoading = false;
        });
    }
}

/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Developer Workload Dashboard — shows active work item distribution
 * per developer with estimated hours and stage breakdown.
 * @author Cloud Nimbus LLC
 */
import { LightningElement, wire, track } from 'lwc';
import getWorkloadData from '@salesforce/apex/DeliveryWorkloadController.getWorkloadData';
import getUnassignedCount from '@salesforce/apex/DeliveryWorkloadController.getUnassignedCount';
import { refreshApex } from '@salesforce/apex';

export default class DeliveryDeveloperWorkload extends LightningElement {
    @track developers = [];
    @track unassignedCount = 0;
    @track error;
    @track isLoading = true;

    _wiredWorkloadResult;
    _wiredUnassignedResult;
    _maxItems = 0;

    @wire(getWorkloadData, { workflowTypeName: 'Software_Delivery' })
    wiredWorkload(result) {
        this._wiredWorkloadResult = result;
        if (result.data) {
            this._processWorkloadData(result.data);
            this.error = undefined;
        } else if (result.error) {
            this.error = result.error.body ? result.error.body.message : result.error.message;
            this.developers = [];
        }
        this._updateLoading();
    }

    @wire(getUnassignedCount, { workflowTypeName: 'Software_Delivery' })
    wiredUnassigned(result) {
        this._wiredUnassignedResult = result;
        if (result.data !== undefined) {
            this.unassignedCount = result.data;
        } else if (result.error) {
            this.unassignedCount = 0;
        }
        this._updateLoading();
    }

    /** Processes raw Apex workload data into view-model with computed properties. */
    _processWorkloadData(data) {
        this._maxItems = 0;
        for (let i = 0; i < data.length; i++) {
            if (data[i].totalItems > this._maxItems) {
                this._maxItems = data[i].totalItems;
            }
        }

        this.developers = data.map((dev, index) => {
            const stagePills = this._buildStagePills(dev.stageBreakdown);
            const barPercent = this._maxItems > 0
                ? Math.round((dev.totalItems / this._maxItems) * 100)
                : 0;
            const hours = dev.totalEstimatedHours != null ? dev.totalEstimatedHours : 0;

            return {
                key: dev.developerId || `dev-${index}`,
                developerId: dev.developerId,
                developerName: dev.developerName,
                totalItems: dev.totalItems,
                totalEstimatedHours: this._formatHours(hours),
                barStyle: `width: ${barPercent}%`,
                barPercent,
                stagePills
            };
        });
    }

    /** Builds an array of stage pill view-models from the stage breakdown map. */
    _buildStagePills(stageBreakdown) {
        if (!stageBreakdown) {
            return [];
        }
        const pills = [];
        const entries = Object.entries(stageBreakdown);
        entries.sort((a, b) => b[1] - a[1]);

        for (let i = 0; i < entries.length; i++) {
            const [stage, count] = entries[i];
            pills.push({
                key: `${stage}-${count}`,
                label: `${stage} (${count})`,
                cssClass: this._pillClass(stage)
            });
        }
        return pills;
    }

    /** Returns a CSS class for a stage pill based on stage keywords. */
    _pillClass(stage) {
        const lower = stage.toLowerCase();
        if (lower.includes('blocked')) {
            return 'dw-pill dw-pill--blocked';
        }
        if (lower.includes('uat') || lower.includes('testing') || lower.includes('qa')) {
            return 'dw-pill dw-pill--testing';
        }
        if (lower.includes('development') || lower.includes('dev')) {
            return 'dw-pill dw-pill--dev';
        }
        if (lower.includes('review') || lower.includes('approval') || lower.includes('sign-off')) {
            return 'dw-pill dw-pill--review';
        }
        return 'dw-pill dw-pill--default';
    }

    /** Formats hours to one decimal place with 'h' suffix. */
    _formatHours(hours) {
        if (hours === 0) {
            return '0h';
        }
        const rounded = Math.round(hours * 10) / 10;
        return `${rounded}h`;
    }

    /** Marks loading complete when both wires have resolved. */
    _updateLoading() {
        if (this._wiredWorkloadResult && this._wiredUnassignedResult) {
            const workloadResolved = this._wiredWorkloadResult.data !== undefined
                || this._wiredWorkloadResult.error !== undefined;
            const unassignedResolved = this._wiredUnassignedResult.data !== undefined
                || this._wiredUnassignedResult.error !== undefined;
            if (workloadResolved && unassignedResolved) {
                this.isLoading = false;
            }
        }
    }

    /** Summary text for the header bar. */
    get summaryText() {
        const devCount = this.developers.length;
        const devLabel = devCount === 1 ? 'developer active' : 'developers active';
        const unLabel = this.unassignedCount === 1 ? 'item unassigned' : 'items unassigned';
        return `${devCount} ${devLabel}, ${this.unassignedCount} ${unLabel}`;
    }

    /** True when there is data to show (developers list is not empty). */
    get hasData() {
        return this.developers.length > 0;
    }

    /** True when data loaded successfully but no active items exist. */
    get showEmptyState() {
        return !this.isLoading && !this.error && !this.hasData;
    }

    /** True when an unassigned count badge should be highlighted. */
    get hasUnassigned() {
        return this.unassignedCount > 0;
    }

    /** CSS class for the unassigned badge. */
    get unassignedBadgeClass() {
        return this.unassignedCount > 0
            ? 'dw-badge dw-badge--warning'
            : 'dw-badge dw-badge--neutral';
    }

    /** Refreshes both wire adapters. */
    handleRefresh() {
        this.isLoading = true;
        refreshApex(this._wiredWorkloadResult);
        refreshApex(this._wiredUnassignedResult);
    }
}

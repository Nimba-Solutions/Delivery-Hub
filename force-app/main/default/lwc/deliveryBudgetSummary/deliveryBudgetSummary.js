import { LightningElement, track, wire } from 'lwc';
import getBudgetMetrics from '@salesforce/apex/DeliveryHubDashboardController.getBudgetMetrics';
import { refreshApex } from '@salesforce/apex';

export default class DeliveryBudgetSummary extends LightningElement {
    @track metrics = { 
        totalHours: 0, 
        activeRequests: 0, 
        succeededSyncs: 0, 
        failedSyncs: 0 
    };

    wiredMetricsResult;

    @wire(getBudgetMetrics)
    wiredMetrics(result) {
        this.wiredMetricsResult = result;
        if (result.data) {
            this.metrics = result.data;
        } else if (result.error) {
            console.error('Error loading metrics', result.error);
        }
    }

    get syncHealth() {
        const total = this.metrics.succeededSyncs + this.metrics.failedSyncs;
        if (total === 0) return 100;
        // Calculate percentage of success
        return Math.floor((this.metrics.succeededSyncs / total) * 100);
    }

    get healthBarClass() {
        // Dynamic color: Green if 100%, Yellow if > 90%, Red if below
        if (this.syncHealth === 100) return 'slds-progress-bar__value slds-progress-bar__value_success';
        if (this.syncHealth > 90) return 'slds-progress-bar__value slds-theme_warning';
        return 'slds-progress-bar__value slds-theme_error';
    }

    get failTextClass() {
        // Make the failed number RED if > 0
        return this.metrics.failedSyncs > 0 
            ? 'slds-text-heading_medium slds-text-color_error' 
            : 'slds-text-heading_medium slds-text-color_weak';
    }

    get barStyle() {
        return `width: ${this.syncHealth}%`;
    }

    handleRefresh() {
        refreshApex(this.wiredMetricsResult);
    }
}
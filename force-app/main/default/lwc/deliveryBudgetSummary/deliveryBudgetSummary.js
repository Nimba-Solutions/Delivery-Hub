/* eslint-disable new-cap */
/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @author Cloud Nimbus LLC
 */
import { LightningElement, api, track, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getBudgetMetrics from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryHubDashboardController.getBudgetMetrics';
import { refreshApex } from '@salesforce/apex';

export default class DeliveryBudgetSummary extends NavigationMixin(LightningElement) {
    @api hideConnectionHealth = false;

    get shouldShowConnectionHealth() {
        return !this.hideConnectionHealth;
    }

    @track metrics = {
        hoursThisMonth: 0,
        hoursLastMonth: 0,
        activeRequests: 0,
        succeededSyncs: 0,
        failedSyncs: 0,
        lastEntry: '--'
    };

    wiredMetricsResult;

    @wire(getBudgetMetrics)
    wiredMetrics(result) {
        this.wiredMetricsResult = result;
        if (result.data) {
            // Apex returns Map<String, Object>, so we can assign directly
            this.metrics = result.data;
        } else if (result.error) {
            console.error('Error loading metrics', result.error);
        }
    }

    /**
     * Calculates the percentage of successful syncs.
     * Returns 100 if no syncs have occurred yet.
     */
    get syncHealth() {
        const total = (this.metrics.succeededSyncs || 0) + (this.metrics.failedSyncs || 0);
        if (total === 0) return 100;
        
        const success = this.metrics.succeededSyncs || 0;
        return Math.floor((success / total) * 100);
    }

    /**
     * Returns the CSS class for the progress bar based on health score.
     */
    get healthBarClass() {
        if (this.syncHealth === 100) return 'slds-progress-bar__value slds-progress-bar__value_success';
        if (this.syncHealth > 90) return 'slds-progress-bar__value slds-theme_warning';
        return 'slds-progress-bar__value slds-theme_error';
    }

    /**
     * Styles the "Failed" text red only if there are actual failures.
     */
    get failTextClass() {
        return this.metrics.failedSyncs > 0 
            ? 'slds-text-heading_medium slds-text-color_error' 
            : 'slds-text-heading_medium slds-text-color_weak';
    }

    get barStyle() {
        return `width: ${this.syncHealth}%`;
    }

    /**
     * Navigates to the Sync Item list view showing all records.
     */
    handleSyncedClick() {
        this[NavigationMixin.Navigate]({
            attributes: {
                actionName: 'list',
                objectApiName: '%%%NAMESPACED_ORG%%%SyncItem__c'
            },
            state: {
                filterName: 'Recent'
            },
            type: 'standard__objectPage'
        });
    }

    /**
     * Navigates to the Sync Item list view (failed items).
     */
    handleFailedClick() {
        this[NavigationMixin.Navigate]({
            attributes: {
                actionName: 'list',
                objectApiName: '%%%NAMESPACED_ORG%%%SyncItem__c'
            },
            state: {
                filterName: 'Recent'
            },
            type: 'standard__objectPage'
        });
    }

    handleRefresh() {
        refreshApex(this.wiredMetricsResult);
    }

    handleActiveItemsClick() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: {
                objectApiName: '%%%NAMESPACED_ORG%%%WorkItem__c',
                actionName: 'list'
            },
            state: { filterName: 'In_Flight' }
        });
    }

    handleHoursThisMonthClick() {
        const now = new Date();
        const start = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-01`;
        const lastDay = new Date(now.getFullYear(), now.getMonth() + 1, 0).getDate();
        const end = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-${lastDay}`;
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: {
                objectApiName: '%%%NAMESPACED_ORG%%%WorkLog__c',
                actionName: 'list'
            },
            state: { filterName: 'This_Month' }
        });
    }

    handleHoursLastMonthClick(event) {
        event.stopPropagation();
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: {
                objectApiName: '%%%NAMESPACED_ORG%%%WorkLog__c',
                actionName: 'list'
            },
            state: { filterName: 'Last_Month' }
        });
    }
}
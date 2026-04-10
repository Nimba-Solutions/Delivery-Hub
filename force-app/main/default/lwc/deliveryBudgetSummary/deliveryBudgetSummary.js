/* eslint-disable new-cap */
/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @author Cloud Nimbus LLC
 */
import { LightningElement, api, track, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getBudgetMetrics from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryHubDashboardController.getBudgetMetrics';
import getReportIds from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryHubDashboardController.getReportIds';
import { refreshApex } from '@salesforce/apex';

export default class DeliveryBudgetSummary extends NavigationMixin(LightningElement) {
    @api hideConnectionHealth = false;

    get shouldShowConnectionHealth() {
        return !this.hideConnectionHealth;
    }

    @track metrics = {
        hoursThisMonth: 0,
        hoursLastMonth: 0,
        hoursLoggedThisMonth: 0,
        hoursLoggedLastMonth: 0,
        activeRequests: 0,
        succeededSyncs: 0,
        failedSyncs: 0,
        lastEntry: '--'
    };

    @track reportIds = {};

    wiredMetricsResult;

    @wire(getBudgetMetrics)
    wiredMetrics(result) {
        this.wiredMetricsResult = result;
        if (result.data) {
            // Apex returns Map<String, Object>, so we can assign directly
            this.metrics = result.data;
        } else if (result.error) {
            // eslint-disable-next-line no-console
            console.error('Error loading metrics', result.error);
        }
    }

    connectedCallback() {
        // Fetch report Ids by DeveloperName so the click handlers can navigate
        // to real reports with date-range URL parameters. If a report doesn't
        // exist in this org (e.g. it was deleted), the handler falls back to
        // the relevant list view so the click is never dead.
        getReportIds({ developerNames: ['Monthly_Hours', 'Monthly_Hours_By_Entry_Date', 'In_Flight_Work_Items', 'Synced_Items', 'Failed_Items'] })
            .then((data) => {
                this.reportIds = data || {};
            })
            // eslint-disable-next-line no-unused-vars
            .catch((_e) => {
                // Report Ids not available — handlers fall back to list views
                this.reportIds = {};
            });
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

    handleSyncedClick() {
        const reportId = this.reportIds.Synced_Items;
        if (reportId) {
            this[NavigationMixin.Navigate]({ type: 'standard__webPage', attributes: { url: `/lightning/r/Report/${reportId}/view` } });
            return;
        }
        this[NavigationMixin.Navigate]({ type: 'standard__objectPage', attributes: { objectApiName: '%%%NAMESPACED_ORG%%%SyncItem__c', actionName: 'list' }, state: { filterName: 'Recent' } });
    }

    handleFailedClick() {
        const reportId = this.reportIds.Failed_Items;
        if (reportId) {
            this[NavigationMixin.Navigate]({ type: 'standard__webPage', attributes: { url: `/lightning/r/Report/${reportId}/view` } });
            return;
        }
        this[NavigationMixin.Navigate]({ type: 'standard__objectPage', attributes: { objectApiName: '%%%NAMESPACED_ORG%%%SyncItem__c', actionName: 'list' }, state: { filterName: 'Recent' } });
    }

    handleRefresh() {
        refreshApex(this.wiredMetricsResult);
    }

    /**
     * Active Work Items tile click — navigate to the In_Flight_Work_Items report
     * if available, otherwise fall back to the In_Flight list view.
     */
    handleActiveItemsClick() {
        const reportId = this.reportIds.In_Flight_Work_Items;
        if (reportId) {
            this[NavigationMixin.Navigate]({
                type: 'standard__webPage',
                attributes: {
                    url: `/lightning/r/Report/${reportId}/view`
                }
            });
            return;
        }
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: {
                objectApiName: '%%%NAMESPACED_ORG%%%WorkItem__c',
                actionName: 'list'
            },
            state: { filterName: 'In_Flight' }
        });
    }

    // ── Hours click handlers ───────────────────────────────────────────
    // Two reports, two date concepts:
    //   Monthly_Hours_By_Entry_Date → CreatedDate (when entered)
    //   Monthly_Hours              → WorkDate    (when performed)

    handleHoursEnteredThisMonthClick() {
        this.openHoursReport('Monthly_Hours_By_Entry_Date', 0);
    }

    handleHoursPerformedThisMonthClick(event) {
        if (event && event.stopPropagation) { event.stopPropagation(); }
        this.openHoursReport('Monthly_Hours', 0);
    }

    handleHoursEnteredLastMonthClick(event) {
        if (event && event.stopPropagation) { event.stopPropagation(); }
        this.openHoursReport('Monthly_Hours_By_Entry_Date', -1);
    }

    handleHoursPerformedLastMonthClick(event) {
        if (event && event.stopPropagation) { event.stopPropagation(); }
        this.openHoursReport('Monthly_Hours', -1);
    }

    openHoursReport(reportName, offsetMonths) {
        const reportId = this.reportIds[reportName];
        if (reportId) {
            const { start, end } = this.monthBounds(offsetMonths);
            this[NavigationMixin.Navigate]({
                type: 'standard__webPage',
                attributes: { url: `/lightning/r/Report/${reportId}/view?fv0=${start}&fv1=${end}` }
            });
            return;
        }
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: { objectApiName: '%%%NAMESPACED_ORG%%%WorkLog__c', actionName: 'list' },
            state: { filterName: offsetMonths === 0 ? 'This_Month' : 'Last_Month' }
        });
    }

    /**
     * Returns ISO date strings for the start and end of a calendar month
     * relative to today. offsetMonths=0 → current month; -1 → previous; etc.
     * @param {number} offsetMonths
     * @returns {{start: string, end: string}}
     */
    monthBounds(offsetMonths) {
        const now = new Date();
        const year = now.getFullYear();
        const month = now.getMonth() + offsetMonths;
        const startDate = new Date(year, month, 1);
        const endDate = new Date(year, month + 1, 0);
        const fmt = (d) => `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
        return { start: fmt(startDate), end: fmt(endDate) };
    }
}

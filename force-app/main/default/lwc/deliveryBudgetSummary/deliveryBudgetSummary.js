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
        getReportIds({ developerNames: ['Monthly_Hours', 'In_Flight_Work_Items'] })
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

    /**
     * "Hours Logged This Month" big number click — navigates to the
     * Monthly_Hours report with CreatedDate filters (fv2/fv3) narrowed
     * to the current month. WorkDate filters (fv0/fv1) are left wide-open
     * so they don't constrain. Shows exactly the records behind the
     * CreatedDate-based metric the user clicked on.
     */
    handleHoursThisMonthClick() {
        this.navigateToHoursReport(0, 'created');
    }

    /**
     * "X hrs by Work Date" sub-text click — navigates to the Monthly_Hours
     * report with WorkDate filters (fv0/fv1) narrowed to the current month.
     * CreatedDate filters (fv2/fv3) left wide-open. Shows exactly the
     * records behind the WorkDate-based metric the user clicked on.
     */
    handleHoursWorkedClick(event) {
        if (event && event.stopPropagation) {
            event.stopPropagation();
        }
        this.navigateToHoursReport(0, 'worked');
    }

    /**
     * Last-month sub-text click — same Monthly_Hours report. Narrows
     * BOTH pairs to the previous month, so clicking either the "logged"
     * or "by Work Date" number in the sub-text takes you to the full
     * last-month view (both columns visible for comparison).
     */
    handleHoursLastMonthClick(event) {
        if (event && event.stopPropagation) {
            event.stopPropagation();
        }
        this.navigateToHoursReport(-1, 'both');
    }

    /**
     * Unified navigation to the Monthly_Hours report. The report has
     * 4 unlocked filters: fv0/fv1 on WorkDate, fv2/fv3 on CreatedDate.
     * The mode controls which pair is narrowed:
     *   'created' → narrow CreatedDate, leave WorkDate wide-open
     *   'worked'  → narrow WorkDate, leave CreatedDate wide-open
     *   'both'    → narrow both (shows full intersection for comparison)
     *
     * @param {number} offsetMonths - 0 for current month, -1 for last, etc.
     * @param {string} mode - 'created', 'worked', or 'both'
     */
    navigateToHoursReport(offsetMonths, mode) {
        const reportId = this.reportIds.Monthly_Hours;
        if (reportId) {
            const { start, end } = this.monthBounds(offsetMonths);
            const wide = { start: '1900-01-01', end: '2099-12-31' };
            let fv0, fv1, fv2, fv3;
            if (mode === 'created') {
                fv0 = wide.start; fv1 = wide.end; fv2 = start; fv3 = end;
            } else if (mode === 'worked') {
                fv0 = start; fv1 = end; fv2 = wide.start; fv3 = wide.end;
            } else {
                fv0 = start; fv1 = end; fv2 = start; fv3 = end;
            }
            this[NavigationMixin.Navigate]({
                type: 'standard__webPage',
                attributes: {
                    url: `/lightning/r/Report/${reportId}/view?fv0=${fv0}&fv1=${fv1}&fv2=${fv2}&fv3=${fv3}`
                }
            });
            return;
        }
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: {
                objectApiName: '%%%NAMESPACED_ORG%%%WorkLog__c',
                actionName: 'list'
            },
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

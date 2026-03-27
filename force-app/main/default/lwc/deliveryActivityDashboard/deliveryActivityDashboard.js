/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @author Cloud Nimbus LLC
 */
import { LightningElement, track, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { refreshApex } from '@salesforce/apex';
import getActivitySummary from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryActivityDashboardController.getActivitySummary';
import getReportIds from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryHubDashboardController.getReportIds';

const BAR_PERCENT_SCALE = 100,
    BAR_MIN_PERCENT = 5,
    BAR_HEIGHT_SCALE = 80,
    BAR_MIN_HEIGHT = 2,
    PAGE_LABEL_MAX = 50,
    PAGE_LABEL_TRUNCATE = 47,
    BAR_COLOR = '#0176d3',
    EMPTY = 0,
    FIRST_INDEX = 0,
    FALLBACK_MAX = 1,
    SECOND_ELEMENT = 1;

export default class DeliveryActivityDashboard extends NavigationMixin(LightningElement) { // eslint-disable-line new-cap
    @track totalThisWeek = 0;
    @track totalThisMonth = 0;
    @track topUsers = [];
    @track topComponents = [];
    @track topPages = [];
    @track dailyCounts = [];
    @track hasData = false;

    get isEmpty() {
        return !this.isLoading && !this.hasData;
    }

    wiredSummaryResult;
    maxDailyCount = FALLBACK_MAX;

    @wire(getActivitySummary)
    wiredSummary(result) {
        this.wiredSummaryResult = result;
        if (result.data) {
            this.totalThisWeek = result.data.totalThisWeek || EMPTY;
            this.totalThisMonth = result.data.totalThisMonth || EMPTY;
            this.topUsers = this.formatRankedItems(result.data.topUsers || []);
            this.topComponents = this.formatRankedItems(result.data.topComponents || []);
            this.topPages = this.formatPageItems(result.data.topPages || []);
            this.processDailyCounts(result.data.dailyCounts || []);
            this.hasData = this.totalThisMonth > EMPTY;
        }
    }

    formatRankedItems(items) {
        if (!items || items.length === EMPTY) {
            return [];
        }
        const maxCount = items[FIRST_INDEX].count || FALLBACK_MAX;
        return items.map((item, index) => {
            const pct = Math.max(Math.round((item.count / maxCount) * BAR_PERCENT_SCALE), BAR_MIN_PERCENT);
            return {
                barStyle: `width: ${pct}%; height: 6px; border-radius: 3px; background: ${BAR_COLOR};`,
                barWidth: pct,
                count: item.count,
                key: `${item.label}-${index}`,
                label: item.label
            };
        });
    }

    formatPageItems(items) {
        if (!items || items.length === EMPTY) {
            return [];
        }
        const maxCount = items[FIRST_INDEX].count || FALLBACK_MAX;
        return items.map((item, index) => {
            let shortLabel = item.label || '';
            // Extract meaningful part of URL
            if (shortLabel.includes('/lightning/')) {
                const parts = shortLabel.split('/lightning/');
                shortLabel = `/lightning/${parts[SECOND_ELEMENT] || ''}`;
            }
            // Truncate if too long
            if (shortLabel.length > PAGE_LABEL_MAX) {
                shortLabel = `${shortLabel.substring(0, PAGE_LABEL_TRUNCATE)}...`;
            }
            const pct = Math.max(Math.round((item.count / maxCount) * BAR_PERCENT_SCALE), BAR_MIN_PERCENT);
            return {
                barStyle: `width: ${pct}%; height: 6px; border-radius: 3px; background: ${BAR_COLOR};`,
                barWidth: pct,
                count: item.count,
                fullUrl: item.label,
                key: `${item.label}-${index}`,
                label: shortLabel
            };
        });
    }

    processDailyCounts(counts) {
        if (!counts || counts.length === EMPTY) {
            this.dailyCounts = [];
            this.maxDailyCount = FALLBACK_MAX;
            return;
        }
        this.maxDailyCount = Math.max(...counts.map(day => day.count), FALLBACK_MAX);
        this.dailyCounts = counts.map((day, index) => {
            const height = Math.max(Math.round((day.count / this.maxDailyCount) * BAR_HEIGHT_SCALE), BAR_MIN_HEIGHT);
            return {
                barHeight: height,
                barStyle: `height: ${height}px; width: 100%; border-radius: 3px 3px 0 0; background: ${BAR_COLOR};`,
                count: day.count,
                key: `${day.dateLabel}-${index}`,
                label: day.dateLabel
            };
        });
    }

    get hasTopUsers() {
        return this.topUsers.length > EMPTY;
    }

    get hasTopComponents() {
        return this.topComponents.length > EMPTY;
    }

    get hasTopPages() {
        return this.topPages.length > EMPTY;
    }

    get hasDailyCounts() {
        return this.dailyCounts.length > EMPTY;
    }

    handleRefresh() {
        refreshApex(this.wiredSummaryResult);
    }

    handleViewReport() {
        getReportIds({ developerNames: ['User_Activity_Summary'] })
            .then(ids => {
                const reportId = ids.User_Activity_Summary;
                if (reportId) {
                    this[NavigationMixin.Navigate]({ // eslint-disable-line new-cap
                        attributes: {
                            actionName: 'view',
                            objectApiName: 'Report',
                            recordId: reportId
                        },
                        type: 'standard__recordPage'
                    });
                } else {
                    this.navigateToActivityLogs();
                }
            })
            .catch(() => this.navigateToActivityLogs());
    }

    navigateToActivityLogs() {
        this[NavigationMixin.Navigate]({ // eslint-disable-line new-cap
            attributes: {
                actionName: 'list',
                objectApiName: '%%%NAMESPACED_ORG%%%ActivityLog__c'
            },
            state: {
                filterName: 'Recent'
            },
            type: 'standard__objectPage'
        });
    }
}

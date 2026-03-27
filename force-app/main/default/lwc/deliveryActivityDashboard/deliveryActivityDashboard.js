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

const BAR_PERCENT_SCALE = 100;
const BAR_MIN_PERCENT = 5;
const BAR_HEIGHT_SCALE = 80;
const BAR_MIN_HEIGHT = 2;
const PAGE_LABEL_MAX = 50;
const PAGE_LABEL_TRUNCATE = 47;
const BAR_COLOR = '#0176d3';

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
    maxDailyCount = 1;

    @wire(getActivitySummary)
    wiredSummary(result) {
        this.wiredSummaryResult = result;
        if (result.data) {
            this.totalThisWeek = result.data.totalThisWeek || 0;
            this.totalThisMonth = result.data.totalThisMonth || 0;
            this.topUsers = this.formatRankedItems(result.data.topUsers || []);
            this.topComponents = this.formatRankedItems(result.data.topComponents || []);
            this.topPages = this.formatPageItems(result.data.topPages || []);
            this.processDailyCounts(result.data.dailyCounts || []);
            this.hasData = this.totalThisMonth > 0;
        }
    }

    formatRankedItems(items) {
        if (!items || items.length === 0) {
            return [];
        }
        const maxCount = items[0].count || 1;
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
        if (!items || items.length === 0) {
            return [];
        }
        const maxCount = items[0].count || 1;
        return items.map((item, index) => {
            let shortLabel = item.label || '';
            // Extract meaningful part of URL
            if (shortLabel.includes('/lightning/')) {
                const parts = shortLabel.split('/lightning/');
                shortLabel = `/lightning/${parts[1] || ''}`;
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
        if (!counts || counts.length === 0) {
            this.dailyCounts = [];
            this.maxDailyCount = 1;
            return;
        }
        this.maxDailyCount = Math.max(...counts.map(day => day.count), 1);
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
        return this.topUsers.length > 0;
    }

    get hasTopComponents() {
        return this.topComponents.length > 0;
    }

    get hasTopPages() {
        return this.topPages.length > 0;
    }

    get hasDailyCounts() {
        return this.dailyCounts.length > 0;
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

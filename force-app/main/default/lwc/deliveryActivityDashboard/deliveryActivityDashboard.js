/* eslint-disable */
/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @author Cloud Nimbus LLC
 */
import { LightningElement, track, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getActivitySummary from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryActivityDashboardController.getActivitySummary';
import getReportIds from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryHubDashboardController.getReportIds';
import { refreshApex } from '@salesforce/apex';

export default class DeliveryActivityDashboard extends NavigationMixin(LightningElement) {
    @track totalThisWeek = 0;
    @track totalThisMonth = 0;
    @track topUsers = [];
    @track topComponents = [];
    @track topPages = [];
    @track dailyCounts = [];
    @track hasData = false;

    get isEmpty() { return !this.isLoading && !this.hasData; }

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
        } else if (result.error) {
            console.error('Error loading activity summary', result.error);
        }
    }

    formatRankedItems(items) {
        if (!items || items.length === 0) {
            return [];
        }
        const maxCount = items[0].count || 1;
        return items.map((item, index) => ({
            key: item.label + '-' + index,
            label: item.label,
            count: item.count,
            barWidth: Math.max(Math.round((item.count / maxCount) * 100), 5),
            barStyle: 'width: ' + Math.max(Math.round((item.count / maxCount) * 100), 5) + '%; height: 6px; border-radius: 3px; background: #0176d3;'
        }));
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
                shortLabel = '/lightning/' + (parts[1] || '');
            }
            // Truncate if too long
            if (shortLabel.length > 50) {
                shortLabel = shortLabel.substring(0, 47) + '...';
            }
            return {
                key: item.label + '-' + index,
                label: shortLabel,
                fullUrl: item.label,
                count: item.count,
                barWidth: Math.max(Math.round((item.count / maxCount) * 100), 5),
                barStyle: 'width: ' + Math.max(Math.round((item.count / maxCount) * 100), 5) + '%; height: 6px; border-radius: 3px; background: #0176d3;'
            };
        });
    }

    processDailyCounts(counts) {
        if (!counts || counts.length === 0) {
            this.dailyCounts = [];
            this.maxDailyCount = 1;
            return;
        }
        this.maxDailyCount = Math.max(...counts.map(d => d.count), 1);
        this.dailyCounts = counts.map((d, index) => ({
            key: d.dateLabel + '-' + index,
            label: d.dateLabel,
            count: d.count,
            barHeight: Math.max(Math.round((d.count / this.maxDailyCount) * 80), 2),
            barStyle: 'height: ' + Math.max(Math.round((d.count / this.maxDailyCount) * 80), 2) + 'px; width: 100%; border-radius: 3px 3px 0 0; background: #0176d3;'
        }));
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
                    this[NavigationMixin.Navigate]({
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
        this[NavigationMixin.Navigate]({
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

/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Portal dashboard component for Experience Cloud.
 * Shows welcome banner, stats cards, phase distribution, recent activity, and quick links.
 * @author Cloud Nimbus LLC
 */
import { LightningElement, api, wire, track } from 'lwc';
import getPortalDashboard from '@salesforce/apex/DeliveryPortalController.getPortalDashboard';

export default class DeliveryPortalDashboard extends LightningElement {
    @api networkEntityId;

    @track dashboardData;
    @track error;
    @track isLoading = true;

    @wire(getPortalDashboard, { networkEntityId: '$networkEntityId' })
    wiredDashboard({ data, error }) {
        this.isLoading = false;
        if (data) {
            this.dashboardData = data;
            this.error = undefined;
        } else if (error) {
            this.error = this.reduceError(error);
            this.dashboardData = undefined;
        }
    }

    get hasData() {
        return this.dashboardData != null;
    }

    get entityName() {
        return this.dashboardData ? this.dashboardData.entityName : '';
    }

    get greeting() {
        const hour = new Date().getHours();
        if (hour < 12) return 'Good morning';
        if (hour < 17) return 'Good afternoon';
        return 'Good evening';
    }

    get activeCount() {
        return this.dashboardData ? this.dashboardData.activeCount : 0;
    }

    get completedCount() {
        return this.dashboardData ? this.dashboardData.completedCount : 0;
    }

    get attentionCount() {
        return this.dashboardData ? this.dashboardData.attentionCount : 0;
    }

    get phases() {
        return this.dashboardData ? this.dashboardData.phases : [];
    }

    get recentActivity() {
        if (!this.dashboardData || !this.dashboardData.recentActivity) return [];
        return this.dashboardData.recentActivity.map(item => ({
            ...item,
            formattedDate: this.formatDate(item.lastModified)
        }));
    }

    get recentCompleted() {
        if (!this.dashboardData || !this.dashboardData.recentCompleted) return [];
        return this.dashboardData.recentCompleted.map(item => ({
            ...item,
            formattedDate: this.formatDate(item.lastModified)
        }));
    }

    get hasRecentActivity() {
        return this.recentActivity.length > 0;
    }

    get hasRecentCompleted() {
        return this.recentCompleted.length > 0;
    }

    get hasAttentionItems() {
        return this.attentionCount > 0;
    }

    formatDate(dateStr) {
        if (!dateStr) return '';
        const d = new Date(dateStr);
        return d.toLocaleDateString(undefined, { month: 'short', day: 'numeric', hour: 'numeric', minute: '2-digit' });
    }

    handleViewAllItems() {
        this.dispatchEvent(new CustomEvent('navigateto', {
            detail: { target: 'workItemList', networkEntityId: this.networkEntityId }
        }));
    }

    handleSubmitRequest() {
        this.dispatchEvent(new CustomEvent('navigateto', {
            detail: { target: 'requestForm', networkEntityId: this.networkEntityId }
        }));
    }

    handleViewAttention() {
        this.dispatchEvent(new CustomEvent('navigateto', {
            detail: { target: 'workItemList', networkEntityId: this.networkEntityId, filter: 'attention' }
        }));
    }

    reduceError(error) {
        if (typeof error === 'string') return error;
        if (error.body && error.body.message) return error.body.message;
        if (error.message) return error.message;
        return 'An unknown error occurred.';
    }
}

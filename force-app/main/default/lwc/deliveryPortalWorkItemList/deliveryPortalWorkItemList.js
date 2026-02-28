/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Portal work item list component for Experience Cloud.
 * Card-based, filterable list of work items scoped to one NetworkEntity.
 * @author Cloud Nimbus LLC
 */
import { LightningElement, api, wire, track } from 'lwc';
import getPortalWorkItems from '@salesforce/apex/DeliveryPortalController.getPortalWorkItems';

const FILTER_OPTIONS = [
    { label: 'All', value: '' },
    { label: 'Active', value: 'active' },
    { label: 'Needs Your Input', value: 'attention' },
    { label: 'Completed', value: 'completed' }
];

const STAGE_COLORS = {
    'Backlog': '#6b7280',
    'Scoping In Progress': '#6366f1',
    'Ready for Sizing': '#8b5cf6',
    'Ready for Development': '#3b82f6',
    'In Development': '#0070d2',
    'Ready for QA': '#06b6d4',
    'QA In Progress': '#14b8a6',
    'Ready for Client UAT': '#dd7a01',
    'In Client UAT': '#f59e0b',
    'Ready for Deployment': '#10b981',
    'Deploying': '#059669',
    'Done': '#2e844a',
    'Cancelled': '#9ca3af',
    'Deployed to Prod': '#2e844a'
};

const PRIORITY_COLORS = {
    'Critical': '#ea001e',
    'High': '#dd7a01',
    'Medium': '#0070d2',
    'Low': '#6b7280'
};

export default class DeliveryPortalWorkItemList extends LightningElement {
    @api networkEntityId;
    @api initialFilter = '';

    @track items = [];
    @track error;
    @track isLoading = true;
    @track activeFilter = '';
    @track searchTerm = '';

    filterOptions = FILTER_OPTIONS;

    connectedCallback() {
        if (this.initialFilter) {
            this.activeFilter = this.initialFilter;
        }
    }

    @wire(getPortalWorkItems, { networkEntityId: '$networkEntityId', statusFilter: '$activeFilter' })
    wiredItems({ data, error }) {
        this.isLoading = false;
        if (data) {
            this.items = data.map(item => ({
                ...item,
                formattedDate: this.formatDate(item.lastModified),
                stageBadgeStyle: this.getStageStyle(item.stage),
                priorityBadgeStyle: this.getPriorityStyle(item.priority),
                hasPriority: !!item.priority,
                hasDescription: !!item.descriptionPreview,
                hasEta: !!item.eta,
                formattedEta: item.eta ? this.formatEtaDate(item.eta) : ''
            }));
            this.error = undefined;
        } else if (error) {
            this.error = this.reduceError(error);
            this.items = [];
        }
    }

    get filteredItems() {
        if (!this.searchTerm) return this.items;
        const term = this.searchTerm.toLowerCase();
        return this.items.filter(item =>
            (item.title && item.title.toLowerCase().includes(term)) ||
            (item.name && item.name.toLowerCase().includes(term))
        );
    }

    get hasItems() {
        return this.filteredItems.length > 0;
    }

    get itemCount() {
        return this.filteredItems.length;
    }

    get itemCountLabel() {
        const n = this.itemCount;
        return `${n} item${n === 1 ? '' : 's'}`;
    }

    getStageStyle(stage) {
        const color = STAGE_COLORS[stage] || '#6b7280';
        return `background-color: ${color}; color: #ffffff; padding: 0.2rem 0.6rem; border-radius: 12px; font-size: 0.7rem; font-weight: 600; display: inline-block;`;
    }

    getPriorityStyle(priority) {
        const color = PRIORITY_COLORS[priority] || '#6b7280';
        return `background-color: ${color}15; color: ${color}; border: 1px solid ${color}40; padding: 0.15rem 0.5rem; border-radius: 12px; font-size: 0.7rem; font-weight: 600; display: inline-block;`;
    }

    formatDate(dateStr) {
        if (!dateStr) return '';
        const d = new Date(dateStr);
        return d.toLocaleDateString(undefined, { month: 'short', day: 'numeric', hour: 'numeric', minute: '2-digit' });
    }

    formatEtaDate(dateStr) {
        if (!dateStr) return '';
        const d = new Date(dateStr);
        return d.toLocaleDateString(undefined, { month: 'short', day: 'numeric', year: 'numeric' });
    }

    handleFilterChange(event) {
        const selected = event.target.dataset.filter;
        this.activeFilter = selected;
        this.isLoading = true;
    }

    handleSearchInput(event) {
        this.searchTerm = event.target.value;
    }

    handleItemClick(event) {
        const itemId = event.currentTarget.dataset.id;
        this.dispatchEvent(new CustomEvent('navigateto', {
            detail: { target: 'workItemDetail', workItemId: itemId, networkEntityId: this.networkEntityId }
        }));
    }

    getFilterClass(filterValue) {
        return this.activeFilter === filterValue
            ? 'portal-filter-btn portal-filter-active'
            : 'portal-filter-btn';
    }

    get filterAll() { return this.getFilterClass(''); }
    get filterActive() { return this.getFilterClass('active'); }
    get filterAttention() { return this.getFilterClass('attention'); }
    get filterCompleted() { return this.getFilterClass('completed'); }

    reduceError(error) {
        if (typeof error === 'string') return error;
        if (error.body && error.body.message) return error.body.message;
        if (error.message) return error.message;
        return 'An unknown error occurred.';
    }
}

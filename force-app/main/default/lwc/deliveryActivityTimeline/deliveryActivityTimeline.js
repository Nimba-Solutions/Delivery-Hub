/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Activity Timeline LWC for Work Item record pages.
 * Displays a unified, filterable, chronological timeline of comments,
 * stage changes, and time logs.
 * @author Cloud Nimbus LLC
 */
import { LightningElement, api, wire, track } from 'lwc';
import getTimelineEvents from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryActivityTimelineController.getTimelineEvents';
import { refreshApex } from '@salesforce/apex';
import { subscribe, unsubscribe, onError } from 'lightning/empApi';

// Live updates — refresh on any DeliveryWorkItemChange__e for THIS record.
// Filter to events whose WorkItemIdTxt__c matches the @api recordId so the
// timeline doesn't refresh storm when other records on the org are edited.
const PE_CHANNEL = '/event/%%%NAMESPACE_DOT%%%DeliveryWorkItemChange__e';

const FILTER_OPTIONS = [
    { label: 'All', value: 'all', icon: 'utility:list' },
    { label: 'Comments', value: 'comments', icon: 'utility:comments' },
    { label: 'Stage Changes', value: 'stage_changes', icon: 'utility:change_record_type' },
    { label: 'Time Logs', value: 'time_logs', icon: 'utility:clock' }
];

const RELATIVE_TIME_THRESHOLDS = {
    MINUTE: 60000,
    HOUR: 3600000,
    DAY: 86400000
};

export default class DeliveryActivityTimeline extends LightningElement {
    @api recordId;

    @track events = [];
    @track displayGroups = [];

    filterOptions = FILTER_OPTIONS;
    activeFilter = 'all';
    currentPage = 0;
    hasMore = true;
    isLoadingMore = false;
    error;

    _wiredResult;
    _empSubscription;

    // ── Lifecycle ───────────────────────────────────────────────────────

    connectedCallback() {
        if (!this.recordId) return;
        onError((err) => {
            console.warn('[DeliveryActivityTimeline] empApi error:', JSON.stringify(err));
        });
        subscribe(PE_CHANNEL, -1, (message) => {
            const payload = message && message.data && message.data.payload;
            if (!payload) return;
            const ns = this._peNs();
            const eventWiId = payload.WorkItemIdTxt__c || payload[`${ns}WorkItemIdTxt__c`];
            // Only refresh when the change is for this record.
            if (!eventWiId) return;
            if (eventWiId.substring(0, 15) !== this.recordId.substring(0, 15)) return;
            if (this._wiredResult) {
                refreshApex(this._wiredResult);
            }
        }).then((sub) => { this._empSubscription = sub; });
    }

    disconnectedCallback() {
        if (this._empSubscription) {
            try { unsubscribe(this._empSubscription, () => {}); } catch (e) { /* best-effort */ }
            this._empSubscription = null;
        }
    }

    _peNs() {
        if (this.__peNs !== undefined) return this.__peNs;
        const m = PE_CHANNEL.match(/\/event\/(.*?)DeliveryWorkItemChange__e/);
        this.__peNs = (m && m[1]) ? m[1] : '';
        return this.__peNs;
    }

    // ── Wire ────────────────────────────────────────────────────────────

    @wire(getTimelineEvents, {
        workItemId: '$recordId',
        filterType: '$activeFilter',
        pageOffset: '$currentPage'
    })
    wiredTimeline(result) {
        this._wiredResult = result;
        const { data, error } = result;

        if (data) {
            if (this.currentPage === 0) {
                this.events = [...data];
            } else {
                this.events = [...this.events, ...data];
            }
            // If we got fewer than 20, there are no more pages
            this.hasMore = data.length >= 20;
            this.isLoadingMore = false;
            this.error = undefined;
            this.buildDisplayGroups();
        } else if (error) {
            this.error = error;
            this.events = [];
            this.displayGroups = [];
            this.isLoadingMore = false;
        }
    }

    // ── Getters ─────────────────────────────────────────────────────────

    get hasEvents() {
        return this.events.length > 0;
    }

    get showEmpty() {
        return !this.isLoading && !this.hasEvents;
    }

    get isLoading() {
        return !this._wiredResult || (!this._wiredResult.data && !this._wiredResult.error);
    }

    get showLoadMore() {
        return this.hasMore && this.hasEvents;
    }

    get loadMoreLabel() {
        return this.isLoadingMore ? 'Loading...' : 'Load More';
    }

    // ── Filter Handling ─────────────────────────────────────────────────

    get computedFilterButtons() {
        return this.filterOptions.map(opt => ({
            ...opt,
            variant: opt.value === this.activeFilter ? 'brand' : 'neutral',
            cssClass: opt.value === this.activeFilter
                ? 'filter-btn filter-btn--active'
                : 'filter-btn'
        }));
    }

    handleFilterChange(event) {
        const newFilter = event.currentTarget.dataset.value;
        if (newFilter === this.activeFilter) return;

        this.activeFilter = newFilter;
        this.currentPage = 0;
        this.events = [];
        this.displayGroups = [];
        this.hasMore = true;
    }

    // ── Pagination ──────────────────────────────────────────────────────

    handleLoadMore() {
        if (this.isLoadingMore) return;
        this.isLoadingMore = true;
        this.currentPage = this.currentPage + 1;
    }

    // ── Refresh ─────────────────────────────────────────────────────────

    handleRefresh() {
        this.currentPage = 0;
        this.events = [];
        this.displayGroups = [];
        this.hasMore = true;
        return refreshApex(this._wiredResult);
    }

    // ── Collapsible detail ──────────────────────────────────────────────

    handleToggleDetail(event) {
        const eventId = event.currentTarget.dataset.id;
        this.displayGroups = this.displayGroups.map(group => ({
            ...group,
            events: group.events.map(ev => {
                if (ev.id === eventId) {
                    return { ...ev, isExpanded: !ev.isExpanded };
                }
                return ev;
            })
        }));
    }

    // ── Build Display Groups (grouped by date) ──────────────────────────

    buildDisplayGroups() {
        const groups = new Map();
        const today = new Date();
        today.setHours(0, 0, 0, 0);
        const yesterday = new Date(today);
        yesterday.setDate(yesterday.getDate() - 1);

        for (const ev of this.events) {
            const ts = new Date(ev.timestamp);
            const dateKey = `${ts.getFullYear()}-${String(ts.getMonth() + 1).padStart(2, '0')}-${String(ts.getDate()).padStart(2, '0')}`;

            let dateLabel;
            const evDate = new Date(ts);
            evDate.setHours(0, 0, 0, 0);

            if (evDate.getTime() === today.getTime()) {
                dateLabel = 'Today';
            } else if (evDate.getTime() === yesterday.getTime()) {
                dateLabel = 'Yesterday';
            } else {
                dateLabel = ts.toLocaleDateString(undefined, {
                    weekday: 'short',
                    year: 'numeric',
                    month: 'short',
                    day: 'numeric'
                });
            }

            if (!groups.has(dateKey)) {
                groups.set(dateKey, { dateKey, dateLabel, events: [] });
            }

            groups.get(dateKey).events.push({
                ...ev,
                relativeTime: this.getRelativeTime(ts),
                formattedTime: ts.toLocaleTimeString(undefined, {
                    hour: '2-digit',
                    minute: '2-digit'
                }),
                hasDetail: !!ev.detail,
                isExpanded: false,
                typeClass: 'timeline-icon timeline-icon--' + ev.type,
                isComment: ev.type === 'comment',
                isStageChange: ev.type === 'stage_change',
                isWorklog: ev.type === 'worklog'
            });
        }

        this.displayGroups = Array.from(groups.values());
    }

    // ── Relative Time ───────────────────────────────────────────────────

    getRelativeTime(date) {
        const now = Date.now();
        const diff = now - date.getTime();

        if (diff < RELATIVE_TIME_THRESHOLDS.MINUTE) {
            return 'Just now';
        }
        if (diff < RELATIVE_TIME_THRESHOLDS.HOUR) {
            const mins = Math.floor(diff / RELATIVE_TIME_THRESHOLDS.MINUTE);
            return mins + (mins === 1 ? ' min ago' : ' mins ago');
        }
        if (diff < RELATIVE_TIME_THRESHOLDS.DAY) {
            const hrs = Math.floor(diff / RELATIVE_TIME_THRESHOLDS.HOUR);
            return hrs + (hrs === 1 ? ' hour ago' : ' hours ago');
        }

        const days = Math.floor(diff / RELATIVE_TIME_THRESHOLDS.DAY);
        if (days < 30) {
            return days + (days === 1 ? ' day ago' : ' days ago');
        }

        return date.toLocaleDateString();
    }
}

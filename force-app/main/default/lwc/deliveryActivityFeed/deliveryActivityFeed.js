/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Cross-item Activity Feed — unified view of comments, hours,
 *               and changes across all Work Items. Supports filtering, pagination,
 *               inline conversations, and WorkLog approval.
 * @author Cloud Nimbus LLC
 */
import { LightningElement, wire, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from 'lightning/uiRecordApi';
import { subscribe, unsubscribe, onError } from 'lightning/empApi';
import getActivityFeed from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryActivityFeedController.getActivityFeed';
import getConversations from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryActivityFeedController.getConversations';
import getPendingApprovals from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryActivityFeedController.getPendingApprovals';
import approveWorkLogs from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryActivityFeedController.approveWorkLogs';
import rejectWorkLogs from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryActivityFeedController.rejectWorkLogs';
import postCommentFromFeed from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryActivityFeedController.postCommentFromFeed';

const COMMENT_CHANNEL = '/event/%%%NAMESPACE_DOT%%%DeliveryComment__e';
const STAGE_CHANGE_CHANNEL = '/event/%%%NAMESPACE_DOT%%%DeliveryWorkItemChange__e';
// Fallback poll cadence — used only as a safety net if both empApi
// subscriptions silently disconnect. Real-time updates come from the events.
const FALLBACK_POLL_MS = 300000; // 5 minutes

const TAB_OPTIONS = [
    { label: 'All Activity', value: 'all', icon: 'utility:list' },
    { label: 'Conversations', value: 'conversations', icon: 'utility:comments' },
    { label: 'Hours', value: 'hours', icon: 'utility:clock' },
    { label: 'Changes', value: 'changes', icon: 'utility:change_record_type' }
];

const RELATIVE_TIME_THRESHOLDS = {
    MINUTE: 60000,
    HOUR: 3600000,
    DAY: 86400000
};

export default class DeliveryActivityFeed extends NavigationMixin(LightningElement) {
    tabOptions = TAB_OPTIONS;
    @track activeTab = 'all';
    @track currentPage = 0;
    @track events = [];
    @track displayGroups = [];
    @track conversations = [];
    @track pendingApprovals = [];
    @track totalCount = 0;
    @track hasMore = false;
    @track isLoadingMore = false;
    @track selectedApprovals = new Set();
    @track replyWorkItemId = null;
    @track replyBody = '';
    @track isSendingReply = false;
    @track isProcessingApproval = false;
    @track pendingCount = 0;

    _wiredFeed;
    _wiredConversations;
    _wiredApprovals;
    _pollingInterval;
    _commentSubscription;
    _stageSubscription;

    // ── Lifecycle ──────────────────────────────────────────────────────

    connectedCallback() {
        // Real-time updates: subscribe to both DeliveryComment__e (new chats)
        // and DeliveryWorkItemChange__e (stage transitions). Each event triggers
        // a refresh of the currently active tab. The 30s polling we used to do
        // is replaced by sub-second event push + a 5-min safety-net poll.
        subscribe(COMMENT_CHANNEL, -1, () => {
            if (document.visibilityState === 'visible') {
                this.refreshCurrentTab();
            }
        }).then(response => {
            this._commentSubscription = response;
        });
        subscribe(STAGE_CHANGE_CHANNEL, -1, () => {
            if (document.visibilityState === 'visible') {
                this.refreshCurrentTab();
            }
        }).then(response => {
            this._stageSubscription = response;
        });
        onError(error => {
            console.warn('[DeliveryActivityFeed] EMP API error:', JSON.stringify(error));
        });

        this._pollingInterval = setInterval(() => {
            if (document.visibilityState === 'visible') {
                this.refreshCurrentTab();
            }
        }, FALLBACK_POLL_MS);
    }

    disconnectedCallback() {
        if (this._commentSubscription) {
            unsubscribe(this._commentSubscription, () => {});
            this._commentSubscription = null;
        }
        if (this._stageSubscription) {
            unsubscribe(this._stageSubscription, () => {});
            this._stageSubscription = null;
        }
        if (this._pollingInterval) {
            clearInterval(this._pollingInterval);
        }
    }

    // ── Wire: All Activity / Hours / Changes ───────────────────────────

    @wire(getActivityFeed, {
        filterType: '$feedFilterType',
        pageOffset: '$feedPageOffset',
        networkEntityId: null,
        workItemId: null,
        startDate: null,
        endDate: null
    })
    wiredFeed(result) {
        this._wiredFeed = result;
        const { data, error } = result;
        if (data) {
            const newEvents = data.events || [];
            if (this.currentPage === 0) {
                this.events = [...newEvents];
            } else {
                this.events = [...this.events, ...newEvents];
            }
            this.totalCount = data.totalCount || 0;
            this.hasMore = data.hasMore || false;
            this.isLoadingMore = false;
            this.buildDisplayGroups();
        } else if (error) {
            this.events = [];
            this.displayGroups = [];
            this.isLoadingMore = false;
        }
    }

    // Reactive properties for wire — only fire for activity/hours/changes tabs
    get feedFilterType() {
        if (this.activeTab === 'conversations') return null;
        return this.activeTab;
    }

    get feedPageOffset() {
        if (this.activeTab === 'conversations') return null;
        return this.currentPage;
    }

    // ── Wire: Conversations ────────────────────────────────────────────

    @wire(getConversations, {
        pageOffset: '$convoPageOffset',
        networkEntityId: null
    })
    wiredConversations(result) {
        this._wiredConversations = result;
        const { data, error } = result;
        if (data) {
            this.conversations = data.map(thread => ({
                ...thread,
                relativeTime: this.getRelativeTime(new Date(thread.latestTimestamp)),
                isExpanded: false,
                comments: (thread.comments || []).map(c => ({
                    ...c,
                    relativeTime: this.getRelativeTime(new Date(c.timestamp))
                }))
            }));
        } else if (error) {
            this.conversations = [];
        }
    }

    get convoPageOffset() {
        return this.activeTab === 'conversations' ? 0 : null;
    }

    // ── Wire: Pending Approvals ────────────────────────────────────────

    @wire(getPendingApprovals, {
        pageOffset: 0,
        networkEntityId: null
    })
    wiredApprovals(result) {
        this._wiredApprovals = result;
        const { data, error } = result;
        if (data) {
            this.pendingApprovals = (data.approvals || []).map(a => ({
                ...a,
                isSelected: false,
                relativeTime: this.getRelativeTime(new Date(a.timestamp)),
                formattedDate: a.workDate ? new Date(a.workDate).toLocaleDateString() : ''
            }));
            this.pendingCount = data.totalCount || 0;
        } else if (error) {
            this.pendingApprovals = [];
            this.pendingCount = 0;
        }
    }

    // ── Computed getters ───────────────────────────────────────────────

    get computedTabs() {
        return this.tabOptions.map(t => ({
            ...t,
            cssClass: `af-tab${t.value === this.activeTab ? ' af-tab--active' : ''}`,
            badgeCount: t.value === 'hours' && this.pendingCount > 0 ? this.pendingCount : null,
            hasBadge: t.value === 'hours' && this.pendingCount > 0
        }));
    }

    get isAllTab() { return this.activeTab === 'all'; }
    get isConversationsTab() { return this.activeTab === 'conversations'; }
    get isHoursTab() { return this.activeTab === 'hours'; }
    get isChangesTab() { return this.activeTab === 'changes'; }

    get hasEvents() { return this.displayGroups.length > 0; }
    get hasConversations() { return this.conversations.length > 0; }
    get hasPendingApprovals() { return this.pendingApprovals.length > 0; }
    get hasSelectedApprovals() { return this.selectedApprovals.size > 0; }

    get selectedCount() { return this.selectedApprovals.size; }

    get showFeed() { return this.isAllTab || this.isHoursTab || this.isChangesTab; }
    get showEmpty() { return this.showFeed && !this.hasEvents && this._wiredFeed && (this._wiredFeed.data || this._wiredFeed.error); }
    get showConvoEmpty() { return this.isConversationsTab && !this.hasConversations && this._wiredConversations && (this._wiredConversations.data || this._wiredConversations.error); }

    get isLoading() {
        if (this.showFeed) {
            return !this._wiredFeed || (!this._wiredFeed.data && !this._wiredFeed.error);
        }
        if (this.isConversationsTab) {
            return !this._wiredConversations || (!this._wiredConversations.data && !this._wiredConversations.error);
        }
        return false;
    }

    get showLoadMore() { return this.showFeed && this.hasMore && this.hasEvents; }
    get loadMoreLabel() { return this.isLoadingMore ? 'Loading...' : 'Load More'; }

    // ── Tab Handling ───────────────────────────────────────────────────

    handleTabClick(event) {
        const newTab = event.currentTarget.dataset.value;
        if (newTab === this.activeTab) return;
        this.activeTab = newTab;
        this.currentPage = 0;
        this.events = [];
        this.displayGroups = [];
        this.hasMore = false;
        this.selectedApprovals = new Set();
    }

    // ── Pagination ─────────────────────────────────────────────────────

    handleLoadMore() {
        if (this.isLoadingMore) return;
        this.isLoadingMore = true;
        this.currentPage = this.currentPage + 1;
    }

    // ── Refresh ────────────────────────────────────────────────────────

    handleRefresh() {
        this.refreshCurrentTab();
    }

    refreshCurrentTab() {
        if (this.showFeed && this._wiredFeed) {
            this.currentPage = 0;
            this.events = [];
            this.displayGroups = [];
            refreshApex(this._wiredFeed);
        }
        if (this.isConversationsTab && this._wiredConversations) {
            refreshApex(this._wiredConversations);
        }
        if (this._wiredApprovals) {
            refreshApex(this._wiredApprovals);
        }
    }

    // ── Work Item Navigation ───────────────────────────────────────────

    handleWorkItemClick(event) {
        const workItemId = event.currentTarget.dataset.id;
        if (!workItemId) return;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: workItemId,
                actionName: 'view'
            }
        });
    }

    // ── Conversation Toggle + Reply ────────────────────────────────────

    handleToggleThread(event) {
        const workItemId = event.currentTarget.dataset.id;
        this.conversations = this.conversations.map(t => {
            if (t.workItemId === workItemId) {
                return { ...t, isExpanded: !t.isExpanded };
            }
            return t;
        });
    }

    handleReplyClick(event) {
        this.replyWorkItemId = event.currentTarget.dataset.id;
        this.replyBody = '';
    }

    handleReplyInput(event) {
        this.replyBody = event.target.value;
    }

    handleReplyCancel() {
        this.replyWorkItemId = null;
        this.replyBody = '';
    }

    async handleReplySend(event) {
        const targetId = event.currentTarget.dataset.id;
        if (!this.replyBody || !targetId) return;
        this.isSendingReply = true;
        try {
            await postCommentFromFeed({
                workItemId: targetId,
                body: this.replyBody
            });
            this.dispatchEvent(new ShowToastEvent({
                title: 'Reply Sent',
                message: 'Your comment has been posted.',
                variant: 'success'
            }));
            this.replyWorkItemId = null;
            this.replyBody = '';
            if (this._wiredConversations) {
                refreshApex(this._wiredConversations);
            }
        } catch (error) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error',
                message: error.body ? error.body.message : error.message,
                variant: 'error'
            }));
        } finally {
            this.isSendingReply = false;
        }
    }

    // ── Approval Selection + Actions ───────────────────────────────────

    handleApprovalSelect(event) {
        const logId = event.currentTarget.dataset.id;
        const updated = new Set(this.selectedApprovals);
        if (updated.has(logId)) {
            updated.delete(logId);
        } else {
            updated.add(logId);
        }
        this.selectedApprovals = updated;
        this.pendingApprovals = this.pendingApprovals.map(a => ({
            ...a,
            isSelected: updated.has(a.id)
        }));
    }

    handleSelectAll() {
        const allIds = new Set(this.pendingApprovals.map(a => a.id));
        this.selectedApprovals = allIds;
        this.pendingApprovals = this.pendingApprovals.map(a => ({
            ...a,
            isSelected: true
        }));
    }

    handleDeselectAll() {
        this.selectedApprovals = new Set();
        this.pendingApprovals = this.pendingApprovals.map(a => ({
            ...a,
            isSelected: false
        }));
    }

    async handleBatchApprove() {
        if (this.selectedApprovals.size === 0) return;
        this.isProcessingApproval = true;
        try {
            await approveWorkLogs({ workLogIds: [...this.selectedApprovals] });
            this.dispatchEvent(new ShowToastEvent({
                title: 'Approved',
                message: `${this.selectedApprovals.size} work log(s) approved and queued for sync.`,
                variant: 'success'
            }));
            this.selectedApprovals = new Set();
            this.refreshCurrentTab();
        } catch (error) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error',
                message: error.body ? error.body.message : error.message,
                variant: 'error'
            }));
        } finally {
            this.isProcessingApproval = false;
        }
    }

    async handleBatchReject() {
        if (this.selectedApprovals.size === 0) return;
        this.isProcessingApproval = true;
        try {
            await rejectWorkLogs({ workLogIds: [...this.selectedApprovals] });
            this.dispatchEvent(new ShowToastEvent({
                title: 'Rejected',
                message: `${this.selectedApprovals.size} work log(s) rejected.`,
                variant: 'warning'
            }));
            this.selectedApprovals = new Set();
            this.refreshCurrentTab();
        } catch (error) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error',
                message: error.body ? error.body.message : error.message,
                variant: 'error'
            }));
        } finally {
            this.isProcessingApproval = false;
        }
    }

    // ── Date Grouping ──────────────────────────────────────────────────

    buildDisplayGroups() {
        const groups = new Map();
        const today = new Date();
        today.setHours(0, 0, 0, 0);
        const yesterday = new Date(today);
        yesterday.setDate(yesterday.getDate() - 1);

        for (const ev of this.events) {
            const ts = new Date(ev.timestamp);
            const dateKey = `${ts.getFullYear()}-${String(ts.getMonth() + 1).padStart(2, '0')}-${String(ts.getDate()).padStart(2, '0')}`;

            const evDate = new Date(ts);
            evDate.setHours(0, 0, 0, 0);

            let dateLabel;
            if (evDate.getTime() === today.getTime()) {
                dateLabel = 'Today';
            } else if (evDate.getTime() === yesterday.getTime()) {
                dateLabel = 'Yesterday';
            } else {
                dateLabel = ts.toLocaleDateString(undefined, {
                    weekday: 'short', year: 'numeric', month: 'short', day: 'numeric'
                });
            }

            if (!groups.has(dateKey)) {
                groups.set(dateKey, { dateKey, dateLabel, events: [] });
            }

            groups.get(dateKey).events.push({
                ...ev,
                relativeTime: this.getRelativeTime(ts),
                formattedTime: ts.toLocaleTimeString(undefined, { hour: '2-digit', minute: '2-digit' }),
                hasDetail: !!ev.detail,
                hasWorkItem: !!ev.workItemName,
                isComment: ev.type === 'comment',
                isWorklog: ev.type === 'worklog',
                isStageChange: ev.type === 'stage_change',
                isFieldChange: ev.type === 'field_change',
                isDraft: ev.status === 'Draft',
                typeClass: 'af-event-icon af-event-icon--' + ev.type
            });
        }

        this.displayGroups = Array.from(groups.values());
    }

    // ── Relative Time ──────────────────────────────────────────────────

    getRelativeTime(date) {
        const now = Date.now();
        const diff = now - date.getTime();
        if (diff < RELATIVE_TIME_THRESHOLDS.MINUTE) return 'Just now';
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

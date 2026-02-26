/**
 * @author Cloud Nimbus LLC
 */
import { LightningElement, api, wire, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { refreshApex } from '@salesforce/apex';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import getClientDashboard from '@salesforce/apex/DeliveryHubDashboardController.getClientDashboard';
import getWorkflowConfig from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryWorkflowConfigService.getWorkflowConfig';
import USER_ID from '@salesforce/user/Id';
import FIRST_NAME_FIELD from '@salesforce/schema/User.FirstName';

// Fallback phase order used when CMT config is not yet loaded
const FALLBACK_PHASE_ORDER = ['Planning', 'Approval', 'Development', 'Testing', 'UAT', 'Deployment'];

const PHASE_LIST_VIEWS = {
    'Planning':    'WorkItems_Planning',
    'Approval':    'WorkItems_Approval',
    'Development': 'WorkItems_Development',
    'Testing':     'WorkItems_Testing',
    'UAT':         'WorkItems_UAT',
    'Deployment':  'WorkItems_Deployment'
};

// Maps phase name → badge CSS modifier (for attention work item styling)
const PHASE_BADGE_SUFFIX = {
    'Approval':   'approval',
    'UAT':        'uat',
    'Deployment': 'signoff'
};

export default class DeliveryClientDashboard extends NavigationMixin(LightningElement) {
    @api hideAttentionSection = false;
    @api hideInFlightSection = false;
    @api hideRecentSection = false;

    @api hideThisWeekSection = false;

    @track attentionWorkItems = [];
    @track phases = [];
    @track recentWorkItems = [];
    @track thisWeek = null;
    @track isLoading = true;
    @track announcements = [];
    @track inFlightCollapsed = false;
    @track recentCollapsed = false;
    @track thisWeekCollapsed = false;
    @track workflowConfig = null;

    _wiredResult;
    _pendingData = null; // holds dashboard data until config is ready

    @wire(getRecord, { recordId: USER_ID, fields: [FIRST_NAME_FIELD] })
    wiredUser;

    @wire(getWorkflowConfig, { workflowTypeName: 'Software_Delivery' })
    wiredConfig({ data, error }) {
        if (data) {
            this.workflowConfig = data;
            // If dashboard data arrived before config, process it now
            if (this._pendingData) {
                this._processData(this._pendingData);
                this._pendingData = null;
            }
        } else if (error) {
            console.error('[DeliveryClientDashboard] getWorkflowConfig error:', error);
        }
    }

    @wire(getClientDashboard)
    wiredDashboard(result) {
        this._wiredResult = result;
        const { data, error } = result;
        if (data) {
            if (this.workflowConfig) {
                this._processData(data);
            } else {
                this._pendingData = data; // wait for config
            }
            this.isLoading = false;
        } else if (error) {
            console.error('Error loading client dashboard', error);
            this.isLoading = false;
        }
    }

    // CMT-driven badge class for a given stage
    _getBadgeClass(stage) {
        const stageData = (this.workflowConfig?.stages || []).find(s => s.apiValue === stage);
        const phase = stageData?.phase;
        const suffix = PHASE_BADGE_SUFFIX[phase] || null;
        const base = 'slds-badge slds-badge_lightest stage-badge';
        return suffix ? `${base} stage-badge--${suffix}` : base;
    }

    // CMT-driven phase order (distinct non-terminal phases in CMT sort order)
    get _phaseOrder() {
        if (!this.workflowConfig?.stages) return FALLBACK_PHASE_ORDER;
        const seen = new Set();
        const order = [];
        this.workflowConfig.stages.forEach(s => {
            if (!s.isTerminal && s.phase && !seen.has(s.phase)) {
                seen.add(s.phase);
                order.push(s.phase);
            }
        });
        return order.length > 0 ? order : FALLBACK_PHASE_ORDER;
    }

    _processData(data) {
        // Attention work items
        this.attentionWorkItems = (data.attentionWorkItems || []).map(t => ({
            id: t.id,
            name: t.name,
            title: t.title || null,
            stage: t.stage,
            badgeClass: this._getBadgeClass(t.stage)
        }));

        // Phase counts
        const phaseCounts = {};
        (data.phases || []).forEach(p => {
            phaseCounts[p.label] = p.count || 0;
        });

        const largePhase = !this.hasAttentionItems;
        this.phases = this._phaseOrder.map(label => {
            const count = phaseCounts[label] || 0;
            return {
                label,
                count,
                tileClass: [
                    'phase-tile phase-tile--btn slds-box slds-box_x-small slds-text-align_center',
                    count > 0 ? 'phase-tile--active' : 'phase-tile--empty',
                    largePhase ? 'phase-tile--large' : ''
                ].join(' ').trim(),
                colClass: largePhase ? 'slds-col slds-size_1-of-2 slds-m-bottom_x-small' : 'slds-col slds-size_1-of-3 slds-m-bottom_x-small'
            };
        });

        // Recent work items
        this.recentWorkItems = (data.recentWorkItems || []).map(t => ({
            id: t.id,
            name: t.name,
            title: t.title || null,
            stage: t.stage,
            lastModified: t.lastModified
        }));

        // Vendor announcements (one per active vendor with a message)
        this.announcements = (data.announcements || []).map((text, idx) => ({
            key: idx,
            text
        }));

        // This Week metrics
        if (data.thisWeek) {
            this.thisWeek = {
                completed: data.thisWeek.completed || 0,
                moved: data.thisWeek.moved || 0,
                hoursLogged: data.thisWeek.hoursLogged || 0,
                blocked: data.thisWeek.blocked || 0
            };
        }
    }

    // ── Derived getters ──

    get hasAttentionItems() {
        return this.attentionWorkItems && this.attentionWorkItems.length > 0;
    }

    get hasRecentItems() {
        return this.recentWorkItems && this.recentWorkItems.length > 0;
    }

    get hasAnnouncements() {
        return this.announcements && this.announcements.length > 0;
    }

    get attentionCount() {
        return this.attentionWorkItems ? this.attentionWorkItems.length : 0;
    }

    get greeting() {
        const hour = new Date().getHours();
        if (hour < 12) return 'Good morning';
        if (hour < 17) return 'Good afternoon';
        return 'Good evening';
    }

    get firstName() {
        return getFieldValue(this.wiredUser && this.wiredUser.data, FIRST_NAME_FIELD) || '';
    }

    get greetingLine() {
        const name = this.firstName ? `, ${this.firstName}` : '';
        if (this.isLoading) return `${this.greeting}${name}`;
        if (this.hasAttentionItems) {
            const n = this.attentionCount;
            return `${this.greeting}${name} \u2014 ${n} item${n === 1 ? '' : 's'} need${n === 1 ? 's' : ''} your attention`;
        }
        return `${this.greeting}${name} \u2014 You\u2019re all caught up`;
    }

    get greetingSubtext() {
        if (this.hasAttentionItems) {
            return 'Review the work items below and take action to keep your project moving.';
        }
        return 'Nothing is waiting on you right now. Check back after your team makes progress.';
    }

    get greetingClass() {
        return this.hasAttentionItems ? 'cd-greeting cd-greeting--attention' : 'cd-greeting cd-greeting--clean';
    }

    get hasThisWeek() {
        return this.thisWeek != null;
    }

    get inFlightChevronIcon() { return this.inFlightCollapsed ? 'utility:chevronright' : 'utility:chevrondown'; }
    get recentChevronIcon()   { return this.recentCollapsed   ? 'utility:chevronright' : 'utility:chevrondown'; }
    get thisWeekChevronIcon() { return this.thisWeekCollapsed  ? 'utility:chevronright' : 'utility:chevrondown'; }

    // ── Handlers ──

    toggleInFlight()  { this.inFlightCollapsed  = !this.inFlightCollapsed;  }
    toggleRecent()    { this.recentCollapsed    = !this.recentCollapsed;   }
    toggleThisWeek()  { this.thisWeekCollapsed  = !this.thisWeekCollapsed; }

    handleWorkItemClick(event) {
        const recordId = event.currentTarget.dataset.id;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: recordId,
                objectApiName: 'WorkItem__c',
                actionName: 'view'
            }
        });
    }

    handlePhaseClick(event) {
        const phase = event.currentTarget.dataset.phase;
        const listView = PHASE_LIST_VIEWS[phase];
        if (!listView) return;
        this[NavigationMixin.Navigate]({
            type: 'standard__listView',
            attributes: { objectApiName: 'WorkItem__c', listViewApiName: listView }
        });
    }

    handleRefresh() {
        this.isLoading = true;
        refreshApex(this._wiredResult).then(() => {
            this.isLoading = false;
        });
    }
}

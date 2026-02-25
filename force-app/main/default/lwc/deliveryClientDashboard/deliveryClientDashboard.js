import { LightningElement, wire, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { refreshApex } from '@salesforce/apex';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import getClientDashboard from '@salesforce/apex/DeliveryHubDashboardController.getClientDashboard';
import USER_ID from '@salesforce/user/Id';
import FIRST_NAME_FIELD from '@salesforce/schema/User.FirstName';

const PHASE_ORDER = ['Planning', 'Approval', 'Development', 'Testing', 'UAT', 'Deployment'];

const STAGE_BADGE_CLASSES = {
    'In Client Approval':       'slds-badge slds-badge_lightest stage-badge stage-badge--approval',
    'Ready for Client Approval':'slds-badge slds-badge_lightest stage-badge stage-badge--approval',
    'Ready for Client UAT':     'slds-badge slds-badge_lightest stage-badge stage-badge--uat',
    'In Client UAT':            'slds-badge slds-badge_lightest stage-badge stage-badge--uat',
    'Ready for UAT Sign-off':   'slds-badge slds-badge_lightest stage-badge stage-badge--signoff'
};

export default class DeliveryClientDashboard extends NavigationMixin(LightningElement) {
    @track attentionTickets = [];
    @track phases = [];
    @track recentTickets = [];
    @track isLoading = true;
    @track announcements = [];

    _wiredResult;

    @wire(getRecord, { recordId: USER_ID, fields: [FIRST_NAME_FIELD] })
    wiredUser;

    @wire(getClientDashboard)
    wiredDashboard(result) {
        this._wiredResult = result;
        const { data, error } = result;
        if (data) {
            this._processData(data);
            this.isLoading = false;
        } else if (error) {
            console.error('Error loading client dashboard', error);
            this.isLoading = false;
        }
    }

    _processData(data) {
        // Attention tickets
        this.attentionTickets = (data.attentionTickets || []).map(t => ({
            id: t.id,
            name: t.name,
            title: t.title || null,
            stage: t.stage,
            badgeClass: STAGE_BADGE_CLASSES[t.stage] || 'slds-badge slds-badge_lightest stage-badge'
        }));

        // Phase counts
        const phaseCounts = {};
        (data.phases || []).forEach(p => {
            phaseCounts[p.label] = p.count || 0;
        });

        const largePhase = !this.hasAttentionItems;
        this.phases = PHASE_ORDER.map(label => {
            const count = phaseCounts[label] || 0;
            return {
                label,
                count,
                tileClass: [
                    'phase-tile slds-box slds-box_x-small slds-text-align_center',
                    count > 0 ? 'phase-tile--active' : 'phase-tile--empty',
                    largePhase ? 'phase-tile--large' : ''
                ].join(' ').trim(),
                colClass: largePhase ? 'slds-col slds-size_1-of-2 slds-m-bottom_x-small' : 'slds-col slds-size_1-of-3 slds-m-bottom_x-small'
            };
        });

        // Recent tickets
        this.recentTickets = (data.recentTickets || []).map(t => ({
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
    }

    // ── Derived getters ──

    get hasAttentionItems() {
        return this.attentionTickets && this.attentionTickets.length > 0;
    }

    get hasRecentItems() {
        return this.recentTickets && this.recentTickets.length > 0;
    }

    get hasAnnouncements() {
        return this.announcements && this.announcements.length > 0;
    }

    get attentionCount() {
        return this.attentionTickets ? this.attentionTickets.length : 0;
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
            return 'Review the tickets below and take action to keep your project moving.';
        }
        return 'Nothing is waiting on you right now. Check back after your team makes progress.';
    }

    get greetingClass() {
        return this.hasAttentionItems ? 'cd-greeting cd-greeting--attention' : 'cd-greeting cd-greeting--clean';
    }

    // ── Handlers ──

    handleTicketClick(event) {
        const recordId = event.currentTarget.dataset.id;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: recordId,
                objectApiName: 'Ticket__c',
                actionName: 'view'
            }
        });
    }

    handleRefresh() {
        this.isLoading = true;
        refreshApex(this._wiredResult).then(() => {
            this.isLoading = false;
        });
    }
}

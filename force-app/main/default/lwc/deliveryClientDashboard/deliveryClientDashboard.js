import { LightningElement, wire, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { refreshApex } from '@salesforce/apex';
import getClientDashboard from '@salesforce/apex/DeliveryHubDashboardController.getClientDashboard';

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

    _wiredResult;

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

        this.phases = PHASE_ORDER.map(label => {
            const count = phaseCounts[label] || 0;
            return {
                label,
                count,
                tileClass: [
                    'phase-tile slds-box slds-box_x-small slds-text-align_center',
                    count > 0 ? 'phase-tile--active' : 'phase-tile--empty'
                ].join(' ')
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
    }

    get hasAttentionItems() {
        return this.attentionTickets && this.attentionTickets.length > 0;
    }

    get hasRecentItems() {
        return this.recentTickets && this.recentTickets.length > 0;
    }

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

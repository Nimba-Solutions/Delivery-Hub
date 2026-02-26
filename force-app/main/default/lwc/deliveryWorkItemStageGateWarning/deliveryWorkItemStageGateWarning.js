/**
 * @author Cloud Nimbus LLC
 */
import { LightningElement, api, wire, track } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';

// Fields to monitor
import STAGE_FIELD from '@salesforce/schema/WorkItem__c.StageNamePk__c';
import DEV_FIELD from '@salesforce/schema/WorkItem__c.Developer__c';
import ESTIMATED_HOURS_FIELD from '@salesforce/schema/WorkItem__c.EstimatedHoursNumber__c';
import PRE_APPROVED_HOURS_FIELD from '@salesforce/schema/WorkItem__c.ClientPreApprovedHoursNumber__c';

const FIELDS = [STAGE_FIELD, DEV_FIELD, ESTIMATED_HOURS_FIELD, PRE_APPROVED_HOURS_FIELD];

export default class DeliveryWorkItemStageGateWarning extends LightningElement {
    @api recordId;
    @track message = '';
    @track type = ''; // 'warning', 'error', 'success' (for fast track), 'info'
    @track showAlert = false;
    
    isDismissed = false;

    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    wiredTicket({ error, data }) {
        if (data) {
            this.evaluateGates(data);
        } else if (error) {
            console.error('Error fetching ticket data', error);
        }
    }

    evaluateGates(data) {
        if (this.isDismissed) return;

        const stage = getFieldValue(data, STAGE_FIELD);
        const dev = getFieldValue(data, DEV_FIELD);
        const estimate = getFieldValue(data, ESTIMATED_HOURS_FIELD);
        const preApproved = getFieldValue(data, PRE_APPROVED_HOURS_FIELD);

        this.resetAlert();

        // --- GATE 1: SIZING & PROPOSAL (Missing Estimate) ---
        const sizingStages = ['Drafting Proposal', 'Ready for Prioritization', 'Proposal Requested'];
        if (sizingStages.includes(stage)) {
            if (estimate == null) {
                this.setAlert('warning', 'Ticket requires an Hours Estimate before moving forward.');
                return;
            }
        }

        // --- GATE 2: THE "FAST TRACK" CHECK (Budget vs Estimate) ---
        if (stage === 'Ready for Client Approval' || stage === 'Proposal Requested') {
            if (estimate != null && preApproved != null) {
                if (estimate <= preApproved) {
                    // Logic: Estimate is within budget -> Green Light
                    this.setAlert('success', `🚀 FAST TRACK AVAILABLE: Estimate (${estimate}h) is within Pre-Approved Budget (${preApproved}h). You may skip Approval and move to "Ready for Development".`);
                    return;
                } else {
                    // Logic: Over budget -> Red Light
                    this.setAlert('error', `🛑 OVER BUDGET: Estimate (${estimate}h) exceeds Pre-Approved Budget (${preApproved}h). Explicit Client Approval is required.`);
                    return;
                }
            } else if (estimate != null && preApproved == null) {
                 this.setAlert('info', 'No Pre-Approved budget found. Standard Approval process required.');
                 return;
            }
        }

        // --- GATE 3: DEVELOPMENT READINESS (Hard Stop) ---
        const devStages = ['Ready for Development', 'In Development'];
        if (devStages.includes(stage)) {
            let errors = [];
            if (!estimate) errors.push('Missing Hours Estimate');
            if (!dev) errors.push('No Developer Assigned');
            
            if (errors.length > 0) {
                this.setAlert('error', `Cannot start Development: ${errors.join(' & ')}.`);
                return;
            }
        }
    }

    setAlert(type, msg) {
        this.type = type;
        this.message = msg;
        this.showAlert = true;
    }

    resetAlert() {
        this.showAlert = false;
        this.message = '';
        this.type = '';
    }

    handleDismiss() {
        this.showAlert = false;
        this.isDismissed = true;
    }

    get alertClass() {
        switch(this.type) {
            case 'error': return 'slds-notify slds-notify_alert slds-theme_error';
            case 'success': return 'slds-notify slds-notify_alert slds-theme_success';
            case 'warning': return 'slds-notify slds-notify_alert slds-theme_warning';
            default: return 'slds-notify slds-notify_alert slds-theme_info';
        }
    }

    get iconName() {
        switch(this.type) {
            case 'error': return 'utility:error';
            case 'success': return 'utility:success';
            default: return 'utility:warning';
        }
    }
}
import { LightningElement, api, wire, track } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import sendRequestToVendor from '@salesforce/apex/DeliveryHubSender.sendRequestToVendor';
import checkRequestStatus from '@salesforce/apex/DeliveryHubSender.checkRequestStatus';

// Update these to match your EXACT API Names
import STATUS_FIELD from '@salesforce/schema/Request__c.StatusPk__c';
import REMOTE_ID_FIELD from '@salesforce/schema/Request__c.RemoteTicketIdTxt__c';

const FIELDS = [STATUS_FIELD, REMOTE_ID_FIELD];

export default class ManageDeliveryRequest extends LightningElement {
    @api recordId;
    @track isLoading = false;
    
    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    request;

    // Getters for UI state
    get requestStatus() {
        return getFieldValue(this.request.data, STATUS_FIELD);
    }

    get remoteId() {
        return getFieldValue(this.request.data, REMOTE_ID_FIELD);
    }

    get isLinked() {
        return (this.remoteId != null && this.remoteId !== '');
    }

    get isNotLinked() {
        return !this.isLinked;
    }

    // Handlers
    handleSend() {
        this.isLoading = true;
        sendRequestToVendor({ requestId: this.recordId })
            // FIX: Removed unused 'result' parameter and used empty parenthesis ()
            .then(() => {
                this.showToast('Success', 'Offer sent successfully!', 'success');
                // Refresh data (handled automatically by wire in most cases, or use notifyRecordUpdate)
            })
            .catch(error => {
                this.showToast('Error', error.body ? error.body.message : error.message, 'error');
            })
            .finally(() => { this.isLoading = false; });
    }

    handleCheckStatus() {
        this.isLoading = true;
        checkRequestStatus({ requestId: this.recordId })
            .then(result => {
                this.showToast('Status Update', result, 'info');
            })
            .catch(error => {
                this.showToast('Error', error.body ? error.body.message : error.message, 'error');
            })
            .finally(() => { this.isLoading = false; });
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
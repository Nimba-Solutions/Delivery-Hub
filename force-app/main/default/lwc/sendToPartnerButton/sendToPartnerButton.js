import { LightningElement, api, wire, track } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import USER_EMAIL_FIELD from '@salesforce/schema/User.Email';
import USER_ID from '@salesforce/user/Id';
import sendTicketToPartner from '@salesforce/apex/DeliveryHubSender.sendTicketToPartner';

export default class SendToPartnerButton extends LightningElement {
    @api recordId;
    @track isModalOpen = false;
    @track isSending = false;
    @track userEmail;

    // FIX: Removed 'error' from destructuring since it was unused
    @wire(getRecord, { recordId: USER_ID, fields: [USER_EMAIL_FIELD] })
    wireUser({ data }) {
        if (data) {
            this.userEmail = getFieldValue(data, USER_EMAIL_FIELD);
        }
    }

    get sendButtonLabel() {
        return this.isSending ? 'Sending...' : 'Confirm & Send';
    }

    handleOpenModal() { this.isModalOpen = true; }
    handleCloseModal() { this.isModalOpen = false; }

    handleEmailChange(event) {
        this.userEmail = event.target.value;
    }

    handleSend() {
        if (!this.userEmail) {
            this.showToast('Error', 'Please enter a contact email.', 'error');
            return;
        }

        this.isSending = true;

        sendTicketToPartner({ 
            ticketId: this.recordId, 
            targetUrl: '', 
            senderEmail: this.userEmail 
        })
        .then(() => {
            this.showToast('Success', 'Ticket sent! The partner will contact you shortly.', 'success');
            this.isModalOpen = false;
        })
        .catch(error => {
            let message = error.body ? error.body.message : error.message;
            this.showToast('Error', 'Failed to send: ' + message, 'error');
        })
        .finally(() => {
            this.isSending = false;
        });
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}

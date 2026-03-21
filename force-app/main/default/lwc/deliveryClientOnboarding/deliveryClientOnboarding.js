/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Client onboarding form. Collects client details, creates
 *               a NetworkEntity, and generates a Client Agreement document.
 * @author Cloud Nimbus LLC
 */
import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import onboardClient from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryClientOnboardingController.onboardClient';
import sendDocumentEmail from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryDocumentController.sendDocumentEmail';

export default class DeliveryClientOnboarding extends LightningElement {
    @track clientName = '';
    @track contactEmail = '';
    @track hourlyRate = null;
    @track contactPhone = '';
    @track address = '';

    @track isProcessing = false;
    @track showForm = false;
    @track showResult = false;
    @track result = null;
    @track isSending = false;

    get hasResult() {
        return this.result != null;
    }

    get showEmptyState() {
        return !this.showForm && !this.showResult;
    }

    get toggleButtonLabel() {
        return this.showForm ? 'Cancel' : 'New Client';
    }

    get toggleButtonIcon() {
        return this.showForm ? 'utility:close' : 'utility:add';
    }

    get toggleButtonVariant() {
        return this.showForm ? 'neutral' : 'brand';
    }

    handleToggleForm() {
        this.showForm = !this.showForm;
        this.showResult = false;
        this.result = null;
    }

    handleNameChange(event) {
        this.clientName = event.target.value;
    }

    handleEmailChange(event) {
        this.contactEmail = event.target.value;
    }

    handleRateChange(event) {
        this.hourlyRate = event.target.value;
    }

    handlePhoneChange(event) {
        this.contactPhone = event.target.value;
    }

    handleAddressChange(event) {
        this.address = event.target.value;
    }

    async handleSubmit() {
        // Validate required fields
        const allValid = [...this.template.querySelectorAll('lightning-input')]
            .reduce((valid, input) => {
                input.reportValidity();
                return valid && input.checkValidity();
            }, true);

        if (!allValid) {
            return;
        }

        this.isProcessing = true;
        try {
            this.result = await onboardClient({
                clientName: this.clientName,
                contactEmail: this.contactEmail,
                hourlyRate: parseFloat(this.hourlyRate),
                contactPhone: this.contactPhone || null,
                address: this.address || null
            });

            this.showForm = false;
            this.showResult = true;

            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Client Onboarded',
                    message: `${this.clientName} created with agreement ${this.result.documentName}`,
                    variant: 'success'
                })
            );
        } catch (error) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: error.body?.message || error.message || 'An error occurred',
                    variant: 'error'
                })
            );
        } finally {
            this.isProcessing = false;
        }
    }

    async handleSendAgreement() {
        if (!this.result?.documentId) {
            return;
        }

        this.isSending = true;
        try {
            const emailResult = await sendDocumentEmail({
                documentId: this.result.documentId,
                recipientEmail: this.contactEmail
            });

            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Agreement Sent',
                    message: `Agreement emailed to ${emailResult.recipientEmail}`,
                    variant: 'success'
                })
            );
        } catch (error) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Email Error',
                    message: error.body?.message || error.message || 'Failed to send email',
                    variant: 'error'
                })
            );
        } finally {
            this.isSending = false;
        }
    }

    handleReset() {
        this.clientName = '';
        this.contactEmail = '';
        this.hourlyRate = null;
        this.contactPhone = '';
        this.address = '';
        this.result = null;
        this.showResult = false;
        this.showForm = true;
    }
}

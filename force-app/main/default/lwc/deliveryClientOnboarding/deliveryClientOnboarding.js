/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Client onboarding form. Collects client details, creates
 *               a NetworkEntity, and generates a Client Agreement document.
 * @author Cloud Nimbus LLC
 */
/* eslint-disable no-ternary, sort-keys, new-cap */
import { LightningElement, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import onboardClient from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryClientOnboardingController.onboardClient';
import sendDocumentEmail from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryDocumentController.sendDocumentEmail';

export default class DeliveryClientOnboarding extends NavigationMixin(LightningElement) {
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
        return this.result !== null;
    }

    get showEmptyState() {
        return !this.showForm && !this.showResult;
    }

    get toggleButtonLabel() {
        if (this.showForm) {
            return 'Cancel';
        }
        return 'New Client';
    }

    get toggleButtonIcon() {
        if (this.showForm) {
            return 'utility:close';
        }
        return 'utility:add';
    }

    get toggleButtonVariant() {
        if (this.showForm) {
            return 'neutral';
        }
        return 'brand';
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
            await this.performOnboarding();
        } catch (error) {
            this.showError('Error', error);
        } finally {
            this.isProcessing = false;
        }
    }

    async performOnboarding() {
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
                message: `${this.clientName} created with agreement ${this.result.documentName}`,
                title: 'Client Onboarded',
                variant: 'success'
            })
        );
    }

    handleViewAgreement() {
        if (!this.result || !this.result.documentId) {
            return;
        }
        this[NavigationMixin.Navigate]({
            attributes: {
                actionName: 'view',
                recordId: this.result.documentId
            },
            type: 'standard__recordPage'
        });
    }

    async handleSendAgreement() {
        if (!this.result || !this.result.documentId) {
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
                    message: `Agreement emailed to ${emailResult.recipientEmail}`,
                    title: 'Agreement Sent',
                    variant: 'success'
                })
            );
        } catch (error) {
            this.showError('Email Error', error);
        } finally {
            this.isSending = false;
        }
    }

    showError(title, error) {
        const msg = (error.body && error.body.message) || error.message || 'An error occurred';
        this.dispatchEvent(
            new ShowToastEvent({
                message: msg,
                title,
                variant: 'error'
            })
        );
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

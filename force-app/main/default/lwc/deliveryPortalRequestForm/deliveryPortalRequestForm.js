/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Portal request submission form for Experience Cloud.
 * Allows external users to submit new work item requests.
 * @author Cloud Nimbus LLC
 */
import { LightningElement, api, track } from 'lwc';
import submitPortalRequest from '@salesforce/apex/DeliveryPortalController.submitPortalRequest';

export default class DeliveryPortalRequestForm extends LightningElement {
    @api networkEntityId;

    @track title = '';
    @track description = '';
    @track priority = 'Medium';
    @track requestType = 'Internal';
    @track isSubmitting = false;
    @track submitSuccess = false;
    @track submitError = '';
    @track createdItemId;

    get priorityOptions() {
        return [
            { label: 'Low', value: 'Low' },
            { label: 'Medium', value: 'Medium' },
            { label: 'High', value: 'High' }
        ];
    }

    get typeOptions() {
        return [
            { label: 'Bug / Issue', value: 'Internal' },
            { label: 'Feature Request', value: 'Partner Request' },
            { label: 'Question', value: 'Public Lead' },
            { label: 'Other', value: 'Internal' }
        ];
    }

    get isFormValid() {
        return this.title && this.title.trim().length > 0;
    }

    get submitDisabled() {
        return !this.isFormValid || this.isSubmitting;
    }

    handleTitleInput(event) {
        this.title = event.target.value;
        this.submitSuccess = false;
        this.submitError = '';
    }

    handleDescriptionInput(event) {
        this.description = event.target.value;
    }

    handlePriorityChange(event) {
        this.priority = event.target.value;
    }

    handleTypeChange(event) {
        this.requestType = event.target.value;
    }

    handleSubmit() {
        if (!this.isFormValid) return;

        this.isSubmitting = true;
        this.submitSuccess = false;
        this.submitError = '';

        const requestData = {
            title: this.title.trim(),
            description: this.description,
            priority: this.priority,
            type: this.requestType,
            networkEntityId: this.networkEntityId || ''
        };

        submitPortalRequest({ requestData })
            .then(itemId => {
                this.createdItemId = itemId;
                this.submitSuccess = true;
                this.resetForm();
            })
            .catch(err => {
                this.submitError = this.reduceError(err);
            })
            .finally(() => {
                this.isSubmitting = false;
            });
    }

    handleCancel() {
        this.resetForm();
        this.dispatchEvent(new CustomEvent('navigateto', {
            detail: { target: 'dashboard', networkEntityId: this.networkEntityId }
        }));
    }

    handleViewCreatedItem() {
        if (this.createdItemId) {
            this.dispatchEvent(new CustomEvent('navigateto', {
                detail: { target: 'workItemDetail', workItemId: this.createdItemId, networkEntityId: this.networkEntityId }
            }));
        }
    }

    resetForm() {
        this.title = '';
        this.description = '';
        this.priority = 'Medium';
        this.requestType = 'Internal';
    }

    reduceError(error) {
        if (typeof error === 'string') return error;
        if (error.body && error.body.message) return error.body.message;
        if (error.message) return error.message;
        return 'An unknown error occurred. Please try again.';
    }
}

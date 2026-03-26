/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @author Cloud Nimbus LLC
 */
import { LightningElement, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import WORK_ITEM_OBJECT from '@salesforce/schema/%%%NAMESPACED_ORG%%%WorkItem__c';

export default class DeliveryGanttQuickEdit extends NavigationMixin(LightningElement) {
    @api recordId;
    objectApiName = WORK_ITEM_OBJECT;
    _showAdvanced = false;

    get showAdvanced() { return this._showAdvanced; }
    get advancedToggleLabel() { return this._showAdvanced ? 'Hide advanced fields' : 'Show advanced fields'; }
    get advancedToggleIcon() { return this._showAdvanced ? 'utility:chevrondown' : 'utility:chevronright'; }

    handleToggleAdvanced() { this._showAdvanced = !this._showAdvanced; }

    handleSuccess() {
        this.dispatchEvent(new ShowToastEvent({ title: 'Saved', message: 'Work item updated.', variant: 'success' }));
        this.dispatchEvent(new CustomEvent('save'));
    }

    handleError() {
        // Let lightning-record-edit-form handle error display
    }

    handleClose() {
        this.dispatchEvent(new CustomEvent('close'));
    }

    handleNavigate() {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: { recordId: this.recordId, objectApiName: '%%%NAMESPACED_ORG%%%WorkItem__c', actionName: 'view' }
        });
        this.dispatchEvent(new CustomEvent('close'));
    }

    // Close on escape key
    connectedCallback() {
        this._escHandler = (e) => { if (e.key === 'Escape') this.handleClose(); };
        window.addEventListener('keydown', this._escHandler);
    }
    disconnectedCallback() {
        window.removeEventListener('keydown', this._escHandler);
    }
}

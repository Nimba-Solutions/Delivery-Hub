/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @author Cloud Nimbus LLC
 */
import { LightningElement, api, wire, track } from 'lwc';
import { getRecord, getFieldValue, refreshApex } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import logHours from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryTimeLoggerController.logHours';
import isApprovalRequired from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryTimeLoggerController.isApprovalRequired';
import TOTAL_LOGGED_HOURS_FIELD from '@salesforce/schema/WorkItem__c.TotalLoggedHoursSum__c';
import CLIENT_ENTITY_FIELD from '@salesforce/schema/WorkItem__c.ClientNetworkEntityLookup__c';

const FIELDS = [TOTAL_LOGGED_HOURS_FIELD, CLIENT_ENTITY_FIELD];

export default class DeliveryTimeLogger extends LightningElement {
    @api recordId;
    @track hoursValue = 1;
    @track notesValue = '';
    @track workDateValue;
    @track selectedPreset = 1;
    @track isSubmitting = false;
    @track approvalRequired = false;
    @track showDraftBadge = false;

    wiredWorkItem;

    connectedCallback() {
        this.workDateValue = this.todayDate;
    }

    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    wiredWorkItemHandler(result) {
        this.wiredWorkItem = result;
    }

    @wire(isApprovalRequired)
    wiredApproval({ data, error }) {
        if (data !== undefined) {
            this.approvalRequired = data;
        }
        if (error) {
            this.approvalRequired = false;
        }
    }

    get hasClientEntity() {
        const val = getFieldValue(this.wiredWorkItem && this.wiredWorkItem.data, CLIENT_ENTITY_FIELD);
        return !!val;
    }

    get currentHours() {
        const val = getFieldValue(this.wiredWorkItem && this.wiredWorkItem.data, TOTAL_LOGGED_HOURS_FIELD);
        return val != null ? val : 0;
    }

    get todayDate() {
        const now = new Date();
        return now.getFullYear() + '-' +
            String(now.getMonth() + 1).padStart(2, '0') + '-' +
            String(now.getDate()).padStart(2, '0');
    }

    get presetOptions() {
        const presets = [
            { label: '15m', value: 0.25 },
            { label: '30m', value: 0.5 },
            { label: '1h',  value: 1 },
            { label: '2h',  value: 2 },
            { label: '4h',  value: 4 },
            { label: '8h',  value: 8 }
        ];
        return presets.map((p) => ({
            ...p,
            btnClass: `tl-preset-btn${this.selectedPreset === p.value ? ' is-active' : ''}`
        }));
    }

    handlePresetClick(event) {
        const val = parseFloat(event.currentTarget.dataset.value);
        this.selectedPreset = val;
        this.hoursValue = val;
    }

    handleHoursChange(event) {
        this.hoursValue = parseFloat(event.detail.value) || 0;
        this.selectedPreset = null;
    }

    handleNotesChange(event) {
        this.notesValue = event.detail.value;
    }

    handleDateChange(event) {
        this.workDateValue = event.detail.value;
    }

    async handleSubmit() {
        if (!this.hoursValue || this.hoursValue <= 0) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Invalid Entry',
                message: 'Please enter a positive number of hours.',
                variant: 'error'
            }));
            return;
        }

        this.isSubmitting = true;
        try {
            await logHours({
                workItemId: this.recordId,
                hours: this.hoursValue,
                workNotes: this.notesValue || null,
                workDate: this.workDateValue || null
            });

            const msg = this.approvalRequired
                ? `${this.hoursValue}h saved as draft — pending approval.`
                : `${this.hoursValue}h added to this work item.`;

            this.dispatchEvent(new ShowToastEvent({
                title: 'Time Logged',
                message: msg,
                variant: 'success'
            }));

            if (this.approvalRequired) {
                this.showDraftBadge = true;
            }

            this.hoursValue = 1;
            this.notesValue = '';
            this.selectedPreset = 1;
            this.workDateValue = this.todayDate;
            await refreshApex(this.wiredWorkItem);
        } catch (error) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error Logging Time',
                message: error.body ? error.body.message : error.message,
                variant: 'error'
            }));
        } finally {
            this.isSubmitting = false;
        }
    }
}

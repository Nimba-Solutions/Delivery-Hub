import { LightningElement, api, wire, track } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import logHours from '@salesforce/apex/DeliveryTimeLoggerController.logHours';
import TOTAL_LOGGED_HOURS_FIELD from '@salesforce/schema/Ticket__c.TotalLoggedHoursNumber__c';

export default class DeliveryTimeLogger extends LightningElement {
    @api recordId;
    @track hoursValue = 1;
    @track selectedPreset = 1;
    @track isSubmitting = false;

    @wire(getRecord, { recordId: '$recordId', fields: [TOTAL_LOGGED_HOURS_FIELD] })
    ticket;

    get currentHours() {
        const val = getFieldValue(this.ticket && this.ticket.data, TOTAL_LOGGED_HOURS_FIELD);
        return val != null ? val : 0;
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
            await logHours({ ticketId: this.recordId, hours: this.hoursValue });
            this.dispatchEvent(new ShowToastEvent({
                title: 'Time Logged',
                message: `${this.hoursValue}h added to this ticket.`,
                variant: 'success'
            }));
            this.hoursValue = 1;
            this.selectedPreset = 1;
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

/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @author Cloud Nimbus LLC
 */
import { LightningElement, api, wire, track } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getQuotes from '@salesforce/apex/DeliveryWorkItemQuotesController.getQuotes';
import acceptQuote from '@salesforce/apex/DeliveryWorkItemQuotesController.acceptQuote';

const STATUS_CLASS = {
    'Accepted':   'q-status q-status--accepted',
    'In Progress':'q-status q-status--progress',
    'Completed':  'q-status q-status--completed',
    'Inactive':   'q-status q-status--inactive',
    'Budget Hold':'q-status q-status--hold'
};

export default class DeliveryWorkItemQuotes extends LightningElement {
    @api recordId;
    @track isAccepting = false;
    @track isLoading = true;

    _wiredResult;

    @wire(getQuotes, { workItemId: '$recordId' })
    wiredQuotes(result) {
        this._wiredResult = result;
        if (result.data) {
            this.isLoading = false;
        } else if (result.error) {
            console.error('Error loading quotes', result.error);
            this.isLoading = false;
        }
    }

    get quotes() {
        if (!this._wiredResult || !this._wiredResult.data) return [];
        return this._wiredResult.data.map(q => ({
            ...q,
            quotedHoursDisplay:  q.quotedHours   != null ? `${q.quotedHours}h` : '—',
            hourlyRateDisplay:   q.hourlyRate     != null ? `$${q.hourlyRate}/hr` : '—',
            projectedCostDisplay:q.projectedCost  != null ? `$${q.projectedCost.toFixed(0)}` : '—',
            cardClass:  `q-card${q.isAccepted ? ' q-card--accepted' : ''}`,
            statusClass: STATUS_CLASS[q.status] || 'q-status'
        }));
    }

    get hasQuotes() { return this.quotes.length > 0; }

    async handleAccept(event) {
        const requestId = event.currentTarget.dataset.id;
        this.isAccepting = true;
        try {
            await acceptQuote({ requestId, workItemId: this.recordId });
            await refreshApex(this._wiredResult);
            this.dispatchEvent(new ShowToastEvent({
                title: 'Quote Accepted',
                message: 'This vendor has been selected for this work item.',
                variant: 'success'
            }));
        } catch (error) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error',
                message: error.body ? error.body.message : error.message,
                variant: 'error'
            }));
        } finally {
            this.isAccepting = false;
        }
    }
}

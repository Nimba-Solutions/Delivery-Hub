/**
 * @author Cloud Nimbus LLC
 */
import { LightningElement, wire, track } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getSyncHealth from '@salesforce/apex/DeliverySyncRetryController.getSyncHealth';
import retryFailed from '@salesforce/apex/DeliverySyncRetryController.retryFailed';

export default class DeliverySyncRetryPanel extends LightningElement {
    @track isRetrying = false;
    @track isLoading = true;

    _wiredResult;

    @wire(getSyncHealth)
    wiredHealth(result) {
        this._wiredResult = result;
        if (result.data || result.error) {
            this.isLoading = false;
        }
    }

    get failedCount()   { return this._wiredResult && this._wiredResult.data ? this._wiredResult.data.failedCount || 0 : 0; }
    get recentErrors()  { return this._wiredResult && this._wiredResult.data ? this._wiredResult.data.recentErrors || [] : []; }
    get hasFailures()   { return this.failedCount > 0; }
    get hasErrors()     { return this.recentErrors.length > 0; }
    get pluralSuffix()  { return this.failedCount === 1 ? '' : 's'; }

    async handleRetry() {
        this.isRetrying = true;
        try {
            await retryFailed();
            await refreshApex(this._wiredResult);
            this.dispatchEvent(new ShowToastEvent({
                title: 'Retrying',
                message: `${this.failedCount} sync item${this.pluralSuffix} reset to queued.`,
                variant: 'success'
            }));
        } catch (error) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error',
                message: error.body ? error.body.message : error.message,
                variant: 'error'
            }));
        } finally {
            this.isRetrying = false;
        }
    }

    handleRefresh() {
        this.isLoading = true;
        refreshApex(this._wiredResult).then(() => { this.isLoading = false; });
    }
}

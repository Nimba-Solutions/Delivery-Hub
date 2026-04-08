/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @author Cloud Nimbus LLC
 */
import { LightningElement, wire, track } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getSyncHealth from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliverySyncRetryController.getSyncHealth';
import retryFailed from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliverySyncRetryController.retryFailed';
import dismissFailed from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliverySyncRetryController.dismissFailed';
import restoreDismissed from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliverySyncRetryController.restoreDismissed';

export default class DeliverySyncRetryPanel extends LightningElement {
    @track isRetrying = false;
    @track isLoading = true;
    @track showDismissed = false;

    _wiredResult;

    @wire(getSyncHealth, { includeDismissed: '$showDismissed' })
    wiredHealth(result) {
        this._wiredResult = result;
        if (result.data || result.error) {
            this.isLoading = false;
        }
    }

    get failedCount()        { return this._wiredResult && this._wiredResult.data ? this._wiredResult.data.failedCount || 0 : 0; }
    get recentErrors()       { return this._wiredResult && this._wiredResult.data ? this._wiredResult.data.recentErrors || [] : []; }
    get stagedAwaitingPoll() { return this._wiredResult && this._wiredResult.data ? this._wiredResult.data.stagedAwaitingPoll || 0 : 0; }
    get hasFailures()        { return this.failedCount > 0; }
    get hasErrors()          { return this.recentErrors.length > 0; }
    get hasStaged()          { return this.stagedAwaitingPoll > 0; }
    get pluralSuffix()       { return this.failedCount === 1 ? '' : 's'; }
    get stagedPluralSuffix() { return this.stagedAwaitingPoll === 1 ? '' : 's'; }
    get toggleLabel()        { return this.showDismissed ? 'Hide dismissed' : 'Show dismissed'; }

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

    handleToggleDismissed() {
        this.showDismissed = !this.showDismissed;
    }

    async handleDismissOne(event) {
        const id = event.currentTarget.dataset.id;
        try {
            const count = await dismissFailed({ ids: [id], reason: 'Manual via Sync Retry Panel' });
            await refreshApex(this._wiredResult);
            this.dispatchEvent(new ShowToastEvent({
                title: 'Dismissed',
                message: `${count} sync item dismissed.`,
                variant: 'success'
            }));
        } catch (error) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error',
                message: error.body ? error.body.message : error.message,
                variant: 'error'
            }));
        }
    }

    async handleRestoreOne(event) {
        const id = event.currentTarget.dataset.id;
        try {
            const count = await restoreDismissed({ ids: [id] });
            await refreshApex(this._wiredResult);
            this.dispatchEvent(new ShowToastEvent({
                title: 'Restored',
                message: `${count} sync item restored.`,
                variant: 'success'
            }));
        } catch (error) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error',
                message: error.body ? error.body.message : error.message,
                variant: 'error'
            }));
        }
    }

    async handleDismissAll() {
        const ids = this.recentErrors.filter((r) => !r.dismissed).map((r) => r.id);
        if (ids.length === 0) {
            return;
        }
        try {
            const count = await dismissFailed({ ids, reason: 'Bulk dismiss via Sync Retry Panel' });
            await refreshApex(this._wiredResult);
            this.dispatchEvent(new ShowToastEvent({
                title: 'Dismissed',
                message: `${count} sync item${count === 1 ? '' : 's'} dismissed.`,
                variant: 'success'
            }));
        } catch (error) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error',
                message: error.body ? error.body.message : error.message,
                variant: 'error'
            }));
        }
    }
}

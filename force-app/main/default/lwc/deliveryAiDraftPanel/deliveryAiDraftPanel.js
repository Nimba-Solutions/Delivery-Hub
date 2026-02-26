/**
 * @author Cloud Nimbus LLC
 */
import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import draftStatusUpdate from '@salesforce/apex/DeliveryAiController.draftStatusUpdate';

export default class DeliveryAiDraftPanel extends LightningElement {
    @api recordId;

    @track draft = '';
    @track isLoading = false;
    @track errorMessage = '';
    @track copied = false;

    get hasDraft() {
        return !!this.draft && !this.isLoading;
    }

    get hasError() {
        return !!this.errorMessage && !this.isLoading;
    }

    get copyLabel() {
        return this.copied ? 'Copied!' : 'Copy';
    }

    get copyIcon() {
        return this.copied ? 'utility:check' : 'utility:copy';
    }

    handleDraft() {
        this.isLoading = true;
        this.errorMessage = '';
        this.draft = '';
        this.copied = false;

        draftStatusUpdate({ workItemId: this.recordId })
            .then(result => {
                this.draft = result;
            })
            .catch(error => {
                this.errorMessage = error.body ? error.body.message : error.message;
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    handleDraftChange(event) {
        this.draft = event.target.value;
        this.copied = false;
    }

    handleCopy() {
        navigator.clipboard.writeText(this.draft)
            .then(() => {
                this.copied = true;
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Copied',
                    message: 'Update copied to clipboard.',
                    variant: 'success'
                }));
                setTimeout(() => { this.copied = false; }, 3000); // reset label
            })
            .catch(() => {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Copy failed',
                    message: 'Select the text manually and copy.',
                    variant: 'warning'
                }));
            });
    }
}

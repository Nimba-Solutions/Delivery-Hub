/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @author Cloud Nimbus LLC
 */
import { LightningElement, track } from 'lwc';
import draftReleaseNotes from '@salesforce/apex/DeliveryAiController.draftReleaseNotes';

export default class DeliveryReleaseNotes extends LightningElement {
    @track isLoading = false;
    @track releaseNotes = '';
    @track errorMessage = '';
    @track copied = false;

    async handleDraft() {
        this.isLoading = true;
        this.errorMessage = '';
        this.releaseNotes = '';
        try {
            this.releaseNotes = await draftReleaseNotes();
        } catch (error) {
            this.errorMessage = error.body ? error.body.message : error.message;
        } finally {
            this.isLoading = false;
        }
    }

    handleTextChange(event) {
        this.releaseNotes = event.target.value;
    }

    handleCopy() {
        navigator.clipboard.writeText(this.releaseNotes).then(() => {
            this.copied = true;
            setTimeout(() => { this.copied = false; }, 3000); // reset label
        });
    }

    get draftLabel() {
        return this.isLoading ? 'Generating...' : 'Draft Release Notes';
    }

    get copyLabel() {
        return this.copied ? 'Copied!' : 'Copy';
    }
}

/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Global Quick Action LWC for creating work requests from any page.
 *               Supports optional AI enhancement to auto-fill description,
 *               acceptance criteria, and hour estimates.
 * @author Cloud Nimbus LLC
 */
import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import createWorkRequest from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryQuickRequestController.createWorkRequest';

export default class DeliveryQuickRequest extends LightningElement {
    // When placed on a page/workspace tab (vs. the global quick-action modal) set
    // embedded=true: on submit/cancel the form resets in place instead of firing
    // CloseActionScreenEvent (which only makes sense inside an action modal).
    // Defaults false so the global-action behavior is unchanged (and avoids LWC1503,
    // which forbids a boolean @api defaulting to true).
    @api embedded = false;

    @track title = '';
    @track priority = 'Medium';
    @track description = '';
    @track showDescription = false;
    @track isProcessing = false;
    @track processingMessage = 'Creating...';

    // --- Priority pill getters ---
    get highPillClass() {
        return 'qr-pill qr-pill-high' + (this.priority === 'High' ? ' qr-pill-selected' : '');
    }
    get mediumPillClass() {
        return 'qr-pill qr-pill-medium' + (this.priority === 'Medium' ? ' qr-pill-selected' : '');
    }
    get lowPillClass() {
        return 'qr-pill qr-pill-low' + (this.priority === 'Low' ? ' qr-pill-selected' : '');
    }

    get isCreateDisabled() {
        return this.isProcessing || !this.title.trim();
    }

    // --- Handlers ---
    handleTitleChange(event) {
        this.title = event.target.value;
    }

    handleDescriptionChange(event) {
        this.description = event.target.value;
    }

    handlePriorityClick(event) {
        this.priority = event.currentTarget.dataset.priority;
    }

    toggleDescription() {
        this.showDescription = true;
    }

    handleCancel() {
        this.closeOrReset();
    }

    // Close the action modal when launched as a quick action; reset the form in
    // place when embedded on a page/workspace tab.
    closeOrReset() {
        if (this.embedded) {
            this.title = '';
            this.description = '';
            this.priority = 'Medium';
            this.showDescription = false;
        } else {
            this.dispatchEvent(new CloseActionScreenEvent());
        }
    }

    handleCreate() {
        this._submitRequest(false);
    }

    handleCreateWithAi() {
        this._submitRequest(true);
    }

    async _submitRequest(aiEnhance) {
        if (!this.title.trim()) {
            this.showToast('Missing Title', 'Please enter a title for the work request.', 'warning');
            return;
        }

        this.isProcessing = true;
        this.processingMessage = aiEnhance
            ? 'Creating and enhancing with AI...'
            : 'Creating...';

        try {
            const result = await createWorkRequest({
                title: this.title.trim(),
                priority: this.priority,
                description: this.description.trim() || null,
                aiEnhance: aiEnhance
            });

            const message = aiEnhance
                ? `Created ${result.recordName} — AI is filling in the details`
                : `Created ${result.recordName}`;

            this.showToast('Work Request Created', message, 'success');
            this.closeOrReset();
        } catch (error) {
            const msg = error.body ? error.body.message : error.message;
            this.showToast('Error', msg, 'error');
        } finally {
            this.isProcessing = false;
        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}

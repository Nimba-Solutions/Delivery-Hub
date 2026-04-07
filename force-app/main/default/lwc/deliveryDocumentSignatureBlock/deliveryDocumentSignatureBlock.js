/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Reusable signature block for documents that require multi-party signing.
 *               Renders the slots (pending and completed) and owns the sign modal.
 *               Dispatches `signsubmit` events to the parent which calls the appropriate
 *               Apex controller (admin or public). Used by both deliveryDocumentViewer
 *               (admin) and deliveryDocumentSignPortal (Phase 3 public guest).
 * @author Cloud Nimbus LLC
 */
import { LightningElement, api, track } from 'lwc';

const DEFAULT_CONSENT = 'By checking the box below and clicking Sign, you agree that your electronic signature is the legal equivalent of your manual signature on this document. You consent to be legally bound by its terms and affirm that you have had a reasonable opportunity to review the document before signing.';

export default class DeliveryDocumentSignatureBlock extends LightningElement {
    // Inputs from parent
    @api actions = [];
    @api requiresSigning = false;
    @api consentText = '';
    // Inverted boolean per CLAUDE.md (LWC1503: @api booleans can't default to true)
    @api signingDisabled = false;
    @api title = 'Signatures';

    // Modal state
    @track showSignModal = false;
    @track activeAction = null;
    @track formName = '';
    @track formEmail = '';
    @track formConsent = false;
    @track isSubmitting = false;

    get hasActions() {
        return this.requiresSigning && Array.isArray(this.actions) && this.actions.length > 0;
    }

    get consentDisclosure() {
        return this.consentText || DEFAULT_CONSENT;
    }

    get sortedActions() {
        const list = Array.isArray(this.actions) ? [...this.actions] : [];
        list.sort((a, b) => (a.sortOrder || 0) - (b.sortOrder || 0));
        return list.map((a) => ({
            ...a,
            slotClass: a.isCompleted
                ? 'signature-slot signature-slot--completed'
                : 'signature-slot signature-slot--pending',
            showSignButton: !a.isCompleted && !this.signingDisabled
        }));
    }

    get isSubmitDisabled() {
        return this.isSubmitting || !this.formName || !this.formConsent;
    }

    get modalHeading() {
        return this.activeAction ? this.activeAction.label : 'Sign';
    }

    handleSignClick(event) {
        const actionId = event.currentTarget.dataset.actionId;
        const action = (this.actions || []).find((a) => a.id === actionId);
        if (!action) {
            return;
        }
        this.activeAction = action;
        this.formName = '';
        this.formEmail = '';
        this.formConsent = false;
        this.isSubmitting = false;
        this.showSignModal = true;
    }

    handleNameChange(event) {
        this.formName = event.target.value;
    }

    handleEmailChange(event) {
        this.formEmail = event.target.value;
    }

    handleConsentChange(event) {
        this.formConsent = event.target.checked;
    }

    handleSubmitSign() {
        if (this.isSubmitDisabled) {
            return;
        }
        this.isSubmitting = true;
        this.dispatchEvent(
            new CustomEvent('signsubmit', {
                detail: {
                    actionId: this.activeAction.id,
                    actionLabel: this.activeAction.label,
                    signerName: this.formName,
                    signerEmail: this.formEmail,
                    consentGiven: this.formConsent
                }
            })
        );
        // Parent calls completeSubmission() with the result.
    }

    handleCancelModal() {
        this.showSignModal = false;
        this.activeAction = null;
        this.isSubmitting = false;
    }

    /**
     * @description Public API the parent calls after the @AuraEnabled controller
     *              method finishes. On success, closes the modal and resets state.
     *              On failure, just clears the submitting flag so the user can retry.
     */
    @api
    completeSubmission(success) {
        this.isSubmitting = false;
        if (success) {
            this.showSignModal = false;
            this.activeAction = null;
            this.formName = '';
            this.formEmail = '';
            this.formConsent = false;
        }
    }
}

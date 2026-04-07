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
    // Admin context: when true, render a "Copy Signer Link" button next to each
    // pending slot so admins can grab the per-signer URL without dropping into
    // a SOQL console. Default off — guest portal contexts won't show it.
    @api adminContext = false;
    // Phase 4: Certificate of Completion payload from
    // DeliveryDocActionController.getCertificateOfCompletion. When provided
    // and adminContext is true, the audit trail section renders below the
    // slots with hash chain data, IP, and user agent per signer.
    @api certificate;

    // Modal state
    @track showSignModal = false;
    @track activeAction = null;
    @track formName = '';
    @track formEmail = '';
    @track formConsent = false;
    @track isSubmitting = false;
    // Phase 5: drawn-signature mode toggle. When true, the modal swaps the
    // text-stamp explanation for an inline signature pad and the submit
    // sends the captured PNG bytes instead of the typed name.
    @track useDrawnSignature = false;
    @track drawnHasInk = false;

    get hasActions() {
        return this.requiresSigning && Array.isArray(this.actions) && this.actions.length > 0;
    }

    get consentDisclosure() {
        return this.consentText || DEFAULT_CONSENT;
    }

    get sortedActions() {
        const list = Array.isArray(this.actions) ? [...this.actions] : [];
        list.sort((a, b) => (a.sortOrder || 0) - (b.sortOrder || 0));
        return list.map((a) => {
            const isImage = a.signatureType === 'Image';
            return {
                ...a,
                slotClass: a.isCompleted
                    ? 'signature-slot signature-slot--completed'
                    : 'signature-slot signature-slot--pending',
                showSignButton: !a.isCompleted && !this.signingDisabled,
                showCopyLink: !a.isCompleted && this.adminContext && !!a.signerToken,
                isImageSignature: a.isCompleted && isImage && !!a.signatureImageUrl,
                isTextSignature: a.isCompleted && !isImage
            };
        });
    }

    get isSubmitDisabled() {
        if (this.isSubmitting || !this.formName || !this.formConsent) {
            return true;
        }
        // Phase 5: drawn-mode requires the user to have actually drawn something
        if (this.useDrawnSignature && !this.drawnHasInk) {
            return true;
        }
        return false;
    }

    get modalHeading() {
        return this.activeAction ? this.activeAction.label : 'Sign';
    }

    // ─── Phase 4: Audit trail rendering ───────────────────────────

    get hasAuditTrail() {
        return (
            this.adminContext &&
            this.certificate &&
            Array.isArray(this.certificate.signers) &&
            this.certificate.signers.length > 0
        );
    }

    get documentHashShort() {
        const h = this.certificate && this.certificate.documentHash;
        return h ? `${h.slice(0, 12)}…${h.slice(-6)}` : '—';
    }

    get chainHeadShort() {
        const h = this.certificate && this.certificate.chainHead;
        return h ? `${h.slice(0, 12)}…${h.slice(-6)}` : '—';
    }

    get auditRows() {
        if (!this.hasAuditTrail) {
            return [];
        }
        return this.certificate.signers.map((s, idx) => {
            const ua = s.userAgent || '';
            return {
                key: s.actionId || `row-${idx}`,
                slotLabel: s.slotLabel,
                signerName: s.signerName || '—',
                signerEmail: s.signerEmail || '—',
                signedAt: this.formatTimestamp(s.signedAt),
                ipAddress: s.ipAddress || '—',
                userAgentShort: ua.length > 60 ? `${ua.slice(0, 60)}…` : (ua || '—'),
                priorHashShort: s.priorHash ? `${s.priorHash.slice(0, 12)}…${s.priorHash.slice(-6)}` : '—',
                signatureType: s.signatureType || 'Text'
            };
        });
    }

    formatTimestamp(value) {
        if (!value) {
            return '—';
        }
        try {
            return new Date(value).toLocaleString('en-US', {
                year: 'numeric', month: 'short', day: 'numeric',
                hour: 'numeric', minute: '2-digit', timeZoneName: 'short'
            });
        } catch (err) { // eslint-disable-line no-unused-vars
            return String(value);
        }
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
        this.useDrawnSignature = false;
        this.drawnHasInk = false;
        this.showSignModal = true;
    }

    handleDrawToggle(event) {
        this.useDrawnSignature = event.target.checked;
        this.drawnHasInk = false;
    }

    handleSignaturePadChange(event) {
        this.drawnHasInk = !!(event.detail && event.detail.hasInk);
    }

    /**
     * @description Dispatches a `copylinkrequest` event with the action id, label,
     *              and signer token. Parent component is responsible for building
     *              the actual URL (which depends on the host's Site / Experience
     *              Cloud setup) and copying it to the clipboard.
     */
    handleCopyLinkClick(event) {
        const actionId = event.currentTarget.dataset.actionId;
        const action = (this.actions || []).find((a) => a.id === actionId);
        if (!action || !action.signerToken) {
            return;
        }
        this.dispatchEvent(
            new CustomEvent('copylinkrequest', {
                detail: {
                    actionId: action.id,
                    actionLabel: action.label,
                    signerToken: action.signerToken
                }
            })
        );
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
        // Phase 5: pull the PNG bytes off the drawn pad if the user toggled
        // drawn mode. Drawn signatures send signatureType=Image; the parent
        // routes them through the same signsubmit event.
        let signatureType = 'Text';
        let drawnSignature = null;
        if (this.useDrawnSignature) {
            const pad = this.template.querySelector('c-delivery-signature-pad');
            if (pad) {
                drawnSignature = pad.getSignatureData();
            }
            if (!drawnSignature) {
                // Should be guarded by isSubmitDisabled, but defend anyway.
                return;
            }
            signatureType = 'Image';
        }
        this.isSubmitting = true;
        this.dispatchEvent(
            new CustomEvent('signsubmit', {
                detail: {
                    actionId: this.activeAction.id,
                    actionLabel: this.activeAction.label,
                    signerName: this.formName,
                    signerEmail: this.formEmail,
                    consentGiven: this.formConsent,
                    signatureType: signatureType,
                    drawnSignature: drawnSignature
                }
            })
        );
        // Parent calls completeSubmission() with the result.
    }

    handleCancelModal() {
        this.showSignModal = false;
        this.activeAction = null;
        this.isSubmitting = false;
        this.useDrawnSignature = false;
        this.drawnHasInk = false;
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
            this.useDrawnSignature = false;
            this.drawnHasInk = false;
        }
    }
}

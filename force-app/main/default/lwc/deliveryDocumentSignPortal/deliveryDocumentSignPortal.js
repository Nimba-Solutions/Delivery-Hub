/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Public-facing signing portal LWC. Loads a document by signer token,
 *               renders the existing signature block child LWC, and submits the
 *               sign action via @AuraEnabled. The token comes from the URL query
 *               string `?token=<64hex>`.
 *
 *               Designed for guest user / Experience Cloud / Site context. The
 *               existing deliveryDocumentSignatureBlock child LWC owns the actual
 *               sign UI — this component is the page-level wrapper that handles
 *               loading, errors, and the post-sign success state.
 * @author Cloud Nimbus LLC
 */
import { LightningElement, api, track } from 'lwc';
import getDocumentForSigner from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryDocActionController.getDocumentForSigner';
import signActionPublic from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryDocActionController.signActionPublic';

export default class DeliveryDocumentSignPortal extends LightningElement {
    @api signerToken; // can be passed in or read from URL
    @track loading = true;
    @track loadError = '';
    @track document = null;
    @track actions = [];
    @track signerActionId = null;
    @track signerSlotLabel = '';
    @track consentText = '';
    @track signSuccess = false;
    @track docStatusAfterSign = '';

    connectedCallback() {
        if (!this.signerToken) {
            this.signerToken = this.readTokenFromUrl();
        }
        if (!this.signerToken) {
            this.loading = false;
            this.loadError = 'Missing signer token in the URL.';
            return;
        }
        this.loadBundle();
    }

    readTokenFromUrl() {
        if (typeof window === 'undefined') {
            return null;
        }
        try {
            const params = new URLSearchParams(window.location.search);
            return params.get('token') || params.get('signerToken');
        } catch (e) {
            return null;
        }
    }

    async loadBundle() {
        this.loading = true;
        this.loadError = '';
        try {
            const result = await getDocumentForSigner({ signerToken: this.signerToken });
            this.document = result.document || null;
            this.actions = result.actions || [];
            this.signerActionId = result.signerActionId || null;
            this.signerSlotLabel = result.signerSlotLabel || '';
            this.consentText = (this.document && this.document.consentText) || '';
        } catch (e) {
            this.loadError = (e && e.body && e.body.message) || 'Unable to load document.';
        } finally {
            this.loading = false;
        }
    }

    async handleSignSubmit(event) {
        const detail = event.detail || {};
        const childLwc = this.template.querySelector('c-delivery-document-signature-block');
        try {
            const result = await signActionPublic({
                signerToken: this.signerToken,
                signerName: detail.signerName,
                signerEmail: detail.signerEmail,
                consentGiven: detail.consentGiven,
                userAgent: typeof navigator !== 'undefined' ? navigator.userAgent : null
            });
            this.signSuccess = true;
            this.docStatusAfterSign = (result && result.documentStatus) || '';
            // Refresh actions so the completed slot stamp is visible
            await this.loadBundle();
            if (childLwc && typeof childLwc.completeSubmission === 'function') {
                childLwc.completeSubmission(true);
            }
        } catch (e) {
            const message = (e && e.body && e.body.message) || 'Sign failed.';
            if (childLwc && typeof childLwc.completeSubmission === 'function') {
                childLwc.completeSubmission(false, message);
            }
        }
    }

    get hasDocument() {
        return this.document !== null && !this.loadError;
    }

    get pageTitle() {
        if (!this.document) return 'Sign Document';
        return this.document.name || 'Sign Document';
    }

    get isFullyApproved() {
        return this.docStatusAfterSign === 'Approved';
    }

    // The signature block child expects a Boolean — pass via getter to avoid
    // the HTML-attribute string-coercion gotcha.
    get requiresSigningTrue() {
        return true;
    }
}

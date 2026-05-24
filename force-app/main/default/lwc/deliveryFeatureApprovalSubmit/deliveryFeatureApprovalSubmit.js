/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Submission form for Feature__c toggle requests (Layer 5).
 *               Closes the Flow 4 gap surfaced in
 *               docs/audits/e2e-walkthrough-2026-05-21.md —
 *               DeliveryFeatureApprovalService.submit() existed but no LWC
 *               called it. This form lets any user (admin or otherwise) post
 *               a request that lands in the approval inbox.
 *
 *               Driven by getCatalog() so the feature picker only shows
 *               Features that actually exist in this tenant (i.e. have a
 *               Feature__c row, not just an mdt definition — submit needs a
 *               real Id). FeatureToggleAction GVS is small (Enable/Disable)
 *               and stable so we hard-code its values; if it ever grows we
 *               swap in getPicklistValues / a wire to a controller.
 *
 *               Modal-host friendly: dispatches `submitted` (success) and
 *               `cancel` events so deliveryFeatureCockpit can close the
 *               modal it opens us in.
 *
 *               No ternaries in the template (LWC v62 limitation per
 *               CLAUDE.md). No @api boolean defaulting to true (LWC1503).
 * @author Cloud Nimbus LLC
 */
import { LightningElement, wire, track } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getCatalog from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryFeatureCatalogController.getCatalog';
import submitRequest from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryFeatureApprovalService.submit';

const ACTION_ENABLE = 'Enable',
    ACTION_DISABLE = 'Disable',
    JUSTIFICATION_MIN = 10,
    JUSTIFICATION_MAX = 2000,
    EMPTY = 0;

export default class DeliveryFeatureApprovalSubmit extends LightningElement {
    @track featureOptions = [];
    @track featuresById = {};
    @track selectedFeatureId = '';
    @track selectedAction = '';
    @track justification = '';
    @track justificationTouched = false;
    @track isSubmitting = false;
    @track submitErrorMessage = '';
    @track loadErrorMessage = '';
    @track isLoaded = false;

    wiredCatalogResult;

    /** Hard-coded mirror of the FeatureToggleAction GVS (Enable / Disable).
     *  Kept in sync with force-app/main/default/globalValueSets/FeatureToggleAction.globalValueSet-meta.xml.
     *  If the GVS ever grows beyond these two values, swap to getPicklistValues
     *  off FeatureToggleRequest__c.ActionPk__c. */
    actionOptions = [
        { label: 'Enable', value: ACTION_ENABLE },
        { label: 'Disable', value: ACTION_DISABLE }
    ];

    justificationMin = JUSTIFICATION_MIN;
    justificationMax = JUSTIFICATION_MAX;

    @wire(getCatalog)
    wiredCatalog(result) {
        this.wiredCatalogResult = result;
        if (result.data) {
            const rows = result.data || [];
            const options = [];
            const byId = {};
            for (let i = 0; i < rows.length; i++) {
                const f = rows[i];
                // submit() needs an actual Feature__c Id — skip mdt-only rows
                // that haven't been backfilled yet.
                if (!f.featureId) {
                    continue;
                }
                const label = f.label || f.name || f.featureId;
                const status = f.isActive === true ? 'Active' : 'Inactive';
                options.push({
                    label: `${label} (${status})`,
                    value: f.featureId
                });
                byId[f.featureId] = {
                    label,
                    isActive: f.isActive === true
                };
            }
            this.featureOptions = options;
            this.featuresById = byId;
            this.loadErrorMessage = '';
            this.isLoaded = true;
        } else if (result.error) {
            this.loadErrorMessage = this.extractErrorMessage(result.error)
                || 'Unable to load feature catalog.';
            this.featureOptions = [];
            this.featuresById = {};
            this.isLoaded = true;
        }
    }

    // ── Derived state ──────────────────────────────────────────────────

    get hasLoadError() {
        return this.loadErrorMessage.length > EMPTY;
    }

    get hasSubmitError() {
        return this.submitErrorMessage.length > EMPTY;
    }

    get isReady() {
        return this.isLoaded && !this.hasLoadError;
    }

    get justificationLength() {
        return (this.justification || '').length;
    }

    get justificationCounter() {
        return `${this.justificationLength} / ${this.justificationMax} characters (minimum ${this.justificationMin})`;
    }

    get isFeatureValid() {
        return !!this.selectedFeatureId;
    }

    get isActionValid() {
        return this.selectedAction === ACTION_ENABLE
            || this.selectedAction === ACTION_DISABLE;
    }

    get isJustificationValid() {
        const len = this.justificationLength;
        return len >= this.justificationMin && len <= this.justificationMax;
    }

    get isFormValid() {
        return this.isFeatureValid
            && this.isActionValid
            && this.isJustificationValid;
    }

    get submitDisabled() {
        return this.isSubmitting || !this.isFormValid;
    }

    get submitLabel() {
        if (this.isSubmitting) {
            return 'Submitting...';
        }
        return 'Submit request';
    }

    // ── Handlers ───────────────────────────────────────────────────────

    handleFeatureChange(event) {
        this.selectedFeatureId = event.detail.value || '';
        this.submitErrorMessage = '';
    }

    handleActionChange(event) {
        this.selectedAction = event.detail.value || '';
        this.submitErrorMessage = '';
    }

    handleJustificationChange(event) {
        this.justification = event.detail.value || '';
        this.submitErrorMessage = '';
    }

    handleJustificationBlur() {
        this.justificationTouched = true;
    }

    handleRefresh() {
        if (this.wiredCatalogResult) {
            refreshApex(this.wiredCatalogResult);
        }
    }

    handleReset() {
        this.resetForm();
    }

    handleSubmit() {
        if (!this.isFormValid || this.isSubmitting) {
            return;
        }
        this.isSubmitting = true;
        this.submitErrorMessage = '';
        const featureId = this.selectedFeatureId,
            action = this.selectedAction,
            reason = this.justification;
        submitRequest({ featureId, action, reason })
            .then(requestId => {
                this.isSubmitting = false;
                const feature = this.featuresById[featureId] || { label: 'feature' };
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Request submitted',
                    message: `${action} request for "${feature.label}" sent for approval.`,
                    variant: 'success'
                }));
                this.dispatchEvent(new CustomEvent('submitted', {
                    detail: { requestId, featureId, action }
                }));
                this.resetForm();
                if (this.wiredCatalogResult) {
                    refreshApex(this.wiredCatalogResult);
                }
            })
            .catch(err => {
                this.isSubmitting = false;
                const msg = this.extractErrorMessage(err)
                    || 'Unable to submit the request. Please try again.';
                this.submitErrorMessage = msg;
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Submission failed',
                    message: msg,
                    variant: 'error'
                }));
            });
    }

    // ── Helpers ────────────────────────────────────────────────────────

    resetForm() {
        this.selectedFeatureId = '';
        this.selectedAction = '';
        this.justification = '';
        this.justificationTouched = false;
        this.submitErrorMessage = '';
    }

    extractErrorMessage(error) {
        if (error && error.body && error.body.message) {
            return error.body.message;
        }
        if (error && error.message) {
            return error.message;
        }
        return '';
    }
}

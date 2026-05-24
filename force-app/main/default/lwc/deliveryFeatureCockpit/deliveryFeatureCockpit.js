/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Feature Cockpit (Layer 4 of the DH cockpit architecture).
 *               Renders the catalog returned by DeliveryFeatureCatalogController.getCatalog()
 *               and (PR 2) exposes per-card Enable/Disable buttons that round-trip through
 *               toggleFeature(). Buttons are gated on isAdmin() — non-admins see read-only.
 *
 *               PR 1: scaffold + read-only.
 *               PR 2: bidirectional sync + admin toggle buttons (this file).
 *               PR 3+: onboarding-track gating, dependency-aware disable, approval flow.
 * @author Cloud Nimbus LLC
 */
import { LightningElement, wire, track } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getCatalog from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryFeatureCatalogController.getCatalog';
import isAdminApex from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryFeatureCatalogController.isAdmin';
import toggleFeature from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryFeatureCatalogController.toggleFeature';

const DESCRIPTION_TRUNCATE_AT = 140,
    ELLIPSIS = '…',
    EMPTY = 0;

export default class DeliveryFeatureCockpit extends LightningElement {
    @track features = [];
    @track errorMessage = '';
    @track isLoaded = false;
    @track isAdminUser = false;

    @track isCascadeModalOpen = false;
    @track cascadeFeatureId = null;
    @track cascadeFeatureLabel = '';

    // PR closing Flow 4 gap (audit 2026-05-21): a submission-UI modal
    // hosting deliveryFeatureApprovalSubmit. Open via "Request approval"
    // on any card; closes on submit success or cancel.
    @track isApprovalSubmitModalOpen = false;

    wiredResult;

    @wire(isAdminApex)
    wiredIsAdmin({ data }) {
        if (data === true) {
            this.isAdminUser = true;
        } else {
            this.isAdminUser = false;
        }
    }

    @wire(getCatalog)
    wiredCatalog(result) {
        this.wiredResult = result;
        if (result.data) {
            this.features = (result.data || []).map((f, idx) => {
                const description = f.description || '';
                const truncated = description.length > DESCRIPTION_TRUNCATE_AT
                    ? description.substring(0, DESCRIPTION_TRUNCATE_AT) + ELLIPSIS
                    : description;
                const isActive = f.isActive === true;
                const hasFeatureId = !!f.featureId;
                return {
                    key: f.name || `feature-${idx}`,
                    featureId: f.featureId || null,
                    name: f.name,
                    label: f.label || f.name,
                    description,
                    truncatedDescription: truncated,
                    category: f.category || '',
                    maturity: f.maturity || '',
                    icon: f.icon || 'standard:default',
                    isActive,
                    hasFeatureId,
                    settingsFieldApiName: f.settingsFieldApiName || '',
                    docsUrl: f.docsUrl || '',
                    hasDocsUrl: !!f.docsUrl,
                    hasSettingsField: !!f.settingsFieldApiName,
                    statusBadgeClass: isActive
                        ? 'slds-badge slds-theme_success'
                        : 'slds-badge slds-theme_shade',
                    statusBadgeText: isActive ? 'Active' : 'Inactive',
                    categoryBadgeClass: 'slds-badge slds-badge_lightest',
                    maturityBadgeClass: f.maturity === 'Beta' || f.maturity === 'Alpha'
                        ? 'slds-badge slds-theme_warning'
                        : 'slds-badge slds-badge_lightest',
                    toggleLabel: isActive ? 'Disable' : 'Enable',
                    toggleVariant: isActive ? 'destructive-text' : 'brand',
                    // No featureId means there's no Feature__c row yet — admins
                    // shouldn't see a button that can't act on anything until
                    // the install handler runs / a seed appears. PR 3+ will
                    // expose a "create row + enable" flow.
                    toggleDisabled: !hasFeatureId
                };
            });
            this.errorMessage = '';
            this.isLoaded = true;
        } else if (result.error) {
            this.errorMessage = (result.error && result.error.body && result.error.body.message)
                ? result.error.body.message
                : 'Unable to load feature catalog.';
            this.features = [];
            this.isLoaded = true;
        }
    }

    get hasFeatures() {
        return this.features.length > EMPTY;
    }

    get isEmpty() {
        return this.isLoaded && !this.hasFeatures && !this.errorMessage;
    }

    get hasError() {
        return !!this.errorMessage;
    }

    get canToggle() {
        return this.isAdminUser === true;
    }

    handleRefresh() {
        if (this.wiredResult) {
            refreshApex(this.wiredResult);
        }
    }

    handleToggle(event) {
        const featureId = event.currentTarget.dataset.featureId;
        const featureLabel = event.currentTarget.dataset.featureName || '';
        const isActive = event.currentTarget.dataset.isActive === 'true';
        const enable = !isActive;
        if (!featureId) {
            return;
        }
        toggleFeature({ featureId, enable })
            .then(() => {
                this.dispatchEvent(new ShowToastEvent({
                    title: enable ? 'Feature enabled' : 'Feature disabled',
                    variant: 'success'
                }));
                if (this.wiredResult) {
                    refreshApex(this.wiredResult);
                }
            })
            .catch(err => {
                const msg = (err && err.body && err.body.message)
                    ? err.body.message
                    : 'Toggle failed. Check the Activity Log for details.';
                // PR 4: the onboarding gate throws a message containing
                // "onboarding track" — surface a warning-flavoured toast
                // pointing the user at the feature record page where they
                // can launch the track.
                const isOnboardingGate = typeof msg === 'string'
                    && msg.toLowerCase().indexOf('onboarding track') !== -1;
                // PR 6: the cascade enforcement gate throws a message of the
                // shape `Cannot enable: depends on inactive feature "X" (Hard).`
                // or `Cannot disable: blocked by active dependent "X" (Hard).`
                // — auto-open the cascade preview modal so the user can see
                // the graph that prompted the refusal.
                const isCascadeGate = typeof msg === 'string'
                    && /^Cannot (enable|disable):/i.test(msg);
                if (isOnboardingGate) {
                    this.dispatchEvent(new ShowToastEvent({
                        title: 'Onboarding required',
                        message: 'Open the feature record page to complete the track, then try again.',
                        variant: 'warning'
                    }));
                } else if (isCascadeGate) {
                    this.dispatchEvent(new ShowToastEvent({
                        title: 'Dependency blocked toggle',
                        message: msg + ' View the dependency graph for details.',
                        variant: 'warning'
                    }));
                    this.openCascadeModal(featureId, featureLabel);
                } else {
                    this.dispatchEvent(new ShowToastEvent({
                        title: 'Unable to toggle feature',
                        message: msg,
                        variant: 'error'
                    }));
                }
            });
    }

    openCascadeModal(featureId, featureLabel) {
        if (!featureId) {
            return;
        }
        this.cascadeFeatureId = featureId;
        this.cascadeFeatureLabel = featureLabel || '';
        this.isCascadeModalOpen = true;
    }

    get cascadeModalTitle() {
        if (this.cascadeFeatureLabel) {
            return `Dependencies for ${this.cascadeFeatureLabel}`;
        }
        return 'Feature Dependencies';
    }

    handleShowDependencies(event) {
        const featureId = event.currentTarget.dataset.featureId,
            featureLabel = event.currentTarget.dataset.featureLabel;
        if (!featureId) {
            return;
        }
        this.cascadeFeatureId = featureId;
        this.cascadeFeatureLabel = featureLabel || '';
        this.isCascadeModalOpen = true;
    }

    handleCloseCascadeModal() {
        this.isCascadeModalOpen = false;
        this.cascadeFeatureId = null;
        this.cascadeFeatureLabel = '';
    }

    // ── Approval-submit modal (closes Flow 4 audit gap) ─────────────────

    handleOpenApprovalSubmit() {
        this.isApprovalSubmitModalOpen = true;
    }

    handleCloseApprovalSubmit() {
        this.isApprovalSubmitModalOpen = false;
    }

    handleApprovalSubmitted() {
        // Submission service refreshes its own state — refresh the catalog
        // so the user sees the latest status badges, then close the modal.
        this.isApprovalSubmitModalOpen = false;
        if (this.wiredResult) {
            refreshApex(this.wiredResult);
        }
    }
}

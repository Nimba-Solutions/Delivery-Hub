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
import { NavigationMixin, CurrentPageReference } from 'lightning/navigation';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import FEATURE_OBJECT from '@salesforce/schema/Feature__c';
import getCatalog from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryFeatureCatalogController.getCatalog';
import isAdminApex from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryFeatureCatalogController.isAdmin';
import toggleFeature from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryFeatureCatalogController.toggleFeature';
import getHiddenHomeComponents from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryHomeVisibilityController.getHiddenHomeComponents';

const DESCRIPTION_TRUNCATE_AT = 140,
    ELLIPSIS = '…',
    EMPTY = 0;
// This component's key in the Home-visibility map (matches its LWC folder name).
const HOME_COMPONENT_KEY = 'deliveryFeatureCockpit';

export default class DeliveryFeatureCockpit extends NavigationMixin(LightningElement) {
    // ── Home-page visibility (admin-toggleable, default = shown) ──
    // Hides ONLY on the Delivery Hub app Home page when an admin toggles it
    // off in Settings. Everywhere else this component always renders.
    @wire(CurrentPageReference) _homePageRef;
    @wire(getHiddenHomeComponents) _hiddenHomeComponents;

    get isOnHomePage() {
        const ref = this._homePageRef;
        if (!ref) {
            return false;
        }
        const attrs = ref.attributes || {};
        if (ref.type === 'standard__namedPage' && attrs.pageName === 'home') {
            return true;
        }
        const url = attrs.url
            || (typeof window !== 'undefined' && window.location ? window.location.pathname : '');
        return typeof url === 'string' && url.indexOf('/lightning/page/home') !== -1;
    }

    get isHiddenOnHome() {
        if (!this.isOnHomePage) {
            return false;
        }
        const map = this._hiddenHomeComponents && this._hiddenHomeComponents.data;
        return !!(map && map[HOME_COMPONENT_KEY] === true);
    }

    get isNotHiddenOnHome() {
        return !this.isHiddenOnHome;
    }

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
                    // Closes Flow 3 #1 gap (audit 2026-05-21): the toast now
                    // carries an action link to the Feature__c record page
                    // (where the onboarding LWC mounts) so the user can jump
                    // straight to the track instead of navigating manually.
                    this.fireOnboardingGateToast(featureId, featureLabel);
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

    // Builds and dispatches the onboarding-gate toast with a {url} action
    // link to the Feature__c record page. NavigationMixin.GenerateUrl is
    // async; we fall back to a link-less toast if URL generation fails
    // (e.g. tests without the mixin installed) so the user still sees the
    // refusal message.
    fireOnboardingGateToast(featureId, featureLabel) {
        const labelSuffix = featureLabel ? ` for "${featureLabel}"` : '';
        const fallback = () => {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Onboarding required',
                message: `Open the feature record page${labelSuffix} to complete the track, then try again.`,
                variant: 'warning'
            }));
        };
        try {
            this[NavigationMixin.GenerateUrl]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: featureId,
                    objectApiName: FEATURE_OBJECT.objectApiName,
                    actionName: 'view'
                }
            })
                .then((url) => {
                    if (!url) {
                        fallback();
                        return;
                    }
                    this.dispatchEvent(new ShowToastEvent({
                        title: 'Onboarding required',
                        message: `Complete the onboarding track${labelSuffix}, then try again. {0}`,
                        messageData: [
                            { url, label: 'Open feature record page' }
                        ],
                        variant: 'warning',
                        mode: 'sticky'
                    }));
                })
                .catch(() => fallback());
        } catch (e) {
            fallback();
        }
    }

    // Closes Flow 1 gap (audit 2026-05-21): catalog cards now expose a
    // "View record" affordance that navigates to the Feature__c record
    // page. Skipped (button hidden via getter) when no featureId — mdt-only
    // rows have nothing to navigate to.
    handleViewRecord(event) {
        const featureId = event.currentTarget.dataset.featureId;
        if (!featureId) {
            return;
        }
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: featureId,
                objectApiName: FEATURE_OBJECT.objectApiName,
                actionName: 'view'
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

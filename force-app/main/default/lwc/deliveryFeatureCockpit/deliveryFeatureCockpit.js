/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Read-only Feature Cockpit (Layer 4 of the DH cockpit architecture).
 *               Renders the catalog returned by DeliveryFeatureCatalogController.getCatalog().
 *               PR 1 is scaffold-only; PR 2 wires enable/disable toggles back to
 *               DeliveryHubSettings__c Enable*DateTime__c fields.
 * @author Cloud Nimbus LLC
 */
import { LightningElement, wire, track } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import getCatalog from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryFeatureCatalogController.getCatalog';

const DESCRIPTION_TRUNCATE_AT = 140,
    ELLIPSIS = '…',
    EMPTY = 0;

export default class DeliveryFeatureCockpit extends LightningElement {
    @track features = [];
    @track errorMessage = '';
    @track isLoaded = false;

    wiredResult;

    @wire(getCatalog)
    wiredCatalog(result) {
        this.wiredResult = result;
        if (result.data) {
            this.features = (result.data || []).map((f, idx) => {
                const description = f.description || '';
                const truncated = description.length > DESCRIPTION_TRUNCATE_AT
                    ? description.substring(0, DESCRIPTION_TRUNCATE_AT) + ELLIPSIS
                    : description;
                return {
                    key: f.name || `feature-${idx}`,
                    name: f.name,
                    label: f.label || f.name,
                    description,
                    truncatedDescription: truncated,
                    category: f.category || '',
                    maturity: f.maturity || '',
                    icon: f.icon || 'standard:default',
                    isActive: f.isActive === true,
                    settingsFieldApiName: f.settingsFieldApiName || '',
                    docsUrl: f.docsUrl || '',
                    hasDocsUrl: !!f.docsUrl,
                    hasSettingsField: !!f.settingsFieldApiName,
                    statusBadgeClass: f.isActive === true
                        ? 'slds-badge slds-theme_success'
                        : 'slds-badge slds-theme_shade',
                    statusBadgeText: f.isActive === true ? 'Active' : 'Inactive',
                    categoryBadgeClass: 'slds-badge slds-badge_lightest',
                    maturityBadgeClass: f.maturity === 'Beta' || f.maturity === 'Alpha'
                        ? 'slds-badge slds-theme_warning'
                        : 'slds-badge slds-badge_lightest'
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

    handleRefresh() {
        if (this.wiredResult) {
            refreshApex(this.wiredResult);
        }
    }
}

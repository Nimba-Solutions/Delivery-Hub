/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Settings card that lets an admin hide individual home-page LWC widgets
 *               from the Delivery Hub app Home page, so the Home page only surfaces what
 *               works. Each toggle is "Show on Home" — ON = shown (safe default), OFF =
 *               hidden. Fully reversible. Backed by inverted HideHome…DateTime__c fields on
 *               DeliveryHubSettings__c via DeliveryHomeVisibilityController. Composed into
 *               deliverySettingsContainer (not exposed standalone).
 * @author       Cloud Nimbus LLC
 */
import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getHiddenHomeComponents from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryHomeVisibilityController.getHiddenHomeComponents';
import setHiddenHomeComponents from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryHomeVisibilityController.setHiddenHomeComponents';

// The 6 hideable home-page components, in display order. Keys MUST match both the
// LWC component names and the keys DeliveryHomeVisibilityController emits.
const COMPONENTS = [
    {
        key: 'deliveryGettingStarted',
        label: 'Getting Started Wizard',
        help: 'The guided onboarding / connection wizard.'
    },
    {
        key: 'deliveryHubSetup',
        label: 'Delivery Hub Setup',
        help: 'The connection-setup / quickstart card.'
    },
    {
        key: 'deliveryBudgetSummary',
        label: 'Budget Summary (System Pulse)',
        help: 'Month-over-month hours, active work items, and connection health.'
    },
    {
        key: 'deliveryExecutiveDashboard',
        label: 'Executive Dashboard',
        help: 'The Custom-Metadata-driven dashboard cards.'
    },
    {
        key: 'deliveryFeatureApprovalInbox',
        label: 'Pending Approvals Inbox',
        help: 'Feature-toggle approval requests assigned to the running user.'
    },
    {
        key: 'deliveryPacingForecast',
        label: 'Portfolio Pacing & Forecast',
        help: 'Logged hours, amortized target, and run-rate forecast.'
    }
];

export default class DeliveryHomeVisibilitySettingsCard extends LightningElement {
    @track hiddenMap = {};
    isLoading = true;

    connectedCallback() {
        this.loadVisibility();
    }

    async loadVisibility() {
        try {
            const map = await getHiddenHomeComponents();
            this.hiddenMap = map || {};
        } catch (error) {
            this.showToast('Error Loading Home Visibility', error.body ? error.body.message : error.message, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    // Build the render model. Each toggle is "Show on Home": checked = shown = NOT hidden.
    get toggles() {
        return COMPONENTS.map((c) => ({
            key: c.key,
            label: c.label,
            help: c.help,
            shown: this.hiddenMap[c.key] !== true
        }));
    }

    async handleToggle(event) {
        const key = event.target.dataset.key;
        const shown = event.target.checked; // ON = show on Home
        const previous = { ...this.hiddenMap };
        // Optimistically reflect the new state, then persist.
        const next = { ...this.hiddenMap, [key]: !shown };
        this.hiddenMap = next;
        try {
            const fresh = await setHiddenHomeComponents({ hidden: next });
            this.hiddenMap = fresh || next;
        } catch (error) {
            // Revert on failure — the bound getter resets the toggle DOM.
            this.hiddenMap = previous;
            this.showToast('Error Saving Home Visibility', error.body ? error.body.message : error.message, 'error');
        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}

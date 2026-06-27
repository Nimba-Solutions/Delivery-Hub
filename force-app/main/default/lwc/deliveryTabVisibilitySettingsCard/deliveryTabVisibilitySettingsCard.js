/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Settings card that lets an admin hide individual non-admin sub-tabs of the
 *               Delivery Hub workspace ("Delivery") tab, so the workspace only surfaces what
 *               the org uses. Each toggle is "Show in Delivery tab" — ON = shown (safe
 *               default), OFF = hidden. Fully reversible. Backed by inverted
 *               HideTab…DateTime__c fields on DeliveryHubSettings__c via
 *               DeliveryTabVisibilityController. The 5 admin-only tabs
 *               (Templates/Analytics/Velocity/Settings/Workflows) are gated separately and
 *               are intentionally not listed here. Composed into deliverySettingsContainer
 *               (not exposed standalone).
 * @author       Cloud Nimbus LLC
 */
import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getHiddenWorkspaceTabs from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryTabVisibilityController.getHiddenWorkspaceTabs';
import setHiddenWorkspaceTabs from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryTabVisibilityController.setHiddenWorkspaceTabs';

// The 10 hideable workspace sub-tabs, in display order. Keys MUST match both the
// tab values in deliveryHubWorkspace and the keys DeliveryTabVisibilityController emits.
const TABS = [
    {
        key: 'intake',
        label: 'Intake',
        help: 'Front-of-pipe queue of inbound work awaiting triage.'
    },
    {
        key: 'board',
        label: 'Board',
        help: 'The Kanban work board.'
    },
    {
        key: 'newRequest',
        label: 'New Request',
        help: 'The embedded quick-request intake form.'
    },
    {
        key: 'timeline',
        label: 'Timeline',
        help: 'The pro-forma Gantt timeline.'
    },
    {
        key: 'activity',
        label: 'Activity',
        help: 'The activity feed.'
    },
    {
        key: 'documents',
        label: 'Documents',
        help: 'The document viewer.'
    },
    {
        key: 'guide',
        label: 'Guide',
        help: 'The in-app guide.'
    },
    {
        key: 'approvals',
        label: 'Approvals',
        help: 'The approval summary card and pending-approval queue.'
    },
    {
        key: 'closeouts',
        label: 'Close Outs',
        help: 'Deployed-to-Prod items awaiting close-out verification.'
    },
    {
        key: 'forecast',
        label: 'Forecast',
        help: 'The buyer-facing capacity / "you set the pace" forecast.'
    }
];

export default class DeliveryTabVisibilitySettingsCard extends LightningElement {
    @track hiddenMap = {};
    isLoading = true;

    connectedCallback() {
        this.loadVisibility();
    }

    async loadVisibility() {
        try {
            const map = await getHiddenWorkspaceTabs();
            this.hiddenMap = map || {};
        } catch (error) {
            this.showToast('Error Loading Delivery Visibility', error.body ? error.body.message : error.message, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    // Build the render model. Each toggle is "Show in Delivery tab": checked = shown = NOT hidden.
    get toggles() {
        return TABS.map((t) => ({
            key: t.key,
            label: t.label,
            help: t.help,
            shown: this.hiddenMap[t.key] !== true
        }));
    }

    async handleToggle(event) {
        const key = event.target.dataset.key;
        const shown = event.target.checked; // ON = show in Delivery tab
        const previous = { ...this.hiddenMap };
        // Optimistically reflect the new state, then persist.
        const next = { ...this.hiddenMap, [key]: !shown };
        this.hiddenMap = next;
        try {
            const fresh = await setHiddenWorkspaceTabs({ hidden: next });
            this.hiddenMap = fresh || next;
        } catch (error) {
            // Revert on failure — the bound getter resets the toggle DOM.
            this.hiddenMap = previous;
            this.showToast('Error Saving Delivery Visibility', error.body ? error.body.message : error.message, 'error');
        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}

/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Unified workspace shell combining Board, Timeline, Activity, Documents,
 *               Guide, Settings, and Workflows tabs into a single tabbed experience.
 *               Mounts on AppPage / HomePage / Tab. Wires
 *               DeliveryHubDashboardController.isAdminUser to gate admin-only tabs, and
 *               DeliveryTabVisibilityController.getHiddenWorkspaceTabs to let an org hide
 *               individual non-admin sub-tabs (Settings → Delivery Visibility). Pure
 *               layout — each child LWC owns its own data lifecycle.
 * @author       Cloud Nimbus LLC
 */
import { LightningElement, track, wire } from 'lwc';
import isAdminUser from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryHubDashboardController.isAdminUser';
import getHiddenWorkspaceTabs from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryTabVisibilityController.getHiddenWorkspaceTabs';

// The 10 toggleable non-admin tabs, in render order. Used to fall back to the first
// VISIBLE tab when the would-be active tab is hidden (item 4 of the visibility feature).
const TAB_ORDER = [
    'intake',
    'board',
    'huddle',
    'newRequest',
    'timeline',
    'activity',
    'documents',
    'guide',
    'approvals',
    'closeouts',
    'forecast'
];
// Admin-only tabs are never hideable, so they are always candidates when isAdmin.
const ADMIN_TAB_ORDER = ['templates', 'analytics', 'velocity', 'settings', 'workflows'];

export default class DeliveryHubWorkspace extends LightningElement {
    // Intake is the default landing tab: it's the front-of-pipe queue where the
    // urgent, just-arrived work sits, so the triager opens straight onto it.
    // Buyers (non-admins) are redirected to Approvals below — Intake reads empty
    // for them since the Apex scopes it to triagers.
    @track activeTab = 'intake';
    @track isAdmin = false;
    // tab value → isHidden. Empty until the wire returns → every tab shown by default.
    @track hiddenTabs = {};
    _userPicked = false;
    // Tells the embedded Quick Request component to reset-in-place on submit
    // rather than fire CloseActionScreenEvent (which only applies in the global
    // action modal). Bound as a property so the boolean reaches the child as true.
    requestEmbedded = true;

    @wire(isAdminUser)
    wiredAdmin({ data }) {
        if (data === true || data === false) {
            this.isAdmin = data;
            this.resolveActiveTab();
        }
    }

    @wire(getHiddenWorkspaceTabs)
    wiredHiddenTabs({ data }) {
        if (data) {
            this.hiddenTabs = data;
            this.resolveActiveTab();
        }
    }

    // Per-tab visibility getters — a tab shows unless its map entry is explicitly true,
    // so the workspace opens fully populated before the wire resolves (safe default).
    get showIntake() {
        return !this.isHidden('intake');
    }
    get showBoard() {
        return !this.isHidden('board');
    }
    get showHuddle() {
        return !this.isHidden('huddle');
    }
    get showNewRequest() {
        return !this.isHidden('newRequest');
    }
    get showTimeline() {
        return !this.isHidden('timeline');
    }
    get showActivity() {
        return !this.isHidden('activity');
    }
    get showDocuments() {
        return !this.isHidden('documents');
    }
    get showGuide() {
        return !this.isHidden('guide');
    }
    get showApprovals() {
        return !this.isHidden('approvals');
    }
    get showCloseouts() {
        return !this.isHidden('closeouts');
    }
    get showForecast() {
        return !this.isHidden('forecast');
    }

    isHidden(tabValue) {
        return this.hiddenTabs[tabValue] === true;
    }

    // Keep the active tab on something the user can actually see. Buyers land on
    // Approvals — the actionable surface for the approver persona; admins/devs keep
    // Intake. If that desired tab has been hidden by the org, fall back to the first
    // VISIBLE tab so the workspace never opens on a hidden/blank tab. Only applies
    // before the user has picked a tab themselves. Idempotent — both wires call it.
    resolveActiveTab() {
        if (this._userPicked) {
            return;
        }
        const desired = this.isAdmin ? 'intake' : 'approvals';
        if (!this.isHidden(desired)) {
            this.activeTab = desired;
            return;
        }
        const visible = TAB_ORDER.filter((t) => !this.isHidden(t)).concat(
            this.isAdmin ? ADMIN_TAB_ORDER : []
        );
        // Degenerate edge: a buyer org hid all 10 tabs → nothing visible; leave on
        // Intake (blank) rather than engineer around an admin hiding everything.
        this.activeTab = visible.length ? visible[0] : 'intake';
    }

    handleTabChange(event) {
        this._userPicked = true;
        this.activeTab = event.target.value;
    }
}

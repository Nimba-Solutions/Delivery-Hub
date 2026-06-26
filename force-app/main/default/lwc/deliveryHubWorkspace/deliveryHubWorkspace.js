/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Unified workspace shell combining Board, Timeline, Activity, Documents,
 *               Guide, Settings, and Workflows tabs into a single tabbed experience.
 *               Mounts on AppPage / HomePage / Tab. Wires
 *               DeliveryHubDashboardController.isAdminUser to gate admin-only tabs.
 *               Pure layout — each child LWC owns its own data lifecycle.
 * @author       Cloud Nimbus LLC
 */
import { LightningElement, track, wire } from 'lwc';
import isAdminUser from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryHubDashboardController.isAdminUser';

export default class DeliveryHubWorkspace extends LightningElement {
    @track activeTab = 'board';
    @track isAdmin = false;
    _userPicked = false;
    // Tells the embedded Quick Request component to reset-in-place on submit
    // rather than fire CloseActionScreenEvent (which only applies in the global
    // action modal). Bound as a property so the boolean reaches the child as true.
    requestEmbedded = true;

    @wire(isAdminUser)
    wiredAdmin({ data }) {
        if (data === true || data === false) {
            this.isAdmin = data;
            // Buyers (non-admins) land on Approvals — the actionable surface for the
            // approver persona — so the Delivery tab opens useful instead of on the
            // client-filtered Board (which reads empty for a buyer). Admins/devs keep
            // Board. Only applies before the user has picked a tab themselves.
            if (!this._userPicked && data === false) {
                this.activeTab = 'approvals';
            }
        }
    }

    handleTabChange(event) {
        this._userPicked = true;
        this.activeTab = event.target.value;
    }
}

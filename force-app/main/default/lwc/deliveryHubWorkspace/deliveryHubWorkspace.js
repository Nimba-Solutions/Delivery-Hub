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

    @wire(isAdminUser)
    wiredAdmin({ data }) {
        if (data === true || data === false) {
            this.isAdmin = data;
        }
    }

    handleTabChange(event) {
        this.activeTab = event.target.value;
    }
}

import { LightningElement, wire, track } from 'lwc';
import isAdminUser from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryHubDashboardController.isAdminUser';

export default class DeliveryHubWorkspace extends LightningElement {
    @track activeTab = 'board';
    @track isAdmin = false;

    @wire(isAdminUser)
    wiredAdmin({ data }) {
        if (data !== undefined) {
            this.isAdmin = data;
        }
    }

    handleTabChange(event) {
        this.activeTab = event.target.value;
    }
}

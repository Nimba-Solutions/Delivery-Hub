import { LightningElement, track, wire } from 'lwc';
import getSetupStatus from '@salesforce/apex/HubSetupController.getSetupStatus';
import connectToDefaultMothership from '@salesforce/apex/HubSetupController.connectToDefaultMothership';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';

export default class DeliveryHubSetup extends NavigationMixin(LightningElement) {
    @track status = { isConnected: false, requiredRemoteSite: '', entity: {} };
    @track isLoading = true;

    // Load Status
    @wire(getSetupStatus)
    wiredStatus({ error, data }) {
        this.isLoading = false;
        if (data) {
            this.status = data;
        } else if (error) {
            this.showToast('Error', 'Could not load setup status.', 'error');
        }
    }

    handleConnect() {
        this.isLoading = true;
        connectToDefaultMothership()
            .then(() => {
                this.showToast('Success', 'Connection established successfully!', 'success');
                // Force a refresh of the wire adapter by calling the Apex method imperatively
                return getSetupStatus(); 
            })
            .then((data) => {
                this.status = data;
            })
            .catch(error => {
                this.showToast('Connection Failed', error.body ? error.body.message : error.message, 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    navigateToRequests() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: {
                objectApiName: 'Request__c',
                actionName: 'list'
            },
            state: {
                filterName: 'Recent'
            }
        });
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
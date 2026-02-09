import { LightningElement, track, wire } from 'lwc';
import getSetupStatus from '@salesforce/apex/DeliveryHubSetupController.getSetupStatus';
import connectToDefaultMothership from '@salesforce/apex/DeliveryHubSetupController.connectToDefaultMothership';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import { refreshApex } from '@salesforce/apex'; 

export default class DeliveryHubSetup extends NavigationMixin(LightningElement) {
    @track status = { isConnected: false, requiredRemoteSite: '', entity: {} };
    @track isLoading = true;
    
    wiredStatusResult;

    // Hard-coded check: If URL matches Mothership, return TRUE
    get isMothership() {
        return window.location.hostname.includes('orgfarm-928a77dfd6-dev-ed');
    }

    @wire(getSetupStatus)
    wiredStatus(result) {
        this.wiredStatusResult = result; 
        const { data, error } = result;
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
                this.showToast('Success', 'Connection established!', 'success');
                return refreshApex(this.wiredStatusResult); 
            })
            .catch(error => {
                this.showToast('Connection Failed', error.body ? error.body.message : error.message, 'error');
                this.isLoading = false;
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    navigateToTickets() {
        this[NavigationMixin.Navigate]({
            type: 'standard__navItemPage',
            attributes: { apiName: 'draganddroplwc' }
        });
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
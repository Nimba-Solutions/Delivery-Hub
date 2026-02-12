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

    /**
     * @description Dynamically determines if this org is the Mothership by comparing 
     * current hostname against the endpoint defined in Custom Metadata.
     */
    get isMothership() {
        if (!this.status || !this.status.requiredRemoteSite) {
            return false;
        }
        try {
            // Compare the current browser hostname to the hostname in the metadata URL
            const mothershipHost = new URL(this.status.requiredRemoteSite).hostname;
            return window.location.hostname.includes(mothershipHost);
        } catch (e) {
            // Fallback for malformed URLs
            return false;
        }
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
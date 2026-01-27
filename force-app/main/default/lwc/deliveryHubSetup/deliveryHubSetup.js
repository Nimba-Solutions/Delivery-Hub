import { LightningElement, track, wire } from 'lwc';
import getSetupStatus from '@salesforce/apex/DeliveryHubSetupController.getSetupStatus';
import connectToDefaultMothership from '@salesforce/apex/DeliveryHubSetupController.connectToDefaultMothership';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import { refreshApex } from '@salesforce/apex'; // 1. Import refreshApex

export default class DeliveryHubSetup extends NavigationMixin(LightningElement) {
    @track status = { isConnected: false, requiredRemoteSite: '', entity: {} };
    @track isLoading = true;
    
    // Store the wired result so we can refresh it later
    wiredStatusResult;

    // Load Status
    @wire(getSetupStatus)
    wiredStatus(result) {
        this.wiredStatusResult = result; // 2. Cache the result for refreshing
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
                this.showToast('Success', 'Connection established successfully!', 'success');
                // 3. Force the UI to update immediately
                return refreshApex(this.wiredStatusResult); 
            })
            .catch(error => {
                this.showToast('Connection Failed', error.body ? error.body.message : error.message, 'error');
                this.isLoading = false;
            })
            .finally(() => {
                // If refreshApex finishes fast, we ensure spinner stops
                this.isLoading = false;
            });
    }

    navigateToTickets() {
        this[NavigationMixin.Navigate]({
            type: 'standard__navItemPage',
            attributes: {
                // The API Name of the tab from your URL: /lightning/n/draganddroplwc
                apiName: 'draganddroplwc'
            }
        });
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
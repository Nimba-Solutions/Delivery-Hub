/**
 * @author Cloud Nimbus LLC
 */
import { LightningElement, track, wire } from 'lwc';
import getSetupStatus from '@salesforce/apex/DeliveryHubSetupController.getSetupStatus';
// Updated imports to support the two-step transaction flow
import prepareLocalEntity from '@salesforce/apex/DeliveryHubSetupController.prepareLocalEntity';
import performHandshake from '@salesforce/apex/DeliveryHubSetupController.performHandshake';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import { refreshApex } from '@salesforce/apex'; 

export default class DeliveryHubSetup extends NavigationMixin(LightningElement) {
    @track status = { isConnected: false, requiredRemoteSite: '', entity: {} };
    @track isLoading = true;
    
    wiredStatusResult;

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

    /**
     * Handshake logic split into two steps to bypass "Uncommitted Work Pending" 
     * and ensure the Local Entity ID exists before the Mothership receives the packet.
     */
    handleConnect() {
        if (this.isLoading) return;

        this.isLoading = true;
        
        // STEP 1: Create/Upsert the local record and get the ID (Transaction 1)
        prepareLocalEntity()
            .then(entity => {
                // STEP 2: Use that ID to perform the handshake callout (Transaction 2)
                return performHandshake({ localEntityId: entity.Id });
            })
            .then(() => {
                this.showToast('Success', 'Connection established!', 'success');
                // Refresh the @wire data to show the connected status and IDs
                return refreshApex(this.wiredStatusResult); 
            })
            .catch(error => {
                console.error('Handshake Error:', error);
                const message = error.body ? error.body.message : error.message;
                this.showToast('Connection Failed', message, 'error');
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
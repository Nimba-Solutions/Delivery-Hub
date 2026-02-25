/**
 * @author Cloud Nimbus LLC
 */
import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getSetupStatus from '@salesforce/apex/DeliveryHubSetupController.getSetupStatus';

export default class DeliveryGettingStarted extends LightningElement {
    @track isExpanded = false;
    @track isCheckingConnection = false;

    get rootClass() {
        return 'gs-root' + (this.isExpanded ? ' gs-root--expanded' : '');
    }

    get chevronIcon() {
        return this.isExpanded ? 'utility:chevronup' : 'utility:chevrondown';
    }

    handleToggle() {
        this.isExpanded = !this.isExpanded;
    }

    handleKeydown(event) {
        if (event.key === 'Enter' || event.key === ' ') {
            event.preventDefault();
            this.handleToggle();
        }
    }

    handleCheckConnection() {
        this.isCheckingConnection = true;
        getSetupStatus()
            .then(status => {
                if (status && status.isConnected && status.entity) {
                    this.dispatchEvent(new ShowToastEvent({
                        title: 'Connected',
                        message: `Your portal is connected to ${status.entity.Name}.`,
                        variant: 'success'
                    }));
                } else {
                    this.dispatchEvent(new ShowToastEvent({
                        title: 'Not Connected',
                        message: 'No active vendor connection found. Contact your administrator to complete setup.',
                        variant: 'warning'
                    }));
                }
            })
            .catch(() => {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Connection Check Failed',
                    message: 'Could not verify connection status. Please try again.',
                    variant: 'error'
                }));
            })
            .finally(() => { this.isCheckingConnection = false; });
    }
}

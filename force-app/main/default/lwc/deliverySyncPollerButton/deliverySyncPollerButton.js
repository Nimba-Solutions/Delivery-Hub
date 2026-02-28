/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @author Cloud Nimbus LLC
 */
import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { RefreshEvent } from 'lightning/refresh';
import triggerPoll from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryHubPollerController.triggerPoll';

export default class DeliverySyncPollerButton extends LightningElement {
    @api recordId; // Allows it to sit on a record page seamlessly
    isPolling = false;

    // This fires automatically the millisecond the component loads on the page
    connectedCallback() {
        this.executeSync(true);
    }

    // This fires when you manually click the button
    handleManualPoll() {
        this.executeSync(false);
    }

    executeSync(isAuto) {
        if (this.isPolling) return;
        this.isPolling = true;

        triggerPoll()
            .then(() => {
                // Force standard Salesforce components to refresh their data (like Comments)
                this.dispatchEvent(new RefreshEvent());
                
                // Only show the success toast if they manually clicked it (avoids spam on page load)
                if (!isAuto) {
                    this.dispatchEvent(
                        new ShowToastEvent({
                            title: 'Success',
                            message: 'Updates pulled successfully.',
                            variant: 'success'
                        })
                    );
                }
            })
            .catch((error) => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Sync Failed',
                        message: error.body ? error.body.message : 'Unknown error occurred.',
                        variant: 'error'
                    })
                );
            })
            .finally(() => {
                this.isPolling = false;
            });
    }
}
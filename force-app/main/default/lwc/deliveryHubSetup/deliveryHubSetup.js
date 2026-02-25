/**
 * @author Cloud Nimbus LLC
 */
import { LightningElement, api, track, wire } from 'lwc';
import getSetupStatus from '@salesforce/apex/DeliveryHubSetupController.getSetupStatus';
import prepareLocalEntity from '@salesforce/apex/DeliveryHubSetupController.prepareLocalEntity';
import performHandshake from '@salesforce/apex/DeliveryHubSetupController.performHandshake';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';

export default class DeliveryHubSetup extends LightningElement {
    /** When true, shows a persistent connected-state card after setup completes.
     *  Set to true on the admin home; leave false on the client home so the
     *  component disappears silently once the org is connected. */
    @api showConnectedState = false;

    @track status = { isConnected: false, isMothership: false, requiredRemoteSite: '', entity: {} };
    @track isLoading = true;
    @track isConnecting = false;
    @track connectingStep = '';

    _wiredStatusResult;

    @wire(getSetupStatus)
    wiredStatus(result) {
        this._wiredStatusResult = result;
        const { data, error } = result;
        this.isLoading = false;
        if (data) {
            this.status = data;
        } else if (error) {
            this.showToast('Error', 'Could not load setup status.', 'error');
        }
    }

    get isVisible() {
        if (this.status.isConnected && !this.showConnectedState) return false;
        return true;
    }

    get entityStatus() {
        return this.status.entity && this.status.entity.StatusPk__c
            ? this.status.entity.StatusPk__c
            : 'Active';
    }

    handleConnect() {
        if (this.isConnecting) return;
        this.isConnecting = true;
        this.connectingStep = 'Registering your org\u2026';

        prepareLocalEntity()
            .then(entity => {
                this.connectingStep = 'Establishing connection\u2026';
                return performHandshake({ localEntityId: entity.Id });
            })
            .then(() => {
                this.connectingStep = '';
                this.showToast('Connected!', 'Your org is now linked to Cloud Nimbus LLC.', 'success');
                return refreshApex(this._wiredStatusResult);
            })
            .catch(error => {
                const message = error.body ? error.body.message : error.message;
                this.showToast('Connection Failed', message, 'error');
            })
            .finally(() => {
                this.isConnecting = false;
                this.connectingStep = '';
            });
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}

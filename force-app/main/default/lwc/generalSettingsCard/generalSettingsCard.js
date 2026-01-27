import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getSettings from '@salesforce/apex/DeliveryHubSettingsController.getSettings';
import saveGeneralSettings from '@salesforce/apex/DeliveryHubSettingsController.saveGeneralSettings';

export default class GeneralSettingsCard extends LightningElement {
    @track notifications = false;
    @track autoCreateRequest = true; 
    @track autoSendRequest = true;
    
    isLoading = true;

    connectedCallback() {
        this.loadSettings();
    }

    async loadSettings() {
        try {
            const data = await getSettings(); 
            if (data) {
                this.notifications = data.enableNotifications || false;
                
                // Safe checks for the new booleans
                if (data.autoCreateRequest !== undefined) this.autoCreateRequest = data.autoCreateRequest;
                if (data.autoSendRequest !== undefined) this.autoSendRequest = data.autoSendRequest;
            }
        } catch (error) {
            this.showToast('Error', 'Could not load settings', 'error');
        } finally {
            this.isLoading = false;
        }
    }

    handleNotificationsToggle(event) {
        this.notifications = event.target.checked;
        this.saveState();
    }

    handleAutoCreateToggle(event) {
        this.autoCreateRequest = event.target.checked;
        this.saveState();
    }

    handleAutoSendToggle(event) {
        this.autoSendRequest = event.target.checked;
        this.saveState();
    }

    async saveState() {
        try {
            await saveGeneralSettings({ 
                enableNotifications: this.notifications,
                autoCreateRequest: this.autoCreateRequest,
                autoSendRequest: this.autoSendRequest
            });
        } catch (error) {
            this.showToast('Error', 'Failed to save settings', 'error');
        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
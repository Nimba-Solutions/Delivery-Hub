// import { LightningElement, track } from 'lwc';

// export default class GeneralSettingsCard extends LightningElement {
//     @track theme = 'light';
//     @track notifications = true;
//     @track autoSave = true;

//     get themeOptions() {
//         return [
//             { label: 'Light', value: 'light' },
//             { label: 'Dark', value: 'dark' },
//             { label: 'System', value: 'system' }
//         ];
//     }

//     get currentDate() {
//         return new Date().toLocaleDateString();
//     }

//     handleThemeChange(event) {
//         this.theme = event.detail.value;
//         // Here you would typically save to custom settings or custom metadata
//         this.saveSettings();
//     }

//     handleNotificationsChange(event) {
//         this.notifications = event.target.checked;
//         this.saveSettings();
//     }

//     handleAutoSaveChange(event) {
//         this.autoSave = event.target.checked;
//         this.saveSettings();
//     }

//     saveSettings() {
//         // Implementation to save settings to Salesforce
//         // This could use custom settings, custom metadata, or custom objects
//         console.log('Saving general settings:', {
//             theme: this.theme,
//             notifications: this.notifications,
//             autoSave: this.autoSave
//         });
//     }

//     connectedCallback() {
//         // Load existing settings when component initializes
//         this.loadSettings();
//     }

//     loadSettings() {
//         // Implementation to load settings from Salesforce
//         // This would typically call an Apex method
//         console.log('Loading general settings...');
//     }
// }

import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getSettings from '@salesforce/apex/DH_DeliveryHubSettingsController.getSettings';
import saveGeneralSettings from '@salesforce/apex/DH_DeliveryHubSettingsController.saveGeneralSettings';

export default class GeneralSettingsCard extends LightningElement {
    @track notifications = false;
    isLoading = true;

    @wire(getSettings)
    wiredSettings({ error, data }) {
        this.isLoading = false;
        if (data) {
            this.notifications = data.enableNotifications || false;
        } else if (error) {
            this.showToast('Error Loading Settings', error.body.message, 'error');
        }
    }

    async handleNotificationsToggle(event) {
        this.notifications = event.target.checked;
        try {
            await saveGeneralSettings({ enableNotifications: this.notifications });
        } catch (error) {
            this.showToast('Error Saving Settings', error.body.message, 'error');
            // Revert the toggle on error
            this.notifications = !this.notifications;
        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
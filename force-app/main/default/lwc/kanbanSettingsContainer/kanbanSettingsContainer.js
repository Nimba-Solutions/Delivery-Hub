import { LightningElement, track, wire } from 'lwc';
import getSettings from '@salesforce/apex/KanbanSettingsController.getSettings';
import saveSettings from '@salesforce/apex/KanbanSettingsController.saveSettings';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class KanbanSettingsContainer extends LightningElement {
    @track currentSettings;
    @track initialSettings;
    error;

    @wire(getSettings)
    wiredSettings({ error, data }) {
        if (data) {
            this.currentSettings = JSON.parse(JSON.stringify(data));
            this.initialSettings = JSON.parse(JSON.stringify(data));
            this.error = undefined;
        } else if (error) {
            this.error = error;
            this.currentSettings = undefined;
        }
    }

    handleSettingsChange(event) {
        const { field, value } = event.detail;
        // The field name from detail should match the property in currentSettings
        if (this.currentSettings.hasOwnProperty(field)) {
            this.currentSettings[field] = value;
        }
    }

    async handleSave() {
        try {
            await saveSettings({ settingsJson: JSON.stringify(this.currentSettings) });
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Success',
                    message: 'Settings saved successfully.',
                    variant: 'success',
                })
            );
            // Refresh the initial state to the new saved state
            this.initialSettings = JSON.parse(JSON.stringify(this.currentSettings));
        } catch (error) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error Saving Settings',
                    message: error.body.message,
                    variant: 'error',
                })
            );
        }
    }
}
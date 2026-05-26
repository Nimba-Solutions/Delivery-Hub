/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Tabbed settings container scoped to the Kanban board AI configuration.
 *               Mounts on AppPage / RecordPage / HomePage / Tab. Wires
 *               DeliveryHubSettingsController.getSettings, distributes the snapshot to child
 *               cards (AI features + OpenAI), and batches a single saveAllAiSettings round-trip
 *               on Save. Use this when AI config needs to be edited outside the global
 *               deliverySettingsContainer (e.g. on a board-focused admin page).
 * @author       Cloud Nimbus LLC
 */
import { LightningElement, track, wire } from 'lwc';
import getSettings from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryHubSettingsController.getSettings';
import saveSettings from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryHubSettingsController.saveAllAiSettings';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class DeliveryKanbanSettingsContainer extends LightningElement {
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
                    message: error.body ? error.body.message : error.message,
                    variant: 'error',
                })
            );
        }
    }
}
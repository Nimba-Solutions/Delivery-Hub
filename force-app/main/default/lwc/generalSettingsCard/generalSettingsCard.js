import { LightningElement, track } from 'lwc';

export default class GeneralSettingsCard extends LightningElement {
    @track theme = 'light';
    @track notifications = true;
    @track autoSave = true;

    get themeOptions() {
        return [
            { label: 'Light', value: 'light' },
            { label: 'Dark', value: 'dark' },
            { label: 'System', value: 'system' }
        ];
    }

    get currentDate() {
        return new Date().toLocaleDateString();
    }

    handleThemeChange(event) {
        this.theme = event.detail.value;
        // Here you would typically save to custom settings or custom metadata
        this.saveSettings();
    }

    handleNotificationsChange(event) {
        this.notifications = event.target.checked;
        this.saveSettings();
    }

    handleAutoSaveChange(event) {
        this.autoSave = event.target.checked;
        this.saveSettings();
    }

    saveSettings() {
        // Implementation to save settings to Salesforce
        // This could use custom settings, custom metadata, or custom objects
        console.log('Saving general settings:', {
            theme: this.theme,
            notifications: this.notifications,
            autoSave: this.autoSave
        });
    }

    connectedCallback() {
        // Load existing settings when component initializes
        this.loadSettings();
    }

    loadSettings() {
        // Implementation to load settings from Salesforce
        // This would typically call an Apex method
        console.log('Loading general settings...');
    }
}
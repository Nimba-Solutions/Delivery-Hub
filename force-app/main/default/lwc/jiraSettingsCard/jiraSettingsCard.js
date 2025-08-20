import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getSettings from '@salesforce/apex/DeliveryHubSettingsController.getSettings';
import saveJiraSettings from '@salesforce/apex/DeliveryHubSettingsController.saveJiraSettings';
import testJiraConnectionApex from '@salesforce/apex/DeliveryHubSettingsController.testJiraConnection';
import saveJiraEnabledState from '@salesforce/apex/DeliveryHubSettingsController.saveJiraEnabledState';

export default class JiraSettingCard extends LightningElement {
    // --- Tracked Properties for Settings ---
    @track jiraEnabled = false;
    @track jiraInstanceUrl = '';
    @track jiraUsername = '';
    @track jiraApiToken = '';
    @track jiraProjectKey = '';

    // --- Properties for UI State ---
    @track isLoading = true;
    @track showApiToken = false;
    @track isTestingConnection = false;
    @track testResult = null;
    @track isConnectionVerified = false;

    // --- Wired Apex ---
    @wire(getSettings)
    wiredSettings({ error, data }) {
        this.isLoading = false;
        if (data) {
            this.jiraEnabled = data.jiraEnabled || false;
            this.jiraInstanceUrl = data.jiraInstanceUrl;
            this.jiraUsername = data.jiraUsername;
            this.jiraApiToken = data.jiraApiToken;
            this.jiraProjectKey = data.jiraProjectKey;
            this.isConnectionVerified = data.Jira_Api_tested__c || false;
        } else if (error) {
            this.showToast('Error Loading JIRA Settings', error.body?.message || error.message, 'error');
        }
    }

    // --- Getters for Dynamic UI ---
    
    get apiTokenInputType() {
        return this.showApiToken ? 'text' : 'password';
    }

    get eyeIconName() {
        return this.showApiToken ? 'utility:hide' : 'utility:preview';
    }

    get testButtonLabel() {
        return this.isTestingConnection ? 'Testing...' : 'Test';
    }

    get isTestButtonDisabled() {
        return !this.jiraEnabled || !this.jiraInstanceUrl || !this.jiraUsername || !this.jiraApiToken || !this.jiraProjectKey || this.isTestingConnection;
    }

    get isSaveButtonDisabled() {
        if (!this.jiraEnabled) {
            return true; 
        }
        return !this.isConnectionVerified;
    }

    get showSuccessAlert() {
        return this.testResult === 'success';
    }

    get showErrorAlert() {
        return this.testResult === 'error';
    }
    
    get allInputDisabled() {
        return !this.jiraEnabled;
    }

    // --- Handlers for User Actions ---

    handleInputChange(event) {
        const { name, value } = event.target;
        
        if (name === 'jiraProjectKey') {
            this[name] = value.toUpperCase();
        } else {
            this[name] = value;
        }
        this.testResult = null;
        this.isConnectionVerified = false;
    }
    
    async handleJiraEnabled(event) {
        this.jiraEnabled = event.target.checked;
        this.testResult = null;
        this.isConnectionVerified = false;

        this.isLoading = true;
        try {
            await saveJiraEnabledState({ enabled: this.jiraEnabled });
            const status = this.jiraEnabled ? 'enabled' : 'disabled';
            this.showToast('Status Updated', `JIRA integration has been ${status}.`, 'success');
        } catch (error) {
            this.showToast('Error Updating Status', error.body?.message || error.message, 'error');
            this.jiraEnabled = !this.jiraEnabled;
        } finally {
            this.isLoading = false;
        }
    }

    toggleApiTokenVisibility() {
        this.showApiToken = !this.showApiToken;
    }

    async testJiraConnection() {
        this.isTestingConnection = true;
        this.testResult = null;
        this.isConnectionVerified = false;

        console.log('jirainstacnceurl '+this.jiraInstanceUrl);

        try {
            const result = await testJiraConnectionApex({
                jiraUrl: this.jiraInstanceUrl,
                username: this.jiraUsername,
                token: this.jiraApiToken,
                projectKey: this.jiraProjectKey
            });

            if (result === 'Success') {
                this.testResult = 'success';
                this.isConnectionVerified = true;
                this.showToast('Success', 'JIRA connection is valid!', 'success');
            } else {
                this.testResult = 'error';
                this.showToast('Connection Failed', result, 'error');
            }
        } catch (error) {
            this.testResult = 'error';
            this.showToast('Connection Error', error.body?.message || error.message, 'error');
        } finally {
            this.isTestingConnection = false;
        }
    }

    // --- MODIFIED: This function now re-fetches settings from Apex ---
    async resetJiraSettings() {
        if (confirm('Are you sure you want to revert your changes to the last saved configuration?')) {
            this.isLoading = true;
            try {
                // Imperatively call Apex to get the latest saved settings
                const savedData = await getSettings();

                if (savedData) {
                    this.jiraEnabled = savedData.jiraEnabled || false;
                    this.jiraInstanceUrl = savedData.jiraInstanceUrl;
                    this.jiraUsername = savedData.jiraUsername;
                    this.jiraApiToken = savedData.jiraApiToken;
                    this.jiraProjectKey = savedData.jiraProjectKey;
                    this.isConnectionVerified = savedData.Jira_Api_tested__c || false;
                }
                
                // Clear any transient UI state like test alerts
                this.testResult = null;

                this.showToast('Reset Complete', 'Settings have been reverted to the last saved state.', 'success');
            } catch (error) {
                this.showToast('Error Reverting', 'Could not fetch the saved settings. ' + (error.body?.message || error.message), 'error');
            } finally {
                this.isLoading = false;
            }
        }
    }

    openJiraTokenPage() {
        window.open('https://id.atlassian.com/manage-profile/security/api-tokens', '_blank');
    }

    // --- Apex Callouts ---

    async handleSave() {
        this.isLoading = true;
        try {
            await saveJiraSettings({
                enabled: this.jiraEnabled, // Correctly pass the enabled state
                url: this.jiraInstanceUrl,
                username: this.jiraUsername,
                token: this.jiraApiToken,
                projectKey: this.jiraProjectKey,
                isVerified: this.isConnectionVerified
            });
            this.showToast('Success', 'JIRA settings have been saved.', 'success');
        } catch (error) {
            this.showToast('Error Saving', error.body?.message || error.message, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    // --- Utility ---
    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
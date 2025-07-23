import { LightningElement, track } from 'lwc';

export default class JiraSettingsCard extends LightningElement {
    @track jiraEnabled = false;
    @track jiraUrl = '';
    @track jiraUsername = '';
    @track jiraApiToken = '';
    @track jiraProjectKey = '';
    @track showApiToken = false;
    @track isTestingConnection = false;
    @track testResult = null; // 'success', 'error', or null

    get apiTokenInputType() {
        return this.showApiToken ? 'text' : 'password';
    }

    get eyeIconName() {
        return this.showApiToken ? 'utility:hide' : 'utility:preview';
    }

    get isConfigurationComplete() {
        return this.jiraUrl && this.jiraUsername && this.jiraApiToken && this.jiraProjectKey;
    }

    get isTestButtonDisabled() {
        return !this.jiraEnabled || !this.isConfigurationComplete || this.isTestingConnection;
    }

    get showSuccessAlert() {
        return this.testResult === 'success';
    }

    get showErrorAlert() {
        return this.testResult === 'error';
    }

    get testButtonLabel() {
        return this.isTestingConnection ? 'Testing...' : 'Test';
    }

    handleJiraEnabledChange(event) {
        this.jiraEnabled = event.target.checked;
        this.saveSettings();
    }

    handleJiraUrlChange(event) {
        this.jiraUrl = event.target.value;
        this.saveSettings();
    }

    handleJiraUsernameChange(event) {
        this.jiraUsername = event.target.value;
        this.saveSettings();
    }

    handleJiraApiTokenChange(event) {
        this.jiraApiToken = event.target.value;
        this.saveSettings();
    }

    handleJiraProjectKeyChange(event) {
        this.jiraProjectKey = event.target.value.toUpperCase();
        this.saveSettings();
    }

    toggleApiTokenVisibility() {
        this.showApiToken = !this.showApiToken;
    }

    async testJiraConnection() {
        if (!this.isConfigurationComplete) return;
        
        this.isTestingConnection = true;
        this.testResult = null;
        
        try {
            // Mock test - in real implementation, this would call an Apex method
            await new Promise(resolve => setTimeout(resolve, 2000));
            this.testResult = 'success';
        } catch (error) {
            this.testResult = 'error';
        } finally {
            this.isTestingConnection = false;
        }
    }

    resetJiraSettings() {
        this.jiraEnabled = false;
        this.jiraUrl = '';
        this.jiraUsername = '';
        this.jiraApiToken = '';
        this.jiraProjectKey = '';
        this.testResult = null;
        this.saveSettings();
    }

    openJiraTokenPage() {
        window.open('https://id.atlassian.com/manage-profile/security/api-tokens', '_blank');
    }

    saveSettings() {
        // Implementation to save JIRA settings to Salesforce
        console.log('Saving JIRA settings:', {
            jiraEnabled: this.jiraEnabled,
            jiraUrl: this.jiraUrl,
            jiraUsername: this.jiraUsername,
            jiraApiToken: this.jiraApiToken,
            jiraProjectKey: this.jiraProjectKey
        });
    }

    connectedCallback() {
        this.loadSettings();
    }

    loadSettings() {
        // Implementation to load JIRA settings from Salesforce
        console.log('Loading JIRA settings...');
    }
}
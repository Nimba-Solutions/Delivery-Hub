import { LightningElement, track } from 'lwc';

export default class OpenAISettingsCard extends LightningElement {
    @track openaiApiKey = '';
    @track openaiModel = 'gpt-4.1-2025-04-14';
    @track showApiKey = false;
    @track isTestingConnection = false;
    @track testResult = null; // 'success', 'error', or null

    get modelOptions() {
        return [
            { label: 'GPT-4.1 (Recommended)', value: 'gpt-4.1-2025-04-14' },
            { label: 'O3 (Reasoning)', value: 'o3-2025-04-16' },
            { label: 'O4 Mini (Fast)', value: 'o4-mini-2025-04-16' },
            { label: 'GPT-4.1 Mini', value: 'gpt-4.1-mini-2025-04-14' }
        ];
    }

    get apiKeyInputType() {
        return this.showApiKey ? 'text' : 'password';
    }

    get eyeIconName() {
        return this.showApiKey ? 'utility:hide' : 'utility:preview';
    }

    get isTestButtonDisabled() {
        return !this.openaiApiKey || this.isTestingConnection;
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

    handleApiKeyChange(event) {
        this.openaiApiKey = event.target.value;
        this.testResult = null;
        this.saveSettings();
    }

    handleModelChange(event) {
        this.openaiModel = event.detail.value;
        this.saveSettings();
    }

    toggleApiKeyVisibility() {
        this.showApiKey = !this.showApiKey;
    }

    async testConnection() {
        if (!this.openaiApiKey) return;
        
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

    resetSettings() {
        this.openaiApiKey = '';
        this.openaiModel = 'gpt-4.1-2025-04-14';
        this.testResult = null;
        this.saveSettings();
    }

    openOpenAIPlatform() {
        window.open('https://platform.openai.com/api-keys', '_blank');
    }

    saveSettings() {
        // Implementation to save OpenAI settings to Salesforce
        console.log('Saving OpenAI settings:', {
            openaiApiKey: this.openaiApiKey,
            openaiModel: this.openaiModel
        });
    }

    connectedCallback() {
        this.loadSettings();
    }

    loadSettings() {
        // Implementation to load OpenAI settings from Salesforce
        console.log('Loading OpenAI settings...');
    }
}
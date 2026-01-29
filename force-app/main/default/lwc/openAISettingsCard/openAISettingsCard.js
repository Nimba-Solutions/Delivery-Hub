import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getSettings from '@salesforce/apex/DeliveryHubSettingsController.getSettings';
import saveOpenAISettings from '@salesforce/apex/DeliveryHubSettingsController.saveOpenAISettings';
import testOpenAIConnection from '@salesforce/apex/DeliveryHubSettingsController.testOpenAIConnection';

export default class OpenAISettingCard extends LightningElement {
    @track openaiApiKey = '';
    @track openaiModel = '';
    @track isLoading = true;
    @track showApiKey = false;
    @track isTestingConnection = false;
    @track testResult = null; // Can be 'success' or 'error'
    @track apiTested = false;

    // --- REPLACED @wire WITH IMPERATIVE CALL ---
    connectedCallback() {
        this.loadSettings();
    }

    async loadSettings() {
        try {
            const data = await getSettings();
            if (data) {
                this.openaiApiKey = data.openaiApiKey || '';
                this.openaiModel = data.openaiModel || 'gpt-4o-mini';
                this.apiTested = data.openAiApiTested || false;
            }
        } catch (error) {
            this.showToast('Error Loading OpenAI Settings', error.body?.message || error.message, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    handleInputChange(event) {
        const { name, value } = event.target;
        this[name] = value;
        // When the user changes the API key, the previous test result is no longer valid.
        if (name === 'openaiApiKey') {
            this.testResult = null;
            this.apiTested = false;
        }
    }

    async handleSave() {
        this.isLoading = true;
        try {
            await saveOpenAISettings({
                apiKey: this.openaiApiKey,
                model: this.openaiModel,
                tested: this.apiTested
            });
            this.showToast('Success', 'OpenAI settings saved.', 'success');
        } catch (error) {
            this.showToast('Error Saving OpenAI Settings', error.body?.message || error.message, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async testConnection() {
        if (!this.openaiApiKey) return;
        this.isTestingConnection = true;
        this.testResult = null;

        try {
            const result = await testOpenAIConnection({ apiKey: this.openaiApiKey });
            if (result === 'Success') {
                this.testResult = 'success';
                this.apiTested = true;
                this.showToast('Success', 'OpenAI connection test successful!', 'success');
            } else {
                this.testResult = 'error';
                this.apiTested = false;
                this.showToast('Connection Failed', result, 'error');
            }
        } catch (error) {
            this.testResult = 'error';
            this.apiTested = false;
            this.showToast('Error', 'Failed to test connection: ' + (error.body?.message || error.message), 'error');
        } finally {
            this.isTestingConnection = false;
        }
    }

    async resetSettings() {
        if (confirm('Are you sure you want to revert your changes to the last saved configuration?')) {
            this.isLoading = true;
            try {
                const savedData = await getSettings();
                if (savedData) {
                    this.openaiApiKey = savedData.openaiApiKey;
                    this.openaiModel = savedData.openaiModel || 'gpt-4o-mini';
                    this.apiTested = savedData.openAiApiTested || false;
                }
                
                this.testResult = null;
                this.showToast('Reset Complete', 'Settings have been reverted to the last saved state.', 'success');
            } catch (error) {
                this.showToast('Error Reverting', 'Could not fetch the saved settings. ' + (error.body?.message || error.message), 'error');
            } finally {
                this.isLoading = false;
            }
        }
    }
    
    // --- UI Helpers & Getters ---
    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    toggleApiKeyVisibility() {
        this.showApiKey = !this.showApiKey;
    }
    
    openOpenAIPlatform() {
        window.open('https://platform.openai.com/api-keys', '_blank');
    }

    get apiKeyInputType() {
        return this.showApiKey ? 'text' : 'password';
    }

    get eyeIconName() {
        return this.showApiKey ? 'utility:hide' : 'utility:preview';
    }

    get testButtonLabel() {
        return this.isTestingConnection ? 'Testing...' : 'Test';
    }

    get isTestButtonDisabled() {
        return !this.openaiApiKey || this.isTestingConnection;
    }

    get isSaveDisabled() {
        return !this.apiTested;
    }

    get showSuccessAlert() {
        return this.testResult === 'success';
    }

    get showErrorAlert() {
        return this.testResult === 'error';
    }
    
    get modelOptions() {
        return [
            { label: 'GPT-4o Mini (Recommended)', value: 'gpt-4o-mini' },
            { label: 'GPT-4o', value: 'gpt-4o' },
            { label: 'GPT-4 Turbo', value: 'gpt-4-turbo' },
            { label: 'GPT-3.5 Turbo', value: 'gpt-3.5-turbo' }
        ];
    }
}
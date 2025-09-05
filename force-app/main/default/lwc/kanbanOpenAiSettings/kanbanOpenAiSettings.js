import { LightningElement, api, track } from "lwc";
import testOpenAIConnection from "@salesforce/apex/KanbanSettingsController.testOpenAIConnection";
export default class KanbanOpenAiSettings extends LightningElement {
    @api settings;

    @track showApiKey = false;
    @track isTesting = false;
    @track testResult = null; // null, 'success', or 'error'
    @track testResultMessage = "";

    modelOptions = [
        { label: "GPT-4 Turbo (Recommended)", value: "gpt-4-turbo" },
        { label: "GPT-3.5 Turbo", value: "gpt-3.5-turbo" },
    ];

    get apiKeyInputType() {
        return this.showApiKey ? "text" : "password";
    }

    get apiKeyIcon() {
        return this.showApiKey ? "utility:hide" : "utility:preview";
    }

    get testButtonLabel() {
        return this.isTesting ? "Testing..." : "Test Connection";
    }

    get testResultClass() {
        if (!this.testResult) return "slds-hide";
        return this.testResult === "success"
            ? "slds-notify slds-notify_alert slds-theme_alert-texture slds-theme_success"
            : "slds-notify slds-notify_alert slds-theme_alert-texture slds-theme_error";
    }

    toggleApiKeyVisibility() {
        this.showApiKey = !this.showApiKey;
    }

    handleChange(event) {
        const field = event.target.name;
        const value = event.target.value;
        this.dispatchEvent(
            new CustomEvent("settingschange", {
                detail: { field, value },
            })
        );
    }

    async handleTestConnection() {
        if (!this.settings.openaiApiKey) {
            this.testResult = "error";
            this.testResultMessage = "Please enter an API Key to test.";
            return;
        }

        this.isTesting = true;
        this.testResult = null;

        try {
            const result = await testOpenAIConnection({ apiKey: this.settings.openaiApiKey });
            if (result === "Success") {
                this.testResult = "success";
                this.testResultMessage = "Connection successful!";
            } else {
                this.testResult = "error";
                this.testResultMessage = `Connection failed: ${result}`;
            }
        } catch (error) {
            this.testResult = "error";
            this.testResultMessage = `An error occurred: ${error.body.message}`;
        } finally {
            this.isTesting = false;
        }
    }
}
/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @author Cloud Nimbus LLC
 */
import { LightningElement, api, track } from "lwc";
import testOpenAIConnection from "@salesforce/apex/DeliveryHubSettingsController.testOpenAIConnection";
export default class DeliveryKanbanOpenAiSettings extends LightningElement {
    @api settings;

    @track showApiKey = false;
    @track isTesting = false;
    @track testResult = null; // null, 'success', or 'error'
    @track testResultMessage = "";

    modelOptions = [
        { label: "GPT-4o Mini (Recommended)", value: "gpt-4o-mini" },
        { label: "GPT-4o", value: "gpt-4o" },
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
            this.testResultMessage = `An error occurred: ${error.body ? error.body.message : error.message}`;
        } finally {
            this.isTesting = false;
        }
    }
}
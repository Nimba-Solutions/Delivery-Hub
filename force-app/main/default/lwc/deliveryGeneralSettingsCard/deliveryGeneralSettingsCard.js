/**
 * @author Cloud Nimbus LLC
 */
import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getSettings from '@salesforce/apex/DeliveryHubSettingsController.getSettings';
import saveGeneralSettings from '@salesforce/apex/DeliveryHubSettingsController.saveGeneralSettings';
import saveSlackWebhookUrl from '@salesforce/apex/DeliveryHubSettingsController.saveSlackWebhookUrl';
import testWebhook from '@salesforce/apex/DeliverySlackService.testWebhook';

export default class DeliveryGeneralSettingsCard extends LightningElement {
    @track notifications = false;
    @track autoSyncNetworkEntity = true; // Default to true
    @track slackWebhookUrl = '';
    @track slackTestResult = '';
    @track isSlackTesting = false;

    isLoading = true;

    // 1. REPLACED @wire WITH IMPERATIVE CALL
    // This runs once when the component loads and hits the server directly (bypassing cache)
    connectedCallback() {
        this.loadSettings();
    }

    async loadSettings() {
        try {
            const data = await getSettings(); // Direct Apex Call
            
            if (data) {
                this.notifications = data.enableNotifications || false;

                // Explicit check for undefined/null to respect 'false' values
                if (data.autoSyncNetworkEntity !== undefined && data.autoSyncNetworkEntity !== null) {
                    this.autoSyncNetworkEntity = data.autoSyncNetworkEntity;
                }
                this.slackWebhookUrl = data.slackWebhookUrl || '';
            }
        } catch (error) {
            this.showToast('Error Loading Settings', error.body ? error.body.message : error.message, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    // Handler for Notifications
    handleNotificationsToggle(event) {
        this.notifications = event.target.checked;
        this.saveState();
    }

    // Handler for Auto-Sync
    handleAutoSyncToggle(event) {
        this.autoSyncNetworkEntity = event.target.checked;
        this.saveState();
    }

    // Centralized Save Logic
    async saveState() {
        try {
            await saveGeneralSettings({ 
                enableNotifications: this.notifications,
                autoSyncNetworkEntity: this.autoSyncNetworkEntity
            });
            
            // Optional: Show a subtle success toast
            // this.showToast('Success', 'Settings updated', 'success');

        } catch (error) {
            this.showToast('Error Saving Settings', error.body ? error.body.message : error.message, 'error');
            // Revert toggle on error if needed
        }
    }

    // ── Slack handlers ─────────────────────────────────────────────────────

    handleSlackUrlChange(event) {
        this.slackWebhookUrl = event.target.value;
        this.slackTestResult = '';
    }

    async handleSlackUrlSave() {
        try {
            await saveSlackWebhookUrl({ webhookUrl: this.slackWebhookUrl });
        } catch (error) {
            this.showToast('Error Saving Slack URL', error.body ? error.body.message : error.message, 'error');
        }
    }

    async handleSlackTest() {
        this.isSlackTesting = true;
        this.slackTestResult = '';
        try {
            const result = await testWebhook({ webhookUrl: this.slackWebhookUrl });
            this.slackTestResult = result === 'Success'
                ? 'Connected! Check your Slack channel for a confirmation message.'
                : result;
        } catch (error) {
            this.slackTestResult = error.body ? error.body.message : error.message;
        } finally {
            this.isSlackTesting = false;
        }
    }

    get slackTestLabel() {
        return this.isSlackTesting ? 'Testing...' : 'Test';
    }

    get slackResultClass() {
        const isSuccess = this.slackTestResult && this.slackTestResult.startsWith('Connected');
        return isSuccess ? 'slack-result slack-result--success' : 'slack-result slack-result--error';
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
/* eslint-disable */
/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @author Cloud Nimbus LLC
 */
import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getSettings from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryHubSettingsController.getSettings';
import saveGeneralSettings from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryHubSettingsController.saveGeneralSettings';
import saveSlackWebhookUrl from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryHubSettingsController.saveSlackWebhookUrl';
import testWebhook from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliverySlackService.testWebhook';

export default class DeliveryGeneralSettingsCard extends LightningElement {
    @track notifications = false;
    @track autoSyncNetworkEntity = true; // Default to true
    @track emailNotificationsEnabled = false;
    @track showBoardMetrics = true; // Default to true
    @track slackWebhookUrl = '';
    @track slackTestResult = '';
    @track isSlackTesting = false;

    // Activation-date display strings
    @track notificationsActivatedAt = null;
    @track autoSyncActivatedAt = null;
    @track emailNotificationsActivatedAt = null;
    @track boardMetricsActivatedAt = null;

    // Advanced configurable settings
    @track reconciliationHour = 6;
    @track syncRetryLimit = 3;
    @track activityLogRetentionDays = 90;
    @track escalationCooldownHours = 24;

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
                if (data.autoSendRequest !== undefined && data.autoSendRequest !== null) {
                    this.autoSyncNetworkEntity = data.autoSendRequest;
                }
                this.slackWebhookUrl = data.slackWebhookUrl || '';
                this.emailNotificationsEnabled = data.emailNotificationsEnabled || false;
                this.showBoardMetrics = (data.showBoardMetrics !== undefined && data.showBoardMetrics !== null) ? data.showBoardMetrics : true;

                // Activation dates
                this.notificationsActivatedAt = data.notificationsActivatedAt || null;
                this.autoSyncActivatedAt = data.autoSyncActivatedAt || null;
                this.emailNotificationsActivatedAt = data.emailNotificationsActivatedAt || null;
                this.boardMetricsActivatedAt = data.boardMetricsActivatedAt || null;

                // Advanced configurable settings
                this.reconciliationHour = data.reconciliationHour !== null ? data.reconciliationHour : 6;
                this.syncRetryLimit = data.syncRetryLimit !== null ? data.syncRetryLimit : 3;
                this.activityLogRetentionDays = data.activityLogRetentionDays !== null ? data.activityLogRetentionDays : 90;
                this.escalationCooldownHours = data.escalationCooldownHours !== null ? data.escalationCooldownHours : 24;
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

    // Handler for Email Notifications
    handleEmailNotificationsToggle(event) {
        this.emailNotificationsEnabled = event.target.checked;
        this.saveState();
    }

    // Handler for Board Metrics
    handleBoardMetricsToggle(event) {
        this.showBoardMetrics = event.target.checked;
        this.saveState();
    }

    // Handlers for Advanced Configuration
    handleReconciliationHourChange(event) {
        this.reconciliationHour = parseInt(event.target.value, 10);
        this.saveState();
    }

    handleSyncRetryLimitChange(event) {
        this.syncRetryLimit = parseInt(event.target.value, 10);
        this.saveState();
    }

    handleActivityLogRetentionChange(event) {
        this.activityLogRetentionDays = parseInt(event.target.value, 10);
        this.saveState();
    }

    handleEscalationCooldownChange(event) {
        this.escalationCooldownHours = parseInt(event.target.value, 10);
        this.saveState();
    }

    // Centralized Save Logic
    async saveState() {
        try {
            await saveGeneralSettings({
                activityLogRetentionDays: this.activityLogRetentionDays,
                autoCreateRequest: true,
                autoSendRequest: this.autoSyncNetworkEntity,
                emailNotificationsEnabled: this.emailNotificationsEnabled,
                enableNotifications: this.notifications,
                escalationCooldownHours: this.escalationCooldownHours,
                reconciliationHour: this.reconciliationHour,
                showBoardMetrics: this.showBoardMetrics,
                syncRetryLimit: this.syncRetryLimit
            });

            // Reload to get fresh activation dates from server
            await this.loadSettings();

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
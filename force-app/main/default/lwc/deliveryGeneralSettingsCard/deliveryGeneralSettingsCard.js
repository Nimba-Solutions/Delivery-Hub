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
import saveExtendedSettings from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryHubSettingsController.saveExtendedSettings';
import saveSlackWebhookUrl from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryHubSettingsController.saveSlackWebhookUrl';
import testWebhook from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliverySlackService.testWebhook';

export default class DeliveryGeneralSettingsCard extends LightningElement {
    // ── Core toggles (existing) ─────────────────────────────────────────
    @track notifications = false;
    @track autoSyncNetworkEntity = true;
    @track emailNotificationsEnabled = false;
    @track showBoardMetrics = true;
    @track slackWebhookUrl = '';
    @track slackTestResult = '';
    @track isSlackTesting = false;

    // ── New feature toggles ─────────────────────────────────────────────
    @track activityLoggingEnabled = false;
    @track fieldTrackingEnabled = false;
    @track bellNotificationsEnabled = false;
    @track weeklyDigestEnabled = false;
    @track statusPageEnabled = false;
    @track autoCreateWorkRequest = true;
    @track requireWorkLogApproval = false;

    // ── Activation-date display strings ─────────────────────────────────
    @track notificationsActivatedAt = null;
    @track autoSyncActivatedAt = null;
    @track emailNotificationsActivatedAt = null;
    @track boardMetricsActivatedAt = null;
    @track activityLoggingActivatedAt = null;
    @track fieldTrackingActivatedAt = null;
    @track bellNotificationsActivatedAt = null;
    @track weeklyDigestActivatedAt = null;
    @track statusPageActivatedAt = null;
    @track autoCreateWorkRequestActivatedAt = null;
    @track requireWorkLogApprovalActivatedAt = null;

    // ── Advanced configurable number settings ───────────────────────────
    @track reconciliationHour = 6;
    @track syncRetryLimit = 3;
    @track activityLogRetentionDays = 90;
    @track escalationCooldownHours = 24;
    @track fieldChangeRetentionDays = 0;

    // ── Text configuration settings ─────────────────────────────────────
    @track weeklyDigestDay = 'Monday';
    @track weeklyDigestRecipients = '';
    @track documentCcEmail = '';
    @track statusPageToken = '';
    @track defaultBillingEntityId = '';
    @track stagesToAutoShare = '';

    isLoading = true;

    // Day-of-week options for weekly digest
    get weeklyDigestDayOptions() {
        return [
            { label: 'Monday', value: 'Monday' },
            { label: 'Tuesday', value: 'Tuesday' },
            { label: 'Wednesday', value: 'Wednesday' },
            { label: 'Thursday', value: 'Thursday' },
            { label: 'Friday', value: 'Friday' },
            { label: 'Saturday', value: 'Saturday' },
            { label: 'Sunday', value: 'Sunday' }
        ];
    }

    connectedCallback() {
        this.loadSettings();
    }

    async loadSettings() {
        try {
            const data = await getSettings();

            if (data) {
                // Core toggles
                this.notifications = data.enableNotifications || false;
                if (data.autoSendRequest !== undefined && data.autoSendRequest !== null) {
                    this.autoSyncNetworkEntity = data.autoSendRequest;
                }
                this.slackWebhookUrl = data.slackWebhookUrl || '';
                this.emailNotificationsEnabled = data.emailNotificationsEnabled || false;
                this.showBoardMetrics = (data.showBoardMetrics !== undefined && data.showBoardMetrics !== null) ? data.showBoardMetrics : true;

                // New feature toggles
                this.activityLoggingEnabled = data.activityLoggingEnabled || false;
                this.fieldTrackingEnabled = data.fieldTrackingEnabled || false;
                this.bellNotificationsEnabled = data.bellNotificationsEnabled || false;
                this.weeklyDigestEnabled = data.weeklyDigestEnabled || false;
                this.statusPageEnabled = data.statusPageEnabled || false;
                this.autoCreateWorkRequest = (data.autoCreateWorkRequest !== undefined && data.autoCreateWorkRequest !== null) ? data.autoCreateWorkRequest : true;
                this.requireWorkLogApproval = data.requireWorkLogApproval || false;

                // Activation dates
                this.notificationsActivatedAt = data.notificationsActivatedAt || null;
                this.autoSyncActivatedAt = data.autoSyncActivatedAt || null;
                this.emailNotificationsActivatedAt = data.emailNotificationsActivatedAt || null;
                this.boardMetricsActivatedAt = data.boardMetricsActivatedAt || null;
                this.activityLoggingActivatedAt = data.activityLoggingActivatedAt || null;
                this.fieldTrackingActivatedAt = data.fieldTrackingActivatedAt || null;
                this.bellNotificationsActivatedAt = data.bellNotificationsActivatedAt || null;
                this.weeklyDigestActivatedAt = data.weeklyDigestActivatedAt || null;
                this.statusPageActivatedAt = data.statusPageActivatedAt || null;
                this.autoCreateWorkRequestActivatedAt = data.autoCreateWorkRequestActivatedAt || null;
                this.requireWorkLogApprovalActivatedAt = data.requireWorkLogApprovalActivatedAt || null;

                // Advanced configurable settings
                this.reconciliationHour = data.reconciliationHour !== null ? data.reconciliationHour : 6;
                this.syncRetryLimit = data.syncRetryLimit !== null ? data.syncRetryLimit : 3;
                this.activityLogRetentionDays = data.activityLogRetentionDays !== null ? data.activityLogRetentionDays : 90;
                this.escalationCooldownHours = data.escalationCooldownHours !== null ? data.escalationCooldownHours : 24;
                this.fieldChangeRetentionDays = data.fieldChangeRetentionDays !== null ? data.fieldChangeRetentionDays : 0;

                // Text configuration settings
                this.weeklyDigestDay = data.weeklyDigestDay || 'Monday';
                this.weeklyDigestRecipients = data.weeklyDigestRecipients || '';
                this.documentCcEmail = data.documentCcEmail || '';
                this.statusPageToken = data.statusPageToken || '';
                this.defaultBillingEntityId = data.defaultBillingEntityId || '';
                this.stagesToAutoShare = data.stagesToAutoShare || '';
            }
        } catch (error) {
            this.showToast('Error Loading Settings', error.body ? error.body.message : error.message, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    // ── Core toggle handlers ────────────────────────────────────────────

    handleNotificationsToggle(event) {
        this.notifications = event.target.checked;
        this.saveState();
    }

    handleAutoSyncToggle(event) {
        this.autoSyncNetworkEntity = event.target.checked;
        this.saveState();
    }

    handleEmailNotificationsToggle(event) {
        this.emailNotificationsEnabled = event.target.checked;
        this.saveState();
    }

    handleBoardMetricsToggle(event) {
        this.showBoardMetrics = event.target.checked;
        this.saveState();
    }

    // ── New feature toggle handlers ─────────────────────────────────────

    handleAutoCreateWorkRequestToggle(event) {
        this.autoCreateWorkRequest = event.target.checked;
        this.saveExtended();
    }

    handleActivityLoggingToggle(event) {
        this.activityLoggingEnabled = event.target.checked;
        this.saveExtended();
    }

    handleFieldTrackingToggle(event) {
        this.fieldTrackingEnabled = event.target.checked;
        this.saveExtended();
    }

    handleBellNotificationsToggle(event) {
        this.bellNotificationsEnabled = event.target.checked;
        this.saveExtended();
    }

    handleWeeklyDigestToggle(event) {
        this.weeklyDigestEnabled = event.target.checked;
        this.saveExtended();
    }

    handleStatusPageToggle(event) {
        this.statusPageEnabled = event.target.checked;
        this.saveExtended();
    }

    handleRequireWorkLogApprovalToggle(event) {
        this.requireWorkLogApproval = event.target.checked;
        this.saveExtended();
    }

    // ── Number setting handlers ─────────────────────────────────────────

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

    handleFieldChangeRetentionChange(event) {
        this.fieldChangeRetentionDays = parseInt(event.target.value, 10);
        this.saveExtended();
    }

    // ── Text setting handlers ───────────────────────────────────────────

    handleWeeklyDigestDayChange(event) {
        this.weeklyDigestDay = event.detail.value;
        this.saveExtended();
    }

    handleWeeklyDigestRecipientsChange(event) {
        this.weeklyDigestRecipients = event.target.value;
    }

    handleWeeklyDigestRecipientsSave() {
        this.saveExtended();
    }

    handleDocumentCcEmailChange(event) {
        this.documentCcEmail = event.target.value;
    }

    handleDocumentCcEmailSave() {
        this.saveExtended();
    }

    handleStatusPageTokenChange(event) {
        this.statusPageToken = event.target.value;
    }

    handleStatusPageTokenSave() {
        this.saveExtended();
    }

    handleDefaultBillingEntityChange(event) {
        this.defaultBillingEntityId = event.target.value;
    }

    handleDefaultBillingEntitySave() {
        this.saveExtended();
    }

    handleStagesToAutoShareChange(event) {
        this.stagesToAutoShare = event.target.value;
    }

    handleStagesToAutoShareSave() {
        this.saveExtended();
    }

    // ── Centralized Save Logic (existing settings) ──────────────────────

    async saveState() {
        try {
            await saveGeneralSettings({
                activityLogRetentionDays: this.activityLogRetentionDays,
                autoCreateRequest: this.autoCreateWorkRequest,
                autoSendRequest: this.autoSyncNetworkEntity,
                emailNotificationsEnabled: this.emailNotificationsEnabled,
                enableNotifications: this.notifications,
                escalationCooldownHours: this.escalationCooldownHours,
                reconciliationHour: this.reconciliationHour,
                showBoardMetrics: this.showBoardMetrics,
                syncRetryLimit: this.syncRetryLimit
            });

            await this.loadSettings();

        } catch (error) {
            this.showToast('Error Saving Settings', error.body ? error.body.message : error.message, 'error');
        }
    }

    // ── Save Logic (extended settings) ──────────────────────────────────

    async saveExtended() {
        try {
            await saveExtendedSettings({
                settingsJson: JSON.stringify({
                    activityLoggingEnabled: this.activityLoggingEnabled,
                    fieldTrackingEnabled: this.fieldTrackingEnabled,
                    bellNotificationsEnabled: this.bellNotificationsEnabled,
                    weeklyDigestEnabled: this.weeklyDigestEnabled,
                    statusPageEnabled: this.statusPageEnabled,
                    autoCreateWorkRequest: this.autoCreateWorkRequest,
                    requireWorkLogApproval: this.requireWorkLogApproval,
                    fieldChangeRetentionDays: this.fieldChangeRetentionDays,
                    weeklyDigestDay: this.weeklyDigestDay,
                    weeklyDigestRecipients: this.weeklyDigestRecipients,
                    documentCcEmail: this.documentCcEmail,
                    statusPageToken: this.statusPageToken,
                    defaultBillingEntityId: this.defaultBillingEntityId,
                    stagesToAutoShare: this.stagesToAutoShare
                })
            });

            await this.loadSettings();

        } catch (error) {
            this.showToast('Error Saving Settings', error.body ? error.body.message : error.message, 'error');
        }
    }

    // ── Slack handlers ──────────────────────────────────────────────────

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

    // ── Conditional visibility getters ──────────────────────────────────

    get isWeeklyDigestConfigVisible() {
        return this.weeklyDigestEnabled;
    }

    get isStatusPageConfigVisible() {
        return this.statusPageEnabled;
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}

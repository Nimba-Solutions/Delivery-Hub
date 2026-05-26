/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Admin form for the Phase 2 Watcher digest. Wraps
 *               DeliveryWatcherSetupController so subscribers no longer
 *               need to open Setup → Custom Settings to flip the master
 *               opt-in (EnableWatcherDigestDateTime__c) or curate the
 *               recipient list (WatcherDigestRecipientUserIdsTxt__c).
 *
 *               Closes Flow 8 #1 from docs/audits/e2e-walkthrough-2026-05-21.md.
 * @author Cloud Nimbus LLC
 */
import { LightningElement, track, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getSettings from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryWatcherSetupController.getSettings';
import saveSettings from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryWatcherSetupController.saveSettings';

export default class DeliveryWatcherSetup extends LightningElement {
    @track isEnabled = false;
    @track recipientIdsCsv = '';
    @track slackWebhookOverride = '';
    @track recipientUsers = [];
    @track invalidRecipientIds = [];
    @track lastSavedDateTime;
    @track enabledSince;
    @track nextScheduledRunDateTime;
    @track currentWebhookMasked = '';
    @track slackChannel = '';
    @track runHourGmt;
    @track isSaving = false;
    @track isLoading = true;

    wiredResult;

    @wire(getSettings)
    wiredSettings(result) {
        this.wiredResult = result;
        this.isLoading = false;
        const { data, error } = result;
        if (data) {
            this.applyDto(data);
        } else if (error) {
            this.showToast('Error', 'Could not load Watcher settings.', 'error');
        }
    }

    applyDto(dto) {
        this.isEnabled = !!dto.enabled;
        this.enabledSince = dto.enabledSince;
        this.recipientIdsCsv = dto.recipientIdsCsv || '';
        this.recipientUsers = dto.recipientUsers || [];
        this.invalidRecipientIds = dto.invalidRecipientIds || [];
        this.lastSavedDateTime = dto.lastSavedDateTime;
        this.nextScheduledRunDateTime = dto.nextScheduledRunDateTime;
        this.currentWebhookMasked = this.maskWebhook(dto.slackWebhookUrl);
        this.slackChannel = dto.slackChannel || '';
        this.runHourGmt = dto.runHourGmt;
        // Clear the optional override input after a successful save so the
        // existing webhook isn't accidentally re-pasted on a follow-on save.
        this.slackWebhookOverride = '';
    }

    maskWebhook(url) {
        if (!url) {
            return '';
        }
        // Show only the leading scheme + host + a short token tail so admins
        // can identify the webhook without leaking the secret in the DOM.
        const trimmed = String(url).trim();
        if (trimmed.length <= 24) {
            return trimmed;
        }
        return trimmed.slice(0, 24) + '…' + trimmed.slice(-6);
    }

    // ────────────────────────────────────────────────────────────────────
    // Getters — keep template ternary-free per CLAUDE.md (LWC v62 limit)
    // ────────────────────────────────────────────────────────────────────

    get enabledBadgeLabel() {
        return this.isEnabled ? 'On' : 'Off';
    }

    get enabledBadgeVariant() {
        return this.isEnabled ? 'success' : 'inverse';
    }

    get hasRecipients() {
        return Array.isArray(this.recipientUsers) && this.recipientUsers.length > 0;
    }

    get hasInvalidIds() {
        return Array.isArray(this.invalidRecipientIds) && this.invalidRecipientIds.length > 0;
    }

    get invalidIdsText() {
        if (!this.hasInvalidIds) {
            return '';
        }
        return this.invalidRecipientIds.join(', ');
    }

    get hasCurrentWebhook() {
        return !!this.currentWebhookMasked;
    }

    get hasNextScheduledRun() {
        return !!this.nextScheduledRunDateTime;
    }

    get hasLastSaved() {
        return !!this.lastSavedDateTime;
    }

    get recipientCountLabel() {
        const n = this.hasRecipients ? this.recipientUsers.length : 0;
        if (n === 0) {
            return 'No recipients — Watcher will write its audit row but will not Slack-post.';
        }
        if (n === 1) {
            return '1 recipient configured.';
        }
        return n + ' recipients configured.';
    }

    get saveButtonDisabled() {
        return this.isSaving || this.isLoading;
    }

    get recipientHelpText() {
        return 'Comma-separated Salesforce User IDs (max ~13 in 255 chars). Each Id is validated against active Users at save time — invalid Ids are reported back and dropped.';
    }

    get webhookHelpText() {
        return 'Optional override for the org-wide Slack webhook. Leave blank to keep the current value (used by escalations and forecasts too).';
    }

    get scheduledJobsUrl() {
        return '/lightning/setup/ScheduledJobs/home';
    }

    // ────────────────────────────────────────────────────────────────────
    // Event handlers
    // ────────────────────────────────────────────────────────────────────

    handleToggleChange(event) {
        this.isEnabled = !!event.detail.checked;
    }

    handleRecipientChange(event) {
        this.recipientIdsCsv = event.detail.value || '';
    }

    handleWebhookChange(event) {
        this.slackWebhookOverride = event.detail.value || '';
    }

    handleSave() {
        if (this.isSaving) {
            return;
        }
        this.isSaving = true;
        saveSettings({
            enabled: this.isEnabled,
            recipientIdsCsv: this.recipientIdsCsv,
            slackWebhookUrl: this.slackWebhookOverride
        })
            .then((dto) => {
                this.applyDto(dto);
                const invalid = (dto && dto.invalidRecipientIds) || [];
                if (invalid.length > 0) {
                    this.showToast(
                        'Saved with warnings',
                        'Saved. Dropped invalid / inactive recipient Ids: ' + invalid.join(', '),
                        'warning'
                    );
                } else {
                    this.showToast('Saved', 'Watcher settings updated.', 'success');
                }
                return refreshApex(this.wiredResult);
            })
            .catch((error) => {
                const message =
                    (error && error.body && error.body.message) ||
                    (error && error.message) ||
                    'Save failed.';
                this.showToast('Error', message, 'error');
            })
            .finally(() => {
                this.isSaving = false;
            });
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}

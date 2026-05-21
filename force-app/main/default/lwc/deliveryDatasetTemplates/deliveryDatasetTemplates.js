/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Dataset Templates card (Layer 7 of the DH cockpit
 *               architecture). Renders the available templates for a Feature__c
 *               or WorkItem__c record page and exposes a "Copy Load Command"
 *               button that puts the cci task run load_feature_data string on
 *               the clipboard via navigator.clipboard.writeText.
 *
 *               Subscriber-org awareness: the card explicitly tells non-CCI
 *               operators that this surface is for package developers. We
 *               can't reliably detect "is this org running CCI?" from the
 *               LWC, but we can detect "is this org a managed-package
 *               install?" via the namespace prefix on Apex imports and
 *               degrade the wording accordingly.
 * @author Cloud Nimbus LLC
 */
import { LightningElement, api, wire, track } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getTemplatesForFeature from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryDatasetController.getTemplatesForFeature';
import getTemplatesForWorkItem from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryDatasetController.getTemplatesForWorkItem';
import getRecentAssignmentsForTemplate from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryDatasetController.getRecentAssignmentsForTemplate';
import formatCciCommand from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryDatasetController.formatCciCommand';

const FEATURE_OBJECT = 'Feature__c',
    WORK_ITEM_OBJECT = 'WorkItem__c',
    EMPTY = 0;

export default class DeliveryDatasetTemplates extends LightningElement {
    /** Set automatically when placed on a record page. */
    @api recordId;
    /** Object api name (Feature__c, WorkItem__c). Set by the record page. */
    @api objectApiName;

    @track templates = [];
    @track recent = [];
    @track errorMessage = '';
    @track isLoaded = false;
    @track selectedTemplateId = null;

    wiredTemplatesResult;
    wiredRecentResult;

    @wire(getTemplatesForFeature, { featureId: '$featureIdForWire' })
    wiredFeatureTemplates(result) {
        if (this.objectApiName !== FEATURE_OBJECT) {
            return;
        }
        this.wiredTemplatesResult = result;
        this.applyTemplatesResult(result);
    }

    @wire(getTemplatesForWorkItem, { workItemId: '$workItemIdForWire' })
    wiredWorkItemTemplates(result) {
        if (this.objectApiName !== WORK_ITEM_OBJECT) {
            return;
        }
        this.wiredTemplatesResult = result;
        this.applyTemplatesResult(result);
    }

    @wire(getRecentAssignmentsForTemplate, { templateId: '$selectedTemplateId' })
    wiredRecent(result) {
        this.wiredRecentResult = result;
        if (result.data) {
            this.recent = (result.data || []).map((a, idx) => {
                const outcome = a.outcome || 'Unknown';
                return {
                    key: a.assignmentId || `assignment-${idx}`,
                    assignmentId: a.assignmentId,
                    templateName: a.templateName || '',
                    loadedAt: a.loadedAt,
                    outcome,
                    recordsLoaded: typeof a.recordsLoaded === 'number' ? a.recordsLoaded : null,
                    outcomeBadgeClass: this.outcomeBadgeFor(outcome)
                };
            });
        } else if (result.error) {
            // Recent panel is best-effort — don't block the main template
            // list rendering on its failure.
            this.recent = [];
        }
    }

    applyTemplatesResult(result) {
        if (result.data) {
            this.templates = (result.data || []).map((t, idx) => ({
                key: t.templateId || `template-${idx}`,
                templateId: t.templateId,
                name: t.name || '',
                description: t.description || '',
                hasDescription: !!t.description,
                apexScriptPath: t.apexScriptPath || '',
                hasApexScriptPath: !!t.apexScriptPath,
                recordCountEstimate: typeof t.recordCountEstimate === 'number' ? t.recordCountEstimate : null,
                hasRecordCountEstimate: typeof t.recordCountEstimate === 'number',
                featureName: t.featureName || ''
            }));
            this.errorMessage = '';
            this.isLoaded = true;
        } else if (result.error) {
            this.errorMessage = (result.error && result.error.body && result.error.body.message)
                ? result.error.body.message
                : 'Unable to load dataset templates.';
            this.templates = [];
            this.isLoaded = true;
        }
    }

    outcomeBadgeFor(outcome) {
        const normalized = (outcome || '').toLowerCase();
        if (normalized === 'success') {
            return 'slds-badge slds-theme_success';
        }
        if (normalized === 'partialfailure') {
            return 'slds-badge slds-theme_warning';
        }
        if (normalized === 'failure') {
            return 'slds-badge slds-theme_error';
        }
        return 'slds-badge slds-badge_lightest';
    }

    // ────────────────────────────────────────────────────────────────────
    // Wire-driver getters — strict null returns when the object api name
    // doesn't match, so the wire stays inert until the user lands on the
    // matching record page.
    // ────────────────────────────────────────────────────────────────────

    get featureIdForWire() {
        return this.objectApiName === FEATURE_OBJECT ? this.recordId : null;
    }

    get workItemIdForWire() {
        return this.objectApiName === WORK_ITEM_OBJECT ? this.recordId : null;
    }

    get hasTemplates() {
        return this.templates.length > EMPTY;
    }

    get isEmpty() {
        return this.isLoaded && !this.hasTemplates && !this.errorMessage;
    }

    get hasError() {
        return !!this.errorMessage;
    }

    get hasRecent() {
        return this.recent.length > EMPTY;
    }

    get cardTitle() {
        return 'Sample Data';
    }

    get emptyMessage() {
        return 'No dataset templates registered for this record. '
            + 'This surface is for package developers — install CCI locally to load sample data.';
    }

    // ────────────────────────────────────────────────────────────────────
    // Handlers
    // ────────────────────────────────────────────────────────────────────

    handleCopyCommand(event) {
        const templateId = event.currentTarget.dataset.templateId;
        if (!templateId) {
            return;
        }
        formatCciCommand({ templateId })
            .then(cmd => this.writeToClipboard(cmd))
            .catch(err => {
                const msg = (err && err.body && err.body.message)
                    ? err.body.message
                    : 'Unable to format load command.';
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Copy failed',
                    message: msg,
                    variant: 'error'
                }));
            });
    }

    writeToClipboard(text) {
        if (!navigator || !navigator.clipboard || !navigator.clipboard.writeText) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Clipboard unavailable',
                message: 'Copy this command manually: ' + text,
                variant: 'warning'
            }));
            return;
        }
        navigator.clipboard.writeText(text)
            .then(() => {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Command copied',
                    message: text,
                    variant: 'success'
                }));
            })
            .catch(() => {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Clipboard write failed',
                    message: 'Copy this command manually: ' + text,
                    variant: 'warning'
                }));
            });
    }

    handleSelectTemplate(event) {
        const templateId = event.currentTarget.dataset.templateId;
        this.selectedTemplateId = templateId || null;
    }

    handleRefresh() {
        if (this.wiredTemplatesResult) {
            refreshApex(this.wiredTemplatesResult);
        }
        if (this.wiredRecentResult) {
            refreshApex(this.wiredRecentResult);
        }
    }
}

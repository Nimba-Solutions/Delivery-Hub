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
import isSubscriberOrgApex from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryDatasetController.isSubscriberOrg';
import getLastAssignment from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryDatasetController.getLastAssignment';
import recordAssignment from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryDatasetController.recordAssignment';
import loadSampleData from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryDatasetController.loadSampleData';
import removeSampleData from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryDatasetController.removeSampleData';

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
    @track isSubscriberOrg = false;

    // ── Mark-as-Loaded modal state ──────────────────────────────────────
    @track isMarkAsLoadedModalOpen = false;
    @track markAsLoadedTemplateId = null;
    @track markAsLoadedTemplateName = '';
    @track markAsLoadedNotes = '';
    @track isSubmittingMarkAsLoaded = false;

    // ── In-app sample-data confirm modal state ──────────────────────────
    // One modal serves both Load and Remove; sampleActionMode flips which.
    @track isSampleModalOpen = false;
    @track sampleActionMode = ''; // 'load' | 'remove'
    @track sampleTemplateId = null;
    @track sampleTemplateName = '';
    @track isSampleActionRunning = false;

    wiredTemplatesResult;
    wiredRecentResult;

    @wire(isSubscriberOrgApex)
    wiredIsSubscriberOrg({ data }) {
        // Failure path intentionally degrades to non-subscriber rendering —
        // matches the Apex method's defensive `return false` on probe failure.
        if (data === true || data === false) {
            this.isSubscriberOrg = data;
        }
    }

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
                featureName: t.featureName || '',
                lastLoadedSubline: '',
                hasLastLoadedSubline: false
            }));
            this.errorMessage = '';
            this.isLoaded = true;
            this.loadLastAssignmentSublines();
        } else if (result.error) {
            this.errorMessage = (result.error && result.error.body && result.error.body.message)
                ? result.error.body.message
                : 'Unable to load dataset templates.';
            this.templates = [];
            this.isLoaded = true;
        }
    }

    // Imperative fan-out: for each template card, fetch the most-recent
    // assignment so we can render a "Last loaded by X on Y" subline. Best-
    // effort — failures degrade silently to "no subline".
    loadLastAssignmentSublines() {
        const templateIds = (this.templates || [])
            .map(t => t.templateId)
            .filter(id => !!id);
        templateIds.forEach(templateId => {
            getLastAssignment({ templateId })
                .then(dto => this.mergeLastAssignment(templateId, dto))
                .catch(() => {
                    // best-effort — don't surface a toast for the subline path
                });
        });
    }

    mergeLastAssignment(templateId, dto) {
        if (!dto) {
            return;
        }
        const formatted = this.formatLastLoadedSubline(dto);
        this.templates = (this.templates || []).map(t => {
            if (t.templateId !== templateId) {
                return t;
            }
            return Object.assign({}, t, {
                lastLoadedSubline: formatted,
                hasLastLoadedSubline: !!formatted
            });
        });
    }

    formatLastLoadedSubline(dto) {
        if (!dto || !dto.loadedAt) {
            return '';
        }
        const when = new Date(dto.loadedAt);
        const datePart = Number.isNaN(when.getTime())
            ? String(dto.loadedAt)
            : when.toLocaleDateString();
        const who = dto.loadedByName || 'Unknown user';
        return `Last loaded by ${who} on ${datePart}`;
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

    // ── In-app sample-data modal getters (LWC has no ternary in v62) ─────

    get isSampleRemoveMode() {
        return this.sampleActionMode === 'remove';
    }

    get sampleModalHeading() {
        if (this.isSampleRemoveMode) {
            return 'Remove Sample Data';
        }
        return 'Load Sample Data';
    }

    get sampleModalBody() {
        if (this.isSampleRemoveMode) {
            return 'This deletes ONLY the clearly-marked "[DH SAMPLE]" records '
                + 'created by the loader for this feature. Your real records are '
                + 'never touched. This action is reversible — you can reload the '
                + 'sample data afterward.';
        }
        return 'This loads clearly-marked "[DH SAMPLE]" sample records so you can '
            + 'see this feature in action — no CumulusCI or CLI required. '
            + 'Re-running is safe (it will not duplicate). You can remove the '
            + 'sample data in one click afterward.';
    }

    get sampleConfirmLabel() {
        if (this.isSampleRemoveMode) {
            return 'Remove Sample Data';
        }
        return 'Load Sample Data';
    }

    get sampleConfirmVariant() {
        if (this.isSampleRemoveMode) {
            return 'destructive';
        }
        return 'brand';
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

    // ── Mark-as-Loaded modal ────────────────────────────────────────────

    handleOpenMarkAsLoaded(event) {
        const templateId = event.currentTarget.dataset.templateId;
        const templateName = event.currentTarget.dataset.templateName || '';
        if (!templateId) {
            return;
        }
        this.markAsLoadedTemplateId = templateId;
        this.markAsLoadedTemplateName = templateName;
        this.markAsLoadedNotes = '';
        this.isMarkAsLoadedModalOpen = true;
    }

    handleCloseMarkAsLoaded() {
        if (this.isSubmittingMarkAsLoaded) {
            // In-flight submission — let it finish before closing.
            return;
        }
        this.isMarkAsLoadedModalOpen = false;
        this.markAsLoadedTemplateId = null;
        this.markAsLoadedTemplateName = '';
        this.markAsLoadedNotes = '';
    }

    handleMarkAsLoadedNotesChange(event) {
        this.markAsLoadedNotes = event.target.value || '';
    }

    handleSubmitMarkAsLoaded() {
        if (!this.markAsLoadedTemplateId || this.isSubmittingMarkAsLoaded) {
            return;
        }
        this.isSubmittingMarkAsLoaded = true;
        recordAssignment({
            templateId: this.markAsLoadedTemplateId,
            notes: this.markAsLoadedNotes
        })
            .then(() => {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Load recorded',
                    message: `Audit row created for "${this.markAsLoadedTemplateName}".`,
                    variant: 'success'
                }));
                // Refresh the recent-loads panel (if it's currently showing
                // this template) AND the per-card last-loaded subline so the
                // admin sees their entry immediately.
                if (this.wiredRecentResult) {
                    refreshApex(this.wiredRecentResult);
                }
                this.loadLastAssignmentSublines();
                this.isSubmittingMarkAsLoaded = false;
                this.isMarkAsLoadedModalOpen = false;
                this.markAsLoadedTemplateId = null;
                this.markAsLoadedTemplateName = '';
                this.markAsLoadedNotes = '';
            })
            .catch(err => {
                const msg = (err && err.body && err.body.message)
                    ? err.body.message
                    : 'Unable to record this load.';
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Could not record load',
                    message: msg,
                    variant: 'error'
                }));
                this.isSubmittingMarkAsLoaded = false;
            });
    }

    // ── In-app sample-data load / remove ────────────────────────────────

    handleOpenLoadSample(event) {
        this.openSampleModal(event, 'load');
    }

    handleOpenRemoveSample(event) {
        this.openSampleModal(event, 'remove');
    }

    openSampleModal(event, mode) {
        const templateId = event.currentTarget.dataset.templateId;
        const templateName = event.currentTarget.dataset.templateName || '';
        if (!templateId) {
            return;
        }
        this.sampleTemplateId = templateId;
        this.sampleTemplateName = templateName;
        this.sampleActionMode = mode;
        this.isSampleModalOpen = true;
    }

    handleCloseSampleModal() {
        if (this.isSampleActionRunning) {
            // In-flight operation — let it finish before closing.
            return;
        }
        this.resetSampleModal();
    }

    resetSampleModal() {
        this.isSampleModalOpen = false;
        this.sampleActionMode = '';
        this.sampleTemplateId = null;
        this.sampleTemplateName = '';
    }

    handleConfirmSampleAction() {
        if (!this.sampleTemplateId || this.isSampleActionRunning) {
            return;
        }
        const isRemove = this.isSampleRemoveMode;
        const templateName = this.sampleTemplateName;
        const apexCall = isRemove ? removeSampleData : loadSampleData;
        this.isSampleActionRunning = true;
        apexCall({ templateId: this.sampleTemplateId })
            .then(result => this.handleSampleSuccess(result, isRemove, templateName))
            .catch(err => this.handleSampleError(err, isRemove));
    }

    handleSampleSuccess(result, isRemove, templateName) {
        const count = result && typeof result.recordCount === 'number' ? result.recordCount : 0;
        const verb = isRemove ? 'Removed' : 'Loaded';
        let message;
        if (result && result.message) {
            message = result.message;
        } else {
            message = `${verb} ${count} sample record(s) for "${templateName}".`;
        }
        const variant = (result && result.outcome === 'Failure') ? 'error' : 'success';
        this.dispatchEvent(new ShowToastEvent({
            title: isRemove ? 'Sample data removed' : 'Sample data loaded',
            message,
            variant
        }));
        // Refresh audit panel + per-card sublines so the new assignment shows.
        if (this.wiredRecentResult) {
            refreshApex(this.wiredRecentResult);
        }
        this.loadLastAssignmentSublines();
        this.isSampleActionRunning = false;
        this.resetSampleModal();
    }

    handleSampleError(err, isRemove) {
        const msg = (err && err.body && err.body.message)
            ? err.body.message
            : (isRemove ? 'Unable to remove sample data.' : 'Unable to load sample data.');
        this.dispatchEvent(new ShowToastEvent({
            title: isRemove ? 'Could not remove sample data' : 'Could not load sample data',
            message: msg,
            variant: 'error'
        }));
        this.isSampleActionRunning = false;
    }

    handleRefresh() {
        if (this.wiredTemplatesResult) {
            refreshApex(this.wiredTemplatesResult);
        }
        if (this.wiredRecentResult) {
            refreshApex(this.wiredRecentResult);
        }
        this.loadLastAssignmentSublines();
    }
}

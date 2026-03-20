/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Embedded document/invoice viewer. Supports list mode (all documents
 *               for an entity) and preview mode (full invoice/report rendering).
 * @author Cloud Nimbus LLC
 */
import { LightningElement, api, wire, track } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getDocumentsForEntity from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryDocumentController.getDocumentsForEntity';
import generateDocument from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryDocumentController.generateDocument';
import updateDocumentStatus from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryDocumentController.updateDocumentStatus';
import getDocumentById from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryDocumentController.getDocumentById';
import sendDocumentEmail from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryDocumentController.sendDocumentEmail';
import getDocumentTemplates from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryDocumentController.getDocumentTemplates';
import recordPayment from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryDocumentController.recordPayment';

const CURRENCY_FMT = new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD' });

const STATUS_CONFIG = {
    Draft:    { label: 'Draft',    cssClass: 'status-badge status-badge--draft' },
    Ready:    { label: 'Ready',    cssClass: 'status-badge status-badge--ready' },
    Sent:     { label: 'Sent',     cssClass: 'status-badge status-badge--sent' },
    Viewed:   { label: 'Viewed',   cssClass: 'status-badge status-badge--viewed' },
    Paid:     { label: 'Paid',     cssClass: 'status-badge status-badge--paid' },
    Overdue:  { label: 'Overdue',  cssClass: 'status-badge status-badge--overdue' },
    Disputed: { label: 'Disputed', cssClass: 'status-badge status-badge--disputed' }
};

// Fallback if CMT query fails or returns empty
const DEFAULT_TEMPLATE_OPTIONS = [
    { label: 'Invoice', value: 'Invoice' }
];

export default class DeliveryDocumentViewer extends LightningElement {
    @api networkEntityId;
    @api documentId;

    // ── State ──
    @track _effectiveEntityId = null; // Resolved entity ID used by wire + generate
    @track documents = [];
    @track isLoading = true;
    @track error = null;
    @track mode = 'list'; // 'list' or 'preview'

    // Generate form state
    @track showGenerateForm = false;
    @track genTemplate = 'Invoice';
    @track genPeriodStart = '';
    @track genPeriodEnd = '';
    @track isGenerating = false;

    // Preview state
    @track previewDoc = null;
    @track snapshot = null;
    @track isLoadingPreview = false;
    @track isUpdatingStatus = false;

    // Send email state
    @track showSendModal = false;
    @track sendRecipientEmail = '';
    @track isSendingEmail = false;

    // Record payment state
    @track showPaymentModal = false;
    @track paymentAmount = null;
    @track paymentDate = '';
    @track paymentNote = '';
    @track isRecordingPayment = false;

    // Template options loaded from DocumentTemplate__mdt
    @track _templateOptions = DEFAULT_TEMPLATE_OPTIONS;

    _wiredDocsResult;

    // ═══════════════════════════════════════════════════════════
    //  LIFECYCLE
    // ═══════════════════════════════════════════════════════════

    connectedCallback() {
        // Explicit networkEntityId (from flexipage config) takes priority
        if (this.networkEntityId) {
            this._effectiveEntityId = this.networkEntityId;
        }
        if (this.documentId) {
            this.mode = 'preview';
            this._loadDocumentById(this.documentId);
        }
    }

    // ═══════════════════════════════════════════════════════════
    //  WIRE: Document List
    // ═══════════════════════════════════════════════════════════

    @wire(CurrentPageReference)
    handlePageRef(pageRef) {
        if (pageRef) {
            const recId = pageRef.attributes?.recordId || pageRef.state?.recordId;
            if (recId && !this.networkEntityId) {
                this._effectiveEntityId = recId;
            }
        }
    }

    @wire(getDocumentTemplates)
    wiredTemplates({ data, error }) {
        if (data && data.length > 0) {
            this._templateOptions = data.map(t => ({ label: t.label, value: t.value }));
            // Default the generate form to the first template
            if (!this.genTemplate || !this._templateOptions.some(o => o.value === this.genTemplate)) {
                this.genTemplate = this._templateOptions[0].value;
            }
        } else if (error) {
            // Silently fall back to defaults
            this._templateOptions = DEFAULT_TEMPLATE_OPTIONS;
        }
    }

    @wire(getDocumentsForEntity, { entityId: '$_effectiveEntityId' })
    wiredDocuments(result) {
        this._wiredDocsResult = result;
        const { data, error } = result;
        if (data) {
            this.documents = data.map(d => this._enrichDocument(d));
            this.error = null;
        } else if (error) {
            this.error = this._extractError(error);
            this.documents = [];
        }
        this.isLoading = false;
    }

    // ═══════════════════════════════════════════════════════════
    //  GETTERS
    // ═══════════════════════════════════════════════════════════

    get isListMode()    { return this.mode === 'list'; }
    get isPreviewMode() { return this.mode === 'preview'; }
    get isLoaded()      { return !this.isLoading; }
    get hasDocuments()  { return this.documents && this.documents.length > 0; }
    get hasError()      { return !!this.error; }
    get templateOptions() { return this._templateOptions; }

    get cardTitle() {
        return this.isListMode ? 'Documents' : (this.previewDoc?.name || 'Document Preview');
    }

    get documentCount() {
        return this.documents ? this.documents.length : 0;
    }

    // Generate form validation
    get isGenerateDisabled() {
        return !this.genTemplate || !this.genPeriodStart || !this.genPeriodEnd || this.isGenerating;
    }

    get generateButtonLabel() {
        return this.isGenerating ? 'Generating...' : 'Generate';
    }

    // ── Preview getters ──

    get hasPreviewDoc() { return this.previewDoc != null; }

    get previewStatusConfig() {
        return STATUS_CONFIG[this.previewDoc?.status] || STATUS_CONFIG.Draft;
    }

    get previewPeriod() {
        if (!this.previewDoc) return '';
        return `${this._formatDate(this.previewDoc.periodStart)} - ${this._formatDate(this.previewDoc.periodEnd)}`;
    }

    get isInvoiceTemplate() {
        return this.previewDoc?.template === 'Invoice';
    }

    get formattedTotalCost() {
        return CURRENCY_FMT.format(this.previewDoc?.totalCost || 0);
    }

    get formattedTotalHours() {
        const h = this.previewDoc?.totalHours || 0;
        return `${h.toFixed(1)} hrs`;
    }

    get entityName() {
        return this.snapshot?.entity?.name || this.previewDoc?.entityName || '';
    }

    get entityAddress() {
        return this.snapshot?.entity?.address || '';
    }

    get entityEmail() {
        return this.snapshot?.entity?.email || '';
    }

    get entityPhone() {
        return this.snapshot?.entity?.phone || '';
    }

    get entityDefaultRate() {
        const r = this.snapshot?.entity?.defaultRate;
        return r ? CURRENCY_FMT.format(r) + '/hr' : '';
    }

    get hasEntityContact() {
        return this.entityAddress || this.entityEmail || this.entityPhone;
    }

    get snapshotWorkItems() {
        if (!this.snapshot?.workItems) return [];
        return this.snapshot.workItems.map(wi => {
            const hours = wi.totalLoggedHours || 0;
            const rate = wi.billableRate || this.snapshot?.entity?.defaultRate || 0;
            const subtotal = hours * rate;
            return {
                id: wi.id,
                name: wi.name,
                description: wi.description || '--',
                stage: wi.stage || '--',
                hours: hours.toFixed(1),
                rate: CURRENCY_FMT.format(rate),
                subtotal: CURRENCY_FMT.format(subtotal)
            };
        });
    }

    get hasWorkItems() {
        return this.snapshotWorkItems.length > 0;
    }

    get snapshotWorkLogs() {
        if (!this.snapshot?.workLogs) return [];
        return this.snapshot.workLogs.map(wl => ({
            id: wl.id,
            workItemName: wl.workItemName || '--',
            hours: (wl.hours || 0).toFixed(1),
            date: this._formatDate(wl.date),
            description: wl.description || '--'
        }));
    }

    get hasWorkLogs() {
        return this.snapshotWorkLogs.length > 0;
    }

    get snapshotWorkRequests() {
        if (!this.snapshot?.workRequests) return [];
        return this.snapshot.workRequests.map(wr => ({
            id: wr.id,
            workItemName: wr.workItemName || '--',
            status: wr.status || '--',
            hourlyRate: wr.hourlyRate ? CURRENCY_FMT.format(wr.hourlyRate) : '--',
            totalLoggedHours: (wr.totalLoggedHours || 0).toFixed(1),
            vendorEntityName: wr.vendorEntityName || '--'
        }));
    }

    get hasWorkRequests() {
        return this.snapshotWorkRequests.length > 0;
    }

    get aiNarrative() {
        return this.previewDoc?.aiNarrative || '';
    }

    get hasAiNarrative() {
        return !!this.aiNarrative;
    }

    get documentTerms() {
        return this.previewDoc?.terms || 'Net 30';
    }

    get hasPublicToken() {
        return !!this.previewDoc?.publicToken;
    }

    get canMarkReady() {
        return this.previewDoc?.status === 'Draft';
    }

    get canMarkSent() {
        return this.previewDoc?.status === 'Ready';
    }

    get canSendEmail() {
        return this.previewDoc?.status === 'Ready' || this.previewDoc?.status === 'Draft';
    }

    get isSendDisabled() {
        return this.isSendingEmail;
    }

    get sendButtonLabel() {
        return this.isSendingEmail ? 'Sending...' : 'Send Email';
    }

    get canMarkPaid() {
        return this.previewDoc?.status === 'Sent' || this.previewDoc?.status === 'Viewed';
    }

    get canRecordPayment() {
        const s = this.previewDoc?.status;
        return s === 'Sent' || s === 'Viewed' || s === 'Overdue';
    }

    get isRecordPaymentDisabled() {
        return this.isRecordingPayment || !this.paymentAmount || this.paymentAmount <= 0 || !this.paymentDate;
    }

    get recordPaymentButtonLabel() {
        return this.isRecordingPayment ? 'Recording...' : 'Record Payment';
    }

    get templateDisplayName() {
        if (!this.previewDoc?.template) return '';
        return this.previewDoc.template.replace(/_/g, ' ');
    }

    get generatedAt() {
        return this.snapshot?.generatedAt ? this._formatDate(this.snapshot.generatedAt) : '';
    }

    // ═══════════════════════════════════════════════════════════
    //  HANDLERS: List Mode
    // ═══════════════════════════════════════════════════════════

    handleDocumentClick(event) {
        const docId = event.currentTarget.dataset.id;
        const doc = this.documents.find(d => d.id === docId);
        if (doc) {
            this._loadDocumentById(docId);
        }
    }

    handleOpenGenerateForm() {
        this.showGenerateForm = true;
        // Default period: first and last of current month
        const now = new Date();
        const y = now.getFullYear();
        const m = String(now.getMonth() + 1).padStart(2, '0');
        const lastDay = new Date(y, now.getMonth() + 1, 0).getDate();
        this.genPeriodStart = `${y}-${m}-01`;
        this.genPeriodEnd = `${y}-${m}-${String(lastDay).padStart(2, '0')}`;
    }

    handleCloseGenerateForm() {
        this.showGenerateForm = false;
        this._resetGenerateForm();
    }

    handleGenTemplateChange(event) {
        this.genTemplate = event.detail.value;
    }

    handleGenPeriodStartChange(event) {
        this.genPeriodStart = event.detail.value;
    }

    handleGenPeriodEndChange(event) {
        this.genPeriodEnd = event.detail.value;
    }

    async handleGenerate() {
        this.isGenerating = true;
        try {
            const newDocId = await generateDocument({
                entityId: this._effectiveEntityId,
                templateType: this.genTemplate,
                periodStart: this.genPeriodStart,
                periodEnd: this.genPeriodEnd,
                metadata: null
            });
            this._showToast('Success', 'Document generated successfully.', 'success');
            this.showGenerateForm = false;
            this._resetGenerateForm();
            await refreshApex(this._wiredDocsResult);
            // Navigate to preview
            this._loadDocumentById(newDocId);
        } catch (err) {
            this._showToast('Error', this._extractError(err), 'error');
        } finally {
            this.isGenerating = false;
        }
    }

    handleRefreshList() {
        this.isLoading = true;
        refreshApex(this._wiredDocsResult).then(() => {
            this.isLoading = false;
        });
    }

    // ═══════════════════════════════════════════════════════════
    //  HANDLERS: Preview Mode
    // ═══════════════════════════════════════════════════════════

    handleBackToList() {
        this.mode = 'list';
        this.previewDoc = null;
        this.snapshot = null;
    }

    async handleMarkReady() {
        await this._updateStatus('Ready');
    }

    async handleMarkSent() {
        await this._updateStatus('Sent');
    }

    async handleMarkPaid() {
        await this._updateStatus('Paid');
    }

    handleOpenSendModal() {
        // Default recipient to entity contact email from snapshot
        this.sendRecipientEmail = this.snapshot?.entity?.email || '';
        this.showSendModal = true;
    }

    handleCloseSendModal() {
        this.showSendModal = false;
        this.sendRecipientEmail = '';
    }

    handleSendRecipientChange(event) {
        this.sendRecipientEmail = event.detail.value;
    }

    async handleSendEmail() {
        if (!this.previewDoc?.id) return;
        this.isSendingEmail = true;
        try {
            const result = await sendDocumentEmail({
                documentId: this.previewDoc.id,
                recipientEmail: this.sendRecipientEmail
            });
            this.previewDoc = { ...this.previewDoc, status: 'Sent' };
            this.showSendModal = false;
            this.sendRecipientEmail = '';
            this._showToast('Email Sent', `Document emailed to ${result.recipientEmail}`, 'success');
            refreshApex(this._wiredDocsResult);
        } catch (err) {
            this._showToast('Error', this._extractError(err), 'error');
        } finally {
            this.isSendingEmail = false;
        }
    }

    handleOpenPaymentModal() {
        this.paymentAmount = null;
        this.paymentDate = new Date().toISOString().split('T')[0];
        this.paymentNote = '';
        this.showPaymentModal = true;
    }

    handleClosePaymentModal() {
        this.showPaymentModal = false;
        this.paymentAmount = null;
        this.paymentDate = '';
        this.paymentNote = '';
    }

    handlePaymentAmountChange(event) {
        this.paymentAmount = event.detail.value ? Number(event.detail.value) : null;
    }

    handlePaymentDateChange(event) {
        this.paymentDate = event.detail.value;
    }

    handlePaymentNoteChange(event) {
        this.paymentNote = event.detail.value;
    }

    async handleRecordPayment() {
        if (!this.previewDoc?.id || !this.paymentAmount || this.paymentAmount <= 0) return;
        this.isRecordingPayment = true;
        try {
            await recordPayment({
                documentId: this.previewDoc.id,
                amount: this.paymentAmount,
                paymentDate: this.paymentDate,
                note: this.paymentNote
            });
            // Determine new status: if payment covers total, it's Paid
            const existingPayment = this.previewDoc.paymentReceived || 0;
            const newPaymentTotal = existingPayment + this.paymentAmount;
            const docTotal = this.previewDoc.totalCost || 0;
            const newStatus = newPaymentTotal >= docTotal ? 'Paid' : this.previewDoc.status;
            this.previewDoc = {
                ...this.previewDoc,
                status: newStatus,
                paymentReceived: newPaymentTotal,
                paymentDate: this.paymentDate,
                paymentNote: this.paymentNote
            };
            this.showPaymentModal = false;
            this._showToast('Payment Recorded', `Payment of ${CURRENCY_FMT.format(this.paymentAmount)} recorded.`, 'success');
            refreshApex(this._wiredDocsResult);
        } catch (err) {
            this._showToast('Error', this._extractError(err), 'error');
        } finally {
            this.isRecordingPayment = false;
        }
    }

    handleViewPdf() {
        if (!this.previewDoc?.id) return;
        // Open VF page rendered as actual PDF in new tab
        window.open('/apex/DeliveryDocumentPdf?id=' + this.previewDoc.id + '&pdf=true', '_blank');
    }

    handleViewWeb() {
        if (!this.previewDoc?.id) return;
        // Open rich renderer (Static Resource bundle) in new tab
        window.open('/apex/DeliveryDocumentView?id=' + this.previewDoc.id, '_blank');
    }

    handleCopyPublicLink() {
        if (!this.previewDoc?.publicToken) return;
        // Copy the public token URL — works for Sites, portals, or any public access
        const baseUrl = window.location.origin;
        const url = baseUrl + '/apex/DeliveryDocumentPdf?token=' + this.previewDoc.publicToken;
        navigator.clipboard.writeText(url).then(() => {
            this._showToast('Copied', 'Public document link copied to clipboard.', 'success');
        }).catch(() => {
            // Fallback: show the URL in a prompt
            /* eslint-disable-next-line no-alert */
            window.prompt('Copy this link:', url);
        });
    }

    handlePrint() {
        window.print();
    }

    // ═══════════════════════════════════════════════════════════
    //  PRIVATE
    // ═══════════════════════════════════════════════════════════

    async _loadDocumentById(docId) {
        this.mode = 'preview';
        this.isLoadingPreview = true;
        this.previewDoc = null;
        this.snapshot = null;

        try {
            const result = await getDocumentById({ documentId: docId });
            this.previewDoc = {
                id: result.id,
                name: result.name,
                template: result.template,
                periodStart: result.periodStart,
                periodEnd: result.periodEnd,
                status: result.status,
                totalHours: result.totalHours,
                totalCost: result.totalCost,
                entityName: result.entityName,
                aiNarrative: result.aiNarrative,
                terms: result.terms,
                publicToken: result.publicToken,
                paymentReceived: result.paymentReceived,
                paymentDate: result.paymentDate,
                paymentNote: result.paymentNote
            };
            if (result.snapshot) {
                this.snapshot = JSON.parse(result.snapshot);
            }
        } catch (err) {
            this._showToast('Error', this._extractError(err), 'error');
        } finally {
            this.isLoadingPreview = false;
        }
    }

    async _updateStatus(newStatus) {
        if (!this.previewDoc?.id) return;
        this.isUpdatingStatus = true;
        try {
            await updateDocumentStatus({
                documentId: this.previewDoc.id,
                newStatus: newStatus
            });
            this.previewDoc = { ...this.previewDoc, status: newStatus };
            this._showToast('Success', `Document marked as ${newStatus}.`, 'success');
            // Refresh the list so it reflects updated status
            refreshApex(this._wiredDocsResult);
        } catch (err) {
            this._showToast('Error', this._extractError(err), 'error');
        } finally {
            this.isUpdatingStatus = false;
        }
    }

    _enrichDocument(d) {
        const sc = STATUS_CONFIG[d.status] || STATUS_CONFIG.Draft;
        return {
            id: d.id,
            name: d.name,
            template: d.template,
            templateDisplay: (d.template || '').replace(/_/g, ' '),
            periodStart: d.periodStart,
            periodEnd: d.periodEnd,
            periodDisplay: `${this._formatDate(d.periodStart)} - ${this._formatDate(d.periodEnd)}`,
            status: d.status,
            statusLabel: sc.label,
            statusClass: sc.cssClass,
            totalHours: d.totalHours || 0,
            hoursDisplay: `${(d.totalHours || 0).toFixed(1)} hrs`,
            totalCost: d.totalCost || 0,
            costDisplay: CURRENCY_FMT.format(d.totalCost || 0),
            createdDate: d.createdDate,
            createdDateDisplay: this._formatDate(d.createdDate)
        };
    }

    _formatDate(val) {
        if (!val) return '--';
        try {
            const d = new Date(val);
            return d.toLocaleDateString('en-US', { year: 'numeric', month: 'short', day: 'numeric' });
        } catch (e) {
            return String(val);
        }
    }

    _resetGenerateForm() {
        this.genTemplate = 'Invoice';
        this.genPeriodStart = '';
        this.genPeriodEnd = '';
    }

    _extractError(err) {
        if (typeof err === 'string') return err;
        if (err?.body?.message) return err.body.message;
        if (err?.message) return err.message;
        return 'An unexpected error occurred.';
    }

    _showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}

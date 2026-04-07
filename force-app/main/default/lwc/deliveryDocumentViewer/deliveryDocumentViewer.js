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
import generateDocument from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryDocumentController.generateDocument';
import getDefaultBillingEntityId from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryDocumentController.getDefaultBillingEntityId';
import getDocumentById from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryDocumentController.getDocumentById';
import getDocumentTemplates from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryDocumentController.getDocumentTemplates';
import getDocumentTransactions from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryDocumentController.getDocumentTransactions';
import getDocumentsForEntity from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryDocumentController.getDocumentsForEntity';
import recordPayment from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryDocumentController.recordPayment';
import sendDocumentEmail from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryDocumentController.sendDocumentEmail';
import previewDocumentEmail from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryDocumentController.previewDocumentEmail';
import scheduleDocumentSend from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryDocumentController.scheduleDocumentSend';
import getPendingInvoices from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryDocumentController.getPendingInvoices';
import updateDocumentStatus from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryDocumentController.updateDocumentStatus';
import signActionAdmin from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryDocActionController.signActionAdmin';
import getActionsForDocument from '@salesforce/apex/%%%NAMESPACE_DOT%%%DeliveryDocActionController.getActionsForDocument';

const CURRENCY_FMT = new Intl.NumberFormat('en-US', { currency: 'USD', style: 'currency' });

const STATUS_CONFIG = {
    Approved: { cssClass: 'status-badge status-badge--paid', label: 'Approved' },
    Awaiting_Signatures: { cssClass: 'status-badge status-badge--sent', label: 'Awaiting Signatures' },
    Disputed: { cssClass: 'status-badge status-badge--disputed', label: 'Disputed' },
    Draft: { cssClass: 'status-badge status-badge--draft', label: 'Draft' },
    Overdue: { cssClass: 'status-badge status-badge--overdue', label: 'Overdue' },
    Paid: { cssClass: 'status-badge status-badge--paid', label: 'Paid' },
    Ready: { cssClass: 'status-badge status-badge--ready', label: 'Ready' },
    Sent: { cssClass: 'status-badge status-badge--sent', label: 'Sent' },
    Viewed: { cssClass: 'status-badge status-badge--viewed', label: 'Viewed' }
};

// Fallback if CMT query fails or returns empty
const DEFAULT_TEMPLATE_OPTIONS = [
    { label: 'Client Agreement', value: 'Client_Agreement' },
    { label: 'Contractor Agreement', value: 'Contractor_Agreement' },
    { label: 'Invoice', value: 'Invoice' },
    { label: 'Status Report', value: 'Status_Report' }
];

export default class DeliveryDocumentViewer extends LightningElement {
    @api networkEntityId;
    @api documentId;

    // State
    @track effectiveEntityId = null;
    @track documents = [];
    @track isLoading = true;
    @track error = null;
    @track mode = 'list';

    // Pending invoices banner
    @track pendingInvoiceCount = 0;

    // Generate form state
    @track showGenerateForm = false;
    @track genTemplate = 'Invoice';
    @track genPeriodStart = '';
    @track genPeriodEnd = '';
    @track isGenerating = false;

    // Preview state
    @track previewDoc = null;
    @track snapshot = null;
    @track transactions = [];
    @track totalPaid = 0;
    @track isLoadingPreview = false;
    @track isUpdatingStatus = false;

    // Metadata (clauses, etc.)
    @track metadata = null;

    // Send email state
    @track showSendModal = false;
    @track sendRecipientEmail = '';
    @track isSendingEmail = false;
    @track emailPreview = null;
    @track isLoadingEmailPreview = false;
    @track isScheduleMode = false;
    @track scheduledDateTime = null;
    @track isScheduling = false;
    _emailBodyRendered = false;

    // Record payment state
    @track showPaymentModal = false;
    @track paymentAmount = null;
    @track paymentDate = '';
    @track paymentNote = '';
    @track isRecordingPayment = false;

    // Document actioning / signatures (Phase 2)
    @track actions = [];
    @track requiresSigning = false;
    @track consentText = '';

    // Template options loaded from DocumentTemplate__mdt
    @track docTemplateOptions = DEFAULT_TEMPLATE_OPTIONS;

    wiredDocsResult;

    // ═══════════════════════════════════════════════════════════
    //  LIFECYCLE
    // ═══════════════════════════════════════════════════════════

    connectedCallback() {
        // Explicit networkEntityId (from flexipage config) takes priority
        if (this.networkEntityId) {
            this.effectiveEntityId = this.networkEntityId;
        }
        if (this.documentId) {
            this.mode = 'preview';
            this.loadDocumentById(this.documentId);
        }
        // Fallback: if no entity context, load from DefaultBillingEntityId setting
        if (!this.networkEntityId && !this.documentId) {
            this.loadDefaultBillingEntity();
        }
        this.loadPendingInvoices();
    }

    renderedCallback() {
        if (this.emailPreview?.bodyHtml && !this._emailBodyRendered) {
            const container = this.template.querySelector('.email-body-preview');
            if (container) {
                container.innerHTML = this.emailPreview.bodyHtml;
                this._emailBodyRendered = true;
            }
        }
    }

    get hasPendingInvoices() {
        return this.pendingInvoiceCount > 0;
    }

    get pendingInvoiceBannerText() {
        const count = this.pendingInvoiceCount;
        if (count === 1) {
            return '1 document pending review';
        }
        return `${count} documents pending review`;
    }

    async loadPendingInvoices() {
        try {
            const result = await getPendingInvoices();
            this.pendingInvoiceCount = result ? result.count : 0;
        } catch (e) {
            this.pendingInvoiceCount = 0;
        }
    }

    async loadDefaultBillingEntity() {
        try {
            const billingEntityId = await getDefaultBillingEntityId();
            if (billingEntityId && !this.effectiveEntityId) {
                this.effectiveEntityId = billingEntityId;
            }
        } catch (e) {
            // Setting not configured — no fallback
        }
    }

    // ═══════════════════════════════════════════════════════════
    //  WIRE: Document List
    // ═══════════════════════════════════════════════════════════

    @wire(CurrentPageReference)
    handlePageRef(pageRef) {
        if (pageRef) {
            const recId = pageRef.attributes?.recordId || pageRef.state?.recordId;
            const objName = pageRef.attributes?.objectApiName || '';
            if (recId && !this.networkEntityId) {
                // If we're on a Document record page, load that document directly
                if (objName === '%%%NAMESPACED_ORG%%%DeliveryDocument__c' || objName === 'DeliveryDocument__c') {
                    this.loadDocumentById(recId);
                } else {
                    this.effectiveEntityId = recId;
                }
            }
        }
    }

    @wire(getDocumentTemplates)
    wiredTemplates({ data, error }) {
        if (data && data.length > 0) {
            this.docTemplateOptions = data.map(t => ({ label: t.label, value: t.value }));
            // Default the generate form to the first template
            if (!this.genTemplate || !this.docTemplateOptions.some(o => o.value === this.genTemplate)) {
                this.genTemplate = this.docTemplateOptions[0].value;
            }
        } else if (error) {
            // Silently fall back to defaults
            this.docTemplateOptions = DEFAULT_TEMPLATE_OPTIONS;
        }
    }

    @wire(getDocumentsForEntity, { entityId: '$effectiveEntityId' })
    wiredDocuments(result) {
        this.wiredDocsResult = result;
        const { data, error } = result;
        if (data) {
            this.documents = data.map(d => this.enrichDocument(d));
            this.error = null;
        } else if (error) {
            this.error = this.extractError(error);
            this.documents = [];
        }
        this.isLoading = false;
    }

    // ═══════════════════════════════════════════════════════════
    //  GETTERS
    // ═══════════════════════════════════════════════════════════

    get isListMode() {
        return this.mode === 'list';
    }

    get isPreviewMode() {
        return this.mode === 'preview';
    }

    get isLoaded() {
        return !this.isLoading;
    }

    get hasDocuments() {
        return this.documents && this.documents.length > 0;
    }
    get hasError() {
        return Boolean(this.error);
    }

    get templateOptions() {
        return this.docTemplateOptions;
    }

    get cardTitle() {
        if (this.isListMode) {
            return 'Documents';
        }
        return this.previewDoc?.name || 'Document Preview';
    }

    get documentCount() {
        if (this.documents) {
            return this.documents.length;
        }
        return 0;
    }

    // Generate form validation
    get isGenerateDisabled() {
        return !this.genTemplate || !this.genPeriodStart || !this.genPeriodEnd || this.isGenerating;
    }

    get generateButtonLabel() {
        if (this.isGenerating) {
            return 'Generating...';
        }
        return 'Generate';
    }

    get hasPreviewDoc() {
        return this.previewDoc !== undefined && this.previewDoc !== null;
    }

    get previewStatusConfig() {
        return STATUS_CONFIG[this.previewDoc?.status] || STATUS_CONFIG.Draft;
    }

    get previewPeriod() {
        if (!this.previewDoc) {
            return '';
        }
        return `${DeliveryDocumentViewer.formatDate(this.previewDoc.periodStart)} - ${DeliveryDocumentViewer.formatDate(this.previewDoc.periodEnd)}`;
    }

    get isInvoiceTemplate() {
        return this.previewDoc?.template === 'Invoice';
    }

    get isAgreementTemplate() {
        const tmpl = this.previewDoc?.template;
        return tmpl === 'Client_Agreement' || tmpl === 'Contractor_Agreement';
    }

    get isStatusReportTemplate() {
        return this.previewDoc?.template === 'Status_Report';
    }

    get agreementClauses() {
        if (!this.metadata?.clauses) {
            return [];
        }
        return this.metadata.clauses.map((clause, idx) => ({
            body: clause.body || '',
            key: `clause-${idx}`,
            seq: idx + 1,
            title: clause.title || ''
        }));
    }

    get hasAgreementClauses() {
        return this.agreementClauses.length > 0;
    }

    get formattedTotalCost() {
        return CURRENCY_FMT.format(this.previewDoc?.totalCost || 0);
    }

    get formattedTotalHours() {
        const hours = this.previewDoc?.totalHours || 0;
        return `${hours.toFixed(1)} hrs`;
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
        const rate = this.snapshot?.entity?.defaultRate;
        if (rate) {
            return `${CURRENCY_FMT.format(rate)}/hr`;
        }
        return '';
    }

    get hasEntityContact() {
        return this.entityAddress || this.entityEmail || this.entityPhone;
    }

    get snapshotWorkItems() {
        if (!this.snapshot?.workItems) {
            return [];
        }
        return this.snapshot.workItems.map(workItem => {
            const loggedHours = workItem.totalLoggedHours || 0;
            const hourlyRate = workItem.billableRate || this.snapshot?.entity?.defaultRate || 0;
            const subtotal = loggedHours * hourlyRate;
            return {
                description: workItem.description || '--',
                hours: loggedHours.toFixed(1),
                id: workItem.id,
                name: workItem.name,
                rate: CURRENCY_FMT.format(hourlyRate),
                stage: workItem.stage || '--',
                subtotal: CURRENCY_FMT.format(subtotal)
            };
        });
    }

    get hasWorkItems() {
        return this.snapshotWorkItems.length > 0;
    }

    get snapshotWorkLogs() {
        if (!this.snapshot?.workLogs) {
            return [];
        }
        return this.snapshot.workLogs.map(logEntry => ({
            date: DeliveryDocumentViewer.formatDate(logEntry.date),
            description: logEntry.description || '--',
            hours: (logEntry.hours || 0).toFixed(1),
            id: logEntry.id,
            workItemName: logEntry.workItemName || '--'
        }));
    }

    get hasWorkLogs() {
        return this.snapshotWorkLogs.length > 0;
    }

    get snapshotWorkRequests() {
        if (!this.snapshot?.workRequests) {
            return [];
        }
        return this.snapshot.workRequests.map(request => ({
            hourlyRate: request.hourlyRate ? CURRENCY_FMT.format(request.hourlyRate) : '--',
            id: request.id,
            status: request.status || '--',
            totalLoggedHours: (request.totalLoggedHours || 0).toFixed(1),
            vendorEntityName: request.vendorEntityName || '--',
            workItemName: request.workItemName || '--'
        }));
    }

    get hasWorkRequests() {
        return this.snapshotWorkRequests.length > 0;
    }

    get aiNarrative() {
        return this.previewDoc?.aiNarrative || '';
    }

    get hasAiNarrative() {
        return Boolean(this.aiNarrative);
    }

    get documentTerms() {
        return this.previewDoc?.terms || 'Net 30';
    }

    get hasPublicToken() {
        return Boolean(this.previewDoc?.publicToken);
    }

    get hasTransactions() {
        return this.transactions && this.transactions.length > 0;
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

    get isSendNowDisabled() {
        return this.isSendingEmail || !this.sendRecipientEmail;
    }

    get sendButtonLabel() {
        return this.isSendingEmail ? 'Sending...' : 'Send Now';
    }

    get sendEmailToolbarLabel() {
        return 'Prepare Email';
    }

    get scheduleButtonLabel() {
        return this.isScheduling ? 'Scheduling...' : 'Schedule Send';
    }

    get isScheduleDisabled() {
        return this.isScheduling || !this.scheduledDateTime || !this.sendRecipientEmail;
    }

    get minScheduleDateTime() {
        return new Date().toISOString();
    }

    get canMarkPaid() {
        return this.previewDoc?.status === 'Sent' || this.previewDoc?.status === 'Viewed';
    }

    get canRecordPayment() {
        const docStatus = this.previewDoc?.status;
        return docStatus === 'Sent' || docStatus === 'Viewed' || docStatus === 'Overdue';
    }

    get isRecordPaymentDisabled() {
        return this.isRecordingPayment || !this.paymentAmount || this.paymentAmount <= 0 || !this.paymentDate;
    }

    get recordPaymentButtonLabel() {
        if (this.isRecordingPayment) {
            return 'Recording...';
        }
        return 'Record Payment';
    }

    get templateDisplayName() {
        if (!this.previewDoc?.template) {
            return '';
        }
        return this.previewDoc.template.replace(/_/gu, ' ');
    }

    get generatedAt() {
        if (this.snapshot?.generatedAt) {
            return DeliveryDocumentViewer.formatDate(this.snapshot.generatedAt);
        }
        return '';
    }

    // ═══════════════════════════════════════════════════════════
    //  HANDLERS: List Mode
    // ═══════════════════════════════════════════════════════════

    handleDocumentClick(event) {
        const docId = event.currentTarget.dataset.id;
        const doc = this.documents.find(d => d.id === docId);
        if (doc) {
            this.loadDocumentById(docId);
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
        this.resetGenerateForm();
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
                entityId: this.effectiveEntityId,
                templateType: this.genTemplate,
                periodStart: this.genPeriodStart,
                periodEnd: this.genPeriodEnd,
                metadata: null
            });
            this.showToast('Success', 'Document generated successfully.', 'success');
            this.showGenerateForm = false;
            this.resetGenerateForm();
            await refreshApex(this.wiredDocsResult);
            // Navigate to preview
            this.loadDocumentById(newDocId);
        } catch (err) {
            this.showToast('Error', this.extractError(err), 'error');
        } finally {
            this.isGenerating = false;
        }
    }

    handleRefreshList() {
        this.isLoading = true;
        refreshApex(this.wiredDocsResult).then(() => {
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
        this.metadata = null;
        this.transactions = [];
        this.totalPaid = 0;
    }

    async handleMarkReady() {
        await this.updateDocStatus('Ready');
    }

    async handleMarkSent() {
        await this.updateDocStatus('Sent');
    }

    async handleMarkPaid() {
        await this.updateDocStatus('Paid');
    }

    async handleOpenSendModal() {
        this.sendRecipientEmail = this.snapshot?.entity?.email || '';
        this.emailPreview = null;
        this.isScheduleMode = false;
        this.scheduledDateTime = null;
        this._emailBodyRendered = false;
        this.showSendModal = true;
        this.isLoadingEmailPreview = true;
        try {
            this.emailPreview = await previewDocumentEmail({
                documentId: this.previewDoc.id,
                recipientEmail: this.sendRecipientEmail
            });
            if (this.emailPreview.toEmail) {
                this.sendRecipientEmail = this.emailPreview.toEmail;
            }
        } catch (err) {
            this.showToast('Error', this.extractError(err), 'error');
            this.showSendModal = false;
        } finally {
            this.isLoadingEmailPreview = false;
        }
    }

    handleCloseSendModal() {
        this.showSendModal = false;
        this.sendRecipientEmail = '';
        this.emailPreview = null;
        this.isScheduleMode = false;
        this.scheduledDateTime = null;
        this._emailBodyRendered = false;
    }

    handleSendRecipientChange(event) {
        this.sendRecipientEmail = event.detail.value;
    }

    handleScheduleToggle(event) {
        this.isScheduleMode = event.target.checked;
        if (this.isScheduleMode && !this.scheduledDateTime) {
            this.handleSetNextBusinessDay();
        }
    }

    handleScheduleDateTimeChange(event) {
        this.scheduledDateTime = event.detail.value;
    }

    handleSetNextBusinessDay() {
        const now = new Date();
        let target = new Date(now);
        target.setDate(target.getDate() + 1);
        while (target.getDay() === 0 || target.getDay() === 6) {
            target.setDate(target.getDate() + 1);
        }
        target.setHours(8, 0, 0, 0);
        this.scheduledDateTime = target.toISOString();
    }

    async handleSendEmail() {
        if (!this.previewDoc?.id) {
            return;
        }
        this.isSendingEmail = true;
        try {
            const result = await sendDocumentEmail({
                documentId: this.previewDoc.id,
                recipientEmail: this.sendRecipientEmail
            });
            this.previewDoc = { ...this.previewDoc, status: 'Sent' };
            this.showSendModal = false;
            this.sendRecipientEmail = '';
            this.emailPreview = null;
            this.showToast('Email Sent', `Document emailed to ${result.recipientEmail}`, 'success');
            refreshApex(this.wiredDocsResult);
        } catch (err) {
            this.showToast('Error', this.extractError(err), 'error');
        } finally {
            this.isSendingEmail = false;
        }
    }

    async handleScheduleSend() {
        if (!this.previewDoc?.id || !this.scheduledDateTime) {
            return;
        }
        this.isScheduling = true;
        try {
            await scheduleDocumentSend({
                documentId: this.previewDoc.id,
                recipientEmail: this.sendRecipientEmail,
                sendAt: this.scheduledDateTime
            });
            const dt = new Date(this.scheduledDateTime);
            const formatted = dt.toLocaleString(undefined, {
                weekday: 'short', month: 'short', day: 'numeric',
                hour: 'numeric', minute: '2-digit'
            });
            this.previewDoc = { ...this.previewDoc, status: 'Ready' };
            this.showSendModal = false;
            this.emailPreview = null;
            this.showToast('Scheduled', `Email scheduled for ${formatted}`, 'success');
            refreshApex(this.wiredDocsResult);
        } catch (err) {
            this.showToast('Error', this.extractError(err), 'error');
        } finally {
            this.isScheduling = false;
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
        if (!this.previewDoc?.id || !this.paymentAmount || this.paymentAmount <= 0) {
            return;
        }
        this.isRecordingPayment = true;
        try {
            await recordPayment({
                documentId: this.previewDoc.id,
                amount: this.paymentAmount,
                paymentDate: this.paymentDate,
                note: this.paymentNote
            });
            // Optimistically add transaction to local array and recalculate
            const newTxn = {
                amount: this.paymentAmount,
                date: this.paymentDate,
                id: `pending-${Date.now()}`,
                note: this.paymentNote,
                type: 'Payment'
            };
            this.transactions = [...this.transactions, newTxn];
            this.totalPaid = this.totalPaid + this.paymentAmount;
            // Determine new status: if payments cover total, it's Paid
            const docTotal = this.previewDoc.totalCost || 0;
            const newStatus = this.totalPaid >= docTotal ? 'Paid' : this.previewDoc.status;
            this.previewDoc = { ...this.previewDoc, status: newStatus };
            this.showPaymentModal = false;
            this.showToast('Payment Recorded', `Payment of ${CURRENCY_FMT.format(this.paymentAmount)} recorded.`, 'success');
            refreshApex(this.wiredDocsResult);
            // Refresh real transaction list from server
            this.refreshTransactions();
        } catch (err) {
            this.showToast('Error', this.extractError(err), 'error');
        } finally {
            this.isRecordingPayment = false;
        }
    }

    // VF page prefix: 'delivery__' for managed package, '' for unmanaged
    get vfPrefix() {
        // Detect namespace from the component's module name
        const moduleName = this.template.host?.localName || '';
        if (moduleName.startsWith('delivery-')) {
            return 'delivery__';
        }
        return '';
    }

    handlePreviewPdf() {
        const docId = this.emailPreview?.documentId || this.previewDoc?.id;
        if (!docId) { return; }
        window.open(`/apex/${this.vfPrefix}DeliveryDocumentPdf?id=${docId}&pdf=true`, '_blank');
    }

    handleViewPdf() {
        if (!this.previewDoc?.id) {
            return;
        }
        window.open(`/apex/${this.vfPrefix}DeliveryDocumentPdf?id=${this.previewDoc.id}&pdf=true`, '_blank');
    }

    handleViewWeb() {
        if (!this.previewDoc?.id) {
            return;
        }
        window.open(`/apex/${this.vfPrefix}DeliveryDocumentPdf?id=${this.previewDoc.id}`, '_blank');
    }

    handleCopyPublicLink() {
        if (!this.previewDoc?.publicToken) {
            return;
        }
        const baseUrl = window.location.origin;
        const publicUrl = `${baseUrl}/apex/${this.vfPrefix}DeliveryDocumentPdf?token=${this.previewDoc.publicToken}`;
        // LockerService blocks navigator.clipboard — use hidden textarea fallback
        const textarea = document.createElement('textarea');
        textarea.value = publicUrl;
        textarea.style.position = 'fixed';
        textarea.style.opacity = '0';
        document.body.appendChild(textarea);
        textarea.select();
        try {
            document.execCommand('copy');
            this.showToast('Copied', 'Public document link copied to clipboard.', 'success');
        } catch (err) {
            window.prompt('Copy this link:', publicUrl); // eslint-disable-line no-alert
        } finally {
            document.body.removeChild(textarea);
        }
    }

    handlePrint() {
        window.print();
    }

    // ═══════════════════════════════════════════════════════════
    //  PRIVATE
    // ═══════════════════════════════════════════════════════════

    async loadDocumentById(docId) {
        this.mode = 'preview';
        // Ensure the list-mode loading gate is cleared so preview template renders
        this.isLoading = false;
        this.isLoadingPreview = true;
        this.previewDoc = null;
        this.snapshot = null;
        this.metadata = null;
        this.transactions = [];
        this.totalPaid = 0;
        this.actions = [];
        this.requiresSigning = false;

        try {
            const result = await getDocumentById({ documentId: docId });
            this.previewDoc = {
                aiNarrative: result.aiNarrative,
                entityName: result.entityName,
                id: result.id,
                name: result.name,
                periodEnd: result.periodEnd,
                periodStart: result.periodStart,
                publicToken: result.publicToken,
                status: result.status,
                template: result.template,
                terms: result.terms,
                totalCost: result.totalCost,
                totalHours: result.totalHours
            };
            this.transactions = result.transactions || [];
            this.totalPaid = result.totalPaid || 0;
            this.actions = result.actions || [];
            this.requiresSigning = result.requiresSigning === true;
            if (result.snapshot) {
                this.snapshot = JSON.parse(result.snapshot);
            }
            if (result.metadata) {
                try {
                    this.metadata = JSON.parse(result.metadata);
                } catch (parseErr) { // eslint-disable-line no-unused-vars
                    this.metadata = null;
                }
            }
        } catch (err) {
            this.showToast('Error', this.extractError(err), 'error');
        } finally {
            this.isLoadingPreview = false;
        }
    }

    // ═══════════════════════════════════════════════════════════
    //  SIGNATURE BLOCK HANDLERS (Phase 2)
    // ═══════════════════════════════════════════════════════════

    /**
     * Handles the `signsubmit` event from the deliveryDocumentSignatureBlock child LWC.
     * Calls the admin signing controller and refreshes the actions list. The child LWC
     * stays in submitting state until we call its completeSubmission(success) API.
     */
    async handleSignSubmit(event) {
        const { actionId, signerName, signerEmail, consentGiven } = event.detail;
        const childLwc = this.template.querySelector('c-delivery-document-signature-block');
        try {
            const result = await signActionAdmin({
                actionId,
                signerName,
                signerEmail,
                consentGiven
            });
            this.showToast('Signed', `${signerName} signed the document.`, 'success');

            // Refresh the actions list from the server so the slot now shows as completed
            const refreshed = await getActionsForDocument({ documentId: this.previewDoc.id });
            this.actions = refreshed || [];

            // If the doc status flipped to Approved, update the preview
            if (result && result.documentStatus) {
                this.previewDoc = { ...this.previewDoc, status: result.documentStatus };
                refreshApex(this.wiredDocsResult);
            }

            if (childLwc) {
                childLwc.completeSubmission(true);
            }
        } catch (err) {
            this.showToast('Error', this.extractError(err), 'error');
            if (childLwc) {
                childLwc.completeSubmission(false);
            }
        }
    }

    async updateDocStatus(newStatus) {
        if (!this.previewDoc?.id) {
            return;
        }
        this.isUpdatingStatus = true;
        try {
            await updateDocumentStatus({
                documentId: this.previewDoc.id,
                newStatus
            });
            this.previewDoc = { ...this.previewDoc, status: newStatus };
            this.showToast('Success', `Document marked as ${newStatus}.`, 'success');
            // Refresh the list so it reflects updated status
            refreshApex(this.wiredDocsResult);
        } catch (err) {
            this.showToast('Error', this.extractError(err), 'error');
        } finally {
            this.isUpdatingStatus = false;
        }
    }

    async refreshTransactions() {
        if (!this.previewDoc?.id) {
            return;
        }
        try {
            const txns = await getDocumentTransactions({ documentId: this.previewDoc.id });
            this.transactions = txns || [];
            // Recalculate totalPaid from real data
            this.totalPaid = this.transactions.reduce((sum, txn) => sum + (txn.amount || 0), 0);
        } catch (err) { // eslint-disable-line no-unused-vars
            // Silently fail — optimistic data is still in place
        }
    }

    enrichDocument(doc) {
        const statusCfg = STATUS_CONFIG[doc.status] || STATUS_CONFIG.Draft;
        const invoiceType = doc.template === 'Invoice';
        const hoursLabel = invoiceType ? `${(doc.totalHours || 0).toFixed(1)} hrs` : '\u2014';
        const costLabel = invoiceType ? CURRENCY_FMT.format(doc.totalCost || 0) : '\u2014';
        return {
            costDisplay: costLabel,
            createdDate: doc.createdDate,
            createdDateDisplay: DeliveryDocumentViewer.formatDate(doc.createdDate),
            hoursDisplay: hoursLabel,
            id: doc.id,
            isInvoice: invoiceType,
            name: doc.name,
            periodDisplay: `${DeliveryDocumentViewer.formatDate(doc.periodStart)} - ${DeliveryDocumentViewer.formatDate(doc.periodEnd)}`,
            periodEnd: doc.periodEnd,
            periodStart: doc.periodStart,
            status: doc.status,
            statusClass: statusCfg.cssClass,
            statusLabel: statusCfg.label,
            template: doc.template,
            templateDisplay: (doc.template || '').replace(/_/gu, ' '),
            totalCost: doc.totalCost || 0,
            totalHours: doc.totalHours || 0
        };
    }

    static formatDate(val) {
        if (!val) {
            return '--';
        }
        try {
            const dateObj = new Date(val);
            return dateObj.toLocaleDateString('en-US', { day: 'numeric', month: 'short', year: 'numeric' });
        } catch (err) { // eslint-disable-line no-unused-vars
            return String(val);
        }
    }

    resetGenerateForm() {
        if (this.docTemplateOptions.length > 0) {
            this.genTemplate = this.docTemplateOptions[0].value;
        } else {
            this.genTemplate = 'Invoice';
        }
        this.genPeriodStart = '';
        this.genPeriodEnd = '';
    }

    extractError(err) {
        if (typeof err === 'string') {
            return err;
        }
        if (err?.body?.message) {
            return err.body.message;
        }
        if (err?.message) {
            return err.message;
        }
        return 'An unexpected error occurred.';
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ message, title, variant }));
    }
}

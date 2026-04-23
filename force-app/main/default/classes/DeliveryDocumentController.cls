/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Thin facade controller for the Document Engine. Delegates all logic to:
 *              DeliveryDocQueryService, DeliveryDocGenerationService, DeliveryDocPaymentService,
 *              DeliveryDocEmailService, and DeliveryDocApprovalService.
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.AvoidGlobalModifier')
global with sharing class DeliveryDocumentController {

    // ═══════════════════════════════════════════════════════════
    //  GENERATION
    // ═══════════════════════════════════════════════════════════

    /** @description Generates a document (invoice, agreement, status report, etc.) for the given entity and period. */
    @SuppressWarnings('PMD.ExcessiveParameterList')
    @AuraEnabled
    global static Id generateDocument(Id entityId, String templateType, Date periodStart, Date periodEnd, String metadata) {
        return DeliveryDocGenerationService.generateDocument(entityId, templateType, periodStart, periodEnd, metadata);
    }

    // ═══════════════════════════════════════════════════════════
    //  QUERIES
    // ═══════════════════════════════════════════════════════════

    /** @description Returns a summary of all pending draft invoices and daily hour summaries. */
    @AuraEnabled(cacheable=true)
    global static Map<String, Object> getPendingInvoices() {
        return DeliveryDocQueryService.getPendingInvoices();
    }

    /** @description Retrieves a document by its public access token for portal rendering. */
    @AuraEnabled(cacheable=true)
    global static Map<String, Object> getDocumentByToken(String publicToken) {
        return DeliveryDocQueryService.getDocumentByToken(publicToken);
    }

    /** @description Retrieves a document by its Salesforce record Id for the embedded viewer. */
    @AuraEnabled(cacheable=true)
    global static Map<String, Object> getDocumentById(Id documentId) {
        return DeliveryDocQueryService.getDocumentById(documentId);
    }

    /** @description Lists all documents for a given entity, ordered by creation date descending. */
    @AuraEnabled(cacheable=true)
    global static List<Map<String, Object>> getDocumentsForEntity(Id entityId) {
        return DeliveryDocQueryService.getDocumentsForEntity(entityId);
    }

    /** @description Returns available document templates from DocumentTemplate__mdt custom metadata. */
    @AuraEnabled(cacheable=true)
    global static List<Map<String, String>> getDocumentTemplates() {
        return DeliveryDocQueryService.getDocumentTemplates();
    }

    /** @description Queries all transaction records (payments, approvals) for a given document. */
    @AuraEnabled
    global static List<Map<String, Object>> getDocumentTransactions(Id documentId) {
        return DeliveryDocQueryService.getTransactionsForDocument(documentId);
    }

    /** @description Returns the default billing entity Id from org-level custom settings. */
    @AuraEnabled(cacheable=true)
    global static String getDefaultBillingEntityId() {
        return DeliveryDocQueryService.getDefaultBillingEntityId();
    }

    /**
     * @description Returns the list of active NetworkEntity__c records that can
     *              be billed (EntityTypePk__c = 'Client' or 'Both'), formatted
     *              as {label, value} maps for a lightning-combobox. Drives the
     *              Client picker on the Generate Document form so the invoice
     *              generator is usable when the viewer isn't already scoped to
     *              a client record page.
     * @return List of {label, value} maps keyed to NetworkEntity__c Id.
     */
    @AuraEnabled(cacheable=true)
    global static List<Map<String, String>> getAvailableClients() {
        return DeliveryDocQueryService.getAvailableClients();
    }

    // ═══════════════════════════════════════════════════════════
    //  STATUS UPDATES
    // ═══════════════════════════════════════════════════════════

    /** @description Updates a document's status and publishes a platform event for external subscribers. */
    @AuraEnabled
    global static void updateDocumentStatus(Id documentId, String newStatus) {
        DeliveryDocument__c doc = [
            SELECT Id, StatusPk__c, SentDateTime__c, DueDateDate__c, TermsTxt__c,
                   TemplatePk__c, NetworkEntityId__r.Name
            FROM DeliveryDocument__c
            WHERE Id = :documentId
            WITH SYSTEM_MODE
            LIMIT 1
        ];

        doc.StatusPk__c = newStatus;

        if (newStatus == 'Sent' && doc.SentDateTime__c == null) {
            doc.SentDateTime__c = Datetime.now();
            if (doc.DueDateDate__c == null && String.isNotBlank(doc.TermsTxt__c)) {
                doc.DueDateDate__c = DeliveryDocEmailService.parseDueDate(doc.TermsTxt__c, Date.today());
            }
        }

        Database.update(doc, AccessLevel.SYSTEM_MODE);

        String entityName = doc.NetworkEntityId__r != null ? doc.NetworkEntityId__r.Name : '';
        EventBus.publish(new DeliveryDocEvent__e(
            DocumentIdTxt__c = doc.Id,
            TemplateTxt__c   = doc.TemplatePk__c,
            StatusTxt__c     = newStatus,
            EntityNameTxt__c = entityName
        ));
    }

    /** @description Saves an AI-generated narrative summary to the document record. */
    @AuraEnabled
    global static void saveAiNarrative(Id documentId, String narrative) {
        DeliveryDocument__c doc = new DeliveryDocument__c(
            Id = documentId,
            AiNarrativeTxt__c = narrative
        );
        Database.update(doc, AccessLevel.SYSTEM_MODE);
    }

    // ═══════════════════════════════════════════════════════════
    //  PAYMENTS
    // ═══════════════════════════════════════════════════════════

    /** @description Records a payment against a document and auto-marks it Paid when fully covered. */
    @AuraEnabled
    global static void recordPayment(Id documentId, Decimal amount, Date paymentDate, String note) {
        DeliveryDocPaymentService.recordPayment(documentId, amount, paymentDate, note);
    }

    // ═══════════════════════════════════════════════════════════
    //  EMAIL
    // ═══════════════════════════════════════════════════════════

    /** @description Sends a document as a PDF email attachment and marks it as Sent. */
    @AuraEnabled
    global static Map<String, Object> sendDocumentEmail(Id documentId, String recipientEmail) {
        return DeliveryDocEmailService.sendDocumentEmail(documentId, recipientEmail);
    }

    /** @description Returns a preview of the email that would be sent for this document. */
    @AuraEnabled
    global static Map<String, Object> previewDocumentEmail(Id documentId, String recipientEmail) {
        return DeliveryDocEmailService.previewDocumentEmail(documentId, recipientEmail);
    }

    /** @description Schedules a document to be automatically emailed at a future date/time. */
    @AuraEnabled
    global static Map<String, Object> scheduleDocumentSend(Id documentId, String recipientEmail, Datetime sendAt) {
        return DeliveryDocEmailService.scheduleDocumentSend(documentId, recipientEmail, sendAt);
    }

    /** @description Cancels a previously scheduled document send. */
    @AuraEnabled
    global static Map<String, Object> cancelScheduledSend(Id documentId) {
        return DeliveryDocEmailService.cancelScheduledSend(documentId);
    }

    /** @description Processes all documents whose scheduled send time has passed (called by scheduler). */
    public static void processScheduledDocumentSends() {
        DeliveryDocEmailService.processScheduledDocumentSends();
    }

    // ═══════════════════════════════════════════════════════════
    //  APPROVAL (token-authenticated, called from API service)
    // ═══════════════════════════════════════════════════════════

    /** @description Approves a document identified by its public token and logs the action. */
    public static Map<String, Object> approveDocumentByToken(String publicToken) {
        return DeliveryDocApprovalService.approveDocumentByToken(publicToken);
    }

    /** @description Disputes a document identified by its public token with a reason. */
    public static Map<String, Object> disputeDocumentByToken(String publicToken, String reason) {
        return DeliveryDocApprovalService.disputeDocumentByToken(publicToken, reason);
    }

    // ═══════════════════════════════════════════════════════════
    //  DELEGATES FOR @TestVisible METHODS (preserve test API)
    // ═══════════════════════════════════════════════════════════

    /** @description Calculates the outstanding balance from prior unpaid invoices for an entity. */
    @TestVisible
    private static Decimal calculatePriorBalance(Id entityId, Date currentPeriodStart) {
        return DeliveryDocPaymentService.calculatePriorBalance(entityId, currentPeriodStart);
    }

    /** @description Queries a document record by its public access token. */
    @TestVisible
    private static DeliveryDocument__c queryDocumentByToken(String publicToken) {
        return DeliveryDocApprovalService.queryDocumentByToken(publicToken);
    }

    /** @description Parses payment terms (e.g., 'Net 30') into a due date. */
    @TestVisible
    private static Date parseDueDate(String terms, Date fromDate) {
        return DeliveryDocEmailService.parseDueDate(terms, fromDate);
    }

    /** @description Builds the HTML email body for a document email. */
    @TestVisible
    private static String buildDocumentEmailBody(DeliveryDocument__c doc, String templateDisplay) {
        return DeliveryDocEmailService.buildDocumentEmailBody(doc, templateDisplay);
    }

    /** @description Builds default legal clauses for agreement-type documents. */
    @TestVisible
    private static List<Map<String, String>> buildDefaultAgreementClauses(String templateType, Map<String, Object> snapshot) {
        return DeliveryDocGenerationService.buildDefaultAgreementClauses(templateType, snapshot);
    }

    /** @description Builds a frozen JSON snapshot of entity, work item, and work log data. */
    @TestVisible
    private static Map<String, Object> buildSnapshot(Id entityId, String templateType, Date periodStart, Date periodEnd) {
        return DeliveryDocGenerationService.buildSnapshot(entityId, templateType, periodStart, periodEnd);
    }
}

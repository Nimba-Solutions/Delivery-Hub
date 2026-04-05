/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Thin facade controller for the Document Engine. Delegates all logic to:
 *              DocumentQueryService, DocumentGenerationService, DocumentPaymentService,
 *              DocumentEmailService, and DocumentApprovalService.
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.AvoidGlobalModifier')
global with sharing class DeliveryDocumentController {

    // ═══════════════════════════════════════════════════════════
    //  GENERATION
    // ═══════════════════════════════════════════════════════════

    @AuraEnabled
    global static Id generateDocument(Id entityId, String templateType, Date periodStart, Date periodEnd, String metadata) {
        return DocumentGenerationService.generateDocument(entityId, templateType, periodStart, periodEnd, metadata);
    }

    // ═══════════════════════════════════════════════════════════
    //  QUERIES
    // ═══════════════════════════════════════════════════════════

    @AuraEnabled(cacheable=true)
    global static Map<String, Object> getPendingInvoices() {
        return DocumentQueryService.getPendingInvoices();
    }

    @AuraEnabled(cacheable=true)
    global static Map<String, Object> getDocumentByToken(String publicToken) {
        return DocumentQueryService.getDocumentByToken(publicToken);
    }

    @AuraEnabled(cacheable=true)
    global static Map<String, Object> getDocumentById(Id documentId) {
        return DocumentQueryService.getDocumentById(documentId);
    }

    @AuraEnabled(cacheable=true)
    global static List<Map<String, Object>> getDocumentsForEntity(Id entityId) {
        return DocumentQueryService.getDocumentsForEntity(entityId);
    }

    @AuraEnabled(cacheable=true)
    global static List<Map<String, String>> getDocumentTemplates() {
        return DocumentQueryService.getDocumentTemplates();
    }

    @AuraEnabled
    global static List<Map<String, Object>> getDocumentTransactions(Id documentId) {
        return DocumentQueryService.getTransactionsForDocument(documentId);
    }

    @AuraEnabled(cacheable=true)
    global static String getDefaultBillingEntityId() {
        return DocumentQueryService.getDefaultBillingEntityId();
    }

    // ═══════════════════════════════════════════════════════════
    //  STATUS UPDATES
    // ═══════════════════════════════════════════════════════════

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
                doc.DueDateDate__c = DocumentEmailService.parseDueDate(doc.TermsTxt__c, Date.today());
            }
        }

        Database.update(doc, AccessLevel.SYSTEM_MODE);

        String entityName = doc.NetworkEntityId__r != null ? doc.NetworkEntityId__r.Name : '';
        EventBus.publish(new DeliveryDocEvent__e(
            DocumentIdTxt__c = doc.Id,
            TemplatePk__c    = doc.TemplatePk__c,
            StatusPk__c      = newStatus,
            EntityNameTxt__c = entityName
        ));
    }

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

    @AuraEnabled
    global static void recordPayment(Id documentId, Decimal amount, Date paymentDate, String note) {
        DocumentPaymentService.recordPayment(documentId, amount, paymentDate, note);
    }

    // ═══════════════════════════════════════════════════════════
    //  EMAIL
    // ═══════════════════════════════════════════════════════════

    @AuraEnabled
    global static Map<String, Object> sendDocumentEmail(Id documentId, String recipientEmail) {
        return DocumentEmailService.sendDocumentEmail(documentId, recipientEmail);
    }

    @AuraEnabled
    global static Map<String, Object> previewDocumentEmail(Id documentId, String recipientEmail) {
        return DocumentEmailService.previewDocumentEmail(documentId, recipientEmail);
    }

    @AuraEnabled
    global static Map<String, Object> scheduleDocumentSend(Id documentId, String recipientEmail, Datetime sendAt) {
        return DocumentEmailService.scheduleDocumentSend(documentId, recipientEmail, sendAt);
    }

    @AuraEnabled
    global static Map<String, Object> cancelScheduledSend(Id documentId) {
        return DocumentEmailService.cancelScheduledSend(documentId);
    }

    public static void processScheduledDocumentSends() {
        DocumentEmailService.processScheduledDocumentSends();
    }

    // ═══════════════════════════════════════════════════════════
    //  APPROVAL (token-authenticated, called from API service)
    // ═══════════════════════════════════════════════════════════

    public static Map<String, Object> approveDocumentByToken(String publicToken) {
        return DocumentApprovalService.approveDocumentByToken(publicToken);
    }

    public static Map<String, Object> disputeDocumentByToken(String publicToken, String reason) {
        return DocumentApprovalService.disputeDocumentByToken(publicToken, reason);
    }

    // ═══════════════════════════════════════════════════════════
    //  DELEGATES FOR @TestVisible METHODS (preserve test API)
    // ═══════════════════════════════════════════════════════════

    @TestVisible
    private static Decimal calculatePriorBalance(Id entityId, Date currentPeriodStart) {
        return DocumentPaymentService.calculatePriorBalance(entityId, currentPeriodStart);
    }

    @TestVisible
    private static DeliveryDocument__c queryDocumentByToken(String publicToken) {
        return DocumentApprovalService.queryDocumentByToken(publicToken);
    }

    @TestVisible
    private static Date parseDueDate(String terms, Date fromDate) {
        return DocumentEmailService.parseDueDate(terms, fromDate);
    }

    @TestVisible
    private static String buildDocumentEmailBody(DeliveryDocument__c doc, String templateDisplay) {
        return DocumentEmailService.buildDocumentEmailBody(doc, templateDisplay);
    }

    @TestVisible
    private static List<Map<String, String>> buildDefaultAgreementClauses(String templateType, Map<String, Object> snapshot) {
        return DocumentGenerationService.buildDefaultAgreementClauses(templateType, snapshot);
    }

    @TestVisible
    private static Map<String, Object> buildSnapshot(Id entityId, String templateType, Date periodStart, Date periodEnd) {
        return DocumentGenerationService.buildSnapshot(entityId, templateType, periodStart, periodEnd);
    }
}

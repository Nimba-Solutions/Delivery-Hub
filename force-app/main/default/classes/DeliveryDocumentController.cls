/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Controller for the Document Engine. Generates, retrieves, and manages
 *              DeliveryDocument__c records. Packages work item, work log, and entity
 *              data into JSON snapshots that the portal renders as web pages and PDFs.
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.ApexCRUDViolation, PMD.CyclomaticComplexity, PMD.StdCyclomaticComplexity, PMD.ExcessiveClassLength, PMD.ExcessiveParameterList')
public with sharing class DeliveryDocumentController {

    /**
     * @description Generates a new document by querying all relevant data for the given
     *              entity and period, packaging it into a frozen JSON snapshot, and
     *              creating a DeliveryDocument__c record with a public access token.
     * @param entityId The NetworkEntity__c Id the document is for.
     * @param templateType The template picklist value (e.g., 'Invoice', 'Status_Report').
     * @param periodStart First day of the period.
     * @param periodEnd Last day of the period.
     * @param metadata Optional JSON string of template-specific parameters.
     * @return The Id of the created DeliveryDocument__c record.
     */
    @AuraEnabled
    public static Id generateDocument(Id entityId, String templateType, Date periodStart, Date periodEnd, String metadata) {
        Map<String, Object> snapshot = buildSnapshot(entityId, templateType, periodStart, periodEnd);

        String publicToken = generateToken();
        Decimal currentCharges = calculateTotalCost(snapshot);

        // Auto-calculate prior balance for invoices: sum of all unpaid invoices for this entity
        Decimal priorBalance = 0;
        if (templateType == 'Invoice' && entityId != null) {
            priorBalance = calculatePriorBalance(entityId);
        }

        // Merge A/R data into metadata
        Map<String, Object> metaMap = new Map<String, Object>();
        if (String.isNotBlank(metadata)) {
            metaMap = (Map<String, Object>) JSON.deserializeUntyped(metadata);
        }
        metaMap.put('priorBalance', priorBalance);
        metaMap.put('amountDue', currentCharges + priorBalance);

        // Build unpaid invoices summary for the snapshot
        if (templateType == 'Invoice' && entityId != null) {
            metaMap.put('unpaidInvoices', buildUnpaidInvoicesSummary(entityId));
        }

        DeliveryDocument__c doc = new DeliveryDocument__c(
            NetworkEntityId__c  = entityId,
            TemplatePk__c       = templateType,
            PeriodStartDate__c  = periodStart,
            PeriodEndDate__c    = periodEnd,
            StatusPk__c         = 'Draft',
            PublicTokenTxt__c   = publicToken,
            SnapshotTxt__c      = JSON.serialize(snapshot),
            TotalHoursNumber__c = calculateTotalHours(snapshot),
            TotalCurrency__c    = currentCharges,
            TermsTxt__c         = 'Net 30',
            MetadataTxt__c      = JSON.serialize(metaMap)
        );

        Database.insert(doc, AccessLevel.SYSTEM_MODE);
        return doc.Id;
    }

    /**
     * @description Calculates the outstanding balance from all prior unpaid invoices
     *              for the given entity. Queries unpaid invoices and aggregates
     *              DeliveryTransaction__c amounts per document to compute paid totals.
     *              Balance = sum of (docTotal - paidTotal) for each unpaid invoice.
     * @param entityId The NetworkEntity__c Id.
     * @return The total unpaid prior balance.
     */
    @TestVisible
    private static Decimal calculatePriorBalance(Id entityId) {
        List<DeliveryDocument__c> unpaidDocs = [
            SELECT Id, TotalCurrency__c
            FROM DeliveryDocument__c
            WHERE NetworkEntityId__c = :entityId
            AND TemplatePk__c = 'Invoice'
            AND StatusPk__c != 'Paid'
            WITH SYSTEM_MODE
        ];
        if (unpaidDocs.isEmpty()) {
            return 0;
        }

        Set<Id> docIds = new Map<Id, DeliveryDocument__c>(unpaidDocs).keySet();
        Map<Id, Decimal> paidByDoc = aggregatePaidByDocument(docIds);

        Decimal balance = 0;
        for (DeliveryDocument__c doc : unpaidDocs) {
            Decimal docTotal = doc.TotalCurrency__c != null ? doc.TotalCurrency__c : 0;
            Decimal docPaid = paidByDoc.containsKey(doc.Id) ? paidByDoc.get(doc.Id) : 0;
            balance += (docTotal - docPaid);
        }
        return balance;
    }

    /**
     * @description Records a payment against a document by creating a DeliveryTransaction__c
     *              record. Auto-transitions the document status to 'Paid' when total
     *              payments meet or exceed the document total.
     * @param documentId The DeliveryDocument__c Id.
     * @param amount The payment amount received.
     * @param paymentDate The date the payment was received.
     * @param note Optional reference number, check number, or note.
     */
    @AuraEnabled
    public static void recordPayment(Id documentId, Decimal amount, Date paymentDate, String note) {
        if (documentId == null || amount == null || amount <= 0) {
            throw new AuraHandledException('A valid document ID and positive payment amount are required.');
        }

        DeliveryTransaction__c txn = new DeliveryTransaction__c(
            DocumentId__c = documentId,
            TypePk__c = 'Payment',
            AmountCurrency__c = amount,
            TransactionDateDate__c = paymentDate,
            NoteTxt__c = String.isNotBlank(note) ? note : null
        );
        Database.insert(txn, AccessLevel.SYSTEM_MODE);

        // Check if total payments now cover the document total → auto-mark Paid
        DeliveryDocument__c doc = [
            SELECT Id, TotalCurrency__c, StatusPk__c
            FROM DeliveryDocument__c
            WHERE Id = :documentId
            WITH SYSTEM_MODE
            LIMIT 1
        ];

        Decimal docTotal = doc.TotalCurrency__c != null ? doc.TotalCurrency__c : 0;
        Decimal totalPaid = getTotalPaid(documentId);
        if (totalPaid >= docTotal) {
            doc.StatusPk__c = 'Paid';
            Database.update(doc, AccessLevel.SYSTEM_MODE);
        }
    }

    /**
     * @description Builds a summary list of all unpaid invoices for the entity.
     *              Aggregates DeliveryTransaction__c amounts per document for paid totals.
     *              Used in the invoice metadata to show A/R breakdown.
     * @param entityId The NetworkEntity__c Id to query unpaid invoices for.
     * @return List of maps containing name, period, total, paid, outstanding, and status keys.
     */
    private static List<Map<String, Object>> buildUnpaidInvoicesSummary(Id entityId) {
        List<DeliveryDocument__c> unpaidDocs = [
            SELECT Id, Name, PeriodStartDate__c, PeriodEndDate__c,
                   TotalCurrency__c, StatusPk__c, SentDateTime__c
            FROM DeliveryDocument__c
            WHERE NetworkEntityId__c = :entityId
            AND TemplatePk__c = 'Invoice'
            AND StatusPk__c != 'Paid'
            WITH SYSTEM_MODE
            ORDER BY PeriodStartDate__c ASC
        ];
        if (unpaidDocs.isEmpty()) {
            return new List<Map<String, Object>>();
        }

        Set<Id> docIds = new Map<Id, DeliveryDocument__c>(unpaidDocs).keySet();
        Map<Id, Decimal> paidByDoc = aggregatePaidByDocument(docIds);

        List<Map<String, Object>> summary = new List<Map<String, Object>>();
        for (DeliveryDocument__c doc : unpaidDocs) {
            Decimal total = doc.TotalCurrency__c != null ? doc.TotalCurrency__c : 0;
            Decimal paid = paidByDoc.containsKey(doc.Id) ? paidByDoc.get(doc.Id) : 0;
            Decimal outstanding = total - paid;
            if (outstanding <= 0) {
                continue;
            }
            Map<String, Object> item = new Map<String, Object>();
            item.put('name', doc.Name);
            item.put('periodStart', String.valueOf(doc.PeriodStartDate__c));
            item.put('periodEnd', String.valueOf(doc.PeriodEndDate__c));
            item.put('total', total);
            item.put('paid', paid);
            item.put('outstanding', outstanding);
            item.put('status', doc.StatusPk__c);
            summary.add(item);
        }
        return summary;
    }

    /**
     * @description Retrieves a document's full data by its public token.
     *              Used by the portal to render the document without Salesforce auth.
     * @param publicToken The unique public access token.
     * @return Map containing the document record fields and parsed snapshot.
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getDocumentByToken(String publicToken) {
        List<DeliveryDocument__c> docs = [
            SELECT Id, Name, TemplatePk__c, NetworkEntityId__c,
                   NetworkEntityId__r.Name, NetworkEntityId__r.DefaultHourlyRateCurrency__c,
                   PeriodStartDate__c, PeriodEndDate__c,
                   StatusPk__c, PublicTokenTxt__c,
                   AiNarrativeTxt__c, SnapshotTxt__c,
                   TotalHoursNumber__c, TotalCurrency__c,
                   SentDateTime__c, ViewedDateTime__c,
                   DueDateDate__c, TermsTxt__c, MetadataTxt__c
            FROM DeliveryDocument__c
            WHERE PublicTokenTxt__c = :publicToken
            WITH SYSTEM_MODE
            LIMIT 1
        ];

        if (docs.isEmpty()) {
            throw new AuraHandledException('Document not found.');
        }

        DeliveryDocument__c doc = docs[0];

        // Mark as viewed on first access
        if (doc.ViewedDateTime__c == null && doc.StatusPk__c == 'Sent') {
            doc.ViewedDateTime__c = Datetime.now();
            doc.StatusPk__c = 'Viewed';
            Database.update(doc, AccessLevel.SYSTEM_MODE);
        }

        Map<String, Object> result = new Map<String, Object>();
        result.put('id', doc.Id);
        result.put('name', doc.Name);
        result.put('template', doc.TemplatePk__c);
        result.put('entityName', doc.NetworkEntityId__r.Name);
        result.put('entityId', doc.NetworkEntityId__c);
        result.put('defaultRate', doc.NetworkEntityId__r.DefaultHourlyRateCurrency__c);
        result.put('periodStart', doc.PeriodStartDate__c);
        result.put('periodEnd', doc.PeriodEndDate__c);
        result.put('status', doc.StatusPk__c);
        result.put('aiNarrative', doc.AiNarrativeTxt__c);
        result.put('totalHours', doc.TotalHoursNumber__c);
        result.put('totalCost', doc.TotalCurrency__c);
        result.put('sentDate', doc.SentDateTime__c);
        result.put('viewedDate', doc.ViewedDateTime__c);
        result.put('dueDate', doc.DueDateDate__c);
        result.put('terms', doc.TermsTxt__c);
        result.put('metadata', doc.MetadataTxt__c);
        result.put('transactions', getTransactionsForDocument(doc.Id));
        result.put('totalPaid', getTotalPaid(doc.Id));
        result.put('snapshot', doc.SnapshotTxt__c);
        return result;
    }

    /**
     * @description Retrieves a document's full data by its record Id.
     *              Used by the embedded LWC viewer (admin context, authenticated).
     * @param documentId The DeliveryDocument__c Id.
     * @return Map containing the document record fields and parsed snapshot.
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getDocumentById(Id documentId) {
        List<DeliveryDocument__c> docs = [
            SELECT Id, Name, TemplatePk__c, NetworkEntityId__c,
                   NetworkEntityId__r.Name, NetworkEntityId__r.DefaultHourlyRateCurrency__c,
                   PeriodStartDate__c, PeriodEndDate__c,
                   StatusPk__c, PublicTokenTxt__c,
                   AiNarrativeTxt__c, SnapshotTxt__c,
                   TotalHoursNumber__c, TotalCurrency__c,
                   SentDateTime__c, ViewedDateTime__c,
                   DueDateDate__c, TermsTxt__c, MetadataTxt__c
            FROM DeliveryDocument__c
            WHERE Id = :documentId
            WITH SYSTEM_MODE
            LIMIT 1
        ];

        if (docs.isEmpty()) {
            throw new AuraHandledException('Document not found.');
        }

        DeliveryDocument__c doc = docs[0];
        Map<String, Object> result = new Map<String, Object>();
        result.put('id', doc.Id);
        result.put('name', doc.Name);
        result.put('template', doc.TemplatePk__c);
        result.put('entityName', doc.NetworkEntityId__r.Name);
        result.put('entityId', doc.NetworkEntityId__c);
        result.put('defaultRate', doc.NetworkEntityId__r.DefaultHourlyRateCurrency__c);
        result.put('periodStart', doc.PeriodStartDate__c);
        result.put('periodEnd', doc.PeriodEndDate__c);
        result.put('status', doc.StatusPk__c);
        result.put('publicToken', doc.PublicTokenTxt__c);
        result.put('aiNarrative', doc.AiNarrativeTxt__c);
        result.put('totalHours', doc.TotalHoursNumber__c);
        result.put('totalCost', doc.TotalCurrency__c);
        result.put('sentDate', doc.SentDateTime__c);
        result.put('viewedDate', doc.ViewedDateTime__c);
        result.put('dueDate', doc.DueDateDate__c);
        result.put('terms', doc.TermsTxt__c);
        result.put('metadata', doc.MetadataTxt__c);
        result.put('transactions', getTransactionsForDocument(doc.Id));
        result.put('totalPaid', getTotalPaid(doc.Id));
        result.put('snapshot', doc.SnapshotTxt__c);
        return result;
    }

    /**
     * @description Lists documents ordered by creation date. When entityId is provided,
     *              returns documents for that entity. When null, returns all documents
     *              (useful for Admin Home where no entity context is available).
     * @param entityId The NetworkEntity__c Id, or null for all documents.
     * @return List of document summary maps.
     */
    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getDocumentsForEntity(Id entityId) {
        List<Map<String, Object>> results = new List<Map<String, Object>>();

        String query = 'SELECT Id, Name, TemplatePk__c, PeriodStartDate__c, PeriodEndDate__c, '
            + 'StatusPk__c, TotalHoursNumber__c, TotalCurrency__c, CreatedDate, '
            + 'NetworkEntityId__r.Name '
            + 'FROM DeliveryDocument__c ';
        if (entityId != null) {
            query += 'WHERE NetworkEntityId__c = :entityId ';
        }
        query += 'ORDER BY CreatedDate DESC LIMIT 100';

        for (DeliveryDocument__c doc : Database.query(query)) { // NOPMD
            Map<String, Object> item = new Map<String, Object>();
            item.put('id', doc.Id);
            item.put('name', doc.Name);
            item.put('template', doc.TemplatePk__c);
            item.put('entityName', doc.NetworkEntityId__r.Name);
            item.put('periodStart', doc.PeriodStartDate__c);
            item.put('periodEnd', doc.PeriodEndDate__c);
            item.put('status', doc.StatusPk__c);
            item.put('totalHours', doc.TotalHoursNumber__c);
            item.put('totalCost', doc.TotalCurrency__c);
            item.put('createdDate', doc.CreatedDate);
            results.add(item);
        }

        return results;
    }

    /**
     * @description Updates a document's status and optionally sets sent/due dates.
     * @param documentId The DeliveryDocument__c Id.
     * @param newStatus The new status value.
     */
    @AuraEnabled
    public static void updateDocumentStatus(Id documentId, String newStatus) {
        DeliveryDocument__c doc = [
            SELECT Id, StatusPk__c, SentDateTime__c, DueDateDate__c, TermsTxt__c
            FROM DeliveryDocument__c
            WHERE Id = :documentId
            WITH SYSTEM_MODE
            LIMIT 1
        ];

        doc.StatusPk__c = newStatus;

        if (newStatus == 'Sent' && doc.SentDateTime__c == null) {
            doc.SentDateTime__c = Datetime.now();
            // Auto-calculate due date from terms
            if (doc.DueDateDate__c == null && String.isNotBlank(doc.TermsTxt__c)) {
                doc.DueDateDate__c = parseDueDate(doc.TermsTxt__c, Date.today());
            }
        }

        Database.update(doc, AccessLevel.SYSTEM_MODE);
    }

    /**
     * @description Stores an AI-generated narrative on an existing document.
     * @param documentId The DeliveryDocument__c Id.
     * @param narrative The AI-generated text to store.
     */
    @AuraEnabled
    public static void saveAiNarrative(Id documentId, String narrative) {
        DeliveryDocument__c doc = new DeliveryDocument__c(
            Id = documentId,
            AiNarrativeTxt__c = narrative
        );
        Database.update(doc, AccessLevel.SYSTEM_MODE);
    }

    /**
     * @description Returns available document templates from DocumentTemplate__mdt.
     *              Subscribers can create their own CMT records to add new template types
     *              without modifying package code. The DeveloperName maps to TemplatePk__c.
     * @return List of maps with 'value' (DeveloperName), 'label', and 'description' keys.
     */
    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getDocumentTemplates() {
        List<Map<String, String>> templates = new List<Map<String, String>>();
        for (DocumentTemplate__mdt tmpl : [
            SELECT DeveloperName, Label, DescriptionTxt__c
            FROM DocumentTemplate__mdt
            ORDER BY Label
        ]) {
            Map<String, String> t = new Map<String, String>();
            t.put('value', tmpl.DeveloperName);
            t.put('label', tmpl.Label);
            t.put('description', tmpl.DescriptionTxt__c);
            templates.add(t);
        }
        return templates;
    }

    /**
     * @description Sends a document as a PDF email attachment and marks it as Sent.
     *              Generates a PDF via the DeliveryDocumentPdf Visualforce page, attaches it
     *              to the email, and CCs the address configured in DocumentCcEmailTxt__c.
     * @param documentId The DeliveryDocument__c Id.
     * @param recipientEmail The primary recipient email. Falls back to entity contact email.
     * @return Map with 'success' and 'recipientEmail' keys.
     */
    @AuraEnabled
    public static Map<String, Object> sendDocumentEmail(Id documentId, String recipientEmail) {
        DeliveryDocument__c doc = [
            SELECT Id, Name, TemplatePk__c, NetworkEntityId__r.Name,
                   NetworkEntityId__r.ContactEmailTxt__c,
                   PeriodStartDate__c, PeriodEndDate__c,
                   StatusPk__c, TotalHoursNumber__c, TotalCurrency__c,
                   TermsTxt__c, DueDateDate__c, SentDateTime__c,
                   PublicTokenTxt__c
            FROM DeliveryDocument__c
            WHERE Id = :documentId
            WITH SYSTEM_MODE
            LIMIT 1
        ];

        // Resolve recipient: explicit param > entity contact email
        String toEmail = String.isNotBlank(recipientEmail)
            ? recipientEmail.trim()
            : doc.NetworkEntityId__r.ContactEmailTxt__c;

        if (String.isBlank(toEmail)) {
            throw new AuraHandledException(
                'No recipient email provided and the entity has no contact email on file.'
            );
        }

        // Generate PDF from Visualforce page
        PageReference pdfPage = Page.DeliveryDocumentPdf;
        pdfPage.getParameters().put('id', String.valueOf(documentId));
        Blob pdfBlob;
        if (!Test.isRunningTest()) {
            pdfBlob = pdfPage.getContentAsPDF();
        } else {
            pdfBlob = Blob.valueOf('test-pdf-content');
        }

        // Build attachment
        String templateDisplay = doc.TemplatePk__c.replace('_', ' ');
        Messaging.EmailFileAttachment att = new Messaging.EmailFileAttachment();
        att.setFileName(doc.Name + ' - ' + templateDisplay + '.pdf');
        att.setContentType('application/pdf');
        att.setBody(pdfBlob);

        // Build email
        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        email.setToAddresses(new List<String>{ toEmail });

        // CC from org settings
        DeliveryHubSettings__c settings = DeliveryHubSettings__c.getOrgDefaults();
        if (settings != null && String.isNotBlank(settings.DocumentCcEmailTxt__c)) {
            email.setCcAddresses(new List<String>{ settings.DocumentCcEmailTxt__c });
        }

        // Resolve vendor name for email subject/body
        String vendorName = resolveVendorName();
        email.setSubject(vendorName + ' \u2014 ' + templateDisplay + ' ' + doc.Name);
        email.setHtmlBody(buildDocumentEmailBody(doc, templateDisplay, vendorName));
        email.setFileAttachments(new List<Messaging.EmailFileAttachment>{ att });
        email.setSaveAsActivity(false);

        // Send
        Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ email });

        // Update document status to Sent
        doc.StatusPk__c = 'Sent';
        if (doc.SentDateTime__c == null) {
            doc.SentDateTime__c = Datetime.now();
        }
        if (doc.DueDateDate__c == null && String.isNotBlank(doc.TermsTxt__c)) {
            doc.DueDateDate__c = parseDueDate(doc.TermsTxt__c, Date.today());
        }
        Database.update(doc, AccessLevel.SYSTEM_MODE);

        Map<String, Object> result = new Map<String, Object>();
        result.put('success', true);
        result.put('recipientEmail', toEmail);
        return result;
    }

    /**
     * @description Retrieves the transaction history for a document. Allows the LWC
     *              to refresh the transaction list independently after recording a payment.
     * @param documentId The DeliveryDocument__c Id.
     * @return List of maps containing transaction fields (id, name, type, amount, date, note, method).
     */
    @AuraEnabled
    public static List<Map<String, Object>> getDocumentTransactions(Id documentId) {
        return getTransactionsForDocument(documentId);
    }

    // ═══════════════════════════════════════════════════════════
    //  PRIVATE: Transaction Helpers
    // ═══════════════════════════════════════════════════════════

    /**
     * @description Queries all DeliveryTransaction__c records for a given document
     *              and returns them as a list of serialized maps.
     * @param docId The DeliveryDocument__c Id.
     * @return List of maps with transaction fields.
     */
    @TestVisible
    private static List<Map<String, Object>> getTransactionsForDocument(Id docId) {
        List<Map<String, Object>> txns = new List<Map<String, Object>>();
        for (DeliveryTransaction__c t : [
            SELECT Id, Name, TypePk__c, AmountCurrency__c,
                   TransactionDateDate__c, NoteTxt__c, MethodPk__c, CreatedDate
            FROM DeliveryTransaction__c
            WHERE DocumentId__c = :docId
            WITH SYSTEM_MODE
            ORDER BY TransactionDateDate__c ASC, CreatedDate ASC
        ]) {
            Map<String, Object> m = new Map<String, Object>();
            m.put('id', t.Id);
            m.put('name', t.Name);
            m.put('type', t.TypePk__c);
            m.put('amount', t.AmountCurrency__c);
            m.put('date', t.TransactionDateDate__c);
            m.put('note', t.NoteTxt__c);
            m.put('method', t.MethodPk__c);
            txns.add(m);
        }
        return txns;
    }

    /**
     * @description Calculates the total paid amount for a document by aggregating
     *              all DeliveryTransaction__c AmountCurrency__c values.
     * @param docId The DeliveryDocument__c Id.
     * @return The sum of all transaction amounts, or 0 if none exist.
     */
    @TestVisible
    private static Decimal getTotalPaid(Id docId) {
        AggregateResult[] results = [
            SELECT SUM(AmountCurrency__c) totalPaid
            FROM DeliveryTransaction__c
            WHERE DocumentId__c = :docId
            WITH SYSTEM_MODE
        ];
        Object val = results[0].get('totalPaid');
        return val != null ? (Decimal) val : 0;
    }

    /**
     * @description Aggregates paid amounts across multiple documents. Returns a map
     *              of document Id to total paid amount from DeliveryTransaction__c records.
     * @param docIds The set of DeliveryDocument__c Ids to aggregate.
     * @return Map of document Id to total paid Decimal.
     */
    private static Map<Id, Decimal> aggregatePaidByDocument(Set<Id> docIds) {
        Map<Id, Decimal> paidByDoc = new Map<Id, Decimal>();
        for (AggregateResult ar : [
            SELECT DocumentId__c docId, SUM(AmountCurrency__c) totalPaid
            FROM DeliveryTransaction__c
            WHERE DocumentId__c IN :docIds
            WITH SYSTEM_MODE
            GROUP BY DocumentId__c
        ]) {
            Id dId = (Id) ar.get('docId');
            Decimal paid = ar.get('totalPaid') != null ? (Decimal) ar.get('totalPaid') : 0;
            paidByDoc.put(dId, paid);
        }
        return paidByDoc;
    }

    // ═══════════════════════════════════════════════════════════
    //  PRIVATE: Email Body Builder
    // ═══════════════════════════════════════════════════════════

    private static String resolveVendorName() {
        List<NetworkEntity__c> vendors = [
            SELECT Name FROM NetworkEntity__c
            WHERE EntityTypePk__c IN ('Vendor', 'Both')
            WITH SYSTEM_MODE
            ORDER BY CreatedDate ASC LIMIT 1
        ];
        return vendors.isEmpty() ? 'Delivery Hub' : vendors[0].Name;
    }

    @TestVisible
    private static String buildDocumentEmailBody(DeliveryDocument__c doc, String templateDisplay) {
        return buildDocumentEmailBody(doc, templateDisplay, resolveVendorName());
    }

    @TestVisible
    private static String buildDocumentEmailBody(DeliveryDocument__c doc, String templateDisplay, String vendorName) {
        String entityName = doc.NetworkEntityId__r != null ? doc.NetworkEntityId__r.Name : '';
        Decimal totalHours = doc.TotalHoursNumber__c != null ? doc.TotalHoursNumber__c : 0;
        Decimal totalCost = doc.TotalCurrency__c != null ? doc.TotalCurrency__c : 0;

        String body = '<div style="font-family: \'Helvetica Neue\', Helvetica, Arial, sans-serif; max-width: 600px; margin: 0 auto;">'
            + '<div style="background: #0176d3; padding: 24px 30px; border-radius: 8px 8px 0 0;">'
            + '<h1 style="color: #fff; font-size: 20px; margin: 0;">' + String.valueOf(vendorName).escapeHtml4() + '</h1>'
            + '</div>'
            + '<div style="background: #fff; border: 1px solid #e5e5e5; border-top: none; padding: 30px; border-radius: 0 0 8px 8px;">';

        body += '<h2 style="color: #1a1a2e; font-size: 16px; margin: 0 0 6px;">'
            + templateDisplay + ' ' + String.valueOf(doc.Name).escapeHtml4() + '</h2>'
            + '<p style="color: #706e6b; font-size: 13px; margin: 0 0 20px;">Prepared for '
            + String.valueOf(entityName).escapeHtml4() + '</p>';

        // Summary
        if (doc.TemplatePk__c != 'Client_Agreement' && doc.TemplatePk__c != 'Contractor_Agreement') {
            body += '<div style="background: #f3f3f5; border-radius: 6px; padding: 16px 20px; margin-bottom: 20px;">'
                + '<table style="width: 100%;"><tr>'
                + '<td style="text-align: center;"><div style="font-size: 11px; color: #706e6b; text-transform: uppercase;">Total Hours</div>'
                + '<div style="font-size: 18px; font-weight: 700; color: #1a1a2e;">' + totalHours.setScale(1) + '</div></td>'
                + '<td style="text-align: center;"><div style="font-size: 11px; color: #706e6b; text-transform: uppercase;">Total Due</div>'
                + '<div style="font-size: 18px; font-weight: 700; color: #0176d3;">$' + totalCost.setScale(2).format() + '</div></td>'
                + '</tr></table></div>';
        }

        // Period
        if (doc.PeriodStartDate__c != null && doc.PeriodEndDate__c != null) {
            body += '<p style="font-size: 13px; color: #444;"><strong>Period:</strong> '
                + doc.PeriodStartDate__c.format() + ' \u2013 ' + doc.PeriodEndDate__c.format() + '</p>';
        }

        // Terms
        if (String.isNotBlank(doc.TermsTxt__c)) {
            body += '<p style="font-size: 13px; color: #444;"><strong>Terms:</strong> ' + doc.TermsTxt__c + '</p>';
        }

        // Due date
        if (doc.DueDateDate__c != null) {
            body += '<p style="font-size: 13px; color: #444;"><strong>Due Date:</strong> '
                + doc.DueDateDate__c.format() + '</p>';
        }

        body += '<p style="font-size: 13px; color: #444; margin-top: 20px;">Please find the attached '
            + templateDisplay.toLowerCase() + ' for your review. '
            + 'If you have any questions, please don\'t hesitate to reach out.</p>';

        // Footer
        body += '<hr style="border: none; border-top: 1px solid #eee; margin: 24px 0;" />'
            + '<p style="font-size: 11px; color: #aaa;">This document was generated by Delivery Hub.</p>'
            + '</div></div>';

        return body;
    }

    // ═══════════════════════════════════════════════════════════
    //  PRIVATE: Snapshot Builder
    // ═══════════════════════════════════════════════════════════

    @TestVisible
    private static Map<String, Object> buildSnapshot(Id entityId, String templateType, Date periodStart, Date periodEnd) {
        Map<String, Object> snapshot = new Map<String, Object>();

        // Entity info (vendor/billing details)
        NetworkEntity__c entity = [
            SELECT Id, Name, EntityTypePk__c, DefaultHourlyRateCurrency__c,
                   OrgIdTxt__c, AddressTxt__c, ContactEmailTxt__c, ContactPhoneTxt__c
            FROM NetworkEntity__c
            WHERE Id = :entityId
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        snapshot.put('entity', serializeEntity(entity));

        // Work items linked to this entity
        List<WorkItem__c> items = [
            SELECT Id, Name, BriefDescriptionTxt__c, StageNamePk__c, PriorityPk__c,
                   EstimatedHoursNumber__c, TotalLoggedHoursNumber__c,
                   BillableRateCurrency__c, BudgetVarianceNumber__c,
                   ClientNetworkEntityId__c, WorkflowTypeTxt__c
            FROM WorkItem__c
            WHERE ClientNetworkEntityId__c = :entityId
            WITH SYSTEM_MODE
            ORDER BY Name
        ];
        snapshot.put('workItems', serializeWorkItems(items));

        // Work logs within the period for these items
        Set<Id> itemIds = new Map<Id, WorkItem__c>(items).keySet();
        List<WorkLog__c> logs = [
            SELECT Id, Name, WorkItemId__c, WorkItemId__r.Name,
                   HoursLoggedNumber__c, WorkDateDate__c, WorkDescriptionTxt__c
            FROM WorkLog__c
            WHERE WorkItemId__c IN :itemIds
            AND WorkDateDate__c >= :periodStart
            AND WorkDateDate__c <= :periodEnd
            WITH SYSTEM_MODE
            ORDER BY WorkDateDate__c ASC
        ];
        snapshot.put('workLogs', serializeWorkLogs(logs));

        // Work requests (for rates and status)
        List<WorkRequest__c> requests = [
            SELECT Id, WorkItemId__c, WorkItemId__r.Name, StatusPk__c,
                   HourlyRateCurrency__c, QuotedHoursNumber__c,
                   PreApprovedHoursNumber__c, TotalLoggedHoursNumber__c,
                   BudgetUtilizationPercent__c, DeliveryEntityId__c,
                   DeliveryEntityId__r.Name
            FROM WorkRequest__c
            WHERE WorkItemId__c IN :itemIds
            AND StatusPk__c != 'Inactive'
            WITH SYSTEM_MODE
            ORDER BY WorkItemId__r.Name
        ];
        snapshot.put('workRequests', serializeWorkRequests(requests));

        // Period metadata
        snapshot.put('periodStart', String.valueOf(periodStart));
        snapshot.put('periodEnd', String.valueOf(periodEnd));
        snapshot.put('generatedAt', String.valueOf(Datetime.now()));
        snapshot.put('templateType', templateType);

        return snapshot;
    }

    // ═══════════════════════════════════════════════════════════
    //  PRIVATE: Serializers
    // ═══════════════════════════════════════════════════════════

    private static Map<String, Object> serializeEntity(NetworkEntity__c entity) {
        Map<String, Object> m = new Map<String, Object>();
        m.put('id', entity.Id);
        m.put('name', entity.Name);
        m.put('type', entity.EntityTypePk__c);
        m.put('defaultRate', entity.DefaultHourlyRateCurrency__c);
        m.put('orgId', entity.OrgIdTxt__c);
        m.put('address', entity.AddressTxt__c);
        m.put('email', entity.ContactEmailTxt__c);
        m.put('phone', entity.ContactPhoneTxt__c);
        return m;
    }

    private static List<Map<String, Object>> serializeWorkItems(List<WorkItem__c> items) {
        List<Map<String, Object>> result = new List<Map<String, Object>>();
        for (WorkItem__c wi : items) {
            Map<String, Object> m = new Map<String, Object>();
            m.put('id', wi.Id);
            m.put('name', wi.Name);
            m.put('description', wi.BriefDescriptionTxt__c);
            m.put('stage', wi.StageNamePk__c);
            m.put('priority', wi.PriorityPk__c);
            m.put('estimatedHours', wi.EstimatedHoursNumber__c);
            m.put('totalLoggedHours', wi.TotalLoggedHoursNumber__c);
            m.put('billableRate', wi.BillableRateCurrency__c);
            m.put('budgetVariance', wi.BudgetVarianceNumber__c);
            m.put('workflowType', wi.WorkflowTypeTxt__c);
            result.add(m);
        }
        return result;
    }

    private static List<Map<String, Object>> serializeWorkLogs(List<WorkLog__c> logs) {
        List<Map<String, Object>> result = new List<Map<String, Object>>();
        for (WorkLog__c wl : logs) {
            Map<String, Object> m = new Map<String, Object>();
            m.put('id', wl.Id);
            m.put('workItemId', wl.WorkItemId__c);
            m.put('workItemName', wl.WorkItemId__r.Name);
            m.put('hours', wl.HoursLoggedNumber__c);
            m.put('date', String.valueOf(wl.WorkDateDate__c));
            m.put('description', wl.WorkDescriptionTxt__c);
            result.add(m);
        }
        return result;
    }

    private static List<Map<String, Object>> serializeWorkRequests(List<WorkRequest__c> requests) {
        List<Map<String, Object>> result = new List<Map<String, Object>>();
        for (WorkRequest__c wr : requests) {
            Map<String, Object> m = new Map<String, Object>();
            m.put('id', wr.Id);
            m.put('workItemId', wr.WorkItemId__c);
            m.put('workItemName', wr.WorkItemId__r.Name);
            m.put('status', wr.StatusPk__c);
            m.put('hourlyRate', wr.HourlyRateCurrency__c);
            m.put('quotedHours', wr.QuotedHoursNumber__c);
            m.put('preApprovedHours', wr.PreApprovedHoursNumber__c);
            m.put('totalLoggedHours', wr.TotalLoggedHoursNumber__c);
            m.put('budgetUtilization', wr.BudgetUtilizationPercent__c);
            m.put('vendorEntityId', wr.DeliveryEntityId__c);
            m.put('vendorEntityName', wr.DeliveryEntityId__r.Name);
            result.add(m);
        }
        return result;
    }

    // ═══════════════════════════════════════════════════════════
    //  PRIVATE: Calculations
    // ═══════════════════════════════════════════════════════════

    private static Decimal calculateTotalHours(Map<String, Object> snapshot) {
        Decimal total = 0;
        List<Object> logs = (List<Object>) snapshot.get('workLogs');
        if (logs == null) {
            return total;
        }
        for (Object logObj : logs) {
            Map<String, Object> log = (Map<String, Object>) logObj;
            Object hours = log.get('hours');
            if (hours != null) {
                total += (Decimal) hours;
            }
        }
        return total;
    }

    private static Decimal calculateTotalCost(Map<String, Object> snapshot) {
        // Build a rate map: workItemId → rate (from request, then item, then entity default)
        Map<String, Decimal> rateMap = new Map<String, Decimal>();
        Map<String, Object> entity = (Map<String, Object>) snapshot.get('entity');
        Decimal defaultRate = entity != null && entity.get('defaultRate') != null
            ? (Decimal) entity.get('defaultRate') : 0;

        List<Object> items = (List<Object>) snapshot.get('workItems');
        if (items != null) {
            for (Object itemObj : items) {
                Map<String, Object> item = (Map<String, Object>) itemObj;
                String itemId = (String) item.get('id');
                Decimal itemRate = item.get('billableRate') != null
                    ? (Decimal) item.get('billableRate') : defaultRate;
                rateMap.put(itemId, itemRate);
            }
        }

        // Override with request-level rates where available
        List<Object> requests = (List<Object>) snapshot.get('workRequests');
        if (requests != null) {
            for (Object reqObj : requests) {
                Map<String, Object> req = (Map<String, Object>) reqObj;
                if (req.get('hourlyRate') != null) {
                    rateMap.put((String) req.get('workItemId'), (Decimal) req.get('hourlyRate'));
                }
            }
        }

        // Sum: hours × rate per log entry
        Decimal total = 0;
        List<Object> logs = (List<Object>) snapshot.get('workLogs');
        if (logs != null) {
            for (Object logObj : logs) {
                Map<String, Object> log = (Map<String, Object>) logObj;
                Decimal hours = log.get('hours') != null ? (Decimal) log.get('hours') : 0;
                String workItemId = (String) log.get('workItemId');
                Decimal rate = rateMap.containsKey(workItemId) ? rateMap.get(workItemId) : defaultRate;
                total += hours * rate;
            }
        }
        return total;
    }

    // ═══════════════════════════════════════════════════════════
    //  PRIVATE: Utilities
    // ═══════════════════════════════════════════════════════════

    private static String generateToken() {
        Blob randomBytes = Crypto.generateAesKey(256);
        return EncodingUtil.convertToHex(randomBytes);
    }

    @TestVisible
    private static Date parseDueDate(String terms, Date fromDate) {
        if (String.isBlank(terms)) {
            return null;
        }
        String lower = terms.toLowerCase().trim();
        if (lower.startsWith('net ')) {
            try {
                Integer days = Integer.valueOf(lower.substringAfter('net ').trim());
                return fromDate.addDays(days);
            } catch (Exception e) {
                return null;
            }
        }
        if (lower == 'due on receipt') {
            return fromDate;
        }
        return null;
    }
}

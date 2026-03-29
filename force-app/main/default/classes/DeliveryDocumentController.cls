/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Controller for the Document Engine. Generates, retrieves, and manages
 *              DeliveryDocument__c records. Packages work item, work log, and entity
 *              data into JSON snapshots that the portal renders as web pages and PDFs.
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.ApexCRUDViolation, PMD.CyclomaticComplexity, PMD.StdCyclomaticComplexity, PMD.ExcessiveClassLength, PMD.ExcessiveParameterList, PMD.AvoidGlobalModifier')
global with sharing class DeliveryDocumentController {

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
    global static Id generateDocument(Id entityId, String templateType, Date periodStart, Date periodEnd, String metadata) {
        if (entityId == null) {
            throw new AuraHandledException('Please select a client before generating a document.');
        }
        Map<String, Object> snapshot = buildSnapshot(entityId, templateType, periodStart, periodEnd);

        String publicToken = generateToken();
        Decimal currentCharges = calculateTotalCost(snapshot);

        // Auto-calculate prior balance for invoices: sum of all unpaid invoices for this entity
        Decimal priorBalance = 0;
        if (templateType == 'Invoice' && entityId != null) {
            priorBalance = calculatePriorBalance(entityId, periodStart);
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

        // Inject default agreement clauses if none provided
        if ((templateType == 'Client_Agreement' || templateType == 'Contractor_Agreement')
            && !metaMap.containsKey('clauses')) {
            metaMap.put('clauses', buildDefaultAgreementClauses(templateType, snapshot));
        }

        // ── Versioning: supersede existing document for same entity+period+template ──
        Integer nextVersion = 1;
        Id previousVersionId = null;
        List<DeliveryDocument__c> existing = [
            SELECT Id, VersionNumber__c
            FROM DeliveryDocument__c
            WHERE NetworkEntityId__c = :entityId
            AND TemplatePk__c = :templateType
            AND PeriodStartDate__c = :periodStart
            AND PeriodEndDate__c = :periodEnd
            AND StatusPk__c != 'Superseded'
            WITH SYSTEM_MODE
            ORDER BY VersionNumber__c DESC
            LIMIT 1
        ];
        if (!existing.isEmpty()) {
            DeliveryDocument__c prev = existing[0];
            Decimal prevVer = prev.VersionNumber__c != null ? prev.VersionNumber__c : 1;
            nextVersion = prevVer.intValue() + 1;
            previousVersionId = prev.Id;
            prev.StatusPk__c = 'Superseded';
            Database.update(prev, AccessLevel.SYSTEM_MODE);
        }

        DeliveryDocument__c doc = new DeliveryDocument__c(
            NetworkEntityId__c     = entityId,
            TemplatePk__c          = templateType,
            PeriodStartDate__c     = periodStart,
            PeriodEndDate__c       = periodEnd,
            StatusPk__c            = 'Draft',
            PublicTokenTxt__c      = publicToken,
            SnapshotTxt__c         = JSON.serialize(snapshot),
            TotalHoursNumber__c    = calculateTotalHours(snapshot),
            TotalCurrency__c       = currentCharges,
            TermsTxt__c            = 'Net 30',
            MetadataTxt__c         = JSON.serialize(metaMap),
            VersionNumber__c       = nextVersion,
            PreviousVersionId__c   = previousVersionId
        );

        Database.insert(doc, AccessLevel.SYSTEM_MODE);

        // Publish platform event for external subscribers
        Map<String, Object> entityMap = (Map<String, Object>) snapshot.get('entity');
        String entityName = entityMap != null ? (String) entityMap.get('name') : '';
        EventBus.publish(new DeliveryDocEvent__e(
            DocumentIdTxt__c = doc.Id,
            TemplatePk__c    = templateType,
            StatusPk__c      = 'Draft',
            EntityNameTxt__c = entityName
        ));

        return doc.Id;
    }

    /**
     * @description Returns a summary of all Draft invoices and daily hour summaries
     *              that are pending review. Used by the document viewer banner.
     * @return Map with 'count' (Integer) and 'documents' (List of summary maps).
     */
    @AuraEnabled(cacheable=true)
    @SuppressWarnings('PMD.ApexCRUDViolation')
    global static Map<String, Object> getPendingInvoices() {
        List<DeliveryDocument__c> drafts = [
            SELECT Id, Name, TemplatePk__c, PeriodStartDate__c, PeriodEndDate__c,
                   TotalCurrency__c, NetworkEntityId__r.Name
            FROM DeliveryDocument__c
            WHERE StatusPk__c = 'Draft'
            AND TemplatePk__c IN ('Invoice', 'Daily_Hours_Summary')
            WITH SYSTEM_MODE
            ORDER BY CreatedDate DESC
            LIMIT 50
        ];

        List<Map<String, Object>> docSummaries = new List<Map<String, Object>>();
        for (DeliveryDocument__c doc : drafts) {
            Map<String, Object> summary = new Map<String, Object>();
            summary.put('id', doc.Id);
            summary.put('name', doc.Name);
            summary.put('templateType', doc.TemplatePk__c);
            summary.put('entityName', doc.NetworkEntityId__r.Name);
            summary.put('periodStart', String.valueOf(doc.PeriodStartDate__c));
            summary.put('periodEnd', String.valueOf(doc.PeriodEndDate__c));
            summary.put('total', doc.TotalCurrency__c);
            docSummaries.add(summary);
        }

        Map<String, Object> result = new Map<String, Object>();
        result.put('count', drafts.size());
        result.put('documents', docSummaries);
        return result;
    }

    /**
     * @description Calculates the outstanding balance from all prior unpaid invoices
     *              for the given entity. Queries unpaid invoices and aggregates
     *              DeliveryTransaction__c amounts per document to compute paid totals.
     *              Balance = sum of (docTotal - paidTotal) for each unpaid invoice.
     * @param entityId The NetworkEntity__c Id.
     * @param currentPeriodStart Only includes invoices with periods before this date.
     * @return The total unpaid prior balance.
     */
    @TestVisible
    private static Decimal calculatePriorBalance(Id entityId, Date currentPeriodStart) {
        List<DeliveryDocument__c> unpaidDocs = [
            SELECT Id, TotalCurrency__c
            FROM DeliveryDocument__c
            WHERE NetworkEntityId__c = :entityId
            AND TemplatePk__c = 'Invoice'
            AND StatusPk__c != 'Paid'
            AND StatusPk__c != 'Superseded'
            AND PeriodStartDate__c < :currentPeriodStart
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
    global static void recordPayment(Id documentId, Decimal amount, Date paymentDate, String note) {
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
            AND StatusPk__c != 'Superseded'
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
    global static Map<String, Object> getDocumentByToken(String publicToken) {
        List<DeliveryDocument__c> docs = [
            SELECT Id, Name, TemplatePk__c, NetworkEntityId__c,
                   NetworkEntityId__r.Name, NetworkEntityId__r.DefaultHourlyRateCurrency__c,
                   PeriodStartDate__c, PeriodEndDate__c,
                   StatusPk__c, PublicTokenTxt__c,
                   AiNarrativeTxt__c, SnapshotTxt__c,
                   TotalHoursNumber__c, TotalCurrency__c,
                   SentDateTime__c, ViewedDateTime__c,
                   DueDateDate__c, TermsTxt__c, MetadataTxt__c,
                   VersionNumber__c, PreviousVersionId__c
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
        result.put('version', doc.VersionNumber__c);
        result.put('previousVersionId', doc.PreviousVersionId__c);
        return result;
    }

    /**
     * @description Retrieves a document's full data by its record Id.
     *              Used by the embedded LWC viewer (admin context, authenticated).
     * @param documentId The DeliveryDocument__c Id.
     * @return Map containing the document record fields and parsed snapshot.
     */
    @AuraEnabled(cacheable=true)
    global static Map<String, Object> getDocumentById(Id documentId) {
        List<DeliveryDocument__c> docs = [
            SELECT Id, Name, TemplatePk__c, NetworkEntityId__c,
                   NetworkEntityId__r.Name, NetworkEntityId__r.DefaultHourlyRateCurrency__c,
                   PeriodStartDate__c, PeriodEndDate__c,
                   StatusPk__c, PublicTokenTxt__c,
                   AiNarrativeTxt__c, SnapshotTxt__c,
                   TotalHoursNumber__c, TotalCurrency__c,
                   SentDateTime__c, ViewedDateTime__c,
                   DueDateDate__c, TermsTxt__c, MetadataTxt__c,
                   VersionNumber__c, PreviousVersionId__c
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
        result.put('version', doc.VersionNumber__c);
        result.put('previousVersionId', doc.PreviousVersionId__c);
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
    global static List<Map<String, Object>> getDocumentsForEntity(Id entityId) {
        List<Map<String, Object>> results = new List<Map<String, Object>>();

        String query = 'SELECT Id, Name, TemplatePk__c, PeriodStartDate__c, PeriodEndDate__c, '
            + 'StatusPk__c, TotalHoursNumber__c, TotalCurrency__c, CreatedDate, '
            + 'NetworkEntityId__r.Name, VersionNumber__c, PreviousVersionId__c '
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
            item.put('version', doc.VersionNumber__c);
            item.put('previousVersionId', doc.PreviousVersionId__c);
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
            // Auto-calculate due date from terms
            if (doc.DueDateDate__c == null && String.isNotBlank(doc.TermsTxt__c)) {
                doc.DueDateDate__c = parseDueDate(doc.TermsTxt__c, Date.today());
            }
        }

        Database.update(doc, AccessLevel.SYSTEM_MODE);

        // Publish platform event for external subscribers
        String entityName = doc.NetworkEntityId__r != null ? doc.NetworkEntityId__r.Name : '';
        EventBus.publish(new DeliveryDocEvent__e(
            DocumentIdTxt__c = doc.Id,
            TemplatePk__c    = doc.TemplatePk__c,
            StatusPk__c      = newStatus,
            EntityNameTxt__c = entityName
        ));
    }

    /**
     * @description Stores an AI-generated narrative on an existing document.
     * @param documentId The DeliveryDocument__c Id.
     * @param narrative The AI-generated text to store.
     */
    @AuraEnabled
    global static void saveAiNarrative(Id documentId, String narrative) {
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
    global static List<Map<String, String>> getDocumentTemplates() {
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
    global static Map<String, Object> sendDocumentEmail(Id documentId, String recipientEmail) {
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
     * @description Returns a preview of the email that would be sent for this document,
     *              including the subject, HTML body, recipient, CC, attachment name, and
     *              PDF preview URL. Nothing is sent — this is read-only preview data.
     * @param documentId The DeliveryDocument__c Id.
     * @param recipientEmail Optional explicit recipient. Falls back to entity contact email.
     * @return Map with keys: toEmail, ccEmail, subject, bodyHtml, attachmentName, pdfPreviewUrl, entityName.
     */
    @AuraEnabled
    global static Map<String, Object> previewDocumentEmail(Id documentId, String recipientEmail) {
        DeliveryDocument__c doc = [
            SELECT Id, Name, TemplatePk__c, NetworkEntityId__r.Name,
                   NetworkEntityId__r.ContactEmailTxt__c,
                   PeriodStartDate__c, PeriodEndDate__c,
                   StatusPk__c, TotalHoursNumber__c, TotalCurrency__c,
                   TermsTxt__c, DueDateDate__c
            FROM DeliveryDocument__c
            WHERE Id = :documentId
            WITH SYSTEM_MODE
            LIMIT 1
        ];

        String toEmail = String.isNotBlank(recipientEmail)
            ? recipientEmail.trim()
            : doc.NetworkEntityId__r.ContactEmailTxt__c;

        DeliveryHubSettings__c settings = DeliveryHubSettings__c.getOrgDefaults();
        String ccEmail = (settings != null) ? settings.DocumentCcEmailTxt__c : null;

        String vendorName = resolveVendorName();
        String templateDisplay = doc.TemplatePk__c.replace('_', ' ');
        String subject = vendorName + ' \u2014 ' + templateDisplay + ' ' + doc.Name;
        String bodyHtml = buildDocumentEmailBody(doc, templateDisplay, vendorName);
        String attachmentName = doc.Name + ' - ' + templateDisplay + '.pdf';

        Map<String, Object> preview = new Map<String, Object>();
        preview.put('toEmail', toEmail != null ? toEmail : '');
        preview.put('ccEmail', ccEmail != null ? ccEmail : '');
        preview.put('subject', subject);
        preview.put('bodyHtml', bodyHtml);
        preview.put('attachmentName', attachmentName);
        preview.put('pdfPreviewUrl', '/apex/DeliveryDocumentPdf?id=' + documentId);
        preview.put('entityName', doc.NetworkEntityId__r != null ? doc.NetworkEntityId__r.Name : '');
        return preview;
    }

    /**
     * @description Schedules a document to be automatically emailed at a future date/time.
     *              Sets the scheduled send fields and marks the document as Ready if currently Draft.
     * @param documentId The DeliveryDocument__c Id.
     * @param recipientEmail The recipient email to lock in for the scheduled send.
     * @param sendAt The future DateTime when the email should be sent.
     * @return Map with 'success' and 'scheduledSend' keys.
     */
    @AuraEnabled
    global static Map<String, Object> scheduleDocumentSend(Id documentId, String recipientEmail, Datetime sendAt) {
        if (sendAt == null || sendAt <= Datetime.now()) {
            throw new AuraHandledException('Scheduled send time must be in the future.');
        }
        if (String.isBlank(recipientEmail)) {
            throw new AuraHandledException('Recipient email is required for scheduled send.');
        }

        DeliveryDocument__c doc = [
            SELECT Id, StatusPk__c
            FROM DeliveryDocument__c
            WHERE Id = :documentId
            WITH SYSTEM_MODE
            LIMIT 1
        ];

        doc.ScheduledSendDateTime__c = sendAt;
        doc.ScheduledRecipientEmailTxt__c = recipientEmail.trim();
        if (doc.StatusPk__c == 'Draft') {
            doc.StatusPk__c = 'Ready';
        }
        Database.update(doc, AccessLevel.SYSTEM_MODE);

        Map<String, Object> result = new Map<String, Object>();
        result.put('success', true);
        result.put('scheduledSend', String.valueOf(sendAt));
        return result;
    }

    /**
     * @description Cancels a previously scheduled document send by clearing the
     *              scheduled send fields.
     * @param documentId The DeliveryDocument__c Id.
     * @return Map with 'success' key.
     */
    @AuraEnabled
    global static Map<String, Object> cancelScheduledSend(Id documentId) {
        DeliveryDocument__c doc = [
            SELECT Id
            FROM DeliveryDocument__c
            WHERE Id = :documentId
            WITH SYSTEM_MODE
            LIMIT 1
        ];

        doc.ScheduledSendDateTime__c = null;
        doc.ScheduledRecipientEmailTxt__c = null;
        Database.update(doc, AccessLevel.SYSTEM_MODE);

        Map<String, Object> result = new Map<String, Object>();
        result.put('success', true);
        return result;
    }

    /**
     * @description Processes all documents whose scheduled send time has passed.
     *              Called by DeliveryHubScheduler every 15 minutes. Sends each document
     *              via sendDocumentEmail and clears the schedule fields afterward.
     */
    public static void processScheduledDocumentSends() {
        List<DeliveryDocument__c> dueDocs = [
            SELECT Id, ScheduledRecipientEmailTxt__c
            FROM DeliveryDocument__c
            WHERE ScheduledSendDateTime__c <= :Datetime.now()
            AND ScheduledSendDateTime__c != null
            AND SentDateTime__c = null
            WITH SYSTEM_MODE
            LIMIT 50
        ];

        for (DeliveryDocument__c doc : dueDocs) {
            try {
                sendDocumentEmail(doc.Id, doc.ScheduledRecipientEmailTxt__c);
            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR,
                    '[DeliveryDocumentController] Scheduled send failed for ' + doc.Id + ': ' + e.getMessage());
            }
            // Clear schedule fields regardless of success (sendDocumentEmail already sets Sent on success;
            // on failure we don't want infinite retries — the admin can reschedule manually)
            doc.ScheduledSendDateTime__c = null;
            doc.ScheduledRecipientEmailTxt__c = null;
        }
        if (!dueDocs.isEmpty()) {
            Database.update(dueDocs, AccessLevel.SYSTEM_MODE);
        }
    }

    /**
     * @description Retrieves the transaction history for a document. Allows the LWC
     *              to refresh the transaction list independently after recording a payment.
     * @param documentId The DeliveryDocument__c Id.
     * @return List of maps containing transaction fields (id, name, type, amount, date, note, method).
     */
    @AuraEnabled
    global static List<Map<String, Object>> getDocumentTransactions(Id documentId) {
        return getTransactionsForDocument(documentId);
    }

    /**
     * @description Returns the Default Billing Entity ID from org settings.
     * Used by the Document Viewer LWC to resolve the entity context when
     * no record page context or explicit networkEntityId is available.
     * @return The 18-character NetworkEntity__c ID, or null if not configured.
     */
    @AuraEnabled(cacheable=true)
    global static String getDefaultBillingEntityId() {
        DeliveryHubSettings__c settings = DeliveryHubSettings__c.getOrgDefaults();
        if (settings == null) {
            return null;
        }
        return (String) settings.get('DefaultBillingEntityIdTxt__c');
    }

    // ═══════════════════════════════════════════════════════════
    //  PUBLIC: Document Approval Flow (token-authenticated)
    // ═══════════════════════════════════════════════════════════

    /**
     * @description Approves a document identified by its public token.
     *              Sets status to Approved, creates an Approval transaction,
     *              and logs a Document_Action activity entry.
     *              Only documents in Sent or Viewed status can be approved.
     * @param publicToken The 64-char hex public access token.
     * @return Map with document id and new status.
     */
    public static Map<String, Object> approveDocumentByToken(String publicToken) {
        DeliveryDocument__c doc = queryDocumentByToken(publicToken);
        validateApprovableStatus(doc);

        doc.StatusPk__c = 'Approved';
        Database.update(doc, AccessLevel.SYSTEM_MODE);

        DeliveryTransaction__c txn = new DeliveryTransaction__c(
            DocumentId__c          = doc.Id,
            TypePk__c              = 'Approval',
            AmountCurrency__c      = doc.TotalCurrency__c != null ? doc.TotalCurrency__c : 0,
            TransactionDateDate__c = Date.today(),
            NoteTxt__c             = 'Approved by client via portal'
        );
        Database.insert(txn, AccessLevel.SYSTEM_MODE);

        logDocumentAction(doc.Id, 'approve', null);

        return new Map<String, Object>{
            'id'     => doc.Id,
            'status' => 'Approved'
        };
    }

    /**
     * @description Disputes a document identified by its public token.
     *              Sets status to Disputed, stores the dispute reason,
     *              and logs a Document_Action activity entry.
     *              Only documents in Sent or Viewed status can be disputed.
     * @param publicToken The 64-char hex public access token.
     * @param reason The client-provided reason for the dispute.
     * @return Map with document id and new status.
     */
    public static Map<String, Object> disputeDocumentByToken(String publicToken, String reason) {
        DeliveryDocument__c doc = queryDocumentByToken(publicToken);
        validateApprovableStatus(doc);

        doc.StatusPk__c = 'Disputed';
        doc.DisputeReasonTxt__c = String.isNotBlank(reason) ? reason.left(5000) : null;
        Database.update(doc, AccessLevel.SYSTEM_MODE);

        logDocumentAction(doc.Id, 'dispute', reason);

        return new Map<String, Object>{
            'id'     => doc.Id,
            'status' => 'Disputed'
        };
    }

    /**
     * @description Queries a document by its public token. Throws if not found.
     * @param publicToken The public access token.
     * @return The DeliveryDocument__c record.
     */
    @TestVisible
    private static DeliveryDocument__c queryDocumentByToken(String publicToken) {
        if (String.isBlank(publicToken)) {
            throw new AuraHandledException('Public token is required.');
        }
        List<DeliveryDocument__c> docs = [
            SELECT Id, StatusPk__c, TotalCurrency__c, NetworkEntityId__c,
                   TemplatePk__c, NetworkEntityId__r.Name
            FROM DeliveryDocument__c
            WHERE PublicTokenTxt__c = :publicToken
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        if (docs.isEmpty()) {
            throw new AuraHandledException('Document not found.');
        }
        return docs[0];
    }

    /**
     * @description Validates that a document is in an approvable status (Sent or Viewed).
     * @param doc The document to validate.
     */
    @TestVisible
    private static void validateApprovableStatus(DeliveryDocument__c doc) {
        Set<String> approvable = new Set<String>{ 'Sent', 'Viewed' };
        if (!approvable.contains(doc.StatusPk__c)) {
            throw new AuraHandledException(
                'Document cannot be approved or disputed in its current status: ' + doc.StatusPk__c
            );
        }
    }

    /**
     * @description Creates an ActivityLog__c entry for a document approval action.
     * @param documentId The DeliveryDocument__c Id.
     * @param action The action performed (approve or dispute).
     * @param reason Optional dispute reason.
     */
    private static void logDocumentAction(Id documentId, String action, String reason) {
        Map<String, Object> contextData = new Map<String, Object>{
            'action'     => action,
            'documentId' => documentId
        };
        if (String.isNotBlank(reason)) {
            contextData.put('reason', reason.left(500));
        }
        ActivityLog__c log = new ActivityLog__c(
            ActionTypePk__c    = 'Document_Action',
            RecordIdTxt__c     = documentId,
            ContextDataTxt__c  = JSON.serialize(contextData)
        );
        Database.insert(log, AccessLevel.SYSTEM_MODE);
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
                   ClientNetworkEntityId__c, WorkflowTypeTxt__c,
                   Developer__c, Developer__r.Name, Developer__r.Title
            FROM WorkItem__c
            WHERE ClientNetworkEntityId__c = :entityId
            WITH SYSTEM_MODE
            ORDER BY Name
        ];
        snapshot.put('workItems', serializeWorkItems(items, templateType));

        // Work logs within the period for these items
        Set<Id> itemIds = new Map<Id, WorkItem__c>(items).keySet();
        List<WorkLog__c> logs;
        if (templateType == 'Invoice' || templateType == 'Daily_Hours_Summary') {
            logs = [
                SELECT Id, Name, WorkItemId__c, WorkItemId__r.Name,
                       HoursLoggedNumber__c, WorkDateDate__c, WorkDescriptionTxt__c,
                       ResourceTitleTxt__c
                FROM WorkLog__c
                WHERE WorkItemId__c IN :itemIds
                AND WorkDateDate__c >= :periodStart
                AND WorkDateDate__c <= :periodEnd
                AND (StatusPk__c = 'Approved' OR StatusPk__c = null)
                WITH SYSTEM_MODE
                ORDER BY WorkDateDate__c ASC
            ];
        } else {
            logs = [
                SELECT Id, Name, WorkItemId__c, WorkItemId__r.Name,
                       HoursLoggedNumber__c, WorkDateDate__c, WorkDescriptionTxt__c,
                       ResourceTitleTxt__c
                FROM WorkLog__c
                WHERE WorkItemId__c IN :itemIds
                AND WorkDateDate__c >= :periodStart
                AND WorkDateDate__c <= :periodEnd
                WITH SYSTEM_MODE
                ORDER BY WorkDateDate__c ASC
            ];
        }
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

    private static List<Map<String, Object>> serializeWorkItems(List<WorkItem__c> items, String templateType) {
        List<Map<String, Object>> result = new List<Map<String, Object>>();
        for (WorkItem__c wi : items) {
            // Skip work items with zero hours only for invoices (billable items only);
            // agreements and status reports should include all work items
            if (templateType == 'Invoice'
                && (wi.TotalLoggedHoursNumber__c == null || wi.TotalLoggedHoursNumber__c <= 0)) {
                continue;
            }
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
            m.put('developerName', wi.Developer__r != null ? wi.Developer__r.Name : null);
            m.put('developerTitle', wi.Developer__r != null ? wi.Developer__r.Title : null);
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
            m.put('resourceTitle', wl.ResourceTitleTxt__c);
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

    @TestVisible
    private static List<Map<String, String>> buildDefaultAgreementClauses(String templateType, Map<String, Object> snapshot) {
        Map<String, Object> entity = (Map<String, Object>) snapshot.get('entity');
        String clientName = entity != null && entity.get('name') != null ? (String) entity.get('name') : '[Client Name]';
        Decimal rate = entity != null && entity.get('defaultRate') != null ? (Decimal) entity.get('defaultRate') : 0;
        String vendorName = resolveVendorName();
        String formattedRate = '$' + rate.setScale(2).format();
        Boolean isContractor = templateType == 'Contractor_Agreement';
        String partyA = isContractor ? vendorName : vendorName;
        String partyB = isContractor ? clientName : clientName;
        String partyARole = isContractor ? 'Company' : 'Consultant';
        String partyBRole = isContractor ? 'Contractor' : 'Client';

        List<Map<String, String>> clauses = new List<Map<String, String>>();

        Map<String, String> c1 = new Map<String, String>();
        c1.put('title', 'Scope of Services');
        c1.put('body', partyA + ' ("' + partyARole + '") shall provide professional Salesforce development, '
            + 'administration, and consulting services to ' + partyB + ' ("' + partyBRole + '") as mutually '
            + 'agreed upon in writing. Services may include but are not limited to: custom development, '
            + 'system configuration, data migration, integration, training, and ongoing support. The specific '
            + 'deliverables, timeline, and acceptance criteria for each engagement shall be documented via '
            + 'Work Items in the Delivery Hub platform.');
        clauses.add(c1);

        Map<String, String> c2 = new Map<String, String>();
        c2.put('title', 'Compensation');
        c2.put('body', partyBRole + ' agrees to pay ' + partyARole + ' at a rate of ' + formattedRate
            + ' per hour for all services rendered. Invoices are issued monthly and are payable within '
            + 'thirty (30) days of receipt. Late payments are subject to a finance charge of three percent '
            + '(3%) per month on outstanding balances. All work hours are tracked and documented in the '
            + 'Delivery Hub platform and are available for review at any time.');
        clauses.add(c2);

        Map<String, String> c3 = new Map<String, String>();
        c3.put('title', 'Term and Termination');
        c3.put('body', 'This agreement is effective as of the date of last signature below and continues '
            + 'until terminated by either party with thirty (30) days written notice. Upon termination, '
            + partyBRole + ' shall pay for all services rendered through the termination date. Any outstanding '
            + 'Work Items will be documented and transitioned according to a mutually agreed transition plan.');
        clauses.add(c3);

        Map<String, String> c4 = new Map<String, String>();
        c4.put('title', 'Confidentiality');
        c4.put('body', 'Both parties agree to maintain the confidentiality of all proprietary information, '
            + 'trade secrets, business processes, and technical data shared during the course of this engagement. '
            + 'This obligation survives termination of this agreement for a period of two (2) years. '
            + 'Confidential information does not include information that is publicly available, independently '
            + 'developed, or rightfully received from a third party.');
        clauses.add(c4);

        Map<String, String> c5 = new Map<String, String>();
        c5.put('title', 'Intellectual Property');
        c5.put('body', 'All custom code, configurations, and deliverables created specifically for ' + partyBRole
            + ' during this engagement shall be the property of ' + partyBRole + ' upon full payment. '
            + partyARole + ' retains ownership of all pre-existing tools, frameworks, and methodologies, '
            + 'including the Delivery Hub platform, and grants ' + partyBRole + ' a perpetual license to use '
            + 'any such tools incorporated into the deliverables.');
        clauses.add(c5);

        Map<String, String> c6 = new Map<String, String>();
        c6.put('title', 'Limitation of Liability');
        c6.put('body', 'In no event shall either party be liable for any indirect, incidental, special, '
            + 'consequential, or punitive damages. ' + partyARole + '\'s total liability under this agreement '
            + 'shall not exceed the total fees paid by ' + partyBRole + ' in the twelve (12) months preceding '
            + 'the claim. ' + partyARole + ' shall not be liable for any delays or failures caused by '
            + 'Salesforce platform limitations, third-party service outages, or force majeure events.');
        clauses.add(c6);

        Map<String, String> c7 = new Map<String, String>();
        c7.put('title', 'Independent Contractor');
        c7.put('body', partyARole + ' is an independent contractor and nothing in this agreement creates '
            + 'an employer-employee relationship, partnership, or joint venture. ' + partyARole + ' is '
            + 'responsible for all taxes, insurance, and benefits related to the performance of services '
            + 'under this agreement.');
        clauses.add(c7);

        Map<String, String> c8 = new Map<String, String>();
        c8.put('title', 'Governing Law');
        c8.put('body', 'This agreement shall be governed by and construed in accordance with the laws '
            + 'of the State of Florida, without regard to its conflict of laws principles. Any dispute '
            + 'arising under this agreement shall first be submitted to good-faith mediation before '
            + 'either party may pursue other remedies.');
        clauses.add(c8);

        return clauses;
    }

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

/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Read/query operations for DeliveryDocument__c records.
 *               Extracted from DeliveryDocumentController to reduce class size.
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.ApexCRUDViolation')
public with sharing class DeliveryDocQueryService {

    /**
     * @description Retrieves a document's full data by its public token.
     *              Used by the portal to render the document without Salesforce auth.
     *              Marks the document as Viewed on first access if status is Sent.
     * @param publicToken The unique public access token.
     * @return Map containing the document record fields and parsed snapshot.
     */
    public static Map<String, Object> getDocumentByToken(String publicToken) {
        List<DeliveryDocument__c> docs = [
            SELECT Id, Name, TemplatePk__c, NetworkEntityId__c,
                   NetworkEntityId__r.Name, NetworkEntityId__r.DefaultHourlyRateCurrency__c,
                   PeriodStartDate__c, PeriodEndDate__c,
                   StatusPk__c, PublicTokenTxt__c,
                   AiNarrativeTxt__c, SnapshotTxt__c,
                   TotalHoursNumber__c, TotalCurrency__c,
                   SentDateTime__c, ViewedDateTime__c,
                   DueDateDate__c, TermsTxt__c, MetadataTxt__c,
                   VersionNumber__c, PreviousVersionId__c,
                   RequiresSigningCheckbox__c
            FROM DeliveryDocument__c
            WHERE PublicTokenTxt__c = :publicToken
            WITH SYSTEM_MODE
            LIMIT 1
        ];

        if (docs.isEmpty()) {
            throw new AuraHandledException('Document not found.');
        }

        DeliveryDocument__c doc = docs[0];

        // Mark as viewed on first access. When the document requires signing,
        // jump straight to Awaiting_Signatures so the signing flow can take over
        // — the legacy Approve button on the public viewer is short-circuited in
        // DeliveryDocApprovalService when this flag is set.
        if (doc.ViewedDateTime__c == null && doc.StatusPk__c == 'Sent') {
            doc.ViewedDateTime__c = Datetime.now();
            doc.StatusPk__c = doc.RequiresSigningCheckbox__c == true
                ? 'Awaiting_Signatures'
                : 'Viewed';
            Database.update(doc, AccessLevel.SYSTEM_MODE);
        }

        return buildDocumentResultMap(doc, false);
    }

    /**
     * @description Retrieves a document's full data by its record Id.
     *              Used by the embedded LWC viewer (admin context, authenticated).
     * @param documentId The DeliveryDocument__c Id.
     * @return Map containing the document record fields and parsed snapshot.
     */
    public static Map<String, Object> getDocumentById(Id documentId) {
        List<DeliveryDocument__c> docs = [
            SELECT Id, Name, TemplatePk__c, NetworkEntityId__c,
                   NetworkEntityId__r.Name, NetworkEntityId__r.DefaultHourlyRateCurrency__c,
                   PeriodStartDate__c, PeriodEndDate__c,
                   StatusPk__c, PublicTokenTxt__c,
                   AiNarrativeTxt__c, SnapshotTxt__c,
                   TotalHoursNumber__c, TotalCurrency__c,
                   SentDateTime__c, ViewedDateTime__c,
                   DueDateDate__c, TermsTxt__c, MetadataTxt__c,
                   VersionNumber__c, PreviousVersionId__c,
                   RequiresSigningCheckbox__c
            FROM DeliveryDocument__c
            WHERE Id = :documentId
            WITH SYSTEM_MODE
            LIMIT 1
        ];

        if (docs.isEmpty()) {
            throw new AuraHandledException('Document not found.');
        }

        return buildDocumentResultMap(docs[0], true);
    }

    /**
     * @description Lists documents ordered by creation date. When entityId is provided,
     *              returns documents for that entity. When null, returns all documents.
     * @param entityId The NetworkEntity__c Id, or null for all documents.
     * @return List of document summary maps.
     */
    public static List<Map<String, Object>> getDocumentsForEntity(Id entityId) {
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
     * @description Returns a summary of all Draft invoices and daily hour summaries
     *              that are pending review.
     * @return Map with 'count' (Integer) and 'documents' (List of summary maps).
     */
    public static Map<String, Object> getPendingInvoices() {
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
     * @description Returns available document templates from DocumentTemplate__mdt.
     * @return List of maps with 'value' (DeveloperName), 'label', and 'description' keys.
     */
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
     * @description Queries all DeliveryTransaction__c records for a given document
     *              and returns them as a list of serialized maps.
     * @param docId The DeliveryDocument__c Id.
     * @return List of maps with transaction fields.
     */
    @TestVisible
    public static List<Map<String, Object>> getTransactionsForDocument(Id docId) {
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
     * @description Returns the Default Billing Entity ID from org settings.
     * @return The 18-character NetworkEntity__c ID, or null if not configured.
     */
    public static String getDefaultBillingEntityId() {
        DeliveryHubSettings__c settings = DeliveryHubSettings__c.getOrgDefaults();
        if (settings == null) {
            return null;
        }
        return (String) settings.get('DefaultBillingEntityIdTxt__c');
    }

    /**
     * @description Calculates the total paid amount for a document by aggregating
     *              all DeliveryTransaction__c AmountCurrency__c values.
     * @param docId The DeliveryDocument__c Id.
     * @return The sum of all transaction amounts, or 0 if none exist.
     */
    @TestVisible
    public static Decimal getTotalPaid(Id docId) {
        AggregateResult[] results = [
            SELECT SUM(AmountCurrency__c) totalPaid
            FROM DeliveryTransaction__c
            WHERE DocumentId__c = :docId
            WITH SYSTEM_MODE
        ];
        Object val = results[0].get('totalPaid');
        return val != null ? (Decimal) val : 0;
    }

    // ═══════════════════════════════════════════════════════════
    //  PRIVATE: Shared Result Map Builder
    // ═══════════════════════════════════════════════════════════

    /**
     * @description Builds a standard result map from a DeliveryDocument__c record.
     *              Collapses duplicate map-building logic formerly in getDocumentByToken
     *              and getDocumentById.
     * @param doc The queried DeliveryDocument__c record.
     * @param includePublicToken Whether to include the publicToken key (admin view only).
     * @return Map containing the document record fields and parsed snapshot.
     */
    private static Map<String, Object> buildDocumentResultMap(DeliveryDocument__c doc, Boolean includePublicToken) {
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
        result.put('requiresSigning', doc.RequiresSigningCheckbox__c);
        result.put('actions', DeliveryDocActionController.getActionsForDocument(doc.Id));
        if (includePublicToken) {
            result.put('publicToken', doc.PublicTokenTxt__c);
        }
        return result;
    }
}

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

        DeliveryDocument__c doc = new DeliveryDocument__c(
            NetworkEntityId__c  = entityId,
            TemplatePk__c       = templateType,
            PeriodStartDate__c  = periodStart,
            PeriodEndDate__c    = periodEnd,
            StatusPk__c         = 'Draft',
            PublicTokenTxt__c   = publicToken,
            SnapshotTxt__c      = JSON.serialize(snapshot),
            TotalHoursNumber__c = calculateTotalHours(snapshot),
            TotalCurrency__c    = calculateTotalCost(snapshot),
            MetadataTxt__c      = metadata
        );

        Database.insert(doc, AccessLevel.SYSTEM_MODE);
        return doc.Id;
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

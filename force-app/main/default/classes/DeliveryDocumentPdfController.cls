/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Visualforce controller for server-side PDF rendering of DeliveryDocument__c
 *               records. Parses the frozen JSON snapshot and exposes typed properties that
 *               the DeliveryDocumentPdf.page consumes for professional document output.
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.ApexCRUDViolation')
public with sharing class DeliveryDocumentPdfController {

    // ── Core document record ──
    public DeliveryDocument__c doc { get; private set; }
    public String documentName { get; private set; }
    public String templateType { get; private set; }
    public String templateDisplay { get; private set; }
    public Decimal totalHours { get; private set; }
    public Decimal totalCost { get; private set; }
    public String formattedTotalCost { get; private set; }
    public String formattedPeriod { get; private set; }
    public String terms { get; private set; }
    public Date dueDate { get; private set; }
    public String aiNarrative { get; private set; }
    public String generatedAt { get; private set; }

    // ── Balance tracking ──
    public Decimal priorBalance { get; private set; }
    public Decimal amountDue { get; private set; }
    public String formattedPriorBalance { get; private set; }
    public String formattedAmountDue { get; private set; }

    // ── Render mode ──
    public Boolean renderAsPdf { get; private set; }

    // ── Unpaid invoices summary ──
    public List<UnpaidInvoiceRow> unpaidInvoiceRows { get; private set; }

    // ── Entity details ──
    public String entityName { get; private set; }
    public String entityAddress { get; private set; }
    public String entityEmail { get; private set; }
    public String entityPhone { get; private set; }
    public Decimal defaultRate { get; private set; }

    // ── Snapshot collections ──
    public List<WorkItemRow> workItemRows { get; private set; }
    public List<WorkLogRow> workLogRows { get; private set; }
    public List<WorkRequestRow> workRequestRows { get; private set; }

    // ── Inner classes for VF iteration ──

    public class WorkItemRow {
        public String name { get; set; }
        public String description { get; set; }
        public String stage { get; set; }
        public Decimal hours { get; set; }
        public Decimal rate { get; set; }
        public Decimal subtotal { get; set; }
        public String formattedRate { get; set; }
        public String formattedSubtotal { get; set; }
    }

    public class WorkLogRow {
        public String workItemName { get; set; }
        public Decimal hours { get; set; }
        public Decimal rate { get; set; }
        public Decimal amount { get; set; }
        public String formattedRate { get; set; }
        public String formattedAmount { get; set; }
        public String workDate { get; set; }
        public String description { get; set; }
    }

    public class UnpaidInvoiceRow {
        public String name { get; set; }
        public String period { get; set; }
        public String formattedTotal { get; set; }
        public String formattedPaid { get; set; }
        public String formattedOutstanding { get; set; }
        public String status { get; set; }
    }

    public class WorkRequestRow {
        public String workItemName { get; set; }
        public String vendorName { get; set; }
        public String status { get; set; }
        public Decimal hours { get; set; }
        public String formattedRate { get; set; }
    }

    // ═══════════════════════════════════════════════════════════
    //  CONSTRUCTOR
    // ═══════════════════════════════════════════════════════════

    public DeliveryDocumentPdfController() {
        workItemRows = new List<WorkItemRow>();
        workLogRows = new List<WorkLogRow>();
        workRequestRows = new List<WorkRequestRow>();
        unpaidInvoiceRows = new List<UnpaidInvoiceRow>();
        defaultRate = 0;
        totalHours = 0;
        totalCost = 0;
        priorBalance = 0;
        amountDue = 0;

        // ?pdf=true triggers server-side PDF rendering
        renderAsPdf = ApexPages.currentPage().getParameters().get('pdf') == 'true';

        // Support both authenticated (?id=) and public (?token=) access
        String docId = ApexPages.currentPage().getParameters().get('id');
        String publicToken = ApexPages.currentPage().getParameters().get('token');

        if (String.isBlank(docId) && String.isBlank(publicToken)) {
            return;
        }

        String query = 'SELECT Id, Name, TemplatePk__c, NetworkEntityId__r.Name, '
            + 'PeriodStartDate__c, PeriodEndDate__c, '
            + 'StatusPk__c, TotalHoursNumber__c, TotalCurrency__c, '
            + 'SnapshotTxt__c, AiNarrativeTxt__c, TermsTxt__c, '
            + 'DueDateDate__c, MetadataTxt__c, ViewedDateTime__c '
            + 'FROM DeliveryDocument__c WHERE ';
        if (String.isNotBlank(docId)) {
            query += 'Id = :docId';
        } else {
            query += 'PublicTokenTxt__c = :publicToken';
        }
        query += ' WITH SYSTEM_MODE LIMIT 1';

        List<DeliveryDocument__c> docs = Database.query(query);

        if (docs.isEmpty()) {
            return;
        }

        doc = docs[0];

        // Auto-mark as Viewed on first public token access
        // Skip DML on Sites (guest user context) — GET requests don't allow DML
        if (String.isNotBlank(publicToken) && doc.ViewedDateTime__c == null
            && doc.StatusPk__c == 'Sent') {
            try {
                doc.ViewedDateTime__c = Datetime.now();
                doc.StatusPk__c = 'Viewed';
                Database.update(doc, AccessLevel.SYSTEM_MODE);
            } catch (Exception e) {
                // Silently skip — DML not allowed in guest GET context on Sites
            }
        }

        documentName = doc.Name;
        templateType = doc.TemplatePk__c;
        templateDisplay = doc.TemplatePk__c != null ? doc.TemplatePk__c.replace('_', ' ') : '';
        totalHours = doc.TotalHoursNumber__c != null ? doc.TotalHoursNumber__c : 0;
        totalCost = doc.TotalCurrency__c != null ? doc.TotalCurrency__c : 0;
        formattedTotalCost = formatCurrency(totalCost);
        terms = doc.TermsTxt__c;
        dueDate = doc.DueDateDate__c;
        aiNarrative = doc.AiNarrativeTxt__c;

        if (doc.PeriodStartDate__c != null && doc.PeriodEndDate__c != null) {
            formattedPeriod = doc.PeriodStartDate__c.format() + ' \u2013 ' + doc.PeriodEndDate__c.format();
        }

        if (String.isNotBlank(doc.SnapshotTxt__c)) {
            Map<String, Object> snapshot = (Map<String, Object>) JSON.deserializeUntyped(doc.SnapshotTxt__c);
            generatedAt = (String) snapshot.get('generatedAt');
            parseEntity(snapshot);
            parseWorkItems(snapshot);
            parseWorkLogs(snapshot);
            parseWorkRequests(snapshot);
        }

        // Parse metadata for prior balance, unpaid invoices, etc.
        if (String.isNotBlank(doc.MetadataTxt__c)) {
            Map<String, Object> meta = (Map<String, Object>) JSON.deserializeUntyped(doc.MetadataTxt__c);
            if (meta.containsKey('priorBalance') && meta.get('priorBalance') != null) {
                priorBalance = (Decimal) meta.get('priorBalance');
            }
            // Parse unpaid invoices summary
            if (meta.containsKey('unpaidInvoices') && meta.get('unpaidInvoices') != null) {
                List<Object> unpaidList = (List<Object>) meta.get('unpaidInvoices');
                for (Object o : unpaidList) {
                    Map<String, Object> inv = (Map<String, Object>) o;
                    UnpaidInvoiceRow row = new UnpaidInvoiceRow();
                    row.name = (String) inv.get('name');
                    String pStart = (String) inv.get('periodStart');
                    String pEnd = (String) inv.get('periodEnd');
                    row.period = (pStart != null ? pStart : '') + ' - ' + (pEnd != null ? pEnd : '');
                    row.formattedTotal = formatCurrency(inv.get('total') != null ? (Decimal) inv.get('total') : 0);
                    row.formattedPaid = formatCurrency(inv.get('paid') != null ? (Decimal) inv.get('paid') : 0);
                    row.formattedOutstanding = formatCurrency(inv.get('outstanding') != null ? (Decimal) inv.get('outstanding') : 0);
                    row.status = (String) inv.get('status');
                    unpaidInvoiceRows.add(row);
                }
            }
        }
        amountDue = totalCost + priorBalance;
        formattedPriorBalance = formatCurrency(priorBalance);
        formattedAmountDue = formatCurrency(amountDue);
    }

    // ═══════════════════════════════════════════════════════════
    //  BOOLEAN GETTERS (VF requires explicit getters)
    // ═══════════════════════════════════════════════════════════

    public Boolean getIsInvoice() {
        return templateType == 'Invoice';
    }

    public Boolean getIsAgreement() {
        return templateType == 'Client_Agreement' || templateType == 'Contractor_Agreement';
    }

    public Boolean getHasWorkItems() {
        return !workItemRows.isEmpty();
    }

    public Boolean getHasWorkLogs() {
        return !workLogRows.isEmpty();
    }

    public Boolean getHasWorkRequests() {
        return !workRequestRows.isEmpty();
    }

    public Boolean getHasAiNarrative() {
        return String.isNotBlank(aiNarrative);
    }

    public Boolean getHasEntityContact() {
        return String.isNotBlank(entityAddress) || String.isNotBlank(entityEmail) || String.isNotBlank(entityPhone);
    }

    public Boolean getHasUnpaidInvoices() {
        return !unpaidInvoiceRows.isEmpty();
    }

    public Boolean getHasPriorBalance() {
        return priorBalance != null && priorBalance != 0;
    }

    public Boolean getHasTerms() {
        return String.isNotBlank(terms);
    }

    public Boolean getHasDueDate() {
        return dueDate != null;
    }

    public Boolean getHasDocument() {
        return doc != null;
    }

    public String getFormattedDefaultRate() {
        return formatCurrency(defaultRate) + '/hr';
    }

    public String getFormattedDueDate() {
        return dueDate != null ? dueDate.format() : '';
    }

    public String getFormattedTotalHours() {
        return totalHours.setScale(1) + ' hrs';
    }

    // ═══════════════════════════════════════════════════════════
    //  PRIVATE: Snapshot Parsers
    // ═══════════════════════════════════════════════════════════

    private void parseEntity(Map<String, Object> snapshot) {
        if (!snapshot.containsKey('entity')) {
            return;
        }
        Map<String, Object> entity = (Map<String, Object>) snapshot.get('entity');
        entityName = (String) entity.get('name');
        entityAddress = (String) entity.get('address');
        entityEmail = (String) entity.get('email');
        entityPhone = (String) entity.get('phone');
        defaultRate = entity.get('defaultRate') != null ? (Decimal) entity.get('defaultRate') : 0;
    }

    private void parseWorkItems(Map<String, Object> snapshot) {
        if (!snapshot.containsKey('workItems')) {
            return;
        }
        List<Object> items = (List<Object>) snapshot.get('workItems');
        for (Object o : items) {
            Map<String, Object> item = (Map<String, Object>) o;
            WorkItemRow row = new WorkItemRow();
            row.name = (String) item.get('name');
            row.description = (String) item.get('description');
            row.stage = (String) item.get('stage');
            row.hours = item.get('totalLoggedHours') != null ? (Decimal) item.get('totalLoggedHours') : 0;
            row.rate = item.get('billableRate') != null ? (Decimal) item.get('billableRate') : defaultRate;
            row.subtotal = row.hours * row.rate;
            row.formattedRate = formatCurrency(row.rate);
            row.formattedSubtotal = formatCurrency(row.subtotal);
            workItemRows.add(row);
        }
    }

    private void parseWorkLogs(Map<String, Object> snapshot) {
        if (!snapshot.containsKey('workLogs')) {
            return;
        }
        // Build rate map: workItemId -> rate (from items, overridden by requests)
        Map<String, Decimal> rateMap = new Map<String, Decimal>();
        if (snapshot.containsKey('workItems')) {
            for (Object o : (List<Object>) snapshot.get('workItems')) {
                Map<String, Object> item = (Map<String, Object>) o;
                String itemId = (String) item.get('id');
                Decimal itemRate = item.get('billableRate') != null ? (Decimal) item.get('billableRate') : defaultRate;
                rateMap.put(itemId, itemRate);
            }
        }
        if (snapshot.containsKey('workRequests')) {
            for (Object o : (List<Object>) snapshot.get('workRequests')) {
                Map<String, Object> req = (Map<String, Object>) o;
                if (req.get('hourlyRate') != null) {
                    rateMap.put((String) req.get('workItemId'), (Decimal) req.get('hourlyRate'));
                }
            }
        }

        List<Object> logs = (List<Object>) snapshot.get('workLogs');
        for (Object o : logs) {
            Map<String, Object> log = (Map<String, Object>) o;
            WorkLogRow row = new WorkLogRow();
            row.workItemName = (String) log.get('workItemName');
            row.hours = log.get('hours') != null ? (Decimal) log.get('hours') : 0;
            row.workDate = (String) log.get('date');
            row.description = (String) log.get('description');
            String workItemId = (String) log.get('workItemId');
            row.rate = rateMap.containsKey(workItemId) ? rateMap.get(workItemId) : defaultRate;
            row.amount = row.hours * row.rate;
            row.formattedRate = formatCurrency(row.rate);
            row.formattedAmount = formatCurrency(row.amount);
            workLogRows.add(row);
        }
    }

    private void parseWorkRequests(Map<String, Object> snapshot) {
        if (!snapshot.containsKey('workRequests')) {
            return;
        }
        List<Object> reqs = (List<Object>) snapshot.get('workRequests');
        for (Object o : reqs) {
            Map<String, Object> req = (Map<String, Object>) o;
            WorkRequestRow row = new WorkRequestRow();
            row.workItemName = (String) req.get('workItemName');
            row.vendorName = (String) req.get('vendorEntityName');
            row.status = (String) req.get('status');
            row.hours = req.get('totalLoggedHours') != null ? (Decimal) req.get('totalLoggedHours') : 0;
            Decimal rate = req.get('hourlyRate') != null ? (Decimal) req.get('hourlyRate') : 0;
            row.formattedRate = formatCurrency(rate);
            workRequestRows.add(row);
        }
    }

    // ═══════════════════════════════════════════════════════════
    //  PRIVATE: Formatting
    // ═══════════════════════════════════════════════════════════

    private static String formatCurrency(Decimal amount) {
        if (amount == null) {
            return '$0.00';
        }
        return '$' + amount.setScale(2).format();
    }
}

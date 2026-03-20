/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Visualforce controller for server-side PDF rendering of DeliveryDocument__c
 *               records. Parses the frozen JSON snapshot and exposes typed properties that
 *               the DeliveryDocumentPdf.page consumes for professional document output.
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.ApexCRUDViolation, PMD.CyclomaticComplexity, PMD.StdCyclomaticComplexity')
public without sharing class DeliveryDocumentPdfController {

    /** @description The underlying DeliveryDocument__c record. */
    public DeliveryDocument__c doc { get; private set; }
    /** @description Auto-number name of the document (e.g. DOC-000013). */
    public String documentName { get; private set; }
    /** @description Template API name (e.g. Invoice, Status_Report). */
    public String templateType { get; private set; }
    /** @description Human-readable template label for the PDF heading. */
    public String templateDisplay { get; private set; }
    /** @description Sum of hours across all work logs in the period. */
    public Decimal totalHours { get; private set; }
    /** @description Sum of (hours x rate) across all work logs. */
    public Decimal totalCost { get; private set; }
    /** @description Formatted total cost string (e.g. $7,065.00). */
    public String formattedTotalCost { get; private set; }
    /** @description Formatted period range (e.g. Mar 1, 2026 - Mar 31, 2026). */
    public String formattedPeriod { get; private set; }
    /** @description Payment terms (e.g. Net 30). */
    public String terms { get; private set; }
    /** @description Calculated due date based on terms. */
    public Date dueDate { get; private set; }
    /** @description AI-generated executive narrative. */
    public String aiNarrative { get; private set; }
    /** @description Formatted date when the document was generated. */
    public String generatedAt { get; private set; }

    /** @description Outstanding balance from prior unpaid invoices. */
    public Decimal priorBalance { get; private set; }
    /** @description Total amount due (current charges + prior balance). */
    public Decimal amountDue { get; private set; }
    /** @description Formatted prior balance string. */
    public String formattedPriorBalance { get; private set; }
    /** @description Formatted amount due string. */
    public String formattedAmountDue { get; private set; }

    /** @description Whether to render the page as PDF via Flying Saucer. */
    public Boolean renderAsPdf { get; private set; }

    /** @description List of unpaid prior invoices for the A/R summary table. */
    public List<UnpaidInvoiceRow> unpaidInvoiceRows { get; private set; }

    /** @description Vendor (issuer) company name from NetworkEntity. */
    public String vendorName { get; private set; }
    /** @description Vendor address formatted with br tags for PDF. */
    public String vendorAddress { get; private set; }
    /** @description Vendor contact email address. */
    public String vendorEmail { get; private set; }
    /** @description Vendor contact phone number. */
    public String vendorPhone { get; private set; }

    /** @description Client (bill-to) entity name. */
    public String entityName { get; private set; }
    /** @description Client entity address. */
    public String entityAddress { get; private set; }
    /** @description Client entity email. */
    public String entityEmail { get; private set; }
    /** @description Client entity phone. */
    public String entityPhone { get; private set; }
    /** @description Default hourly rate from the entity record. */
    public Decimal defaultRate { get; private set; }

    /** @description Parsed work item rows for VF iteration. */
    public List<WorkItemRow> workItemRows { get; private set; }
    /** @description Parsed work log rows for VF iteration. */
    public List<WorkLogRow> workLogRows { get; private set; }
    /** @description Parsed work request rows for VF iteration. */
    public List<WorkRequestRow> workRequestRows { get; private set; }

    /** @description Row data for work items table in the PDF. */
    public class WorkItemRow {
        /** @description Work item auto-number name. */
        public String name { get; set; }
        /** @description Brief description of the work item. */
        public String description { get; set; }
        /** @description Current workflow stage. */
        public String stage { get; set; }
        /** @description Total logged hours for this item in the period. */
        public Decimal hours { get; set; }
        /** @description Billable hourly rate. */
        public Decimal rate { get; set; }
        /** @description Calculated subtotal (hours x rate). */
        public Decimal subtotal { get; set; }
        /** @description Formatted rate string. */
        public String formattedRate { get; set; }
        /** @description Formatted subtotal string. */
        public String formattedSubtotal { get; set; }
    }

    /** @description Row data for time log detail table in the PDF. */
    public class WorkLogRow {
        /** @description Parent work item name. */
        public String workItemName { get; set; }
        /** @description Hours logged in this entry. */
        public Decimal hours { get; set; }
        /** @description Billable rate for this entry. */
        public Decimal rate { get; set; }
        /** @description Calculated amount (hours x rate). */
        public Decimal amount { get; set; }
        /** @description Formatted rate string. */
        public String formattedRate { get; set; }
        /** @description Formatted amount string. */
        public String formattedAmount { get; set; }
        /** @description Formatted work date. */
        public String workDate { get; set; }
        /** @description Work description text. */
        public String description { get; set; }
    }

    /** @description Row data for unpaid invoices A/R summary table. */
    public class UnpaidInvoiceRow {
        /** @description Invoice document name. */
        public String name { get; set; }
        /** @description Formatted period range. */
        public String period { get; set; }
        /** @description Formatted invoiced total. */
        public String formattedTotal { get; set; }
        /** @description Formatted payment received. */
        public String formattedPaid { get; set; }
        /** @description Formatted outstanding balance. */
        public String formattedOutstanding { get; set; }
        /** @description Invoice status (Draft, Sent, Viewed, Paid). */
        public String status { get; set; }
    }

    /** @description Row data for work requests table in the PDF. */
    public class WorkRequestRow {
        /** @description Parent work item name. */
        public String workItemName { get; set; }
        /** @description Delivery vendor entity name. */
        public String vendorName { get; set; }
        /** @description Request status. */
        public String status { get; set; }
        /** @description Total logged hours for this request. */
        public Decimal hours { get; set; }
        /** @description Formatted hourly rate string. */
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
            formattedPeriod = formatDate(doc.PeriodStartDate__c) + ' \u2013 ' + formatDate(doc.PeriodEndDate__c);
        }

        if (String.isNotBlank(doc.SnapshotTxt__c)) {
            Map<String, Object> snapshot = (Map<String, Object>) JSON.deserializeUntyped(doc.SnapshotTxt__c);
            // Format generated-at as a readable date (not raw ISO timestamp)
            String rawGenAt = (String) snapshot.get('generatedAt');
            if (String.isNotBlank(rawGenAt)) {
                try {
                    Datetime genDt = Datetime.valueOf(rawGenAt.replace('T', ' '));
                    generatedAt = formatDate(genDt.date());
                } catch (Exception e) {
                    generatedAt = rawGenAt;
                }
            }
            parseEntity(snapshot);
            parseWorkItems(snapshot);
            parseWorkLogs(snapshot);
            parseWorkRequests(snapshot);
        }

        // Parse metadata for prior balance, unpaid invoices, etc.
        if (String.isNotBlank(doc.MetadataTxt__c)) {
            parseMetadata(doc.MetadataTxt__c);
        }
        amountDue = totalCost + priorBalance;
        formattedPriorBalance = formatCurrency(priorBalance);
        formattedAmountDue = formatCurrency(amountDue);

        // Load vendor (issuer) entity — the "self" entity with type Vendor or Both
        loadVendorEntity();
    }

    private void loadVendorEntity() {
        // Default fallback
        vendorName = 'Cloud Nimbus LLC';
        vendorAddress = '2301 Collins Ave Apt 1420<br/>Miami Beach, FL 33139';
        vendorEmail = 'glen.bradford@nimbasolutions.com';
        vendorPhone = '(305) 204-0580';

        List<NetworkEntity__c> vendors = [
            SELECT Name, AddressTxt__c, ContactEmailTxt__c, ContactPhoneTxt__c
            FROM NetworkEntity__c
            WHERE EntityTypePk__c IN ('Vendor', 'Both')
            WITH SYSTEM_MODE
            ORDER BY CreatedDate ASC
            LIMIT 1
        ];
        if (!vendors.isEmpty()) {
            NetworkEntity__c v = vendors[0];
            vendorName = v.Name;
            if (String.isNotBlank(v.AddressTxt__c)) {
                vendorAddress = formatAddressForPdf(v.AddressTxt__c);
            }
            if (String.isNotBlank(v.ContactEmailTxt__c)) {
                vendorEmail = v.ContactEmailTxt__c;
            }
            if (String.isNotBlank(v.ContactPhoneTxt__c)) {
                vendorPhone = v.ContactPhoneTxt__c;
            }
        }
    }

    // ═══════════════════════════════════════════════════════════
    //  BOOLEAN GETTERS (VF requires explicit getters)
    // ═══════════════════════════════════════════════════════════

    /** @description Whether the template is an Invoice. */
    public Boolean getIsInvoice() {
        return templateType == 'Invoice';
    }

    /** @description Whether the template is a Client or Contractor Agreement. */
    public Boolean getIsAgreement() {
        return templateType == 'Client_Agreement' || templateType == 'Contractor_Agreement';
    }

    /** @description Whether the snapshot contains work items. */
    public Boolean getHasWorkItems() {
        return !workItemRows.isEmpty();
    }

    /** @description Whether the snapshot contains work logs. */
    public Boolean getHasWorkLogs() {
        return !workLogRows.isEmpty();
    }

    /** @description Whether the snapshot contains work requests. */
    public Boolean getHasWorkRequests() {
        return !workRequestRows.isEmpty();
    }

    /** @description Whether an AI narrative exists on the document. */
    public Boolean getHasAiNarrative() {
        return String.isNotBlank(aiNarrative);
    }

    /** @description Whether the entity has any contact info (address, email, phone). */
    public Boolean getHasEntityContact() {
        return String.isNotBlank(entityAddress) || String.isNotBlank(entityEmail) || String.isNotBlank(entityPhone);
    }

    /** @description Whether there are unpaid prior invoices. */
    public Boolean getHasUnpaidInvoices() {
        return !unpaidInvoiceRows.isEmpty();
    }

    /** @description Whether the document has a non-zero prior balance. */
    public Boolean getHasPriorBalance() {
        return priorBalance != null && priorBalance != 0;
    }

    /** @description Whether payment terms are set. */
    public Boolean getHasTerms() {
        return String.isNotBlank(terms);
    }

    /** @description Whether a due date is set. */
    public Boolean getHasDueDate() {
        return dueDate != null;
    }

    /** @description Whether the document record was found. */
    public Boolean getHasDocument() {
        return doc != null;
    }

    /** @description Formatted default hourly rate with /hr suffix. */
    public String getFormattedDefaultRate() {
        return formatCurrency(defaultRate) + '/hr';
    }

    /** @description Formatted due date string. */
    public String getFormattedDueDate() {
        return dueDate != null ? dueDate.format() : '';
    }

    /** @description Formatted total hours with hrs suffix. */
    public String getFormattedTotalHours() {
        return totalHours.setScale(1) + ' hrs';
    }

    // ═══════════════════════════════════════════════════════════
    //  PRIVATE: Snapshot Parsers
    // ═══════════════════════════════════════════════════════════

    private void parseMetadata(String metadataJson) {
        Map<String, Object> meta = (Map<String, Object>) JSON.deserializeUntyped(metadataJson);
        if (meta.containsKey('priorBalance') && meta.get('priorBalance') != null) {
            priorBalance = (Decimal) meta.get('priorBalance');
        }
        if (meta.containsKey('unpaidInvoices') && meta.get('unpaidInvoices') != null) {
            List<Object> unpaidList = (List<Object>) meta.get('unpaidInvoices');
            for (Object o : unpaidList) {
                Map<String, Object> inv = (Map<String, Object>) o;
                UnpaidInvoiceRow row = new UnpaidInvoiceRow();
                row.name = (String) inv.get('name');
                String pStart = (String) inv.get('periodStart');
                String pEnd = (String) inv.get('periodEnd');
                String fStart = '';
                String fEnd = '';
                try { fStart = formatDate(Date.valueOf(pStart)); } catch (Exception e) { fStart = pStart != null ? pStart : ''; }
                try { fEnd = formatDate(Date.valueOf(pEnd)); } catch (Exception e) { fEnd = pEnd != null ? pEnd : ''; }
                row.period = fStart + ' \u2013 ' + fEnd;
                row.formattedTotal = formatCurrency(inv.get('total') != null ? (Decimal) inv.get('total') : 0);
                row.formattedPaid = formatCurrency(inv.get('paid') != null ? (Decimal) inv.get('paid') : 0);
                row.formattedOutstanding = formatCurrency(inv.get('outstanding') != null ? (Decimal) inv.get('outstanding') : 0);
                row.status = (String) inv.get('status');
                unpaidInvoiceRows.add(row);
            }
        }
    }

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
            String rawDate = (String) log.get('date');
            if (String.isNotBlank(rawDate)) {
                try {
                    row.workDate = formatDate(Date.valueOf(rawDate));
                } catch (Exception e) {
                    row.workDate = rawDate;
                }
            }
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

    private static String formatAddressForPdf(String addr) {
        if (String.isBlank(addr)) {
            return '';
        }
        // If the address already has newlines, just convert to <br/>
        if (addr.contains('\n')) {
            return addr.replace('\n', '<br/>');
        }
        // Single-line comma-separated: split on commas, but keep city/state/zip together.
        // Pattern: "Street, City, ST ZIP" → "Street<br/>City, ST ZIP"
        // Only break on the FIRST comma to preserve "City, ST ZIP" grouping.
        Integer firstComma = addr.indexOf(',');
        if (firstComma > 0) {
            return addr.substring(0, firstComma).trim() + '<br/>' + addr.substring(firstComma + 1).trim();
        }
        return addr;
    }

    private static String formatDate(Date d) {
        if (d == null) {
            return '';
        }
        // Returns "Mar 1, 2026" style
        Datetime dt = Datetime.newInstance(d, Time.newInstance(0, 0, 0, 0));
        return dt.format('MMM d, yyyy');
    }
}

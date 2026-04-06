/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Document creation and snapshot logic for DeliveryDocument__c records.
 *               Extracted from DeliveryDocumentController to reduce class size.
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.ApexCRUDViolation, PMD.CyclomaticComplexity, PMD.StdCyclomaticComplexity, PMD.ExcessiveClassLength, PMD.ExcessiveParameterList, PMD.ApexDoc')
public with sharing class DeliveryDocGenerationService {

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
    public static Id generateDocument(Id entityId, String templateType, Date periodStart, Date periodEnd, String metadata) {
        if (entityId == null && templateType != 'Security_Audit') {
            throw new AuraHandledException('Please select a client before generating a document.');
        }

        Map<String, Object> snapshot;
        if (entityId == null) {
            // Org-wide report — use metadata as the snapshot payload
            snapshot = String.isNotBlank(metadata)
                ? (Map<String, Object>) JSON.deserializeUntyped(metadata)
                : new Map<String, Object>();
        } else {
            snapshot = buildSnapshot(entityId, templateType, periodStart, periodEnd);
        }

        String publicToken = generateToken();
        Decimal currentCharges = calculateTotalCost(snapshot);

        // Auto-calculate prior balance for invoices: sum of all unpaid invoices for this entity
        Decimal priorBalance = 0;
        if (templateType == 'Invoice' && entityId != null) {
            priorBalance = DeliveryDocPaymentService.calculatePriorBalance(entityId, periodStart);
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
            metaMap.put('unpaidInvoices', DeliveryDocPaymentService.buildUnpaidInvoicesSummary(entityId));
        }

        // Inject default agreement clauses if none provided
        if ((templateType == 'Client_Agreement' || templateType == 'Contractor_Agreement')
            && !metaMap.containsKey('clauses')) {
            metaMap.put('clauses', buildDefaultAgreementClauses(templateType, snapshot));
        }

        // ── Versioning: supersede existing document for same entity+period+template ──
        Integer nextVersion = 1;
        Id previousVersionId = null;
        String versionQuery = 'SELECT Id, VersionNumber__c FROM DeliveryDocument__c'
            + ' WHERE TemplatePk__c = :templateType'
            + ' AND PeriodStartDate__c = :periodStart'
            + ' AND PeriodEndDate__c = :periodEnd'
            + ' AND StatusPk__c != \'Superseded\''
            + (entityId != null ? ' AND NetworkEntityId__c = :entityId' : ' AND NetworkEntityId__c = NULL')
            + ' ORDER BY VersionNumber__c DESC LIMIT 1';
        List<DeliveryDocument__c> existing = Database.queryWithBinds(
            versionQuery,
            new Map<String, Object>{ 'templateType' => templateType, 'periodStart' => periodStart, 'periodEnd' => periodEnd, 'entityId' => entityId },
            AccessLevel.SYSTEM_MODE
        );
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

    // ═══════════════════════════════════════════════════════════
    //  SNAPSHOT BUILDER
    // ═══════════════════════════════════════════════════════════

    /** @description Builds a frozen JSON snapshot of entity, work item, and work log data for the given period. */
    @TestVisible
    public static Map<String, Object> buildSnapshot(Id entityId, String templateType, Date periodStart, Date periodEnd) {
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
                   DeveloperLookupId__c, DeveloperLookupId__r.Name, DeveloperLookupId__r.Title
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
    //  SERIALIZERS
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
            m.put('developerName', wi.DeveloperLookupId__r != null ? wi.DeveloperLookupId__r.Name : null);
            m.put('developerTitle', wi.DeveloperLookupId__r != null ? wi.DeveloperLookupId__r.Title : null);
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
    //  CALCULATIONS
    // ═══════════════════════════════════════════════════════════

    /** @description Calculates total hours from work log entries in the snapshot. */
    public static Decimal calculateTotalHours(Map<String, Object> snapshot) {
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

    /** @description Calculates total cost by multiplying hours by applicable rates from the snapshot. */
    public static Decimal calculateTotalCost(Map<String, Object> snapshot) {
        // Build a rate map: workItemId -> rate (from request, then item, then entity default)
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

        // Sum: hours x rate per log entry
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
    //  UTILITIES
    // ═══════════════════════════════════════════════════════════

    /** @description Generates a cryptographically random hex token for public document access. */
    public static String generateToken() {
        Blob randomBytes = Crypto.generateAesKey(256);
        return EncodingUtil.convertToHex(randomBytes);
    }

    /** @description Builds default legal clauses for agreement-type documents based on entity and template. */
    @TestVisible
    public static List<Map<String, String>> buildDefaultAgreementClauses(String templateType, Map<String, Object> snapshot) {
        Map<String, Object> entity = (Map<String, Object>) snapshot.get('entity');
        String clientName = entity != null && entity.get('name') != null ? (String) entity.get('name') : '[Client Name]';
        Decimal rate = entity != null && entity.get('defaultRate') != null ? (Decimal) entity.get('defaultRate') : 0;
        String vendorName = DeliveryDocEmailService.resolveVendorName();
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
}

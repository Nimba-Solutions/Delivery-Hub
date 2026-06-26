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

        // Inject default agreement clauses if none provided. The clause set
        // varies by compensation model (Hourly / Retainer / Fixed_Bid) read
        // from the caller's metadata; commercial numbers (retainer/fixed-bid
        // amounts) flow through the same metadata and fall back to neutral
        // placeholders when not yet finalized.
        if ((templateType == 'Client_Agreement' || templateType == 'Contractor_Agreement')
            && !metaMap.containsKey('clauses')) {
            metaMap.put('clauses', buildDefaultAgreementClauses(templateType, snapshot, metaMap));
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

        // Bound the snapshot to the SnapshotTxt__c field cap (131,072) BEFORE we
        // hash + persist. On long-lived entities the serialized snapshot can
        // exceed the field length and hard-fail the insert with STRING_TOO_LONG;
        // this trims display-only text (never hours/rates) to fit, or fails loud
        // with diagnostics if it still cannot. Must run before the hash so the
        // stored JSON and the tamper-evidence hash describe the same bytes.
        boundSnapshotToFieldCap(snapshot, templateType);

        // Phase 4: anchor the tamper-evidence chain. The document hash is a
        // SHA-256 over the frozen snapshot JSON; any later mutation of the
        // snapshot would change the hash and break the chain that signers
        // attest to. Computed once at generation time and never updated.
        String snapshotJson = JSON.serialize(snapshot);
        String documentHash = DeliveryCryptoService.computeSHA256(snapshotJson);

        DeliveryDocument__c doc = new DeliveryDocument__c(
            NetworkEntityId__c          = entityId,
            TemplatePk__c               = templateType,
            PeriodStartDate__c          = periodStart,
            PeriodEndDate__c            = periodEnd,
            StatusPk__c                 = 'Draft',
            PublicTokenTxt__c           = publicToken,
            SnapshotTxt__c              = snapshotJson,
            TotalHoursNumber__c         = calculateTotalHours(snapshot),
            TotalCurrency__c            = currentCharges,
            TermsTxt__c                 = 'Net 30',
            MetadataTxt__c              = JSON.serialize(metaMap),
            VersionNumber__c            = nextVersion,
            PreviousVersionLookup__c        = previousVersionId,
            RequireSigningDateTime__c  = DeliveryDocActionService.templateSigningRequiredAt(templateType),
            DocumentHashTxt__c          = documentHash
        );

        Database.insert(doc, AccessLevel.SYSTEM_MODE);

        // Defensive: confirm SnapshotTxt__c actually persisted. We've seen it
        // silently null-strip on insert (likely FLS even with SYSTEM_MODE in
        // some user contexts) — better to fail loudly here than ship a doc
        // that quietly corrupts the supersede chain. PR #680 added a read-time
        // live-rebuild as defense-in-depth; this is the write-time guard.
        DeliveryDocument__c persisted = [
            SELECT SnapshotTxt__c
            FROM DeliveryDocument__c
            WHERE Id = :doc.Id
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        if (String.isBlank(persisted.SnapshotTxt__c)) {
            throw new AuraHandledException(
                'Document generated but snapshot did not persist (likely FLS write-strip). ' +
                'Generation aborted to prevent corruption. Contact Admin to verify SnapshotTxt__c FLS for the running user.'
            );
        }

        // Create signature slots for templates that require signing.
        // No-op for templates without DocumentTemplateSlot__mdt records configured.
        DeliveryDocActionService.createSlotsForTemplate(doc.Id, templateType, snapshot);

        // Publish platform event for external subscribers
        Map<String, Object> entityMap = (Map<String, Object>) snapshot.get('entity');
        String entityName = entityMap != null ? (String) entityMap.get('name') : '';
        EventBus.publish(new DeliveryDocEvent__e(
            DocumentIdTxt__c = doc.Id,
            TemplateTxt__c   = templateType,
            StatusTxt__c     = 'Draft',
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

        // Issuer (vendor/self) info — frozen into the snapshot so the public
        // renderer can show the org's own brand on the document instead of any
        // hardcoded fallback in the static resource.
        snapshot.put('issuer', buildIssuerSnapshot());

        // Work items linked to this entity
        List<WorkItem__c> items = [
            SELECT Id, Name, BriefDescriptionTxt__c, StageNamePk__c, PriorityPk__c,
                   EstimatedHoursNumber__c, TotalLoggedHoursSum__c,
                   BillableRateCurrency__c, BudgetVarianceNumber__c,
                   ClientNetworkEntityLookup__c, WorkflowTypeTxt__c,
                   DeveloperLookup__c, DeveloperLookup__r.Name, DeveloperLookup__r.Title
            FROM WorkItem__c
            WHERE ClientNetworkEntityLookup__c = :entityId
            WITH SYSTEM_MODE
            ORDER BY Name
        ];
        snapshot.put('workItems', serializeWorkItems(items, templateType));

        // Work logs within the period for these items
        Set<Id> itemIds = new Map<Id, WorkItem__c>(items).keySet();
        List<WorkLog__c> logs;
        if (templateType == 'Invoice' || templateType == 'Daily_Hours_Summary') {
            logs = [
                SELECT Id, Name, WorkItemLookup__c, WorkItemLookup__r.Name,
                       HoursLoggedNumber__c, WorkDateDate__c, WorkDescriptionTxt__c,
                       ResourceTitleTxt__c
                FROM WorkLog__c
                WHERE WorkItemLookup__c IN :itemIds
                AND WorkDateDate__c >= :periodStart
                AND WorkDateDate__c <= :periodEnd
                AND (StatusPk__c = 'Approved' OR StatusPk__c = null)
                WITH SYSTEM_MODE
                ORDER BY WorkDateDate__c ASC
            ];
        } else {
            logs = [
                SELECT Id, Name, WorkItemLookup__c, WorkItemLookup__r.Name,
                       HoursLoggedNumber__c, WorkDateDate__c, WorkDescriptionTxt__c,
                       ResourceTitleTxt__c
                FROM WorkLog__c
                WHERE WorkItemLookup__c IN :itemIds
                AND WorkDateDate__c >= :periodStart
                AND WorkDateDate__c <= :periodEnd
                WITH SYSTEM_MODE
                ORDER BY WorkDateDate__c ASC
            ];
        }
        snapshot.put('workLogs', serializeWorkLogs(logs));

        // F13: period-scope the WORK ITEMS section for money templates. The
        // workItems query above is entity-wide, so each item carries its ALL-TIME
        // TotalLoggedHoursSum__c — which over-states a period invoice (e.g. 108h
        // all-time displayed as line items against a 60h period total, so the
        // line items don't reconcile to the bill). Rewrite each item's displayed
        // hours to its in-period billable sum and drop items with no period
        // activity. The dollar figures are computed downstream as hours x rate,
        // so correcting the hours corrects the line-item dollars too. This is
        // display-only: calculateTotalHours sums workLogs and calculateTotalCost
        // reads only the rate from workItems, so the (already-correct) totals are
        // unchanged — the fix purely makes the line items tie out to the total.
        if (templateType == 'Invoice' || templateType == 'Daily_Hours_Summary') {
            Map<Id, Decimal> periodHoursByWi = new Map<Id, Decimal>();
            for (WorkLog__c wl : logs) {
                if (wl.WorkItemLookup__c != null && wl.HoursLoggedNumber__c != null) {
                    Decimal acc = periodHoursByWi.containsKey(wl.WorkItemLookup__c)
                        ? periodHoursByWi.get(wl.WorkItemLookup__c) : 0;
                    periodHoursByWi.put(wl.WorkItemLookup__c, acc + wl.HoursLoggedNumber__c);
                }
            }
            List<Map<String, Object>> scopedItems = new List<Map<String, Object>>();
            for (Object itemObj : (List<Object>) snapshot.get('workItems')) {
                Map<String, Object> m = (Map<String, Object>) itemObj;
                Id wiId = (Id) m.get('id');
                Decimal periodHours = periodHoursByWi.containsKey(wiId) ? periodHoursByWi.get(wiId) : 0;
                if (periodHours <= 0) {
                    // No billable hours in this period — omit from the invoice line items.
                    continue;
                }
                m.put('totalLoggedHours', periodHours);
                scopedItems.add(m);
            }
            snapshot.put('workItems', scopedItems);
        }

        // Work requests (for rates and status). Scope to the work items that
        // actually carry logged time in the period for money/hours templates.
        // Previously this pulled EVERY WorkRequest ever linked to the entity (no
        // period, no hours filter); on long-lived entities with hundreds of
        // historical WorkRequests the serialized snapshot overflowed the
        // SnapshotTxt__c field cap (131,072) and hard-failed the insert with
        // STRING_TOO_LONG. Rate resolution in calculateTotalCost only consults
        // WorkRequests for items with billed logs, so for an Invoice this
        // narrowing is loss-free for the total. Non-money templates keep the
        // full set (the snapshot size guard below is the universal backstop).
        Set<Id> requestScopeIds = itemIds;
        if (templateType == 'Invoice' || templateType == 'Daily_Hours_Summary') {
            Set<Id> billedItemIds = new Set<Id>();
            for (WorkLog__c wl : logs) {
                if (wl.WorkItemLookup__c != null) {
                    billedItemIds.add(wl.WorkItemLookup__c);
                }
            }
            requestScopeIds = billedItemIds;
        }
        List<WorkRequest__c> requests = [
            SELECT Id, WorkItemId__c, WorkItemId__r.Name, StatusPk__c,
                   HourlyRateCurrency__c, QuotedHoursNumber__c,
                   PreApprovedHoursNumber__c, TotalLoggedHoursSum__c,
                   BudgetUtilizationPct__c, DeliveryEntityLookup__c,
                   DeliveryEntityLookup__r.Name
            FROM WorkRequest__c
            WHERE WorkItemId__c IN :requestScopeIds
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

    /**
     * @description Builds the issuer (vendor/self) block included in document
     * snapshots so the public renderer can show the customer's own brand on
     * generated documents instead of any package-level fallback.
     * @return Map with name/url/address/email/phone for the first Vendor or Both NetworkEntity.
     */
    private static Map<String, Object> buildIssuerSnapshot() {
        Map<String, Object> issuer = new Map<String, Object>();
        // Default fallback if no Vendor entity has been configured.
        // TODO: surface a dedicated DeliveryHubSettings__c branding block so
        // admins can override the issuer name/url without creating a Vendor.
        issuer.put('name', 'Your Organization');
        issuer.put('url', '');
        issuer.put('address', '');
        issuer.put('email', '');
        issuer.put('phone', '');

        List<NetworkEntity__c> vendors = [
            SELECT Name, AddressTxt__c, ContactEmailTxt__c, ContactPhoneTxt__c, IntegrationEndpointUrlTxt__c
            FROM NetworkEntity__c
            WHERE EntityTypePk__c IN ('Vendor', 'Both')
            WITH SYSTEM_MODE
            ORDER BY CreatedDate ASC
            LIMIT 1
        ];
        if (!vendors.isEmpty()) {
            NetworkEntity__c v = vendors[0];
            if (String.isNotBlank(v.Name)) {
                issuer.put('name', v.Name);
            }
            if (String.isNotBlank(v.AddressTxt__c)) {
                issuer.put('address', v.AddressTxt__c);
            }
            if (String.isNotBlank(v.ContactEmailTxt__c)) {
                issuer.put('email', v.ContactEmailTxt__c);
            }
            if (String.isNotBlank(v.ContactPhoneTxt__c)) {
                issuer.put('phone', v.ContactPhoneTxt__c);
            }
        }
        return issuer;
    }

    private static List<Map<String, Object>> serializeWorkItems(List<WorkItem__c> items, String templateType) {
        List<Map<String, Object>> result = new List<Map<String, Object>>();
        for (WorkItem__c wi : items) {
            // Skip work items with zero hours only for invoices (billable items only);
            // agreements and status reports should include all work items
            if (templateType == 'Invoice'
                && (wi.TotalLoggedHoursSum__c == null || wi.TotalLoggedHoursSum__c <= 0)) {
                continue;
            }
            Map<String, Object> m = new Map<String, Object>();
            m.put('id', wi.Id);
            m.put('name', wi.Name);
            m.put('description', wi.BriefDescriptionTxt__c);
            m.put('stage', wi.StageNamePk__c);
            m.put('priority', wi.PriorityPk__c);
            m.put('estimatedHours', wi.EstimatedHoursNumber__c);
            m.put('totalLoggedHours', wi.TotalLoggedHoursSum__c);
            m.put('billableRate', wi.BillableRateCurrency__c);
            m.put('budgetVariance', wi.BudgetVarianceNumber__c);
            m.put('workflowType', wi.WorkflowTypeTxt__c);
            m.put('developerName', wi.DeveloperLookup__r != null ? wi.DeveloperLookup__r.Name : null);
            m.put('developerTitle', wi.DeveloperLookup__r != null ? wi.DeveloperLookup__r.Title : null);
            result.add(m);
        }
        return result;
    }

    private static List<Map<String, Object>> serializeWorkLogs(List<WorkLog__c> logs) {
        List<Map<String, Object>> result = new List<Map<String, Object>>();
        for (WorkLog__c wl : logs) {
            Map<String, Object> m = new Map<String, Object>();
            m.put('id', wl.Id);
            m.put('workItemId', wl.WorkItemLookup__c);
            m.put('workItemName', wl.WorkItemLookup__r.Name);
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
            m.put('totalLoggedHours', wr.TotalLoggedHoursSum__c);
            m.put('budgetUtilization', wr.BudgetUtilizationPct__c);
            m.put('vendorEntityId', wr.DeliveryEntityLookup__c);
            m.put('vendorEntityName', wr.DeliveryEntityLookup__r.Name);
            result.add(m);
        }
        return result;
    }

    // ═══════════════════════════════════════════════════════════
    //  SNAPSHOT SIZE GUARD
    // ═══════════════════════════════════════════════════════════

    // SnapshotTxt__c is a LongTextArea capped at 131,072 chars. The serialized
    // snapshot is written there verbatim AND hashed for tamper-evidence, so it
    // must fit. SOFT_LIMIT leaves headroom so we trim proactively rather than
    // waiting until we're flush against the hard cap.
    @TestVisible
    private static final Integer SNAPSHOT_FIELD_CAP = 131072;
    @TestVisible
    private static final Integer SNAPSHOT_SOFT_LIMIT = 120000;

    /**
     * @description Ensures the serialized snapshot fits inside SnapshotTxt__c.
     *              Billing-safe: only display-only free text (work log / work
     *              item descriptions) is trimmed — the hours and rates that
     *              drive the invoice total are never altered. If the snapshot
     *              still exceeds the hard field cap after trimming, throws a
     *              diagnostic AuraHandledException instead of letting the
     *              platform raise an opaque STRING_TOO_LONG mid-insert (which
     *              rolls the whole generation back with no actionable cause).
     * @param snapshot The snapshot map, mutated in place to fit.
     * @param templateType Template DeveloperName (recorded in the diagnostic).
     */
    @TestVisible
    private static void boundSnapshotToFieldCap(Map<String, Object> snapshot, String templateType) {
        if (snapshot == null || JSON.serialize(snapshot).length() <= SNAPSHOT_SOFT_LIMIT) {
            return;
        }

        // Step 1 — drop display-only descriptions. These do not feed
        // calculateTotalHours / calculateTotalCost, so the dollar total is
        // unaffected; only the human-readable line text is lost, and we flag it.
        nullOutField(snapshot, 'workLogs', 'description');
        nullOutField(snapshot, 'workItems', 'description');
        snapshot.put('snapshotTrimmed', true);

        if (JSON.serialize(snapshot).length() <= SNAPSHOT_FIELD_CAP) {
            return;
        }

        // Step 2 — still over the hard cap. Fail loud + diagnostic rather than
        // ship a silently corrupt document or throw an opaque STRING_TOO_LONG.
        throw new AuraHandledException(
            'Document data snapshot exceeds the ' + SNAPSHOT_FIELD_CAP + '-char storage limit even after '
            + 'trimming display text (workItems=' + sectionSize(snapshot, 'workItems')
            + ', workLogs=' + sectionSize(snapshot, 'workLogs')
            + ', workRequests=' + sectionSize(snapshot, 'workRequests')
            + ', template=' + templateType + '). Narrow the billing period or split the document into '
            + 'multiple periods. No document was created.'
        );
    }

    /** @description Nulls a field on every map in a snapshot list section (no-op if absent). */
    private static void nullOutField(Map<String, Object> snapshot, String sectionKey, String fieldKey) {
        List<Object> section = (List<Object>) snapshot.get(sectionKey);
        if (section == null) {
            return;
        }
        for (Object o : section) {
            Map<String, Object> row = (Map<String, Object>) o;
            if (row.containsKey(fieldKey)) {
                row.put(fieldKey, null);
            }
        }
    }

    /** @description Row count of a snapshot list section (0 when absent). */
    private static Integer sectionSize(Map<String, Object> snapshot, String sectionKey) {
        List<Object> section = (List<Object>) snapshot.get(sectionKey);
        return section == null ? 0 : section.size();
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

    /**
     * @description Backwards-compatible overload. Builds default legal clauses
     *              with the Hourly compensation model (preserves the historical
     *              behavior for any caller that does not pass a metadata map).
     * @param templateType Client_Agreement or Contractor_Agreement.
     * @param snapshot The frozen document snapshot.
     * @return The ordered list of default clauses (Hourly compensation).
     */
    @TestVisible
    public static List<Map<String, String>> buildDefaultAgreementClauses(String templateType, Map<String, Object> snapshot) {
        return buildDefaultAgreementClauses(templateType, snapshot, new Map<String, Object>());
    }

    /**
     * @description Builds default legal clauses for agreement-type documents
     *              based on entity, template, and the compensation model read
     *              from the document metadata. Only the Compensation clause (and,
     *              for Fixed_Bid, an added Payment Milestones clause) varies by
     *              model — Scope, Confidentiality, IP, Liability, etc. are
     *              identical across models. Commercial numbers are optional and
     *              render as neutral placeholders when not supplied.
     * @param templateType Client_Agreement or Contractor_Agreement.
     * @param snapshot The frozen document snapshot (entity name, default rate).
     * @param metaMap The document metadata map. Recognized keys:
     *               compensationModel (Hourly|Retainer|Fixed_Bid),
     *               retainerAmount, retainerHours, billingFrequency,
     *               fixedBidAmount, milestones.
     * @return The ordered list of default clauses for the resolved model.
     */
    @TestVisible
    public static List<Map<String, String>> buildDefaultAgreementClauses(
        String templateType, Map<String, Object> snapshot, Map<String, Object> metaMap
    ) {
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

        String compModel = resolveCompensationModel(metaMap);

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

        // Compensation clause varies by model (Hourly / Retainer / Fixed_Bid).
        clauses.add(buildCompensationClause(compModel, partyARole, partyBRole, formattedRate, metaMap));

        // Fixed_Bid adds a dedicated Payment Milestones clause (50% on
        // commencement / 50% on completion) alongside the compensation terms.
        if (compModel == 'Fixed_Bid') {
            clauses.add(buildPaymentMilestonesClause(partyARole, partyBRole, metaMap));
        }

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

    // ═══════════════════════════════════════════════════════════
    //  COMPENSATION MODELS
    // ═══════════════════════════════════════════════════════════

    /**
     * @description Normalizes the compensation model from metadata. Recognized
     *              values are Hourly (default), Retainer, and Fixed_Bid. Any
     *              absent / blank / unrecognized value resolves to Hourly so
     *              the historical behavior is preserved exactly.
     * @param metaMap The document metadata map (may be null).
     * @return One of 'Hourly', 'Retainer', 'Fixed_Bid'.
     */
    @TestVisible
    private static String resolveCompensationModel(Map<String, Object> metaMap) {
        if (metaMap == null || metaMap.get('compensationModel') == null) {
            return 'Hourly';
        }
        String model = String.valueOf(metaMap.get('compensationModel')).trim();
        if (model == 'Retainer' || model == 'Fixed_Bid') {
            return model;
        }
        return 'Hourly';
    }

    /**
     * @description Builds the Compensation clause for the resolved model. Hourly
     *              is byte-for-byte the historical clause. Retainer and Fixed_Bid
     *              swap in model-appropriate language; commercial numbers are read
     *              from metadata and fall back to neutral bracketed placeholders
     *              when not finalized so the clause always renders sensibly.
     * @param compModel Resolved model ('Hourly'|'Retainer'|'Fixed_Bid').
     * @param partyARole The paying-to party role label (e.g. 'Consultant').
     * @param partyBRole The paying party role label (e.g. 'Client').
     * @param formattedRate The formatted hourly rate (used by Hourly).
     * @param metaMap The document metadata map.
     * @return A single clause map (title + body).
     */
    @TestVisible
    private static Map<String, String> buildCompensationClause(
        String compModel, String partyARole, String partyBRole, String formattedRate, Map<String, Object> metaMap
    ) {
        if (compModel == 'Retainer') {
            return buildRetainerClause(partyARole, partyBRole, metaMap);
        }
        if (compModel == 'Fixed_Bid') {
            return buildFixedBidClause(partyARole, partyBRole, metaMap);
        }
        return buildHourlyClause(partyARole, partyBRole, formattedRate);
    }

    /** @description Historical hourly time-and-materials Compensation clause (unchanged). */
    private static Map<String, String> buildHourlyClause(String partyARole, String partyBRole, String formattedRate) {
        Map<String, String> c = new Map<String, String>();
        c.put('title', 'Compensation');
        c.put('body', partyBRole + ' agrees to pay ' + partyARole + ' at a rate of ' + formattedRate
            + ' per hour for all services rendered. Invoices are issued monthly and are payable within '
            + 'thirty (30) days of receipt. Late payments are subject to a finance charge of three percent '
            + '(3%) per month on outstanding balances. All work hours are tracked and documented in the '
            + 'Delivery Hub platform and are available for review at any time.');
        return c;
    }

    /**
     * @description Recurring monthly retainer Compensation clause: a fixed
     *              monthly amount is drawn down by tracked work; surplus/deficit
     *              carries forward month to month; overages beyond the retainer
     *              require written pre-approval before work proceeds.
     */
    private static Map<String, String> buildRetainerClause(String partyARole, String partyBRole, Map<String, Object> metaMap) {
        String amount = metaValue(metaMap, 'retainerAmount', '[Monthly Retainer Amount]');
        String hoursPhrase = metaHasValue(metaMap, 'retainerHours')
            ? ' (representing approximately ' + metaValue(metaMap, 'retainerHours', '') + ' hours of service per period)'
            : '';
        String frequency = metaValue(metaMap, 'billingFrequency', 'monthly');

        Map<String, String> c = new Map<String, String>();
        c.put('title', 'Compensation');
        c.put('body', partyBRole + ' agrees to engage ' + partyARole + ' on a recurring retainer basis '
            + 'at a rate of ' + amount + ' per ' + frequency + ' period' + hoursPhrase + '. The retainer is '
            + 'billed in advance and is payable within thirty (30) days of the invoice date. All services '
            + 'rendered are tracked and documented in the Delivery Hub platform and draw down against the '
            + 'retainer for the applicable period. Any unused retainer balance or any deficit at the close '
            + 'of a period carries forward and is reconciled against the following period, so that the '
            + partyBRole + ' is charged only for the net value of services delivered over time. Should the '
            + 'scope of services in any period be expected to exceed the retainer, ' + partyARole + ' shall '
            + 'notify ' + partyBRole + ' and obtain written pre-approval before performing work beyond the '
            + 'retainer; no overage work proceeds without such approval. Late payments are subject to a '
            + 'finance charge of three percent (3%) per month on outstanding balances.');
        return c;
    }

    /**
     * @description Fixed-price scope Compensation clause: a fixed total fee billed
     *              50% on commencement and 50% on completion/acceptance, capable of
     *              running alongside any retainer arrangement. The milestone
     *              mechanics live in the separate Payment Milestones clause.
     */
    private static Map<String, String> buildFixedBidClause(String partyARole, String partyBRole, Map<String, Object> metaMap) {
        String amount = metaValue(metaMap, 'fixedBidAmount', '[Fixed Bid Amount]');

        Map<String, String> c = new Map<String, String>();
        c.put('title', 'Compensation');
        c.put('body', partyBRole + ' agrees to pay ' + partyARole + ' a fixed fee of ' + amount + ' for the '
            + 'defined scope of services, inclusive of all labor required to deliver the agreed scope. The '
            + 'fixed fee is billed in two equal installments of fifty percent (50%) each, as set out in the '
            + 'Payment Milestones clause below. This fixed-price arrangement applies to the defined scope '
            + 'only and may run alongside any concurrent retainer or hourly engagement, which is billed '
            + 'separately under its own terms. Work performed outside the defined scope requires a separate '
            + 'written agreement or change order before it proceeds. All deliverables are tracked and '
            + 'documented in the Delivery Hub platform. Each installment invoice is payable within thirty '
            + '(30) days of receipt, and late payments are subject to a finance charge of three percent '
            + '(3%) per month on outstanding balances.');
        return c;
    }

    /**
     * @description Dedicated Payment Milestones clause for the Fixed_Bid model:
     *              50% due on commencement, 50% due on completion and acceptance.
     *              Optional milestone detail from metadata is appended verbatim.
     */
    private static Map<String, String> buildPaymentMilestonesClause(String partyARole, String partyBRole, Map<String, Object> metaMap) {
        String amount = metaValue(metaMap, 'fixedBidAmount', '[Fixed Bid Amount]');
        String detail = metaHasValue(metaMap, 'milestones')
            ? ' Additional milestone schedule: ' + metaValue(metaMap, 'milestones', '') + '.'
            : '';

        Map<String, String> c = new Map<String, String>();
        c.put('title', 'Payment Milestones');
        c.put('body', 'The fixed fee of ' + amount + ' is invoiced against the following milestones: '
            + 'fifty percent (50%) is due upon commencement of the engagement, invoiced at kickoff; and the '
            + 'remaining fifty percent (50%) is due upon completion and ' + partyBRole + ' acceptance of the '
            + 'agreed deliverables. ' + partyARole + ' shall notify ' + partyBRole + ' when the deliverables '
            + 'are ready for acceptance, and ' + partyBRole + ' shall review and either accept or provide '
            + 'specific written objections within ten (10) business days; absent such objections, the '
            + 'deliverables are deemed accepted and the final installment becomes due. Each milestone '
            + 'invoice is payable within thirty (30) days of receipt.' + detail);
        return c;
    }

    /**
     * @description Reads a metadata value as a trimmed String, returning the
     *              supplied fallback when the key is absent or blank.
     * @param metaMap The metadata map (may be null).
     * @param key The metadata key.
     * @param fallback The neutral placeholder to use when no value is present.
     * @return The metadata value or the fallback.
     */
    private static String metaValue(Map<String, Object> metaMap, String key, String fallback) {
        if (metaMap == null || metaMap.get(key) == null) {
            return fallback;
        }
        String value = String.valueOf(metaMap.get(key)).trim();
        return String.isBlank(value) ? fallback : value;
    }

    /** @description True when metadata carries a non-blank value for the given key. */
    private static Boolean metaHasValue(Map<String, Object> metaMap, String key) {
        if (metaMap == null || metaMap.get(key) == null) {
            return false;
        }
        return String.isNotBlank(String.valueOf(metaMap.get(key)).trim());
    }
}

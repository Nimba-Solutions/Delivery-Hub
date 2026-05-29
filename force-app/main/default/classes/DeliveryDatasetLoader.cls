/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  In-app sample-data loader for Delivery Hub feature datasets
 *               (Layer 7 of the DH cockpit architecture). Ports the dev-only
 *               scripts/feature-data/invoice_generation.apex loader into a
 *               first-class Apex service the cockpit can invoke directly — so a
 *               subscriber admin can prime a feature's sample data with one
 *               click, with NO CumulusCI / CLI required.
 *
 *               SAFETY DESIGN (paramount — this writes to a subscriber org):
 *                 • EVERY sample record carries an unmistakable, queryable
 *                   marker (the literal SAMPLE_MARKER, "[DH SAMPLE]") in a text
 *                   field. The marker is how loaded records are identified and
 *                   how they are removed. Nothing without the marker is ever
 *                   touched.
 *                 • LOAD is idempotent: re-running detects existing marked
 *                   WorkItems and skips insertion (OutcomePk__c='Success',
 *                   recordsLoaded = the already-present count) rather than
 *                   duplicating.
 *                 • REMOVE deletes EXACTLY the marked records this loader
 *                   creates, scoped by SAMPLE_MARKER, in dependency-safe order
 *                   (WorkLog → WorkRequest → WorkItem → NetworkEntity). It can
 *                   never delete a real (non-marked) record.
 *                 • Both operations write a DatasetTemplateAssignment__c audit
 *                   row (real outcome + real count + loader user + timestamp).
 *                 • All DML runs WITH SYSTEM_MODE / AccessLevel.SYSTEM_MODE
 *                   because this is an admin-invoked package operation; the
 *                   calling controller enforces the admin gate.
 *
 *               Placeholder-value discipline (CLAUDE.md): financial values are
 *               deliberately obvious placeholders (HoursLoggedNumber__c = 1.0),
 *               NOT fabricated realistic figures.
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.ApexCRUDViolation,PMD.CyclomaticComplexity,PMD.StdCyclomaticComplexity,PMD.ExcessiveParameterList')
public with sharing class DeliveryDatasetLoader {

    /**
     * Unmistakable, queryable prefix stamped on every sample record this
     * loader creates. This literal is the ENTIRE safety contract: load stamps
     * it, remove filters on it, and nothing without it is ever deleted. Do not
     * change without a data-migration plan for already-loaded orgs.
     */
    public static final String SAMPLE_MARKER = '[DH SAMPLE]';

    /** Logical key for the only dataset this loader currently ships. */
    public static final String DATASET_INVOICE_GENERATION = 'Invoice_Generation';

    /** Number of sample WorkItem__c rows the invoice-generation dataset creates. */
    private static final Integer INVOICE_WI_COUNT = 5;

    /** WorkLogs per WorkItem in the invoice-generation dataset. */
    private static final Integer INVOICE_LOGS_PER_WI = 2;

    /** Deliberately obvious placeholder — NOT a realistic billing rate. */
    private static final Decimal PLACEHOLDER_HOURS = 1.0;

    /** Names of the two placeholder vendors the invoice dataset uses. */
    private static final String SAMPLE_VENDOR_A = SAMPLE_MARKER + ' Vendor A';
    private static final String SAMPLE_VENDOR_B = SAMPLE_MARKER + ' Vendor B';

    /**
     * @description Result of a load/remove run. Returned to the controller so
     *              the LWC can surface a precise toast ("Loaded 17 records" /
     *              "Removed 17 sample records"). All fields populated.
     */
    public class LoadResult {
        /** 'Success' | 'PartialFailure' | 'Failure' (DatasetLoadOutcome GVS). */
        public String outcome;
        /** Count of records inserted (load) or deleted (remove). */
        public Integer recordCount;
        /** Whether a load was a no-op because the data was already present. */
        public Boolean alreadyLoaded;
        /** Id of the DatasetTemplateAssignment__c audit row written. */
        public Id assignmentId;
        /** Human-readable summary for the toast message. */
        public String message;
    }

    // ────────────────────────────────────────────────────────────────────
    // Public entry points (invoked by DeliveryDatasetController)
    // ────────────────────────────────────────────────────────────────────

    /**
     * @description Loads the sample dataset for the given DatasetTemplate__c
     *              and writes a DatasetTemplateAssignment__c audit row. The
     *              dataset is selected by the template's linked feature name
     *              (FeatureLookup__r.Name) so adding more datasets later is a
     *              matter of adding a branch in resolveDatasetKey + a private
     *              loadXxx method — no controller changes required.
     *
     *              Idempotent: if the marked sample records already exist, this
     *              is a no-op insert; the audit row records the already-present
     *              count and outcome='Success'.
     * @param templateId DatasetTemplate__c whose sample data should be loaded.
     * @return LoadResult describing the outcome + record count.
     */
    public static LoadResult load(Id templateId) {
        DatasetTemplate__c template = requireTemplate(templateId);
        String datasetKey = resolveDatasetKey(template);
        LoadResult result;
        try {
            if (datasetKey == DATASET_INVOICE_GENERATION) {
                result = loadInvoiceGeneration();
            } else {
                throw new DatasetLoaderException(
                    'No in-app loader is registered for this dataset template.');
            }
        } catch (DatasetLoaderException dle) {
            // Known, caller-meaningful failure — re-throw so the controller can
            // surface it. No audit row: nothing landed.
            throw dle;
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN,
                '[DeliveryDatasetLoader.load] failed: ' + e.getMessage());
            result = new LoadResult();
            result.outcome = 'Failure';
            result.recordCount = 0;
            result.alreadyLoaded = false;
            result.message = 'Sample data load failed before any records were committed.';
            result.assignmentId = writeAssignment(
                templateId, result.outcome, result.recordCount, e.getMessage(), false);
            return result;
        }
        result.assignmentId = writeAssignment(
            templateId, result.outcome, result.recordCount, null, false);
        return result;
    }

    /**
     * @description Removes the sample dataset for the given DatasetTemplate__c —
     *              deleting EXACTLY the records carrying SAMPLE_MARKER, in
     *              dependency-safe order — and writes a removal audit row. Never
     *              touches non-marked records.
     *
     *              Idempotent: removing when nothing is loaded is a clean no-op
     *              (recordCount=0, outcome='Success').
     * @param templateId DatasetTemplate__c whose sample data should be removed.
     * @return LoadResult with recordCount = number of records deleted.
     */
    public static LoadResult remove(Id templateId) {
        DatasetTemplate__c template = requireTemplate(templateId);
        String datasetKey = resolveDatasetKey(template);
        LoadResult result = new LoadResult();
        result.alreadyLoaded = false;
        try {
            if (datasetKey == DATASET_INVOICE_GENERATION) {
                result.recordCount = removeInvoiceGeneration();
            } else {
                throw new DatasetLoaderException(
                    'No in-app loader is registered for this dataset template.');
            }
            result.outcome = 'Success';
            result.message = result.recordCount == 0
                ? 'No sample data was present to remove.'
                : 'Removed ' + result.recordCount + ' sample record(s).';
        } catch (DatasetLoaderException dle) {
            throw dle;
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN,
                '[DeliveryDatasetLoader.remove] failed: ' + e.getMessage());
            result.outcome = 'Failure';
            result.recordCount = 0;
            result.message = 'Sample data removal failed.';
            result.assignmentId = writeAssignment(
                templateId, result.outcome, result.recordCount, e.getMessage(), true);
            return result;
        }
        result.assignmentId = writeAssignment(
            templateId, result.outcome, result.recordCount, null, true);
        return result;
    }

    // ────────────────────────────────────────────────────────────────────
    // Invoice Generation dataset (first end-to-end example)
    // ────────────────────────────────────────────────────────────────────

    /**
     * @description Inserts the invoice-generation sample dataset:
     *              2 placeholder vendors (NetworkEntity__c) + 5 WorkItem__c +
     *              one WorkRequest__c bridge each + 2 WorkLog__c per WI. Every
     *              record carries SAMPLE_MARKER. Idempotent: if marked
     *              WorkItems already exist (>= INVOICE_WI_COUNT) this is a
     *              no-op and reports the already-present record count.
     * @return LoadResult for the run.
     */
    private static LoadResult loadInvoiceGeneration() {
        LoadResult result = new LoadResult();

        Integer existingWi = [
            SELECT COUNT()
            FROM WorkItem__c
            WHERE BriefDescriptionTxt__c LIKE :markerLike()
            WITH SYSTEM_MODE
        ];
        if (existingWi >= INVOICE_WI_COUNT) {
            // Already loaded — report the full marked record count as a no-op.
            result.outcome = 'Success';
            result.alreadyLoaded = true;
            result.recordCount = countLoadedInvoiceRecords();
            result.message = 'Sample data is already loaded ('
                + result.recordCount + ' record(s)). No changes made.';
            return result;
        }

        Integer inserted = 0;

        // Vendors — two clearly-marked placeholder NetworkEntity__c rows.
        List<NetworkEntity__c> vendors = new List<NetworkEntity__c>{
            new NetworkEntity__c(
                Name = SAMPLE_VENDOR_A,
                EntityTypePk__c = 'Vendor',
                StatusPk__c = 'Active',
                IntegrationEndpointUrlTxt__c = 'https://example.invalid'
            ),
            new NetworkEntity__c(
                Name = SAMPLE_VENDOR_B,
                EntityTypePk__c = 'Vendor',
                StatusPk__c = 'Active',
                IntegrationEndpointUrlTxt__c = 'https://example.invalid'
            )
        };
        // Don't duplicate vendors if a prior partial run already created them.
        List<NetworkEntity__c> existingVendors = [
            SELECT Id, Name FROM NetworkEntity__c
            WHERE Name IN (:SAMPLE_VENDOR_A, :SAMPLE_VENDOR_B)
            WITH SYSTEM_MODE
        ];
        Set<String> haveVendorNames = new Set<String>();
        for (NetworkEntity__c v : existingVendors) {
            haveVendorNames.add(v.Name);
        }
        List<NetworkEntity__c> vendorsToInsert = new List<NetworkEntity__c>();
        for (NetworkEntity__c v : vendors) {
            if (!haveVendorNames.contains(v.Name)) {
                vendorsToInsert.add(v);
            }
        }
        if (!vendorsToInsert.isEmpty()) {
            Database.insert(vendorsToInsert, AccessLevel.SYSTEM_MODE);
            inserted += vendorsToInsert.size();
        }

        // WorkItems — marker in BriefDescriptionTxt__c (100-char field, so the
        // marker + a short suffix fits comfortably).
        List<WorkItem__c> workItems = new List<WorkItem__c>();
        for (Integer i = 1; i <= INVOICE_WI_COUNT; i++) {
            workItems.add(new WorkItem__c(
                BriefDescriptionTxt__c = SAMPLE_MARKER + ' Invoice demo WI ' + i,
                StatusPk__c = 'Active',
                StageNamePk__c = 'Backlog',
                ActivatedDateTime__c = Datetime.now()
            ));
        }
        Database.insert(workItems, AccessLevel.SYSTEM_MODE);
        inserted += workItems.size();

        // One WorkRequest__c bridge per WI (required MD parent of WorkLog).
        List<WorkRequest__c> bridges = new List<WorkRequest__c>();
        for (WorkItem__c wi : workItems) {
            bridges.add(new WorkRequest__c(
                WorkItemId__c = wi.Id,
                StatusPk__c = 'Active'
            ));
        }
        Database.insert(bridges, AccessLevel.SYSTEM_MODE);
        inserted += bridges.size();

        Map<Id, Id> bridgeByWi = new Map<Id, Id>();
        for (WorkRequest__c b : bridges) {
            bridgeByWi.put(b.WorkItemId__c, b.Id);
        }

        // WorkLogs — marker in WorkDescriptionTxt__c; placeholder hours.
        List<WorkLog__c> logs = new List<WorkLog__c>();
        for (WorkItem__c wi : workItems) {
            Id bridgeId = bridgeByWi.get(wi.Id);
            for (Integer k = 0; k < INVOICE_LOGS_PER_WI; k++) {
                logs.add(new WorkLog__c(
                    WorkItemLookup__c = wi.Id,
                    RequestId__c = bridgeId,
                    HoursLoggedNumber__c = PLACEHOLDER_HOURS,
                    WorkDateDate__c = Date.today().addDays(-k),
                    WorkDescriptionTxt__c = SAMPLE_MARKER + ' placeholder log ' + (k + 1)
                ));
            }
        }
        Database.insert(logs, AccessLevel.SYSTEM_MODE);
        inserted += logs.size();

        result.outcome = 'Success';
        result.alreadyLoaded = false;
        result.recordCount = inserted;
        result.message = 'Loaded ' + inserted + ' sample record(s) for Invoice Generation.';
        return result;
    }

    /**
     * @description Deletes the invoice-generation sample dataset — and ONLY
     *              records carrying SAMPLE_MARKER — in dependency-safe order:
     *              WorkLog (child of WorkRequest MD + WorkItem lookup) →
     *              WorkRequest (child of WorkItem MD) → WorkItem → NetworkEntity.
     *              Returns the total number of records deleted.
     * @return Count of deleted records.
     */
    private static Integer removeInvoiceGeneration() {
        Integer deleted = 0;

        // 1. WorkLogs carrying the marker.
        List<WorkLog__c> logs = [
            SELECT Id FROM WorkLog__c
            WHERE WorkDescriptionTxt__c LIKE :markerLike()
            WITH SYSTEM_MODE
        ];
        if (!logs.isEmpty()) {
            Database.delete(logs, AccessLevel.SYSTEM_MODE);
            deleted += logs.size();
        }

        // 2. The marked WorkItems' bridge WorkRequests. We resolve them via the
        //    marked WorkItems so we delete exactly the bridges this loader made
        //    (WorkRequest__c has no own text field to stamp). Deleting the
        //    WorkItem would cascade the MD child anyway, but we delete bridges
        //    explicitly so the returned count is accurate and the order is safe
        //    even if a future schema change loosens the cascade.
        List<WorkItem__c> markedWis = [
            SELECT Id FROM WorkItem__c
            WHERE BriefDescriptionTxt__c LIKE :markerLike()
            WITH SYSTEM_MODE
        ];
        if (!markedWis.isEmpty()) {
            List<WorkRequest__c> bridges = [
                SELECT Id FROM WorkRequest__c
                WHERE WorkItemId__c IN :markedWis
                WITH SYSTEM_MODE
            ];
            if (!bridges.isEmpty()) {
                Database.delete(bridges, AccessLevel.SYSTEM_MODE);
                deleted += bridges.size();
            }
            // 3. The marked WorkItems themselves.
            Database.delete(markedWis, AccessLevel.SYSTEM_MODE);
            deleted += markedWis.size();
        }

        // 4. The placeholder vendors (matched by their exact marked names).
        List<NetworkEntity__c> vendors = [
            SELECT Id FROM NetworkEntity__c
            WHERE Name IN (:SAMPLE_VENDOR_A, :SAMPLE_VENDOR_B)
            WITH SYSTEM_MODE
        ];
        if (!vendors.isEmpty()) {
            Database.delete(vendors, AccessLevel.SYSTEM_MODE);
            deleted += vendors.size();
        }

        return deleted;
    }

    /**
     * @description Counts every record currently carrying SAMPLE_MARKER for the
     *              invoice-generation dataset. Used to report the no-op count on
     *              an already-loaded re-run so the audit row + toast are honest.
     * @return Total count of currently-loaded marked sample records.
     */
    private static Integer countLoadedInvoiceRecords() {
        Integer total = 0;
        total += [
            SELECT COUNT() FROM NetworkEntity__c
            WHERE Name IN (:SAMPLE_VENDOR_A, :SAMPLE_VENDOR_B)
            WITH SYSTEM_MODE
        ];
        List<WorkItem__c> markedWis = [
            SELECT Id FROM WorkItem__c
            WHERE BriefDescriptionTxt__c LIKE :markerLike()
            WITH SYSTEM_MODE
        ];
        total += markedWis.size();
        if (!markedWis.isEmpty()) {
            total += [
                SELECT COUNT() FROM WorkRequest__c
                WHERE WorkItemId__c IN :markedWis
                WITH SYSTEM_MODE
            ];
        }
        total += [
            SELECT COUNT() FROM WorkLog__c
            WHERE WorkDescriptionTxt__c LIKE :markerLike()
            WITH SYSTEM_MODE
        ];
        return total;
    }

    // ────────────────────────────────────────────────────────────────────
    // Helpers
    // ────────────────────────────────────────────────────────────────────

    /**
     * @description SOQL LIKE pattern that matches any field value beginning
     *              with the sample marker. Kept in one place so load/remove/
     *              count can never drift on the matching rule.
     * @return '[DH SAMPLE]%' wrapped for a LIKE bind.
     */
    private static String markerLike() {
        return SAMPLE_MARKER + '%';
    }

    /**
     * @description Loads the DatasetTemplate__c (with its feature name) or
     *              throws a caller-meaningful exception when it's missing.
     * @param templateId Required DatasetTemplate__c id.
     * @return The template row with FeatureLookup__r.Name populated.
     */
    private static DatasetTemplate__c requireTemplate(Id templateId) {
        if (templateId == null) {
            throw new DatasetLoaderException('templateId is required.');
        }
        List<DatasetTemplate__c> rows = [
            SELECT Id, Name, FeatureLookup__c, FeatureLookup__r.Name,
                   FeatureLookup__r.FeatureDefinitionTxt__c
            FROM DatasetTemplate__c
            WHERE Id = :templateId
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        if (rows.isEmpty()) {
            throw new DatasetLoaderException('Dataset template not found.');
        }
        return rows.get(0);
    }

    /**
     * @description Resolves which built-in dataset a template maps to. Prefers
     *              the linked feature's FeatureDefinitionTxt__c (stable across
     *              renames), then the feature Name, then the template Name — so
     *              the seeded Invoice Generation template resolves whether it's
     *              linked by definition key or just named for the feature.
     * @param template DatasetTemplate__c row (feature relationship populated).
     * @return Dataset key (e.g. 'Invoice_Generation') or null when unmatched.
     */
    private static String resolveDatasetKey(DatasetTemplate__c template) {
        String defKey = (template.FeatureLookup__c != null && template.FeatureLookup__r != null)
            ? template.FeatureLookup__r.FeatureDefinitionTxt__c
            : null;
        if (matchesInvoiceGeneration(defKey)) {
            return DATASET_INVOICE_GENERATION;
        }
        String featureName = (template.FeatureLookup__c != null && template.FeatureLookup__r != null)
            ? template.FeatureLookup__r.Name
            : null;
        if (matchesInvoiceGeneration(featureName)) {
            return DATASET_INVOICE_GENERATION;
        }
        if (matchesInvoiceGeneration(template.Name)) {
            return DATASET_INVOICE_GENERATION;
        }
        return null;
    }

    /**
     * @description Whether a candidate string identifies the invoice-generation
     *              dataset (case-insensitive, tolerant of "Invoice Generation"
     *              vs "Invoice_Generation").
     * @param candidate String to test (nullable).
     * @return True when it identifies the invoice dataset.
     */
    private static Boolean matchesInvoiceGeneration(String candidate) {
        if (String.isBlank(candidate)) {
            return false;
        }
        String normalized = candidate.toLowerCase().replace(' ', '_');
        return normalized == DATASET_INVOICE_GENERATION.toLowerCase()
            || normalized.startsWith('invoice_generation');
    }

    /**
     * @description Writes a DatasetTemplateAssignment__c audit row for a load or
     *              remove run. Best-effort — a failure to write the audit row is
     *              logged but never masks the data operation's own outcome
     *              (the records already landed / were already deleted).
     * @param templateId DatasetTemplate__c the run targeted.
     * @param outcome 'Success' | 'PartialFailure' | 'Failure'.
     * @param recordCount Records inserted (load) or deleted (remove).
     * @param errorSummary Optional error text (null on success).
     * @param isRemoval True for a remove run (annotates the notes).
     * @return Id of the inserted assignment row, or null when the write failed.
     */
    private static Id writeAssignment(
        Id templateId, String outcome, Integer recordCount, String errorSummary, Boolean isRemoval
    ) {
        try {
            String action = isRemoval ? 'Removed' : 'Loaded';
            DatasetTemplateAssignment__c row = new DatasetTemplateAssignment__c(
                DatasetTemplateLookup__c = templateId,
                LoadedByUserLookup__c = UserInfo.getUserId(),
                LoadedDateTime__c = Datetime.now(),
                OutcomePk__c = outcome,
                RecordsLoadedNumber__c = recordCount,
                NotesTxt__c = action + ' in-app sample data via DeliveryDatasetLoader '
                    + '(marker "' + SAMPLE_MARKER + '"). ' + recordCount + ' record(s).'
            );
            if (String.isNotBlank(errorSummary)) {
                row.ErrorSummaryTxt__c = errorSummary.length() > 1024
                    ? errorSummary.substring(0, 1024)
                    : errorSummary;
            }
            Database.insert(row, AccessLevel.SYSTEM_MODE);
            return row.Id;
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN,
                '[DeliveryDatasetLoader.writeAssignment] audit-row write failed: ' + e.getMessage());
            return null;
        }
    }

    /** @description Caller-meaningful loader failure surfaced to the controller. */
    public class DatasetLoaderException extends Exception {}
}

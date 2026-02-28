/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Controller for the CSV Import LWC. Handles bulk creation of
 *               WorkItem__c records from parsed CSV data and exposes the
 *               available field schema for dynamic column mapping.
 * @author Cloud Nimbus LLC
 */
public with sharing class DeliveryCsvImportController {

    private static final Integer BATCH_SIZE = 200;

    /** @description Cached schema field map for WorkItem__c, set once per transaction. */
    private static Map<String, Schema.SObjectField> cachedFieldMap;

    /**
     * @description Wrapper to hold the accumulated import results — success/error
     *              counts, created Ids, and error details — across all batches.
     */
    private class ImportResult {
        /** @description Number of successfully inserted records. */
        public Integer successCount = 0;
        /** @description Number of failed records. */
        public Integer errorCount = 0;
        /** @description Per-row error details (row number + message). */
        public List<Map<String, String>> errorDetails = new List<Map<String, String>>();
        /** @description Ids of successfully created WorkItem__c records. */
        public List<String> createdIds = new List<String>();

        /**
         * @description Converts this wrapper to the Map format expected by the LWC.
         * @return Map with keys: successCount, errorCount, errors, createdIds.
         */
        public Map<String, Object> toMap() {
            Map<String, Object> resultMap = new Map<String, Object>();
            resultMap.put('successCount', this.successCount);
            resultMap.put('errorCount', this.errorCount);
            resultMap.put('errors', this.errorDetails);
            resultMap.put('createdIds', this.createdIds);
            return resultMap;
        }
    }

    /**
     * @description Wrapper that pairs a WorkItem__c record with its original CSV
     *              row index so error messages can reference the source row.
     */
    private class IndexedWorkItem {
        /** @description The WorkItem__c record built from the CSV row. */
        public WorkItem__c record;
        /** @description The zero-based index of the original CSV row. */
        public Integer rowIndex;

        /**
         * @description Constructs an IndexedWorkItem.
         * @param record  The WorkItem__c record.
         * @param rowIndex  The original CSV row index.
         */
        public IndexedWorkItem(WorkItem__c record, Integer rowIndex) {
            this.record = record;
            this.rowIndex = rowIndex;
        }
    }

    /**
     * @description Bulk-inserts WorkItem__c records from a list of field-value maps.
     *              Uses Database.insert with allOrNone=false so partial successes are
     *              reported back to the client.
     * @param records  List of Maps where keys are WorkItem__c field API names and
     *                 values are the string data from the CSV.
     * @param workflowType  The WorkflowType developer name to stamp on every record.
     * @return Map with keys: successCount (Integer), errorCount (Integer),
     *         errors (List<Map<String,String>> with row/message), createdIds (List<String>).
     */
    @AuraEnabled
    public static Map<String, Object> importWorkItems(List<Map<String, String>> records, String workflowType) {
        ImportResult importResult = new ImportResult();

        if (records == null || records.isEmpty()) {
            return importResult.toMap();
        }

        String effectiveWorkflowType = String.isBlank(workflowType)
            ? 'Software_Delivery'
            : workflowType;

        cachedFieldMap = Schema.SObjectType.WorkItem__c.fields.getMap();

        // Build all records first (no DML in this loop)
        List<IndexedWorkItem> indexedItems = new List<IndexedWorkItem>();
        for (Integer i = 0; i < records.size(); i++) {
            WorkItem__c wi = buildWorkItem(records[i], effectiveWorkflowType);
            indexedItems.add(new IndexedWorkItem(wi, i));
        }

        // Split into batches, then insert each batch
        List<List<IndexedWorkItem>> batches = splitIntoBatches(indexedItems);
        for (List<IndexedWorkItem> batch : batches) {
            insertBatch(batch, importResult);
        }

        return importResult.toMap();
    }

    /**
     * @description Splits the full list of IndexedWorkItem records into sub-lists
     *              of up to BATCH_SIZE for governor-friendly DML.
     * @param items  The full list of indexed work items.
     * @return List of batches, each containing up to BATCH_SIZE items.
     */
    private static List<List<IndexedWorkItem>> splitIntoBatches(List<IndexedWorkItem> items) {
        List<List<IndexedWorkItem>> batches = new List<List<IndexedWorkItem>>();
        List<IndexedWorkItem> currentBatch = new List<IndexedWorkItem>();

        for (IndexedWorkItem item : items) {
            currentBatch.add(item);
            if (currentBatch.size() >= BATCH_SIZE) {
                batches.add(currentBatch);
                currentBatch = new List<IndexedWorkItem>();
            }
        }
        if (!currentBatch.isEmpty()) {
            batches.add(currentBatch);
        }
        return batches;
    }

    /**
     * @description Inserts a single batch of IndexedWorkItem records and accumulates
     *              results into the ImportResult wrapper.
     * @param batch  The batch of indexed work items to insert.
     * @param importResult  The result wrapper to accumulate into.
     */
    private static void insertBatch(List<IndexedWorkItem> batch, ImportResult importResult) {
        List<WorkItem__c> records = new List<WorkItem__c>();
        List<Integer> rowIndices = new List<Integer>();

        for (IndexedWorkItem item : batch) {
            records.add(item.record);
            rowIndices.add(item.rowIndex);
        }

        List<Database.SaveResult> results =
            Database.insert(records, false, AccessLevel.SYSTEM_MODE);
        processBatchResults(results, rowIndices, importResult);
    }

    /**
     * @description Returns the list of createable WorkItem__c fields with their
     *              API name, label, and type for the column-mapping UI.
     * @return List of Maps with keys: apiName, label, type.
     */
    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getWorkItemFields() {
        List<Map<String, String>> fieldList = new List<Map<String, String>>();
        Map<String, Schema.SObjectField> fieldMap =
            Schema.SObjectType.WorkItem__c.fields.getMap();

        for (String key : fieldMap.keySet()) {
            Schema.DescribeFieldResult dfr = fieldMap.get(key).getDescribe();
            // Only include fields that can be set on insert
            if (!dfr.isCreateable()) {
                continue;
            }
            Map<String, String> entry = new Map<String, String>();
            entry.put('apiName', dfr.getName());
            entry.put('label', dfr.getLabel());
            entry.put('type', dfr.getType().name());
            fieldList.add(entry);
        }

        // Sort alphabetically by label for a nicer UI
        fieldList.sort(new FieldLabelComparator());
        return fieldList;
    }

    // ── Private helpers ──────────────────────────────────────────────

    /**
     * @description Builds a WorkItem__c record from a single CSV row map by
     *              resolving field names, validating creatability, and coercing
     *              string values to their target Apex types.
     * @param csvRow  Map of field API names to string values from one CSV row.
     * @param workflowType  The effective workflow type to stamp on the record.
     * @return A populated WorkItem__c ready for insertion.
     */
    private static WorkItem__c buildWorkItem(Map<String, String> csvRow, String workflowType) {
        WorkItem__c wi = new WorkItem__c();
        wi.WorkflowTypeTxt__c = workflowType;
        wi.IsActiveBool__c = true;

        for (String fieldName : csvRow.keySet()) {
            String val = csvRow.get(fieldName);
            if (String.isBlank(val)) {
                continue;
            }
            applyFieldValue(wi, fieldName, val);
        }

        return wi;
    }

    /**
     * @description Resolves a single field by name, validates it is createable,
     *              coerces the string value, and sets it on the WorkItem__c record.
     *              Silently skips unknown, non-createable, or un-coercible fields.
     *              Uses the class-level cachedFieldMap for schema resolution.
     * @param wi  The WorkItem__c record to populate.
     * @param fieldName  The field API name from the CSV header.
     * @param val  The string value from the CSV cell.
     */
    private static void applyFieldValue(WorkItem__c wi, String fieldName, String val) {
        Schema.SObjectField sField = resolveField(fieldName);
        if (sField == null) {
            return;
        }

        Schema.DescribeFieldResult dfr = sField.getDescribe();
        if (!dfr.isCreateable()) {
            return;
        }

        try {
            wi.put(dfr.getName(), coerceValue(dfr, val));
        } catch (Exception ex) {
            System.debug(LoggingLevel.WARN,
                'CSV Import: Could not coerce value "' + val +
                '" for field ' + dfr.getName() + ': ' + ex.getMessage());
        }
    }

    /**
     * @description Case-insensitive lookup of a field name against the cached schema map.
     * @param fieldName  The field API name to resolve.
     * @return The matched SObjectField, or null if not found.
     */
    private static Schema.SObjectField resolveField(String fieldName) {
        String fieldNameLower = fieldName.toLowerCase();
        for (String key : cachedFieldMap.keySet()) {
            if (key.toLowerCase() == fieldNameLower) {
                return cachedFieldMap.get(key);
            }
        }
        return null;
    }

    /**
     * @description Iterates over Database.SaveResult entries, accumulates success
     *              and error counts, and populates the createdIds and errorDetails
     *              in the ImportResult wrapper.
     * @param results  The SaveResult list from Database.insert.
     * @param rowIndices  The original CSV row indices for each batch item.
     * @param importResult  The ImportResult wrapper to accumulate into.
     */
    private static void processBatchResults(
        List<Database.SaveResult> results,
        List<Integer> rowIndices,
        ImportResult importResult
    ) {
        for (Integer j = 0; j < results.size(); j++) {
            if (results[j].isSuccess()) {
                importResult.successCount++;
                importResult.createdIds.add(results[j].getId());
            } else {
                importResult.errorCount++;
                String msg = '';
                for (Database.Error err : results[j].getErrors()) {
                    msg += err.getMessage() + '; ';
                }
                Map<String, String> errEntry = new Map<String, String>();
                errEntry.put('row', String.valueOf(rowIndices[j] + 1));
                errEntry.put('message', msg);
                importResult.errorDetails.add(errEntry);
            }
        }
    }

    /**
     * @description Coerces a string value to the appropriate Apex type based on
     *              the field describe.
     * @param dfr  The field describe result.
     * @param val  The string value to coerce.
     * @return The coerced Object value.
     */
    private static Object coerceValue(Schema.DescribeFieldResult dfr, String val) {
        Schema.DisplayType dt = dfr.getType();

        if (dt == Schema.DisplayType.BOOLEAN) {
            return val.equalsIgnoreCase('true') || val == '1' || val.equalsIgnoreCase('yes');
        }
        if (dt == Schema.DisplayType.CURRENCY || dt == Schema.DisplayType.DOUBLE ||
            dt == Schema.DisplayType.PERCENT) {
            return Decimal.valueOf(val.replaceAll('[^\\d.\\-]', ''));
        }
        if (dt == Schema.DisplayType.INTEGER) {
            return Integer.valueOf(val.replaceAll('[^\\d\\-]', ''));
        }
        if (dt == Schema.DisplayType.DATE) {
            return Date.valueOf(val);
        }
        if (dt == Schema.DisplayType.DATETIME) {
            return Datetime.valueOf(val);
        }
        // String, Picklist, TextArea, URL, Email, Phone, Html, etc.
        return val;
    }

    /**
     * @description Comparator for sorting field maps by their label value.
     */
    private class FieldLabelComparator implements System.Comparator<Map<String, String>> {
        /**
         * @description Compares two field maps by their 'label' value for sorting.
         * @param a  First field map.
         * @param b  Second field map.
         * @return Negative if a < b, positive if a > b, zero if equal.
         */
        public Integer compare(Map<String, String> a, Map<String, String> b) {
            String labelA = a.get('label') == null ? '' : a.get('label');
            String labelB = b.get('label') == null ? '' : b.get('label');
            return labelA.compareTo(labelB);
        }
    }
}

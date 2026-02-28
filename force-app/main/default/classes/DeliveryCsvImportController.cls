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
        List<Map<String, String>> errorDetails = new List<Map<String, String>>();
        List<String> createdIds = new List<String>();
        Integer successCount = 0;
        Integer errorCount = 0;

        if (records == null || records.isEmpty()) {
            return buildResultMap(0, 0, errorDetails, createdIds);
        }

        String effectiveWorkflowType = String.isBlank(workflowType)
            ? 'Software_Delivery'
            : workflowType;

        Map<String, Schema.SObjectField> fieldMap =
            Schema.SObjectType.WorkItem__c.fields.getMap();

        List<WorkItem__c> batch = new List<WorkItem__c>();
        List<Integer> batchRowIndices = new List<Integer>();

        for (Integer i = 0; i < records.size(); i++) {
            batch.add(buildWorkItem(records[i], effectiveWorkflowType, fieldMap));
            batchRowIndices.add(i);

            if (batch.size() >= BATCH_SIZE || i == records.size() - 1) {
                List<Database.SaveResult> results =
                    Database.insert(batch, false, AccessLevel.SYSTEM_MODE);
                Map<String, Integer> counts = processBatchResults(
                    results, batchRowIndices, createdIds, errorDetails);
                successCount += counts.get('success');
                errorCount += counts.get('error');

                batch.clear();
                batchRowIndices.clear();
            }
        }

        return buildResultMap(successCount, errorCount, errorDetails, createdIds);
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
     * @param fieldMap  Schema field map for WorkItem__c.
     * @return A populated WorkItem__c ready for insertion.
     */
    private static WorkItem__c buildWorkItem(
        Map<String, String> csvRow,
        String workflowType,
        Map<String, Schema.SObjectField> fieldMap
    ) {
        WorkItem__c wi = new WorkItem__c();
        wi.WorkflowTypeTxt__c = workflowType;
        wi.IsActiveBool__c = true;

        for (String fieldName : csvRow.keySet()) {
            String val = csvRow.get(fieldName);
            if (String.isBlank(val)) {
                continue;
            }
            applyFieldValue(wi, fieldName, val, fieldMap);
        }

        return wi;
    }

    /**
     * @description Resolves a single field by name, validates it is createable,
     *              coerces the string value, and sets it on the WorkItem__c record.
     *              Silently skips unknown, non-createable, or un-coercible fields.
     * @param wi  The WorkItem__c record to populate.
     * @param fieldName  The field API name from the CSV header.
     * @param val  The string value from the CSV cell.
     * @param fieldMap  Schema field map for WorkItem__c.
     */
    private static void applyFieldValue(
        WorkItem__c wi,
        String fieldName,
        String val,
        Map<String, Schema.SObjectField> fieldMap
    ) {
        Schema.SObjectField sField = resolveField(fieldName, fieldMap);
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
     * @description Case-insensitive lookup of a field name against the schema map.
     * @param fieldName  The field API name to resolve.
     * @param fieldMap  Schema field map for WorkItem__c.
     * @return The matched SObjectField, or null if not found.
     */
    private static Schema.SObjectField resolveField(
        String fieldName,
        Map<String, Schema.SObjectField> fieldMap
    ) {
        String fieldNameLower = fieldName.toLowerCase();
        for (String key : fieldMap.keySet()) {
            if (key.toLowerCase() == fieldNameLower) {
                return fieldMap.get(key);
            }
        }
        return null;
    }

    /**
     * @description Iterates over Database.SaveResult entries, accumulates success
     *              and error counts, and populates the createdIds and errorDetails
     *              output lists.
     * @param results  The SaveResult list from Database.insert.
     * @param rowIndices  The original CSV row indices for each batch item.
     * @param createdIds  Output list to append successfully created record Ids.
     * @param errorDetails  Output list to append error row/message maps.
     * @return Map with 'success' and 'error' Integer counts for this batch.
     */
    private static Map<String, Integer> processBatchResults(
        List<Database.SaveResult> results,
        List<Integer> rowIndices,
        List<String> createdIds,
        List<Map<String, String>> errorDetails
    ) {
        Integer batchSuccess = 0;
        Integer batchError = 0;

        for (Integer j = 0; j < results.size(); j++) {
            if (results[j].isSuccess()) {
                batchSuccess++;
                createdIds.add(results[j].getId());
            } else {
                batchError++;
                String msg = '';
                for (Database.Error err : results[j].getErrors()) {
                    msg += err.getMessage() + '; ';
                }
                Map<String, String> errEntry = new Map<String, String>();
                errEntry.put('row', String.valueOf(rowIndices[j] + 1));
                errEntry.put('message', msg);
                errorDetails.add(errEntry);
            }
        }

        return new Map<String, Integer>{
            'success' => batchSuccess,
            'error' => batchError
        };
    }

    /**
     * @description Assembles the standard result map returned by importWorkItems.
     * @param successCount  Number of successfully inserted records.
     * @param errorCount  Number of failed records.
     * @param errorDetails  List of error row/message maps.
     * @param createdIds  List of created record Ids.
     * @return The assembled result map.
     */
    private static Map<String, Object> buildResultMap(
        Integer successCount,
        Integer errorCount,
        List<Map<String, String>> errorDetails,
        List<String> createdIds
    ) {
        Map<String, Object> result = new Map<String, Object>();
        result.put('successCount', successCount);
        result.put('errorCount', errorCount);
        result.put('errors', errorDetails);
        result.put('createdIds', createdIds);
        return result;
    }

    /**
     * @description Coerces a string value to the appropriate Apex type based on
     *              the field describe.
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
        public Integer compare(Map<String, String> a, Map<String, String> b) {
            String labelA = a.get('label') == null ? '' : a.get('label');
            String labelB = b.get('label') == null ? '' : b.get('label');
            return labelA.compareTo(labelB);
        }
    }
}

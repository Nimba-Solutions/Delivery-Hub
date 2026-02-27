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
            Map<String, Object> emptyResult = new Map<String, Object>();
            emptyResult.put('successCount', 0);
            emptyResult.put('errorCount', 0);
            emptyResult.put('errors', errorDetails);
            emptyResult.put('createdIds', createdIds);
            return emptyResult;
        }

        // Resolve the effective workflow type
        String effectiveWorkflowType = String.isBlank(workflowType)
            ? 'Software_Delivery'
            : workflowType;

        // Build the field describe map once for type coercion
        Map<String, Schema.SObjectField> fieldMap =
            Schema.SObjectType.WorkItem__c.fields.getMap();

        // Process in batches of BATCH_SIZE to stay within DML limits
        List<WorkItem__c> batch = new List<WorkItem__c>();
        // Track which source row index each batch item came from
        List<Integer> batchRowIndices = new List<Integer>();

        for (Integer i = 0; i < records.size(); i++) {
            Map<String, String> rec = records[i];
            WorkItem__c wi = new WorkItem__c();
            wi.WorkflowTypeTxt__c = effectiveWorkflowType;
            wi.IsActiveBool__c = true;

            for (String fieldName : rec.keySet()) {
                String val = rec.get(fieldName);
                if (String.isBlank(val)) {
                    continue;
                }
                // Only set fields that actually exist on the object
                String fieldNameLower = fieldName.toLowerCase();
                Schema.SObjectField sField = null;
                for (String key : fieldMap.keySet()) {
                    if (key.toLowerCase() == fieldNameLower) {
                        sField = fieldMap.get(key);
                        break;
                    }
                }
                if (sField == null) {
                    continue;
                }

                Schema.DescribeFieldResult dfr = sField.getDescribe();
                // Skip formula, auto-number, and non-createable fields
                if (!dfr.isCreateable()) {
                    continue;
                }

                try {
                    wi.put(dfr.getName(), coerceValue(dfr, val));
                } catch (Exception ex) {
                    // If coercion fails for one field, skip it but continue
                    System.debug(LoggingLevel.WARN,
                        'CSV Import: Could not coerce value "' + val +
                        '" for field ' + dfr.getName() + ': ' + ex.getMessage());
                }
            }

            batch.add(wi);
            batchRowIndices.add(i);

            // Flush when batch is full or this is the last record
            if (batch.size() >= BATCH_SIZE || i == records.size() - 1) {
                List<Database.SaveResult> results =
                    Database.insert(batch, false, AccessLevel.SYSTEM_MODE);

                for (Integer j = 0; j < results.size(); j++) {
                    if (results[j].isSuccess()) {
                        successCount++;
                        createdIds.add(results[j].getId());
                    } else {
                        errorCount++;
                        String msg = '';
                        for (Database.Error err : results[j].getErrors()) {
                            msg += err.getMessage() + '; ';
                        }
                        Map<String, String> errEntry = new Map<String, String>();
                        errEntry.put('row', String.valueOf(batchRowIndices[j] + 1));
                        errEntry.put('message', msg);
                        errorDetails.add(errEntry);
                    }
                }

                batch.clear();
                batchRowIndices.clear();
            }
        }

        Map<String, Object> result = new Map<String, Object>();
        result.put('successCount', successCount);
        result.put('errorCount', errorCount);
        result.put('errors', errorDetails);
        result.put('createdIds', createdIds);
        return result;
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

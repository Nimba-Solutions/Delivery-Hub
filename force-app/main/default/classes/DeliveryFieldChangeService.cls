/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Service for tracking field value changes on any object.
 *               Provides an @InvocableMethod for subscriber Flows to log
 *               field changes to ActivityLog__c, plus query methods for
 *               retrieving change history and trend data.
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.ApexCRUDViolation, PMD.CyclomaticComplexity, PMD.StdCyclomaticComplexity')
global with sharing class DeliveryFieldChangeService {

    /**
     * @description Input wrapper for the invocable method.
     *              Each field change event is represented as one FieldChangeRequest.
     */
    public class FieldChangeRequest {
        @InvocableVariable(label='Record ID' description='The Salesforce record ID of the changed record' required=true)
        public String recordId;

        @InvocableVariable(label='Field Name' description='API name of the field that changed' required=true)
        public String fieldName;

        @InvocableVariable(label='Field Label' description='Display label of the field')
        public String fieldLabel;

        @InvocableVariable(label='Object Name' description='API name of the object')
        public String objectName;

        @InvocableVariable(label='Old Value' description='Previous value as string')
        public String oldValue;

        @InvocableVariable(label='New Value' description='New value as string')
        public String newValue;

        @InvocableVariable(label='Notes' description='Optional context notes')
        public String notes;

        @InvocableVariable(label='Extra Context' description='Optional JSON string for additional data')
        public String extraContext;
    }

    /**
     * @description Logs one or more field value changes to ActivityLog__c.
     *              Respects the org-level EnableActivityLoggingDateTime__c toggle —
     *              when disabled, the method returns silently without inserting.
     *              This is a fire-and-forget call; errors are swallowed to ensure
     *              tracking never disrupts the caller's process.
     * @param requests List of FieldChangeRequest inputs from Flow or Apex callers
     */
    @InvocableMethod(label='Capture Field Change' description='Logs a field value change to the Delivery Hub activity log for history tracking and trend analysis.' category='Delivery Hub')
    public static void captureFieldChanges(List<FieldChangeRequest> requests) {
        try {
            // Gate: activity logging must be explicitly enabled in org settings
            DeliveryHubSettings__c settings = DeliveryHubSettings__c.getInstance();
            if (settings == null || settings.EnableActivityLoggingDateTime__c == null) {
                return;
            }

            // Attempt to link to the first active Network Entity
            Id networkEntityId = resolveNetworkEntityId();

            List<ActivityLog__c> logsToInsert = new List<ActivityLog__c>();
            for (FieldChangeRequest req : requests) {
                logsToInsert.add(buildActivityLog(req, networkEntityId));
            }

            if (!logsToInsert.isEmpty()) {
                insert as system logsToInsert;
            }
        } catch (Exception e) {
            // Field change tracking must never break the caller's process
            System.debug(LoggingLevel.WARN, 'FieldChangeService log failed: ' + e.getMessage());
        }
    }

    /**
     * @description Returns field change history for a given record, sorted newest-first.
     *              Each entry includes old/new values, the user who made the change,
     *              calculated delta (if numeric), and any extra context.
     * @param recordId  The Id of the record to retrieve history for.
     * @param fieldName Optional field API name filter (null/blank = all fields).
     * @param limitCount Maximum number of records to return (default 50).
     * @return List of Maps with keys: id, timestamp, userId, userName, fieldName,
     *         fieldLabel, objectName, oldValue, newValue, delta, notes, extraContext.
     */
    @AuraEnabled(cacheable=true)
    global static List<Map<String, Object>> getFieldChangeHistory(String recordId, String fieldName, Integer limitCount) {
        if (String.isBlank(recordId)) {
            return new List<Map<String, Object>>();
        }

        Integer queryLimit = (limitCount != null && limitCount > 0) ? limitCount : 50;

        List<ActivityLog__c> logs;
        if (String.isNotBlank(fieldName)) {
            logs = [
                SELECT Id, CreatedDate, UserIdTxt__c, ContextDataTxt__c
                FROM ActivityLog__c
                WHERE RecordIdTxt__c = :recordId
                  AND ActionTypePk__c = 'Field_Change'
                  AND ComponentNameTxt__c = :fieldName
                WITH SYSTEM_MODE
                ORDER BY CreatedDate DESC
                LIMIT :queryLimit
            ];
        } else {
            logs = [
                SELECT Id, CreatedDate, UserIdTxt__c, ContextDataTxt__c
                FROM ActivityLog__c
                WHERE RecordIdTxt__c = :recordId
                  AND ActionTypePk__c = 'Field_Change'
                WITH SYSTEM_MODE
                ORDER BY CreatedDate DESC
                LIMIT :queryLimit
            ];
        }

        if (logs.isEmpty()) {
            return new List<Map<String, Object>>();
        }

        // Collect user Ids for name resolution
        Set<Id> userIds = collectUserIds(logs);
        Map<Id, String> userNameMap = resolveUserNames(userIds);

        List<Map<String, Object>> results = new List<Map<String, Object>>();
        for (ActivityLog__c log : logs) {
            results.add(buildHistoryEntry(log, userNameMap));
        }
        return results;
    }

    /**
     * @description Returns field change data in chronological order (ASC) for charting.
     *              Each entry is a simplified map: timestamp, value (newValue), label (fieldLabel).
     * @param recordId  The Id of the record to retrieve trend data for.
     * @param fieldName The field API name to filter by (required for meaningful trends).
     * @param limitCount Maximum number of records to return (default 50).
     * @return List of Maps with keys: timestamp, value, label.
     */
    @AuraEnabled(cacheable=true)
    global static List<Map<String, Object>> getFieldChangeTrend(String recordId, String fieldName, Integer limitCount) {
        if (String.isBlank(recordId)) {
            return new List<Map<String, Object>>();
        }

        Integer queryLimit = (limitCount != null && limitCount > 0) ? limitCount : 50;

        List<ActivityLog__c> logs;
        if (String.isNotBlank(fieldName)) {
            logs = [
                SELECT Id, CreatedDate, ContextDataTxt__c
                FROM ActivityLog__c
                WHERE RecordIdTxt__c = :recordId
                  AND ActionTypePk__c = 'Field_Change'
                  AND ComponentNameTxt__c = :fieldName
                WITH SYSTEM_MODE
                ORDER BY CreatedDate ASC
                LIMIT :queryLimit
            ];
        } else {
            logs = [
                SELECT Id, CreatedDate, ContextDataTxt__c
                FROM ActivityLog__c
                WHERE RecordIdTxt__c = :recordId
                  AND ActionTypePk__c = 'Field_Change'
                WITH SYSTEM_MODE
                ORDER BY CreatedDate ASC
                LIMIT :queryLimit
            ];
        }

        if (logs.isEmpty()) {
            return new List<Map<String, Object>>();
        }

        List<Map<String, Object>> results = new List<Map<String, Object>>();
        for (ActivityLog__c log : logs) {
            results.add(buildTrendEntry(log));
        }
        return results;
    }

    // ── Private helpers ──────────────────────────────────────────────────

    private static ActivityLog__c buildActivityLog(FieldChangeRequest req, Id networkEntityId) {
        Map<String, Object> contextMap = new Map<String, Object>();
        contextMap.put('fieldName', req.fieldName);
        contextMap.put('fieldLabel', req.fieldLabel);
        contextMap.put('objectName', req.objectName);
        contextMap.put('oldValue', req.oldValue);
        contextMap.put('newValue', req.newValue);
        contextMap.put('notes', req.notes);

        // Parse extraContext JSON if provided
        if (String.isNotBlank(req.extraContext)) {
            try {
                Object extra = JSON.deserializeUntyped(req.extraContext);
                contextMap.put('extra', extra);
            } catch (Exception ex) {
                contextMap.put('extra', req.extraContext);
            }
        }

        // Calculate numeric delta if both values are numbers
        if (String.isNotBlank(req.oldValue) && String.isNotBlank(req.newValue)) {
            try {
                Decimal oldNum = Decimal.valueOf(req.oldValue);
                Decimal newNum = Decimal.valueOf(req.newValue);
                contextMap.put('delta', newNum - oldNum);
            } catch (Exception ex) {
                System.debug(LoggingLevel.FINE, 'Non-numeric values, skipping delta: ' + ex.getMessage());
            }
        }

        ActivityLog__c log = new ActivityLog__c();
        log.ActionTypePk__c     = 'Field_Change';
        log.RecordIdTxt__c      = String.isNotBlank(req.recordId) ? req.recordId : null;
        log.UserIdTxt__c        = UserInfo.getUserId();
        log.ComponentNameTxt__c = req.fieldName;
        log.ContextDataTxt__c   = JSON.serialize(contextMap);

        if (networkEntityId != null) {
            log.NetworkEntityId__c = networkEntityId;
        }

        return log;
    }

    private static Id resolveNetworkEntityId() {
        List<NetworkEntity__c> entities = [
            SELECT Id FROM NetworkEntity__c
            WHERE StatusPk__c = 'Active'
            WITH SYSTEM_MODE
            ORDER BY CreatedDate ASC
            LIMIT 1
        ];
        return entities.isEmpty() ? null : entities[0].Id;
    }

    private static Set<Id> collectUserIds(List<ActivityLog__c> logs) {
        Set<Id> userIds = new Set<Id>();
        for (ActivityLog__c log : logs) {
            if (String.isNotBlank(log.UserIdTxt__c)) {
                try {
                    userIds.add((Id) log.UserIdTxt__c);
                } catch (Exception ex) {
                    System.debug(LoggingLevel.FINE, 'Skipping invalid user Id: ' + log.UserIdTxt__c);
                }
            }
        }
        return userIds;
    }

    private static Map<Id, String> resolveUserNames(Set<Id> userIds) {
        Map<Id, String> nameMap = new Map<Id, String>();
        if (!userIds.isEmpty()) {
            for (User u : [SELECT Id, Name FROM User WHERE Id IN :userIds WITH SYSTEM_MODE]) {
                nameMap.put(u.Id, u.Name);
            }
        }
        return nameMap;
    }

    private static Map<String, Object> buildHistoryEntry(
        ActivityLog__c log,
        Map<Id, String> userNameMap
    ) {
        Map<String, Object> entry = new Map<String, Object>{
            'id'           => log.Id,
            'timestamp'    => log.CreatedDate,
            'userId'       => log.UserIdTxt__c,
            'userName'     => resolveUserName(log.UserIdTxt__c, userNameMap),
            'fieldName'    => '',
            'fieldLabel'   => '',
            'objectName'   => '',
            'oldValue'     => '',
            'newValue'     => '',
            'delta'        => null,
            'notes'        => '',
            'extraContext'  => null
        };

        if (String.isNotBlank(log.ContextDataTxt__c)) {
            try {
                Map<String, Object> ctx = (Map<String, Object>) JSON.deserializeUntyped(
                    log.ContextDataTxt__c
                );
                if (ctx.containsKey('fieldName')) {
                    entry.put('fieldName', ctx.get('fieldName'));
                }
                if (ctx.containsKey('fieldLabel')) {
                    entry.put('fieldLabel', ctx.get('fieldLabel'));
                }
                if (ctx.containsKey('objectName')) {
                    entry.put('objectName', ctx.get('objectName'));
                }
                if (ctx.containsKey('oldValue')) {
                    entry.put('oldValue', ctx.get('oldValue'));
                }
                if (ctx.containsKey('newValue')) {
                    entry.put('newValue', ctx.get('newValue'));
                }
                if (ctx.containsKey('delta')) {
                    entry.put('delta', ctx.get('delta'));
                }
                if (ctx.containsKey('notes')) {
                    entry.put('notes', ctx.get('notes'));
                }
                if (ctx.containsKey('extra')) {
                    entry.put('extraContext', ctx.get('extra'));
                }
            } catch (Exception ex) {
                System.debug(LoggingLevel.FINE, 'Malformed context JSON for log ' + log.Id + ': ' + ex.getMessage());
            }
        }

        return entry;
    }

    private static Map<String, Object> buildTrendEntry(ActivityLog__c log) {
        Map<String, Object> entry = new Map<String, Object>{
            'timestamp' => log.CreatedDate,
            'value'     => '',
            'label'     => ''
        };

        if (String.isNotBlank(log.ContextDataTxt__c)) {
            try {
                Map<String, Object> ctx = (Map<String, Object>) JSON.deserializeUntyped(
                    log.ContextDataTxt__c
                );
                if (ctx.containsKey('newValue')) {
                    entry.put('value', ctx.get('newValue'));
                }
                if (ctx.containsKey('fieldLabel')) {
                    entry.put('label', ctx.get('fieldLabel'));
                }
            } catch (Exception ex) {
                System.debug(LoggingLevel.FINE, 'Malformed context JSON for log ' + log.Id + ': ' + ex.getMessage());
            }
        }

        return entry;
    }

    private static String resolveUserName(String userIdTxt, Map<Id, String> userNameMap) {
        if (String.isNotBlank(userIdTxt) && userIdTxt instanceof Id && userNameMap.containsKey(userIdTxt)) {
            return userNameMap.get(userIdTxt);
        }
        return 'System';
    }
}

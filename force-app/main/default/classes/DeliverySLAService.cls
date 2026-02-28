/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Service for SLA tracking — auto-sets target dates based on priority
 *               using configurable SLARule__mdt records. Provides aggregated SLA status
 *               counts for dashboard components and warning day thresholds for At Risk detection.
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.ApexCRUDViolation')
public with sharing class DeliverySLAService {

    /** @description Hardcoded fallback: days for Critical priority (used when no CMT rules exist) */
    private static final Integer FALLBACK_CRITICAL_DAYS = 3;
    /** @description Hardcoded fallback: days for High priority */
    private static final Integer FALLBACK_HIGH_DAYS = 5;
    /** @description Hardcoded fallback: days for Medium priority */
    private static final Integer FALLBACK_MEDIUM_DAYS = 10;
    /** @description Hardcoded fallback: days for Low or null priority */
    private static final Integer FALLBACK_LOW_DAYS = 20;

    /** @description Default workflow type key used for fallback rules (blank WorkflowTypeTxt__c) */
    private static final String DEFAULT_KEY = '__default__';

    /**
     * @description Transaction-cached SLA rules keyed by workflowType -> priority -> SLARule__mdt.
     *              Populated on first access via loadRules(). Made @TestVisible so tests can
     *              verify caching behavior without additional SOQL.
     */
    @TestVisible
    private static Map<String, Map<String, SLARule__mdt>> cachedRules;

    // -------------------------------------------------------------------------
    // Public API — backward-compatible signatures
    // -------------------------------------------------------------------------

    /**
     * @description Sets SLATargetDate__c on work items that do not already have one,
     *              based on PriorityPk__c. Uses default SLA rules (no workflow type).
     *              Does NOT perform DML.
     * @param workItems List of WorkItem__c records to process (modified in-place)
     * @return The same list, with SLATargetDate__c populated where it was null
     */
    public static List<WorkItem__c> autoSetSLATarget(List<WorkItem__c> workItems) {
        return autoSetSLATarget(workItems, null);
    }

    /**
     * @description Sets SLATargetDate__c on work items that do not already have one,
     *              based on PriorityPk__c and the given workflow type. Does NOT perform DML.
     * @param workItems List of WorkItem__c records to process (modified in-place)
     * @param workflowType The workflow type to look up SLA rules for (null = default)
     * @return The same list, with SLATargetDate__c populated where it was null
     */
    public static List<WorkItem__c> autoSetSLATarget(List<WorkItem__c> workItems, String workflowType) {
        Date today = Date.today();
        for (WorkItem__c wi : workItems) {
            if (wi.SLATargetDate__c != null) {
                continue;
            }
            String wfType = workflowType != null ? workflowType : wi.WorkflowTypeTxt__c;
            Integer daysToAdd = getDaysForPriority(wfType, wi.PriorityPk__c);
            wi.SLATargetDate__c = today.addDays(daysToAdd);
        }
        return workItems;
    }

    /**
     * @description Returns the number of calendar days for a given priority value
     *              using default/fallback SLA rules.
     * @param priority The picklist value of PriorityPk__c
     * @return Number of calendar days to add
     */
    public static Integer getDaysForPriority(String priority) {
        return getDaysForPriority(null, priority);
    }

    /**
     * @description Returns the number of calendar days for a given workflow type and priority.
     *              Looks up workflow-specific rules first, then falls back to default rules,
     *              then to hardcoded constants as a last resort.
     * @param workflowType The workflow type (null or blank = default)
     * @param priority The picklist value of PriorityPk__c
     * @return Number of calendar days to add
     */
    public static Integer getDaysForPriority(String workflowType, String priority) {
        SLARule__mdt rule = findRule(workflowType, priority);
        if (rule != null) {
            return rule.TargetDaysNum__c.intValue();
        }
        return getHardcodedFallback(priority);
    }

    /**
     * @description Returns the warning day threshold for a given workflow type and priority.
     *              This is the number of days after creation when At Risk status should begin.
     * @param workflowType The workflow type (null or blank = default)
     * @param priority The picklist value of PriorityPk__c
     * @return Number of warning days, or null if no rule found
     */
    public static Integer getWarningDays(String workflowType, String priority) {
        SLARule__mdt rule = findRule(workflowType, priority);
        if (rule != null) {
            return rule.WarningDaysNum__c.intValue();
        }
        return null;
    }

    /**
     * @description Queries WorkItem__c records for a given workflow type and returns
     *              a count of items grouped by SLA status (On Track, At Risk, Breached, Met).
     * @param workflowTypeName The WorkflowTypeTxt__c value to filter by
     * @return Map of SLA status label to count
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, Integer> getSLAStatusCounts(String workflowTypeName) {
        Map<String, Integer> counts = new Map<String, Integer>{
            'On Track' => 0,
            'At Risk' => 0,
            'Breached' => 0,
            'Met' => 0
        };

        try {
            List<WorkItem__c> items = [
                SELECT SLAStatusTxt__c
                FROM WorkItem__c
                WHERE WorkflowTypeTxt__c = :workflowTypeName
                AND SLATargetDate__c != NULL
                WITH SYSTEM_MODE
            ];

            for (WorkItem__c wi : items) {
                String status = wi.SLAStatusTxt__c;
                if (counts.containsKey(status)) {
                    counts.put(status, counts.get(status) + 1);
                }
            }
        } catch (Exception e) {
            AuraHandledException ahe = new AuraHandledException(e.getMessage());
            ahe.setMessage(e.getMessage());
            throw ahe;
        }

        return counts;
    }

    // -------------------------------------------------------------------------
    // Private helpers — CMT lookup with caching
    // -------------------------------------------------------------------------

    /**
     * @description Finds the best-match SLARule__mdt for the given workflow type and priority.
     *              Priority resolution: workflow-specific rule > default rule > null.
     * @param workflowType The workflow type to look up (null/blank = default only)
     * @param priority The priority level (Critical, High, Medium, Low)
     * @return The matching SLARule__mdt record, or null if none found
     */
    private static SLARule__mdt findRule(String workflowType, String priority) {
        loadRules();
        String normalizedPriority = String.isBlank(priority) ? 'Low' : priority;

        // 1. Try workflow-specific rule
        if (String.isNotBlank(workflowType)) {
            Map<String, SLARule__mdt> workflowRules = cachedRules.get(workflowType);
            if (workflowRules != null && workflowRules.containsKey(normalizedPriority)) {
                return workflowRules.get(normalizedPriority);
            }
        }

        // 2. Fall back to default rules (blank workflow type)
        Map<String, SLARule__mdt> defaultRules = cachedRules.get(DEFAULT_KEY);
        if (defaultRules != null && defaultRules.containsKey(normalizedPriority)) {
            return defaultRules.get(normalizedPriority);
        }

        return null;
    }

    /**
     * @description Loads SLARule__mdt records into the transaction cache on first access.
     *              Subsequent calls within the same transaction are free (no SOQL).
     */
    private static void loadRules() {
        if (cachedRules != null) {
            return;
        }

        cachedRules = new Map<String, Map<String, SLARule__mdt>>();

        List<SLARule__mdt> rules = [
            SELECT DeveloperName, WorkflowTypeTxt__c, PriorityTxt__c,
                   TargetDaysNum__c, WarningDaysNum__c, UseBusinessHoursBool__c, IsActiveBool__c
            FROM SLARule__mdt
            WHERE IsActiveBool__c = true
            WITH SYSTEM_MODE
        ];

        for (SLARule__mdt rule : rules) {
            String key = String.isBlank(rule.WorkflowTypeTxt__c) ? DEFAULT_KEY : rule.WorkflowTypeTxt__c;
            if (!cachedRules.containsKey(key)) {
                cachedRules.put(key, new Map<String, SLARule__mdt>());
            }
            cachedRules.get(key).put(rule.PriorityTxt__c, rule);
        }
    }

    /**
     * @description Ultimate fallback when no CMT rules exist at all (safety net for
     *              orgs that somehow have no SLARule__mdt records deployed).
     * @param priority The priority level
     * @return Hardcoded number of days matching original behavior
     */
    private static Integer getHardcodedFallback(String priority) {
        if (priority == 'Critical') {
            return FALLBACK_CRITICAL_DAYS;
        } else if (priority == 'High') {
            return FALLBACK_HIGH_DAYS;
        } else if (priority == 'Medium') {
            return FALLBACK_MEDIUM_DAYS;
        } else {
            return FALLBACK_LOW_DAYS;
        }
    }
}

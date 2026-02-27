/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Service for SLA tracking — auto-sets target dates based on priority
 *               and provides aggregated SLA status counts for dashboard components.
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.ApexCRUDViolation')
public with sharing class DeliverySLAService {

    /** @description Days to add for Critical priority */
    private static final Integer CRITICAL_DAYS = 3;
    /** @description Days to add for High priority */
    private static final Integer HIGH_DAYS = 5;
    /** @description Days to add for Medium priority */
    private static final Integer MEDIUM_DAYS = 10;
    /** @description Days to add for Low or null priority */
    private static final Integer LOW_DAYS = 20;

    /**
     * @description Sets SLATargetDate__c on work items that do not already have one,
     *              based on PriorityPk__c. Does NOT perform DML.
     * @param workItems List of WorkItem__c records to process (modified in-place)
     * @return The same list, with SLATargetDate__c populated where it was null
     */
    public static List<WorkItem__c> autoSetSLATarget(List<WorkItem__c> workItems) {
        Date today = Date.today();
        for (WorkItem__c wi : workItems) {
            if (wi.SLATargetDate__c != null) {
                continue;
            }
            Integer daysToAdd = getDaysForPriority(wi.PriorityPk__c);
            wi.SLATargetDate__c = today.addDays(daysToAdd);
        }
        return workItems;
    }

    /**
     * @description Returns the number of calendar days for a given priority value.
     * @param priority The picklist value of PriorityPk__c
     * @return Number of calendar days to add
     */
    private static Integer getDaysForPriority(String priority) {
        if (priority == 'Critical') {
            return CRITICAL_DAYS;
        } else if (priority == 'High') {
            return HIGH_DAYS;
        } else if (priority == 'Medium') {
            return MEDIUM_DAYS;
        } else {
            return LOW_DAYS;
        }
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
}

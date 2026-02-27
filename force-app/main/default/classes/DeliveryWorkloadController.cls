/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Controller for the Developer Workload Dashboard LWC. Provides
 * active work item distribution per developer with estimated hours and stage
 * breakdown to help managers identify overloaded developers and unassigned items.
 * @author Cloud Nimbus LLC
 */
public with sharing class DeliveryWorkloadController {

    /**
     * @description Returns workload data for each developer who has active (non-terminal)
     * work items. Each entry contains developer identity, item count, estimated hours,
     * and a per-stage breakdown.
     * @param workflowTypeName DeveloperName of the WorkflowType__mdt record.
     *                         Defaults to 'Software_Delivery' when blank.
     * @return List of Maps, each representing one developer's workload summary.
     */
    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getWorkloadData(String workflowTypeName) {
        try {
            if (String.isBlank(workflowTypeName)) {
                workflowTypeName = 'Software_Delivery';
            }
            Set<String> terminalStages = DeliveryWorkflowConfigService.getTerminalStageValues(workflowTypeName);
            List<WorkItem__c> activeItems = queryActiveItems(terminalStages);
            return buildWorkloadList(activeItems);
        } catch (Exception e) {
            AuraHandledException ahe = new AuraHandledException(e.getMessage());
            ahe.setMessage(e.getMessage());
            throw ahe;
        }
    }

    /**
     * @description Returns the count of active work items that have no developer assigned.
     * @param workflowTypeName DeveloperName of the WorkflowType__mdt record.
     *                         Defaults to 'Software_Delivery' when blank.
     * @return Integer count of unassigned, non-terminal work items.
     */
    @AuraEnabled(cacheable=true)
    public static Integer getUnassignedCount(String workflowTypeName) {
        try {
            if (String.isBlank(workflowTypeName)) {
                workflowTypeName = 'Software_Delivery';
            }
            Set<String> terminalStages = DeliveryWorkflowConfigService.getTerminalStageValues(workflowTypeName);
            return [
                SELECT COUNT()
                FROM WorkItem__c
                WHERE Developer__c = NULL
                AND StageNamePk__c NOT IN :terminalStages
                WITH SYSTEM_MODE
                LIMIT 2000
            ];
        } catch (Exception e) {
            AuraHandledException ahe = new AuraHandledException(e.getMessage());
            ahe.setMessage(e.getMessage());
            throw ahe;
        }
    }

    // -------------------------------------------------------------------------
    // Private helpers
    // -------------------------------------------------------------------------

    /**
     * @description Queries active work items with developer assigned, excluding terminal stages.
     * @param terminalStages Set of stage API values considered terminal.
     * @return List of active WorkItem__c records with Developer__c populated.
     */
    private static List<WorkItem__c> queryActiveItems(Set<String> terminalStages) {
        return [
            SELECT Id, Developer__c, Developer__r.Name,
                   StageNamePk__c, EstimatedHoursNumber__c
            FROM WorkItem__c
            WHERE Developer__c != NULL
            AND StageNamePk__c NOT IN :terminalStages
            WITH SYSTEM_MODE
            ORDER BY Developer__r.Name ASC
            LIMIT 2000
        ];
    }

    /**
     * @description Aggregates a flat list of work items into per-developer workload summaries.
     * Each summary includes developer identity, total item count, estimated hours,
     * and a stage-to-count breakdown map.
     * @param activeItems List of active WorkItem__c records.
     * @return List of Maps sorted by totalItems descending (busiest first).
     */
    private static List<Map<String, Object>> buildWorkloadList(List<WorkItem__c> activeItems) {
        Map<Id, Map<String, Object>> devMap = new Map<Id, Map<String, Object>>();

        for (WorkItem__c wi : activeItems) {
            Id devId = wi.Developer__c;
            if (!devMap.containsKey(devId)) {
                devMap.put(devId, initDeveloperEntry(devId, wi.Developer__r.Name));
            }
            Map<String, Object> entry = devMap.get(devId);
            incrementEntry(entry, wi);
        }

        List<Map<String, Object>> result = devMap.values();
        result.sort(new WorkloadComparator());
        return result;
    }

    /**
     * @description Creates a fresh developer workload entry map with zero counters.
     * @param devId The developer User Id.
     * @param devName The developer's Name.
     * @return Initialized Map for one developer.
     */
    private static Map<String, Object> initDeveloperEntry(Id devId, String devName) {
        Map<String, Object> entry = new Map<String, Object>();
        entry.put('developerId', devId);
        entry.put('developerName', devName);
        entry.put('totalItems', 0);
        entry.put('totalEstimatedHours', (Decimal) 0);
        entry.put('stageBreakdown', new Map<String, Integer>());
        return entry;
    }

    /**
     * @description Increments a developer entry with data from one work item.
     * @param entry The developer's workload map to update.
     * @param wi The work item to tally.
     */
    private static void incrementEntry(Map<String, Object> entry, WorkItem__c wi) {
        entry.put('totalItems', (Integer) entry.get('totalItems') + 1);

        Decimal hours = wi.EstimatedHoursNumber__c != null ? wi.EstimatedHoursNumber__c : 0;
        entry.put('totalEstimatedHours', (Decimal) entry.get('totalEstimatedHours') + hours);

        Map<String, Integer> breakdown = (Map<String, Integer>) entry.get('stageBreakdown');
        String stage = wi.StageNamePk__c;
        if (breakdown.containsKey(stage)) {
            breakdown.put(stage, breakdown.get(stage) + 1);
        } else {
            breakdown.put(stage, 1);
        }
    }

    /**
     * @description Comparator that sorts developer workload entries by totalItems descending.
     */
    private class WorkloadComparator implements Comparator<Map<String, Object>> {
        /**
         * @description Compares two developer maps by totalItems descending.
         * @param a First developer entry.
         * @param b Second developer entry.
         * @return Negative if a has more items, positive if b has more.
         */
        public Integer compare(Map<String, Object> a, Map<String, Object> b) {
            Integer aTotal = (Integer) a.get('totalItems');
            Integer bTotal = (Integer) b.get('totalItems');
            return bTotal - aTotal;
        }
    }
}

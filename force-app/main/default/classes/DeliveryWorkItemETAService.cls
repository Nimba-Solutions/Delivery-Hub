/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description An advanced service to calculate and update dynamic ETAs for WorkItem__c records.
 * This service implements a simulation engine based on developer availability, work item priority, and workload.
 * It is designed to be called from LWC, Triggers (via Queueable), or on a nightly schedule.
 *
 * @version 2.1
 * @author Mahipal Jat
 * @date July 22, 2025
 */
public with sharing class DeliveryWorkItemETAService {

    // #################################################################################
    // SECTION 1: LWC Integration & DTOs
    // #################################################################################

    /**
     * @description Public method callable from Lightning Web Components.
     * Triggers a synchronous, real-time recalculation of all work item ETAs and returns the fresh results.
     * @param numberOfDevs (Not Used) This parameter is maintained for LWC compatibility but the calculation now uses actual User records flagged as developers.
     * @param prioritizedWorkItemIds A list of Work Item IDs to be placed at the very top of the queue, overriding all other sorting logic.
     * @return ETAResult A wrapper object containing the list of calculated work item ETAs.
     */
    @AuraEnabled
    // <<< FIX 1: Changed parameter from Set<Id> to List<Id> which is supported by AuraEnabled.
    public static ETAResult getWorkItemETAsWithPriority(Integer numberOfDevs, List<Id> prioritizedWorkItemIds) {
        ETAResult result = new ETAResult();
        result.workItems = new List<WorkItemETADTO>();
        result.pushedBackWorkItemNumbers = new List<String>(); // Compatibility with original LWC structure

        try {
            ETACalculator calculator = new ETACalculator(prioritizedWorkItemIds);
            calculator.execute();

            Set<Id> processedIds = calculator.getProcessedWorkItemIds();

            List<WorkItem__c> queriedWorkItems = [
                SELECT Id, ProjectedUATReadyDate__c, Developer__c,
                       DeveloperDaysSizeNumber__c, StageNamePk__c
                FROM WorkItem__c
                WHERE Id IN :processedIds
            ];

            // Collect blocked work item IDs for confidence calculation
            Set<Id> blockedIds = new Set<Id>();
            for (WorkItemDependency__c dep : [
                SELECT BlockedWorkItemId__c FROM WorkItemDependency__c
                WHERE BlockedWorkItemId__c IN :processedIds
                AND BlockingWorkItemId__c NOT IN (
                    SELECT Id FROM WorkItem__c WHERE StageNamePk__c IN ('Done', 'Deployed to Prod', 'Cancelled')
                )
                WITH SYSTEM_MODE
            ]) {
                blockedIds.add(dep.BlockedWorkItemId__c);
            }

            Set<String> activeDevStages = new Set<String>{'In Development', 'In Code Review', 'In QA'};

            for (WorkItem__c wi : queriedWorkItems) {
                WorkItemETADTO dto = new WorkItemETADTO();
                dto.workItemId = wi.Id;
                dto.calculatedETA = wi.ProjectedUATReadyDate__c;
                dto.confidencePercent = calculateConfidence(wi, activeDevStages, blockedIds);
                result.workItems.add(dto);
            }

        } catch (Exception e) {
            throw new AuraHandledException('Error calculating ETAs: ' + e.getMessage());
        }

        return result;
    }

    /**
     * @description Data Transfer Object (DTO) to send results back to the LWC.
     */
    public class ETAResult {
        /** @description List of work items with calculated ETA data. */
        @AuraEnabled public List<WorkItemETADTO> workItems { get; set; }
        /** @description Work item numbers that were pushed back during calculation. */
        @AuraEnabled public List<String> pushedBackWorkItemNumbers { get; set; }
    }

    public class WorkItemETADTO {
        /** @description Salesforce Id of the work item. */
        @AuraEnabled public Id workItemId { get; set; }
        /** @description Calculated estimated completion date. */
        @AuraEnabled public Date calculatedETA { get; set; }
        /** @description Confidence percentage (0-100) based on data completeness. */
        @AuraEnabled public Integer confidencePercent { get; set; }
    }


    /**
     * @description Calculates a confidence score (0-100) for an ETA estimate based on data completeness.
     * Each factor contributes 25%: developer assigned, effort estimated, active development, no blockers.
     * @param wi The work item record
     * @param activeDevStages Set of stage values considered active development
     * @param blockedIds Set of work item IDs that have unresolved blocking dependencies
     * @return Integer confidence percentage 0-100
     */
    @TestVisible
    private static Integer calculateConfidence(WorkItem__c wi, Set<String> activeDevStages, Set<Id> blockedIds) {
        Integer score = 0;
        if (wi.Developer__c != null) { score += 25; }
        if (wi.DeveloperDaysSizeNumber__c != null && wi.DeveloperDaysSizeNumber__c > 0) { score += 25; }
        if (activeDevStages.contains(wi.StageNamePk__c)) { score += 25; }
        if (!blockedIds.contains(wi.Id)) { score += 25; }
        return score;
    }

    // #################################################################################
    // SECTION 2: Asynchronous Job Implementations
    // #################################################################################

    /**
     * @description Queueable job to run the ETA calculation asynchronously.
     * This should be called from a trigger on WorkItem__c when relevant fields change.
     */
    public class RecalculateAllETAsQueueable implements Queueable {
        public void execute(QueueableContext context) {
            ETACalculator calculator = new ETACalculator(null);
            calculator.execute();
        }
    }

    /**
     * @description Schedulable job to run a full recalculation nightly, ensuring data consistency.
     */
    public class NightlyRecalculation implements Schedulable {
        public void execute(SchedulableContext sc) {
            // We enqueue the queueable from the scheduler to ensure it has its own governor limits
            // and to handle any potential callout limitations if they are added in the future.
            System.enqueueJob(new RecalculateAllETAsQueueable());
        }
    }


    // #################################################################################
    // SECTION 3: The Core Calculation Engine
    // #################################################################################

    /**
     * @description Private inner class containing the main ETA simulation logic.
     * Stage categorization is derived from WorkflowStage__mdt.PhaseTxt__c:
     *   Planning → pre-development, Development → active development.
     */
    @TestVisible
    private class ETACalculator {
        private Set<String> preDevStages;
        private Set<String> activeDevStages;
        private Map<String, Decimal> priorityWeights;
        private Integer uatBufferDays;
        private final Set<Id> prioritizedWorkItemIds;
        private Set<Id> processedWorkItemIds;

        private static final Integer DEFAULT_UAT_BUFFER_DAYS = 5;
        private static final Map<String, Decimal> DEFAULT_PRIORITY_WEIGHTS = new Map<String, Decimal>{
            'High' => 1, 'Medium' => 2, 'Low' => 3
        };

        public ETACalculator(List<Id> prioritizedIds) {
            this.prioritizedWorkItemIds = (prioritizedIds == null) ? new Set<Id>() : new Set<Id>(prioritizedIds);
            this.processedWorkItemIds = new Set<Id>();
        }

        public Set<Id> getProcessedWorkItemIds() {
            return this.processedWorkItemIds;
        }

        /**
         * @description Main method that executes the entire ETA calculation process.
         */
        public void execute() {
            // --- Phase 1: Initialization from WorkflowStage__mdt ---
            loadStageConfiguration();

            Map<Id, User> developers = loadResources();
            List<WorkItem__c> allWorkItems = loadWorkItems();

            Map<Id, Date> devNextAvailableDate = new Map<Id, Date>();
            for (Id devId : developers.keySet()) {
                devNextAvailableDate.put(devId, Date.today());
            }

            // --- Phase 2: Triage & Queuing ---
            List<WorkItemWrapper> masterQueue = buildAndSortQueue(allWorkItems, developers.keySet());

            // --- Phase 3: The Simulation Loop ---
            List<WorkItem__c> workItemsToUpdate = new List<WorkItem__c>();

            for (WorkItemWrapper wrapper : masterQueue) {
                Id assignedDevId = wrapper.workItem.Developer__c;

                if (assignedDevId == null || !developers.containsKey(assignedDevId)) {
                    assignedDevId = findNextAvailableDeveloper(devNextAvailableDate);
                }

                if (assignedDevId == null) {
                    continue;
                }

                Date devAvailableDate = devNextAvailableDate.get(assignedDevId);
                Date startDate = (Date.today() > devAvailableDate) ? Date.today() : devAvailableDate;
                wrapper.workItem.EstimatedStartDevDate__c = startDate;

                Decimal effort = wrapper.workItem.DeveloperDaysSizeNumber__c == null ? 0 : wrapper.workItem.DeveloperDaysSizeNumber__c;
                Date completionDate = addBusinessDays(startDate, Integer.valueOf(effort));
                wrapper.workItem.EstimatedEndDevDate__c = completionDate;

                Date nextAvailable = addBusinessDays(completionDate, 1);
                devNextAvailableDate.put(assignedDevId, nextAvailable);

                wrapper.workItem.ProjectedUATReadyDate__c = addBusinessDays(completionDate, this.uatBufferDays);

                workItemsToUpdate.add(wrapper.workItem);
                this.processedWorkItemIds.add(wrapper.workItem.Id);
            }

            for (WorkItem__c workItem : allWorkItems) {
                if (!this.processedWorkItemIds.contains(workItem.Id)) {
                    workItemsToUpdate.add(new WorkItem__c(
                        Id = workItem.Id,
                        EstimatedStartDevDate__c = null,
                        EstimatedEndDevDate__c = null,
                        ProjectedUATReadyDate__c = null
                    ));
                }
            }

            if (!workItemsToUpdate.isEmpty()) {
                Database.SaveResult[] results = Database.update(workItemsToUpdate, false);
                for (Database.SaveResult sr : results) {
                    if (!sr.isSuccess()) {
                        System.debug(LoggingLevel.ERROR, 'DeliveryWorkItemETAService update failed: ' + sr.getErrors());
                    }
                }
            }
        }

        // --- Helper Methods for the Calculator ---

        private void loadStageConfiguration() {
            this.preDevStages = new Set<String>();
            this.activeDevStages = new Set<String>();
            this.priorityWeights = DEFAULT_PRIORITY_WEIGHTS;
            this.uatBufferDays = DEFAULT_UAT_BUFFER_DAYS;

            for (WorkflowStage__mdt s : [
                SELECT ApiValueTxt__c, PhaseTxt__c
                FROM WorkflowStage__mdt
                WHERE WorkflowType__r.DeveloperName = 'Software_Delivery'
                WITH SYSTEM_MODE
            ]) {
                if (s.ApiValueTxt__c == null || s.PhaseTxt__c == null) { continue; }
                String apiVal = s.ApiValueTxt__c.toLowerCase().trim();
                if (s.PhaseTxt__c == 'Planning') {
                    this.preDevStages.add(apiVal);
                } else if (s.PhaseTxt__c == 'Development') {
                    this.activeDevStages.add(apiVal);
                }
            }
        }

        private Map<Id, User> loadResources() {
            List<User> developers = [
                SELECT Id, Name FROM User WHERE IsActive = TRUE
            ];
            return new Map<Id, User>(developers);
        }

        private List<WorkItem__c> loadWorkItems() {
            return [
                SELECT Id, Name, StageNamePk__c, PriorityPk__c, DeveloperDaysSizeNumber__c,
                       SortOrderNumber__c, Developer__c, CreatedDate
                FROM WorkItem__c
            ];
        }

        private List<WorkItemWrapper> buildAndSortQueue(List<WorkItem__c> allWorkItems, Set<Id> developerIds) {
            Set<Id> incompleteWorkItemIds = new Set<Id>();
            for (WorkItem__c t : allWorkItems) {
                if (t.StageNamePk__c != 'Done' && t.StageNamePk__c != 'Deployed to Prod') {
                    incompleteWorkItemIds.add(t.Id);
                }
            }

            Set<Id> allBlockedWorkItemIds = new Set<Id>();
            for (WorkItemDependency__c dep : [SELECT BlockedWorkItemId__c FROM WorkItemDependency__c WHERE BlockingWorkItemId__c IN :incompleteWorkItemIds WITH SYSTEM_MODE]) {
                allBlockedWorkItemIds.add(dep.BlockedWorkItemId__c);
            }

            List<WorkItemWrapper> queue = new List<WorkItemWrapper>();

            for (WorkItem__c t : allWorkItems) {
                if (allBlockedWorkItemIds.contains(t.Id)) {
                    continue;
                }
                String stage = t.StageNamePk__c == null ? '' : t.StageNamePk__c.toLowerCase().trim();

                if (this.preDevStages.contains(stage) || this.activeDevStages.contains(stage)) {
                    queue.add(new WorkItemWrapper(t, this.activeDevStages, this.priorityWeights, this.prioritizedWorkItemIds));
                }
            }

            queue.sort();
            return queue;
        }

        private Id findNextAvailableDeveloper(Map<Id, Date> devSchedules) {
            Id nextDev = null;
            Date earliestDate = null;

            if (devSchedules.isEmpty()) {
                return null;
            }

            for (Id devId : devSchedules.keySet()) {
                Date thisDate = devSchedules.get(devId);
                if (earliestDate == null || thisDate < earliestDate) {
                    earliestDate = thisDate;
                    nextDev = devId;
                }
            }
            return nextDev;
        }

        @TestVisible
        private Date addBusinessDays(Date inputDate, Integer daysToAdd) {
            Date resultDate = inputDate;
            if (inputDate == null || daysToAdd == null || daysToAdd <= 0) { return inputDate; }

            Integer daysAdded = 0;
            while (daysAdded < daysToAdd) {
                resultDate = resultDate.addDays(1);
                Datetime tempDt = Datetime.newInstance(resultDate, Time.newInstance(0, 0, 0, 0));
                if (Integer.valueOf(tempDt.format('u')) < 6) {
                    daysAdded++;
                }
            }
            return resultDate;
        }
    }


    // #################################################################################
    // SECTION 4: Work Item Wrapper for Sorting
    // #################################################################################

    /**
     * @description Wrapper class for WorkItem__c to implement complex, multi-level sorting.
     */
    private class WorkItemWrapper implements Comparable {
        /** @description The WorkItem__c record being wrapped for sort comparison. */
        public WorkItem__c workItem { get; private set; }
        private final Integer stageCategory;     // 1 for ACTIVE_DEV, 2 for PRE_DEV
        private final Decimal priorityWeight;    // Lower is better (e.g., High=1, Med=2)
        private final Boolean isPrioritizedByLWC; // Absolute highest priority

        public WorkItemWrapper(WorkItem__c t, Set<String> activeDevStages, Map<String, Decimal> priorityWeights, Set<Id> prioritizedIds) {
            this.workItem = t;
            this.isPrioritizedByLWC = prioritizedIds.contains(t.Id);

            String stage = t.StageNamePk__c == null ? '' : t.StageNamePk__c.toLowerCase().trim();
            this.stageCategory = activeDevStages.contains(stage) ? 1 : 2;

            this.priorityWeight = priorityWeights.get(t.PriorityPk__c);
            if (this.priorityWeight == null) { this.priorityWeight = 999; }
        }

        public Integer compareTo(Object compareTo) {
            WorkItemWrapper other = (WorkItemWrapper)compareTo;

            // Rule 0: A work item explicitly prioritized by the LWC always comes first.
            if (this.isPrioritizedByLWC && !other.isPrioritizedByLWC) { return -1; }
            if (!this.isPrioritizedByLWC && other.isPrioritizedByLWC) { return 1; }

            // Rule 1: Stage Category (Active work items before pre-dev work items)
            if (this.stageCategory < other.stageCategory) { return -1; }
            if (this.stageCategory > other.stageCategory) { return 1; }

            // Rule 2: Priority Weight (Lower number is higher priority)
            if (this.priorityWeight < other.priorityWeight) { return -1; }
            if (this.priorityWeight > other.priorityWeight) { return 1; }

            // Rule 3: Manual Sort Order (Lower number is higher priority)
            Decimal thisSort = this.workItem.SortOrderNumber__c == null ? 9999 : this.workItem.SortOrderNumber__c;
            Decimal otherSort = other.workItem.SortOrderNumber__c == null ? 9999 : other.workItem.SortOrderNumber__c;
            if (thisSort < otherSort) { return -1; }
            if (thisSort > otherSort) { return 1; }

            // Rule 4: Creation Date (Older work items first)
            if (this.workItem.CreatedDate < other.workItem.CreatedDate) { return -1; }
            if (this.workItem.CreatedDate > other.workItem.CreatedDate) { return 1; }

            return 0; // Work items are considered equal
        }
    }
}

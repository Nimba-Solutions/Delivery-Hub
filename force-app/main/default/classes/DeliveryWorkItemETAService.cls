/**
 * @description An advanced service to calculate and update dynamic ETAs for WorkItem__c records.
 * This service implements a simulation engine based on developer availability, ticket priority, and workload.
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
     * Triggers a synchronous, real-time recalculation of all ticket ETAs and returns the fresh results.
     * @param numberOfDevs (Not Used) This parameter is maintained for LWC compatibility but the calculation now uses actual User records flagged as developers.
     * @param prioritizedTicketIds A list of Ticket IDs to be placed at the very top of the queue, overriding all other sorting logic.
     * @return ETAResult A wrapper object containing the list of calculated ticket ETAs.
     */
    @AuraEnabled
    // <<< FIX 1: Changed parameter from Set<Id> to List<Id> which is supported by AuraEnabled.
    public static ETAResult getTicketETAsWithPriority(Integer numberOfDevs, List<Id> prioritizedTicketIds) {
        ETAResult result = new ETAResult();
        result.tickets = new List<TicketETADTO>();
        result.pushedBackTicketNumbers = new List<String>(); // Compatibility with original LWC structure

        try {
            ETACalculator calculator = new ETACalculator(prioritizedTicketIds);
            calculator.execute();

            Set<Id> processedIds = calculator.getProcessedTicketIds();

            List<WorkItem__c> queriedTickets = [
                SELECT Id, ProjectedUATReadyDate__c
                FROM WorkItem__c
                WHERE Id IN :processedIds
            ];

            for(WorkItem__c ticket : queriedTickets) {
                TicketETADTO dto = new TicketETADTO();
                dto.ticketId = ticket.Id;
                dto.calculatedETA = ticket.ProjectedUATReadyDate__c;
                result.tickets.add(dto);
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
        @AuraEnabled public List<TicketETADTO> tickets { get; set; }
        @AuraEnabled public List<String> pushedBackTicketNumbers { get; set; }
    }

    public class TicketETADTO {
        @AuraEnabled public Id ticketId { get; set; }
        @AuraEnabled public Date calculatedETA { get; set; }
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
     */
    @TestVisible
    private class ETACalculator {
        private Kanban_Configuration__mdt config;
        private final Set<Id> prioritizedTicketIds;
        private Set<Id> processedTicketIds;

        public ETACalculator(List<Id> prioritizedIds) {
            // Convert incoming List to a Set for efficient 'contains' checks.
            this.prioritizedTicketIds = (prioritizedIds == null) ? new Set<Id>() : new Set<Id>(prioritizedIds);
            this.processedTicketIds = new Set<Id>();
        }

        public Set<Id> getProcessedTicketIds() {
            return this.processedTicketIds;
        }

        /**
         * @description Main method that executes the entire ETA calculation process.
         */
        public void execute() {
            // --- Phase 1: Initialization ---
            if (!loadConfiguration()) {
                return;
            }

            Map<Id, User> developers = loadResources();
            List<WorkItem__c> allTickets = loadTickets();

            Map<Id, Date> devNextAvailableDate = new Map<Id, Date>();
            for(Id devId : developers.keySet()){
                devNextAvailableDate.put(devId, Date.today());
            }

            // --- Phase 2: Triage & Queuing ---
            List<TicketWrapper> masterWorkQueue = buildAndSortMasterQueue(allTickets, developers.keySet());

            // --- Phase 3: The Simulation Loop ---
            List<WorkItem__c> ticketsToUpdate = new List<WorkItem__c>();

            for(TicketWrapper wrapper : masterWorkQueue) {
                // a. Determine the Resource
                Id assignedDevId = wrapper.ticket.Developer__c;

                if (assignedDevId == null || !developers.containsKey(assignedDevId)) {
                    assignedDevId = findNextAvailableDeveloper(devNextAvailableDate);
                }

                if(assignedDevId == null) {
                    continue; // No developers available, cannot schedule.
                }

                // b. Find Start Date (cannot be in the past)
                Date devAvailableDate = devNextAvailableDate.get(assignedDevId);
                Date startDate = (Date.today() > devAvailableDate) ? Date.today() : devAvailableDate;
                wrapper.ticket.EstimatedStartDevDate__c = startDate;

                // c. Calculate Work Duration
                Decimal effort = wrapper.ticket.DeveloperDaysSizeNumber__c == null ? 0 : wrapper.ticket.DeveloperDaysSizeNumber__c;
                Date completionDate = addBusinessDays(startDate, Integer.valueOf(effort));
                wrapper.ticket.EstimatedEndDevDate__c = completionDate;

                // d. Update Developer's Schedule for the next ticket
                Date nextAvailable = addBusinessDays(completionDate, 1);
                devNextAvailableDate.put(assignedDevId, nextAvailable);

                // e. Calculate Final ETA with UAT Buffer
                Decimal buffer = config.UATBufferDaysNumber__c == null ? 0 : config.UATBufferDaysNumber__c;
                wrapper.ticket.ProjectedUATReadyDate__c = addBusinessDays(completionDate, Integer.valueOf(buffer));

                // f. Add to list for final DML update
                ticketsToUpdate.add(wrapper.ticket);
                this.processedTicketIds.add(wrapper.ticket.Id);
            }

            // Null out dates for any tickets that were NOT in the queue (i.e., blocked or post-dev)
            for (WorkItem__c ticket : allTickets) {
                if (!this.processedTicketIds.contains(ticket.Id)) {
                    ticketsToUpdate.add(new WorkItem__c(
                        Id = ticket.Id,
                        EstimatedStartDevDate__c = null,
                        EstimatedEndDevDate__c = null,
                        ProjectedUATReadyDate__c = null
                    ));
                }
            }

            if (!ticketsToUpdate.isEmpty()) {
                Database.SaveResult[] results = Database.update(ticketsToUpdate, false); // Use partial success for robustness
                for(Database.SaveResult sr : results) {
                    if(!sr.isSuccess()) {
                        System.debug(LoggingLevel.ERROR, 'DeliveryWorkItemETAService update failed: ' + sr.getErrors());
                    }
                }
            }
        }

        // --- Helper Methods for the Calculator ---

        private boolean loadConfiguration() {
            List<Kanban_Configuration__mdt> configs = [
                SELECT PreDevelopmentStagesTxt__c, ActiveDevelopmentStagesTxt__c, BlockedStagesTxt__c,
                       PostDevelopmentStagesTxt__c, PriorityWeightsTxt__c, UATBufferDaysNumber__c
                FROM Kanban_Configuration__mdt LIMIT 1
            ];

            if (configs.isEmpty()) {
                System.debug(LoggingLevel.ERROR, 'ETA Service Error: Kanban_Configuration__mdt record not found.');
                return false;
            }
            this.config = configs[0];
            return true;
        }

        private Map<Id, User> loadResources() {
            List<User> developers = [
                SELECT Id, Name FROM User WHERE IsActive = TRUE
            ];
            return new Map<Id, User>(developers);
        }

        private List<WorkItem__c> loadTickets() {
            return [
                SELECT Id, Name, StageNamePk__c, PriorityPk__c, DeveloperDaysSizeNumber__c,
                       SortOrderNumber__c, Developer__c, CreatedDate
                FROM WorkItem__c
            ];
        }

        private List<TicketWrapper> buildAndSortMasterQueue(List<WorkItem__c> allTickets, Set<Id> developerIds) {
            Set<Id> incompleteTicketIds = new Set<Id>();
            for(WorkItem__c t : allTickets) {
                if (t.StageNamePk__c != 'Done' && t.StageNamePk__c != 'Deployed to Prod') {
                    incompleteTicketIds.add(t.Id);
                }
            }

            // Find all dependencies where the blocker is one of these incomplete tickets
            Set<Id> allBlockedTicketIds = new Set<Id>();
            for (WorkItemDependency__c dep : [SELECT Blocked_WorkItem__c FROM WorkItemDependency__c WHERE Blocking_WorkItem__c IN :incompleteTicketIds WITH SYSTEM_MODE]) {
                allBlockedTicketIds.add(dep.Blocked_WorkItem__c);
            }

            Set<String> preDev = new Set<String>();
            if(config.PreDevelopmentStagesTxt__c != null) {
                preDev = new Set<String>(config.PreDevelopmentStagesTxt__c.toLowerCase().split(','));
            }

            Set<String> activeDev = new Set<String>();
            if(config.ActiveDevelopmentStagesTxt__c != null) {
                activeDev = new Set<String>(config.ActiveDevelopmentStagesTxt__c.toLowerCase().split(','));
            }

            Map<String, Decimal> priorityWeights = new Map<String, Decimal>();
            if(config.PriorityWeightsTxt__c != null) {
                try {
                    priorityWeights = (Map<String, Decimal>)JSON.deserialize(config.PriorityWeightsTxt__c, Map<String, Decimal>.class);
                } catch(Exception e) {
                    System.debug(LoggingLevel.WARN, 'ETA Service: Could not parse PriorityWeightsTxt__c: ' + e.getMessage());
                }
            }

            List<TicketWrapper> queue = new List<TicketWrapper>();

            for(WorkItem__c t : allTickets){
                if (allBlockedTicketIds.contains(t.Id)) {
                    continue; // Ticket is blocked by an incomplete dependency
                }
                String stage = t.StageNamePk__c == null ? '' : t.StageNamePk__c.toLowerCase().trim();

                if(preDev.contains(stage) || activeDev.contains(stage)){
                    queue.add(new TicketWrapper(t, config, priorityWeights, this.prioritizedTicketIds));
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

            for(Id devId : devSchedules.keySet()){
                Date thisDate = devSchedules.get(devId);
                if(earliestDate == null || thisDate < earliestDate){
                    earliestDate = thisDate;
                    nextDev = devId;
                }
            }
            return nextDev;
        }

		@TestVisible
        private Date addBusinessDays(Date inputDate, Integer daysToAdd) {
            Date resultDate = inputDate;
            if(inputDate == null || daysToAdd == null || daysToAdd <= 0) return inputDate;

            Integer daysAdded = 0;
            while (daysAdded < daysToAdd) {
                resultDate = resultDate.addDays(1);
                // <<< FIX 2: Create a Datetime instance to access the more powerful format() method.
                // 'u' returns 1 for Monday, 6 for Saturday, 7 for Sunday.
                // We only count the day if it's a weekday (1-5).
                Datetime tempDt = Datetime.newInstance(resultDate, Time.newInstance(0, 0, 0, 0));
                if (Integer.valueOf(tempDt.format('u')) < 6) {
                    daysAdded++;
                }
            }
            return resultDate;
        }
    }


    // #################################################################################
    // SECTION 4: Ticket Wrapper for Sorting
    // #################################################################################

    /**
     * @description Wrapper class for WorkItem__c to implement complex, multi-level sorting.
     */
    private class TicketWrapper implements Comparable {
        public WorkItem__c ticket { get; private set; }
        private final Integer stageCategory;     // 1 for ACTIVE_DEV, 2 for PRE_DEV
        private final Decimal priorityWeight;    // Lower is better (e.g., High=1, Med=2)
        private final Boolean isPrioritizedByLWC; // Absolute highest priority

        public TicketWrapper(WorkItem__c t, Kanban_Configuration__mdt config, Map<String, Decimal> priorityWeights, Set<Id> prioritizedIds) {
            this.ticket = t;
            this.isPrioritizedByLWC = prioritizedIds.contains(t.Id);

            Set<String> activeDev = new Set<String>();
            if(config.ActiveDevelopmentStagesTxt__c != null) {
                activeDev = new Set<String>(config.ActiveDevelopmentStagesTxt__c.toLowerCase().split(','));
            }
            String stage = t.StageNamePk__c == null ? '' : t.StageNamePk__c.toLowerCase().trim();
            this.stageCategory = activeDev.contains(stage) ? 1 : 2;

            this.priorityWeight = priorityWeights.get(t.PriorityPk__c);
            if (this.priorityWeight == null) this.priorityWeight = 999;
        }

        public Integer compareTo(Object compareTo) {
            TicketWrapper other = (TicketWrapper)compareTo;

            // Rule 0: A ticket explicitly prioritized by the LWC always comes first.
            if (this.isPrioritizedByLWC && !other.isPrioritizedByLWC) return -1;
            if (!this.isPrioritizedByLWC && other.isPrioritizedByLWC) return 1;

            // Rule 1: Stage Category (Active tickets before pre-dev tickets)
            if (this.stageCategory < other.stageCategory) return -1;
            if (this.stageCategory > other.stageCategory) return 1;

            // Rule 2: Priority Weight (Lower number is higher priority)
            if (this.priorityWeight < other.priorityWeight) return -1;
            if (this.priorityWeight > other.priorityWeight) return 1;

            // Rule 3: Manual Sort Order (Lower number is higher priority)
            Decimal thisSort = this.ticket.SortOrderNumber__c == null ? 9999 : this.ticket.SortOrderNumber__c;
            Decimal otherSort = other.ticket.SortOrderNumber__c == null ? 9999 : other.ticket.SortOrderNumber__c;
            if (thisSort < otherSort) return -1;
            if (thisSort > otherSort) return 1;

            // Rule 4: Creation Date (Older tickets first)
            if (this.ticket.CreatedDate < other.ticket.CreatedDate) return -1;
            if (this.ticket.CreatedDate > other.ticket.CreatedDate) return 1;

            return 0; // Tickets are considered equal
        }
    }
}

/**
 * @description An advanced service to calculate and update dynamic ETAs for Ticket__c records.
 * This service implements a simulation engine based on developer availability, ticket priority, and workload.
 * It is designed to be called from LWC, Triggers (via Queueable), or on a nightly schedule.
 *
 * @version 2.1
 * @author Mahipal Jat
 * @date July 22, 2025
 */
public with sharing class TicketETAService {

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
        System.debug('=== TicketETAService.getTicketETAsWithPriority START ===');
        System.debug('Input numberOfDevs: ' + numberOfDevs);
        System.debug('Input prioritizedTicketIds: ' + prioritizedTicketIds);
        
        ETAResult result = new ETAResult();
        result.tickets = new List<TicketETADTO>();
        result.pushedBackTicketNumbers = new List<String>(); // Compatibility with original LWC structure

        try {
            // Instantiate and run the core calculation engine. This runs synchronously.
              
            System.debug('Creating ETACalculator with prioritizedTicketIds: ' + prioritizedTicketIds);
            ETACalculator calculator = new ETACalculator(prioritizedTicketIds);
            
            System.debug('Executing calculator...');
            calculator.execute();
            
            Set<Id> processedIds = calculator.getProcessedTicketIds();
            System.debug('Calculator processed ticket IDs: ' + processedIds);
            System.debug('Number of processed tickets: ' + (processedIds != null ? processedIds.size() : 0));

            // After execution, the records in the database are updated.
            // Query the fresh data to return to the LWC.
            List<Ticket__c> queriedTickets = [
                SELECT Id, ProjectedUATReadyDate__c
                FROM Ticket__c
                WHERE Id IN :processedIds
            ];
            
            System.debug('Queried tickets count: ' + queriedTickets.size());
            System.debug('Queried tickets: ' + queriedTickets);
            
            for(Ticket__c ticket : queriedTickets) {
                System.debug('Processing ticket: ' + ticket.Id + ', ETA: ' + ticket.ProjectedUATReadyDate__c);
                TicketETADTO dto = new TicketETADTO();
                dto.ticketId = ticket.Id;
                dto.calculatedETA = ticket.ProjectedUATReadyDate__c;
                result.tickets.add(dto);
                System.debug('Added DTO to result: ' + dto);
            }
            
            System.debug('Final result.tickets size: ' + result.tickets.size());
            System.debug('Final result.tickets: ' + result.tickets);
            
        } catch (Exception e) {
            System.debug('ERROR in getTicketETAsWithPriority: ' + e.getMessage());
            System.debug('ERROR stack trace: ' + e.getStackTraceString());
            // In case of any failure during calculation, throw an AuraHandledException
            // so the LWC can gracefully handle the error.
            throw new AuraHandledException('Error calculating ETAs: ' + e.getMessage());
        }
        
        System.debug('=== TicketETAService.getTicketETAsWithPriority END ===');
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
     * This should be called from a trigger on Ticket__c when relevant fields change.
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
            System.debug('=== ETACalculator.execute() START ===');
            
            // --- Phase 1: Initialization ---
            System.debug('Phase 1: Loading configuration...');
            if (!loadConfiguration()) {
                System.debug('ERROR: Configuration loading failed, exiting execute()');
                return;
            }
            System.debug('Configuration loaded successfully');

            System.debug('Loading developers...');
            Map<Id, User> developers = loadResources();
            System.debug('Loaded developers: ' + developers.keySet());
            System.debug('Number of developers: ' + developers.size());

            System.debug('Loading all tickets...');
            List<Ticket__c> allTickets = loadTickets();
            System.debug('Total tickets loaded: ' + allTickets.size());
            System.debug('All tickets: ' + allTickets);

            Map<Id, Date> devNextAvailableDate = new Map<Id, Date>();
            for(Id devId : developers.keySet()){
                devNextAvailableDate.put(devId, Date.today());
            }
            System.debug('Developer availability initialized: ' + devNextAvailableDate);

            // --- Phase 2: Triage & Queuing ---
            System.debug('Phase 2: Building master work queue...');
            List<TicketWrapper> masterWorkQueue = buildAndSortMasterQueue(allTickets, developers.keySet());
            System.debug('Master work queue size: ' + masterWorkQueue.size());
            
            for(Integer i = 0; i < masterWorkQueue.size(); i++) {
                TicketWrapper wrapper = masterWorkQueue[i];
                System.debug('Queue position ' + i + ': Ticket ' + wrapper.ticket.Id + ' (' + wrapper.ticket.Name + ') - Stage: ' + wrapper.ticket.StageNamePk__c + ', Priority: ' + wrapper.ticket.PriorityPk__c);
            }

            // --- Phase 3: The Simulation Loop ---
            System.debug('Phase 3: Starting simulation loop...');
            List<Ticket__c> ticketsToUpdate = new List<Ticket__c>();
            
            for(TicketWrapper wrapper : masterWorkQueue) {
                System.debug('Processing ticket: ' + wrapper.ticket.Id + ' (' + wrapper.ticket.Name + ')');
                
                // a. Determine the Resource
                Id assignedDevId = wrapper.ticket.Developer__c;
                System.debug('Original assigned developer: ' + assignedDevId);
                
                if (assignedDevId == null || !developers.containsKey(assignedDevId)) {
                    System.debug('Finding next available developer...');
                    assignedDevId = findNextAvailableDeveloper(devNextAvailableDate);
                    System.debug('Next available developer: ' + assignedDevId);
                }

                if(assignedDevId == null) {
                    System.debug('WARNING: No developers available for ticket ' + wrapper.ticket.Id + ', skipping');
                    continue; // No developers available, cannot schedule.
                }

                // b. Find Start Date (cannot be in the past)
                Date devAvailableDate = devNextAvailableDate.get(assignedDevId);
                Date startDate = (Date.today() > devAvailableDate) ? Date.today() : devAvailableDate;
                wrapper.ticket.EstimatedStartDevDate__c = startDate;
                System.debug('Calculated start date: ' + startDate + ' for developer: ' + assignedDevId);

                // c. Calculate Work Duration
                Decimal effort = wrapper.ticket.DeveloperDaysSizeNumber__c == null ? 0 : wrapper.ticket.DeveloperDaysSizeNumber__c;
                System.debug('Effort in days: ' + effort);
                Date completionDate = addBusinessDays(startDate, Integer.valueOf(effort));
                wrapper.ticket.EstimatedEndDevDate__c = completionDate;
                System.debug('Calculated completion date: ' + completionDate);

                // d. Update Developer's Schedule for the next ticket
                Date nextAvailable = addBusinessDays(completionDate, 1);
                devNextAvailableDate.put(assignedDevId, nextAvailable);
                System.debug('Updated developer ' + assignedDevId + ' next available date to: ' + nextAvailable);

                // e. Calculate Final ETA with UAT Buffer
                Decimal buffer = config.UATBufferDaysNumber__c == null ? 0 : config.UATBufferDaysNumber__c;
                System.debug('UAT buffer days: ' + buffer);
                wrapper.ticket.ProjectedUATReadyDate__c = addBusinessDays(completionDate, Integer.valueOf(buffer));
                System.debug('Final projected UAT ready date: ' + wrapper.ticket.ProjectedUATReadyDate__c);

                // f. Add to list for final DML update
                ticketsToUpdate.add(wrapper.ticket);
                this.processedTicketIds.add(wrapper.ticket.Id);
                System.debug('Added ticket ' + wrapper.ticket.Id + ' to update list and processed IDs');
            }

            System.debug('Processed ticket IDs: ' + this.processedTicketIds);
            System.debug('Tickets to update count: ' + ticketsToUpdate.size());

            // Null out dates for any tickets that were NOT in the queue (i.e., blocked or post-dev)
            System.debug('Nulling out dates for tickets not in queue...');
            Integer nulledCount = 0;
            for (Ticket__c ticket : allTickets) {
                if (!this.processedTicketIds.contains(ticket.Id)) {
                    ticketsToUpdate.add(new Ticket__c(
                        Id = ticket.Id,
                        EstimatedStartDevDate__c = null,
                        EstimatedEndDevDate__c = null,
                        ProjectedUATReadyDate__c = null
                    ));
                    nulledCount++;
                }
            }
            System.debug('Nulled out dates for ' + nulledCount + ' tickets');
            System.debug('Final tickets to update count: ' + ticketsToUpdate.size());

            if (!ticketsToUpdate.isEmpty()) {
                System.debug('Performing database update...');
                Database.SaveResult[] results = Database.update(ticketsToUpdate, false); // Use partial success for robustness
                
                Integer successCount = 0;
                Integer failureCount = 0;
                for(Database.SaveResult result : results) {
                    if(result.isSuccess()) {
                        successCount++;
                    } else {
                        failureCount++;
                        System.debug('Update failed for record: ' + result.getErrors());
                    }
                }
                System.debug('Database update completed - Success: ' + successCount + ', Failures: ' + failureCount);
            } else {
                System.debug('No tickets to update');
            }
            
            System.debug('=== ETACalculator.execute() END ===');
        }

        // --- Helper Methods for the Calculator ---

        private boolean loadConfiguration() {
            System.debug('Loading Kanban configuration...');
            List<Kanban_Configuration__mdt> configs = [
                SELECT PreDevelopmentStagesTxt__c, ActiveDevelopmentStagesTxt__c, BlockedStagesTxt__c,
                       PostDevelopmentStagesTxt__c, PriorityWeightsTxt__c, UATBufferDaysNumber__c
                FROM Kanban_Configuration__mdt LIMIT 1
            ];
            System.debug('Found ' + configs.size() + ' configuration records');
            
            if (configs.isEmpty()) {
                System.debug(System.LoggingLevel.ERROR, 'ETA Service Error: Kanban_Configuration__mdt record not found.');
                return false;
            }
            this.config = configs[0];
            System.debug('Loaded configuration: ' + this.config);
            System.debug('PreDevelopmentStagesTxt__c: ' + this.config.PreDevelopmentStagesTxt__c);
            System.debug('ActiveDevelopmentStagesTxt__c: ' + this.config.ActiveDevelopmentStagesTxt__c);
            System.debug('BlockedStagesTxt__c: ' + this.config.BlockedStagesTxt__c);
            System.debug('PostDevelopmentStagesTxt__c: ' + this.config.PostDevelopmentStagesTxt__c);
            System.debug('PriorityWeightsTxt__c: ' + this.config.PriorityWeightsTxt__c);
            System.debug('UATBufferDaysNumber__c: ' + this.config.UATBufferDaysNumber__c);
            return true;
        }

        private Map<Id, User> loadResources() {
            System.debug('Loading developer resources...');
            List<User> developers = [
                SELECT Id, Name FROM User WHERE IsActive = TRUE
            ];
            System.debug('Found ' + developers.size() + ' active developers');
            for(User dev : developers) {
                System.debug('Developer: ' + dev.Id + ' - ' + dev.Name);
            }
            return new Map<Id, User>(developers);
        }

        private List<Ticket__c> loadTickets() {
            System.debug('Loading all tickets...');
            List<Ticket__c> tickets = [
                SELECT Id, Name, StageNamePk__c, PriorityPk__c, DeveloperDaysSizeNumber__c,
                       SortOrderNumber__c, Developer__c, CreatedDate
                FROM Ticket__c
            ];
            System.debug('Found ' + tickets.size() + ' total tickets');
            for(Ticket__c ticket : tickets) {
                System.debug('Ticket: ' + ticket.Id + ' (' + ticket.Name + ') - Stage: ' + ticket.StageNamePk__c + ', Priority: ' + ticket.PriorityPk__c + ', Size: ' + ticket.DeveloperDaysSizeNumber__c);
            }
            return tickets;
        }

        private List<TicketWrapper> buildAndSortMasterQueue(List<Ticket__c> allTickets, Set<Id> developerIds) {
            System.debug('Building master work queue...');

            Set<Id> incompleteTicketIds = new Set<Id>();
            for(Ticket__c t : allTickets) {
                if (t.StageNamePk__c != 'Done' && t.StageNamePk__c != 'Deployed to Prod') {
                    incompleteTicketIds.add(t.Id);
                }
            }

            // 2. Find all dependencies where the blocker is one of these incomplete tickets
            Set<Id> allBlockedTicketIds = new Set<Id>();
            for (Ticket_Dependency__c dep : [SELECT Blocked_Ticket__c FROM Ticket_Dependency__c WHERE Blocking_Ticket__c IN :incompleteTicketIds]) {
                allBlockedTicketIds.add(dep.Blocked_Ticket__c);
            }
            
            if(config.PreDevelopmentStagesTxt__c == null) {
                System.debug('WARNING: PreDevelopmentStagesTxt__c is null');
            }
            if(config.ActiveDevelopmentStagesTxt__c == null) {
                System.debug('WARNING: ActiveDevelopmentStagesTxt__c is null');
            }
            
            Set<String> preDev = new Set<String>();
            if(config.PreDevelopmentStagesTxt__c != null) {
                preDev = new Set<String>(config.PreDevelopmentStagesTxt__c.toLowerCase().split(','));
            }
            System.debug('Pre-development stages: ' + preDev);
            
            Set<String> activeDev = new Set<String>();
            if(config.ActiveDevelopmentStagesTxt__c != null) {
                activeDev = new Set<String>(config.ActiveDevelopmentStagesTxt__c.toLowerCase().split(','));
            }
            System.debug('Active development stages: ' + activeDev);
            
            Map<String, Decimal> priorityWeights = new Map<String, Decimal>();
            if(config.PriorityWeightsTxt__c != null) {
                try {
                    priorityWeights = (Map<String, Decimal>)JSON.deserialize(config.PriorityWeightsTxt__c, Map<String, Decimal>.class);
                } catch(Exception e) {
                    System.debug('ERROR parsing PriorityWeightsTxt__c JSON: ' + e.getMessage());
                }
            }
            System.debug('Priority weights: ' + priorityWeights);

            List<TicketWrapper> queue = new List<TicketWrapper>();
            Integer queuedCount = 0;
            Integer skippedCount = 0;
            
            for(Ticket__c t : allTickets){
                if (allBlockedTicketIds.contains(t.Id)) {
                    System.debug('Ticket ' + t.Id + ' SKIPPED - It is blocked by an incomplete ticket.');
                    skippedCount++;
                    continue; // Go to the next ticket
                }
                String stage = t.StageNamePk__c == null ? '' : t.StageNamePk__c.toLowerCase().trim();
                System.debug('Evaluating ticket ' + t.Id + ' (' + t.Name + ') with stage: "' + stage + '"');
                
                // A ticket is only queued if it's in a pre-dev or active-dev stage
                if(preDev.contains(stage) || activeDev.contains(stage)){
                    System.debug('Ticket ' + t.Id + ' QUEUED - stage "' + stage + '" matches pre-dev or active-dev');
                    queue.add(new TicketWrapper(t, config, priorityWeights, this.prioritizedTicketIds));
                    queuedCount++;
                } else {
                    System.debug('Ticket ' + t.Id + ' SKIPPED - stage "' + stage + '" does not match pre-dev or active-dev');
                    skippedCount++;
                }
            }
            
            System.debug('Queue building complete - Queued: ' + queuedCount + ', Skipped: ' + skippedCount);
            System.debug('Pre-sort queue size: ' + queue.size());
            
            // Sort the entire list based on the complex business rules in the wrapper
            queue.sort();
            System.debug('Post-sort queue size: ' + queue.size());
            
            return queue;
        }
        
        private Id findNextAvailableDeveloper(Map<Id, Date> devSchedules) {
            System.debug('Finding next available developer from schedules: ' + devSchedules);
            Id nextDev = null;
            Date earliestDate = null;

            if (devSchedules.isEmpty()) {
                System.debug('No developer schedules available');
                return null;
            }

            for(Id devId : devSchedules.keySet()){
                Date thisDate = devSchedules.get(devId);
                System.debug('Developer ' + devId + ' available on: ' + thisDate);
                if(earliestDate == null || thisDate < earliestDate){
                    earliestDate = thisDate;
                    nextDev = devId;
                    System.debug('New earliest developer: ' + nextDev + ' on ' + earliestDate);
                }
            }
            System.debug('Selected developer: ' + nextDev + ' available on: ' + earliestDate);
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
     * @description Wrapper class for Ticket__c to implement complex, multi-level sorting.
     */
    private class TicketWrapper implements Comparable {
        public Ticket__c ticket { get; private set; }
        private final Integer stageCategory;     // 1 for ACTIVE_DEV, 2 for PRE_DEV
        private final Decimal priorityWeight;    // Lower is better (e.g., High=1, Med=2)
        private final Boolean isPrioritizedByLWC; // Absolute highest priority

        public TicketWrapper(Ticket__c t, Kanban_Configuration__mdt config, Map<String, Decimal> priorityWeights, Set<Id> prioritizedIds) {
            System.debug('Creating TicketWrapper for ticket: ' + t.Id + ' (' + t.Name + ')');
            this.ticket = t;
            this.isPrioritizedByLWC = prioritizedIds.contains(t.Id);
            System.debug('Is prioritized by LWC: ' + this.isPrioritizedByLWC);

            Set<String> activeDev = new Set<String>();
            if(config.ActiveDevelopmentStagesTxt__c != null) {
                activeDev = new Set<String>(config.ActiveDevelopmentStagesTxt__c.toLowerCase().split(','));
            }
            String stage = t.StageNamePk__c == null ? '' : t.StageNamePk__c.toLowerCase().trim();
            this.stageCategory = activeDev.contains(stage) ? 1 : 2;
            System.debug('Stage: "' + stage + '", Category: ' + this.stageCategory + ' (1=Active, 2=Pre-dev)');

            this.priorityWeight = priorityWeights.get(t.PriorityPk__c);
            if (this.priorityWeight == null) this.priorityWeight = 999;
            System.debug('Priority: ' + t.PriorityPk__c + ', Weight: ' + this.priorityWeight);
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

public with sharing class DH_TicketETAService {
    // Main method: get ETAs, allowing prioritization of one or more tickets to the front of the dev queue.
    @AuraEnabled(cacheable=true)
    public static TicketETAResult getTicketETAsWithPriority(
        Decimal numberOfDevs, 
        List<Id> prioritizedTicketIds
    ) {
        List<DH_Ticket__c> tickets = [
            SELECT Id, Name, BriefDescriptionTxt__c, PriorityPk__c, DeveloperDaysSizeNumber__c, 
                   SortOrderNumber__c, StageNamePk__c
            FROM DH_Ticket__c WHERE IsActiveBool__c = true
        ];
        return calculateTicketETAs(tickets, numberOfDevs, prioritizedTicketIds);
    }

    public static TicketETAResult calculateTicketETAs(
        List<DH_Ticket__c> tickets, Decimal numberOfDevs, List<Id> prioritizedTicketIds
    ) {
        // Status groupings
        Set<String> inDevStages = new Set<String>{'In Development', 'Back For Development'};
        Set<String> doneStages = new Set<String>{'Done', 'Deployed to Prod', 'Cancelled'};

        // Group tickets
        List<DH_Ticket__c> inDev = new List<DH_Ticket__c>();
        List<DH_Ticket__c> prioritized = new List<DH_Ticket__c>();
        List<DH_Ticket__c> queue = new List<DH_Ticket__c>();

        for (DH_Ticket__c t : tickets) {
            if (doneStages.contains(t.StageNamePk__c)) continue;
            else if (inDevStages.contains(t.StageNamePk__c)) inDev.add(t);
            else if (prioritizedTicketIds != null && prioritizedTicketIds.contains(t.Id)) prioritized.add(t);
            else queue.add(t);
        }

        // Sort each group by your board/picklist order, then priority, then SortOrderNumber__c
        inDev = sortTicketsByStatusPriorityOrder(inDev);
        prioritized = sortTicketsByStatusPriorityOrder(prioritized);
        queue = sortTicketsByStatusPriorityOrder(queue);

        // Build the ETA calculation queue: inDev (fixed), prioritized (to top), then queue
        List<DH_Ticket__c> etaSchedule = new List<DH_Ticket__c>();
        etaSchedule.addAll(inDev);
        etaSchedule.addAll(prioritized);
        etaSchedule.addAll(queue);

        // Dev scheduling
        List<Date> devAvailableDates = new List<Date>();
        Date today = Date.today();
        Integer devs = Math.max(1, numberOfDevs == null ? 1 : numberOfDevs.intValue());
        for (Integer i = 0; i < devs; i++) devAvailableDates.add(today);

        List<TicketETADTO> results = new List<TicketETADTO>();

        // Track which tickets were pushed back by prioritization (the ones after prioritized in the queue)
        Set<Id> prioritizedSet = prioritizedTicketIds == null ? new Set<Id>() : new Set<Id>(prioritizedTicketIds);
        Boolean afterPrioritized = false;
        List<String> pushedBackTicketNumbers = new List<String>();

        for (DH_Ticket__c ticket : etaSchedule) {
            // If we get to the first non-inDev, non-prioritized ticket, all tickets after this are "pushed back"
            if (!inDevStages.contains(ticket.StageNamePk__c) && 
                !(prioritizedSet.contains(ticket.Id)) && 
                prioritizedSet.size() > 0) {
                afterPrioritized = true;
            }
            if (afterPrioritized) {
                pushedBackTicketNumbers.add(ticket.Name);
            }

            TicketETADTO dto = new TicketETADTO();
            dto.ticketId = ticket.Id;
            dto.ticketNumber = ticket.Name;
            dto.briefDescription = ticket.BriefDescriptionTxt__c;
            dto.priority = ticket.PriorityPk__c;
            dto.size = ticket.DeveloperDaysSizeNumber__c == null ? 1 : ticket.DeveloperDaysSizeNumber__c;
            dto.stage = ticket.StageNamePk__c;

            if (doneStages.contains(ticket.StageNamePk__c)) {
                dto.estimatedStartDev = null;
                dto.estimatedEndDev = null;
                dto.calculatedETA = null;
            } else {
                Integer nextDev = 0;
                Date minDate = devAvailableDates[0];
                for (Integer d = 1; d < devs; d++) {
                    if (devAvailableDates[d] < minDate) {
                        minDate = devAvailableDates[d];
                        nextDev = d;
                    }
                }
                Decimal sizeDays = dto.size;
                Date startDev = minDate;
                Date endDev = startDev.addDays(sizeDays.intValue() - 1);
                Date calcEta = endDev.addDays(2); // 2-day buffer

                devAvailableDates[nextDev] = endDev.addDays(1);

                dto.estimatedStartDev = startDev;
                dto.estimatedEndDev = endDev;
                dto.calculatedETA = calcEta;
            }
            results.add(dto);
        }

        TicketETAResult res = new TicketETAResult();
        res.tickets = results;
        res.pushedBackTicketNumbers = pushedBackTicketNumbers;
        return res;
    }

    // Drag-and-drop board/picklist order
    private static final List<String> stageOrder = new List<String>{
        'Backlog',
        'Active Scoping',
        'Client Clarification (Pre-Dev)',
        'Needs Dev Feedback (T-Shirt Sizing)',
        'Pending Client Prioritization',
        'Needs Dev Feedback (Proposal)',
        'Pending Development Approval',
        'Pending Client Approval',
        'Ready for Development',
        'In Development',
        'Dev Blocked',
        'Client Clarification (In-Dev)',
        'Back For Development',
        'Dev Complete',
        'Ready for Scratch Org Test',
        'Ready for QA',
        'In QA',
        'In UAT',
        'Ready for UAT (Consultant)',
        'Ready for UAT (Client)',
        'Ready for UAT Approval',
        'Ready for Feature Merge',
        'Ready for Deployment',
        'Deployed to Prod',
        'Done',
        'Cancelled'
    };

    private static List<DH_Ticket__c> sortTicketsByStatusPriorityOrder(List<DH_Ticket__c> tickets) {
        List<DH_Ticket__c> sorted = tickets.deepClone(true, true, true);
        Integer n = sorted.size();
        for (Integer i = 0; i < n-1; i++) {
            for (Integer j = 0; j < n-i-1; j++) {
                DH_Ticket__c a = sorted[j];
                DH_Ticket__c b = sorted[j+1];
                Integer stageA = getStageSortOrder(a.StageNamePk__c, stageOrder);
                Integer stageB = getStageSortOrder(b.StageNamePk__c, stageOrder);

                Integer prioA = getPrioritySortOrder(a.PriorityPk__c);
                Integer prioB = getPrioritySortOrder(b.PriorityPk__c);
                Integer orderA = a.SortOrderNumber__c == null ? 9999 : (Integer)a.SortOrderNumber__c;
                Integer orderB = b.SortOrderNumber__c == null ? 9999 : (Integer)b.SortOrderNumber__c;
                if (stageA > stageB
                    || (stageA == stageB && prioA > prioB)
                    || (stageA == stageB && prioA == prioB && orderA > orderB)) {
                    DH_Ticket__c temp = sorted[j];
                    sorted[j] = sorted[j+1];
                    sorted[j+1] = temp;
                }
            }
        }
        return sorted;
    }

    private static Integer getStageSortOrder(String stage, List<String> stageOrder) {
        for (Integer i = 0; i < stageOrder.size(); i++) {
            if (stageOrder[i] == stage) return i;
        }
        return 999;
    }

    private static Integer getPrioritySortOrder(String prio) {
        if (prio == 'Urgent') return 0;
        if (prio == 'High') return 1;
        if (prio == 'Medium') return 2;
        if (prio == 'Low') return 3;
        return 99;
    }

    // DTO for UI use
    public class TicketETADTO {
        @AuraEnabled public String ticketId;
        @AuraEnabled public String ticketNumber;
        @AuraEnabled public String briefDescription;
        @AuraEnabled public String priority;
        @AuraEnabled public Decimal size;
        @AuraEnabled public Date estimatedStartDev;
        @AuraEnabled public Date estimatedEndDev;
        @AuraEnabled public Date calculatedETA;
        @AuraEnabled public String stage;

        public override String toString() {
            return 'TicketETADTO [ticketId=' + ticketId + ', ticketNumber=' + ticketNumber + ', calculatedETA=' + calculatedETA + ']';
        }
    }

    // Wrapper for results
    public class TicketETAResult {
        @AuraEnabled public List<TicketETADTO> tickets;
        @AuraEnabled public List<String> pushedBackTicketNumbers;
    }
}
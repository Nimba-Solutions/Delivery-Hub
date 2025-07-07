/**
* @File Name : DH_TicketETAService.cls
* @Description :
* @Author :
* @Last Modified By :
* @Last Modified On : July 7, 2025
* @Modification Log :
*==============================================================================
* Ver | Date | Author | Modification
*==============================================================================
* 1.0 | July 7, 2025 |   | Initial Version
**/

public with sharing class DH_TicketETAService {
    @AuraEnabled(cacheable=true)
    public static List<TicketETADTO> getTicketETAs(Decimal numberOfDevs) {
        List<DH_Ticket__c> tickets = [
            SELECT Id, Name, BriefDescriptionTxt__c, PriorityPk__c, DeveloperDaysSizeNumber__c, SortOrderNumber__c
            FROM DH_Ticket__c WHERE IsActiveBool__c = true ORDER BY PriorityPk__c, SortOrderNumber__c
        ];
        return calculateTicketETAs(tickets, numberOfDevs);
    }

    @AuraEnabled(cacheable=true)
    public static List<TicketETADTO> calculateTicketETAs(List<DH_Ticket__c> tickets, Decimal numberOfDevs) {
        tickets = sortTickets(tickets);

        List<Date> devAvailableDates = new List<Date>();
        Date today = Date.today();
        Integer devs = Math.max(1, numberOfDevs == null ? 1 : numberOfDevs.intValue());
        for (Integer i = 0; i < devs; i++) devAvailableDates.add(today);

        List<TicketETADTO> results = new List<TicketETADTO>();
        for (DH_Ticket__c ticket : tickets) {
            Integer nextDev = 0;
            Date minDate = devAvailableDates[0];
            for (Integer d = 1; d < devs; d++) {
                if (devAvailableDates[d] < minDate) {
                    minDate = devAvailableDates[d];
                    nextDev = d;
                }
            }
            Decimal sizeDays = ticket.DeveloperDaysSizeNumber__c == null ? 1 : ticket.DeveloperDaysSizeNumber__c;
            Date startDev = minDate;
            Date endDev = startDev.addDays(sizeDays.intValue() - 1);
            Date calcEta = endDev.addDays(2);
            devAvailableDates[nextDev] = endDev.addDays(1);

            TicketETADTO dto = new TicketETADTO();
            dto.ticketId = ticket.Id;
            dto.ticketNumber = ticket.Name;
            dto.briefDescription = ticket.BriefDescriptionTxt__c;
            dto.priority = ticket.PriorityPk__c;
            dto.size = sizeDays;
            dto.estimatedStartDev = startDev;
            dto.estimatedEndDev = endDev;
            dto.calculatedETA = calcEta;
            results.add(dto);
        }
        return results;
    }

    private static List<DH_Ticket__c> sortTickets(List<DH_Ticket__c> tickets) {
        // Preserve Ids!
        List<DH_Ticket__c> sorted = tickets.deepClone(true, true, true);
        Integer n = sorted.size();
        for (Integer i = 0; i < n-1; i++) {
            for (Integer j = 0; j < n-i-1; j++) {
                DH_Ticket__c a = sorted[j];
                DH_Ticket__c b = sorted[j+1];
                Integer prioA = getPrioritySortOrder(a.PriorityPk__c);
                Integer prioB = getPrioritySortOrder(b.PriorityPk__c);
                if (prioA > prioB || (prioA == prioB &&
                    ((a.SortOrderNumber__c == null ? 9999 : (Integer)a.SortOrderNumber__c) >
                    (b.SortOrderNumber__c == null ? 9999 : (Integer)b.SortOrderNumber__c)))) {
                    DH_Ticket__c temp = sorted[j];
                    sorted[j] = sorted[j+1];
                    sorted[j+1] = temp;
                }
            }
        }
        return sorted;
    }

    private static Integer getPrioritySortOrder(String prio) {
        if (prio == 'Urgent') return 0;
        if (prio == 'High') return 1;
        if (prio == 'Medium') return 2;
        if (prio == 'Low') return 3;
        return 99;
    }

    public class TicketETADTO {
        @AuraEnabled public String ticketId;
        @AuraEnabled public String ticketNumber;
        @AuraEnabled public String briefDescription;
        @AuraEnabled public String priority;
        @AuraEnabled public Decimal size;
        @AuraEnabled public Date estimatedStartDev;
        @AuraEnabled public Date estimatedEndDev;
        @AuraEnabled public Date calculatedETA;

        public override String toString() {
            return 'TicketETADTO [ticketId=' + ticketId + ', ticketNumber=' + ticketNumber + ', calculatedETA=' + calculatedETA + ']';
        }
    }
}
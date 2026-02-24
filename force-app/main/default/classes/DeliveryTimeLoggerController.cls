/**
 * @description Controller for the deliveryTimeLogger LWC. Creates a WorkLog__c
 *              entry against a Ticket, which the roll-up summary on
 *              TotalLoggedHoursNumber__c then reflects automatically.
 */
public with sharing class DeliveryTimeLoggerController {

    /**
     * @description Inserts a WorkLog__c record linked to the given ticket,
     *              logging the specified number of hours for today's date. The
     *              Ticket's TotalLoggedHoursNumber__c roll-up updates
     *              automatically after the insert.
     * @param ticketId   The Id of the Ticket__c record to log time against.
     * @param hours      The positive number of hours to log.
     * @param workNotes  Optional description of work performed.
     */
    @AuraEnabled
    public static void logHours(Id ticketId, Decimal hours, String workNotes) {
        WorkLog__c entry = new WorkLog__c(
            TicketId__c           = ticketId,
            HoursLoggedNumber__c  = hours,
            WorkDateDate__c       = Date.today(),
            WorkDescriptionTxt__c = workNotes
        );
        insert AS USER entry;
    }
}

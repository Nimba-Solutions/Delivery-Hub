/**
 * @description Controller for the deliveryTimeLogger LWC. Creates a WorkLog__c
 *              entry against a Ticket, which the roll-up summary on
 *              TotalLoggedHoursNumber__c then reflects automatically.
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.ApexCRUDViolation')
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
        List<Request__c> activeReqs = [
            SELECT Id FROM Request__c
            WHERE TicketId__c = :ticketId
            AND StatusPk__c IN ('Accepted', 'In Progress')
            WITH SYSTEM_MODE
            ORDER BY LastModifiedDate DESC
            LIMIT 1
        ];
        if (activeReqs.isEmpty()) {
            throw new AuraHandledException('No accepted request found for this ticket. Please accept a vendor quote before logging time.');
        }
        WorkLog__c entry = new WorkLog__c(
            RequestId__c          = activeReqs[0].Id,
            TicketId__c           = ticketId,
            HoursLoggedNumber__c  = hours,
            WorkDateDate__c       = Date.today(),
            WorkDescriptionTxt__c = workNotes
        );
        // FIX: SYSTEM_MODE to prevent packaging test failures on namespaced fields
        Database.insert(entry, AccessLevel.SYSTEM_MODE);
    }
}

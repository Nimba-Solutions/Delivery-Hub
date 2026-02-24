/**
 * @description Controller for the deliveryTimeLogger LWC. Handles logging
 *              time against a Ticket__c record by incrementing the total
 *              logged hours field.
 */
public with sharing class DeliveryTimeLoggerController {

    /**
     * @description Adds the specified number of hours to the ticket's
     *              TotalLoggedHoursNumber__c field. The increment is applied
     *              atomically via a DML update executed as the running user.
     * @param ticketId The Id of the Ticket__c record to update.
     * @param hours    The positive number of hours to add.
     */
    @AuraEnabled
    public static void logHours(Id ticketId, Decimal hours) {
        Ticket__c t = [
            SELECT TotalLoggedHoursNumber__c
            FROM Ticket__c
            WHERE Id = :ticketId
            WITH USER_MODE
            LIMIT 1
        ];
        Decimal current = t.TotalLoggedHoursNumber__c != null ? t.TotalLoggedHoursNumber__c : 0;
        t.TotalLoggedHoursNumber__c = current + hours;
        update AS USER t;
    }
}

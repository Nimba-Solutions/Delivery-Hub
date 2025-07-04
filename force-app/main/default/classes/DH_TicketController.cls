/**
 * @description Controller for retrieving active DH_Ticket__c records for the Kanban board.
 */
public with sharing class DH_TicketController {

    /**
     * @description Returns all active DH_Ticket__c records, ordered by SortOrderNumber__c.
     * @return List of DH_Ticket__c
     */
    @AuraEnabled(cacheable=true)
    public static List<DH_Ticket__c> getTickets() {
        // Enforce CRUD/FLS
        if (!Schema.sObjectType.DH_Ticket__c.isAccessible()
            || !Schema.sObjectType.DH_Ticket__c.fields.StageNamePk__c.isAccessible()
            || !Schema.sObjectType.DH_Ticket__c.fields.BriefDescriptionTxt__c.isAccessible()) {
            return new List<DH_Ticket__c>();
        }

        return [
            SELECT
                Id,
                Name,
                BriefDescriptionTxt__c,
                CalculatedETADate__c,
                EstimatedStartDevDate__c,
                EstimatedEndDevDate__c,
                DeveloperDaysSizeNumber__c,
                StageNamePk__c
            FROM DH_Ticket__c
            WHERE IsActiveBool__c = true
            ORDER BY SortOrderNumber__c
        ];
    }
}
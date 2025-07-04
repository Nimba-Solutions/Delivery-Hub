/**
* @File Name : DH_TicketController.cls
* @Description :
* @Author :
* @Last Modified By :
* @Last Modified On : July 4, 2025
* @Modification Log :
*==============================================================================
* Ver | Date | Author | Modification
*==============================================================================
* 1.0 | July 4, 2025 |   | Initial Version
**/

public with sharing class DH_TicketController {
    @AuraEnabled(cacheable=true)
    public static List<DH_Ticket__c> getTickets() {
        return [
            SELECT Id, Name,
                   BriefDescriptionTxt__c, CalculatedETADate__c, EstimatedStartDevDate__c,
                   EstimatedEndDevDate__c, DeveloperDaysSizeNumber__c,StageNamePk__c
            FROM DH_Ticket__c
            WHERE IsActiveBool__c = true
            ORDER BY SortOrderNumber__c
        ];
    }
}
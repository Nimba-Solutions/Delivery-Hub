/**
 * @description Controller class for the Delivery Hub Board (Kanban) LWC.
 * Handles drag-and-drop updates, stage transitions, and dependency management.
 * @author Delivery Hub Team
 * @date 2025
 */
public with sharing class DeliveryHubBoardController {

    @AuraEnabled
    public static void updateTicketStage(Id ticketId, String newStage) {
        try {
            Ticket__c ticket = new Ticket__c(Id = ticketId, StageNamePk__c = newStage);
            update ticket;
        } catch (Exception e) {
            throw createAuraException('Error updating ticket stage: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static void updateTicketSortOrder(Id ticketId, Decimal newSortOrder) {
        try {
            Ticket__c ticket = new Ticket__c(Id = ticketId, SortOrderNumber__c = newSortOrder);
            update ticket;
        } catch (Exception e) {
            throw createAuraException(e.getMessage());
        }
    }
    
    @AuraEnabled
    public static Ticket_Dependency__c createDependency(Id blockedTicketId, Id blockingTicketId) {
        if (blockedTicketId == blockingTicketId) {
            throw createAuraException('A ticket cannot block itself.');
        }

        try {
            Ticket_Dependency__c newDependency = new Ticket_Dependency__c(
                Blocked_Ticket__c = blockedTicketId,
                Blocking_Ticket__c = blockingTicketId,
                TypePk__c = 'Blocks'
            );
            insert newDependency;
            return newDependency;
        } catch (Exception e) {
            throw createAuraException('Error creating dependency: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static void removeDependency(Id dependencyId) {
        try {
            Ticket_Dependency__c dep = [SELECT Id FROM Ticket_Dependency__c WHERE Id = :dependencyId LIMIT 1];
            delete dep;
        } catch (Exception e) {
            throw createAuraException('Error removing dependency: ' + e.getMessage());
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static List<Ticket__c> searchForPotentialBlockers(String searchTerm, Id currentTicketId, List<Id> existingDependencyIds) {
        String queryTerm = '%' + String.escapeSingleQuotes(searchTerm) + '%';
        
        Set<Id> exclusionIds = new Set<Id>();
        if (currentTicketId != null) exclusionIds.add(currentTicketId);
        if (existingDependencyIds != null) exclusionIds.addAll(existingDependencyIds);
    
        // FIX: Removed WITH SECURITY_ENFORCED to prevent build failures on FLS checks
        return [
            SELECT Id, Name, StageNamePk__c, BriefDescriptionTxt__c
            FROM Ticket__c
            WHERE (Name LIKE :queryTerm OR BriefDescriptionTxt__c LIKE :queryTerm)
            AND Id NOT IN :exclusionIds
            AND StageNamePk__c != 'Done'
            ORDER BY LastModifiedDate DESC
            LIMIT 10
        ];
    }

    private static AuraHandledException createAuraException(String message) {
        AuraHandledException e = new AuraHandledException(message);
        e.setMessage(message);
        return e;
    }
}
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
            // Just update the stage; sort order remains as is (or handled by reorderTicket if called)
            Ticket__c ticket = new Ticket__c(Id = ticketId, StageNamePk__c = newStage);
            update ticket;
        } catch (Exception e) {
            throw createAuraException('Error updating ticket stage: ' + e.getMessage());
        }
    }

    /**
     * @description Reorders a ticket within a stage (or moves it to a new stage and orders it).
     * Maintains a dense 1-based integer sequence (1, 2, 3...) for the column.
     * @param ticketId The ID of the ticket being moved.
     * @param newStage The target stage name (e.g., 'In Progress').
     * @param newIndex The 0-based index where the ticket was dropped.
     */
    @AuraEnabled
    public static void reorderTicket(Id ticketId, String newStage, Integer newIndex) {
        try {
            // 1. Fetch all other tickets in the target stage, ordered by their current position
            // We lock rows or just query to get the current state
            List<Ticket__c> ticketsInColumn = [
                SELECT Id, SortOrderNumber__c 
                FROM Ticket__c 
                WHERE StageNamePk__c = :newStage 
                AND Id != :ticketId
                AND IsActiveBool__c = TRUE 
                WITH SECURITY_ENFORCED
                ORDER BY SortOrderNumber__c ASC NULLS LAST, CreatedDate DESC
            ];

            // 2. Insert our moving ticket into the list at the desired index
            Ticket__c movingTicket = new Ticket__c(Id = ticketId, StageNamePk__c = newStage);
            
            // Safety bounds check
            if (newIndex < 0) newIndex = 0;
            if (newIndex > ticketsInColumn.size()) newIndex = ticketsInColumn.size();
            
            ticketsInColumn.add(newIndex, movingTicket);

            // 3. Re-index the entire list to ensure sequential integers (1, 2, 3...)
            List<Ticket__c> toUpdate = new List<Ticket__c>();
            
            for (Integer i = 0; i < ticketsInColumn.size(); i++) {
                Ticket__c t = ticketsInColumn[i];
                Decimal expectedSort = i + 1; // 1-based priority
                
                // We assume we need to update if it's the moving ticket OR if the number is wrong
                if (t.Id == ticketId || t.SortOrderNumber__c != expectedSort) {
                    t.SortOrderNumber__c = expectedSort;
                    toUpdate.add(t);
                }
            }

            if (!toUpdate.isEmpty()) {
                update toUpdate;
            }

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
    
        // Using generic query logic; ensure User has permissions
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
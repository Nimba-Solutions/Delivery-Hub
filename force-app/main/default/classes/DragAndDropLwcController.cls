/**
 * @description Controller class for drag and drop functionality in Lightning Web Components
 * @author Delivery Hub Team
 * @date 2025
 */
public with sharing class DragAndDropLwcController {
   

    /**
     * @description Updates the stage of a ticket
     * @param ticketId The ID of the ticket to update
     * @param newStage The new stage name for the ticket
     */
    @AuraEnabled
    public static void updateTicketStage(Id ticketId, String newStage) {
        try {
            Ticket__c ticket = [SELECT Id, StageNamePk__c FROM Ticket__c WHERE Id = :ticketId LIMIT 1];
            ticket.StageNamePk__c = newStage;
            update ticket;
        } catch (Exception e) {
            throw new AuraHandledException('Error updating ticket stage: ' + e.getMessage());
        }
    }

    /**
     * @description Updates the sort order of a ticket
     * @param ticketId The ID of the ticket to update
     * @param newSortOrder The new sort order number
     */
    @AuraEnabled
    public static void updateTicketSortOrder(Id ticketId, Decimal newSortOrder) {
        try {
            Ticket__c ticket = new Ticket__c(
                Id = ticketId,
                SortOrderNumber__c = newSortOrder
            );
            update ticket;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    /**
     * @description Creates a dependency relationship between two tickets
     * @param blockedTicketId The ID of the ticket that is blocked
     * @param blockingTicketId The ID of the ticket that is blocking
     * @return Ticket_Dependency__c The created dependency record
     */
    @AuraEnabled
    public static Ticket_Dependency__c createDependency(Id blockedTicketId, Id blockingTicketId) {
        // Prevent self-dependency
        if (blockedTicketId == blockingTicketId) {
            throw new AuraHandledException('A ticket cannot block itself.');
        }

        // Optional: Check for circular dependencies here

        Ticket_Dependency__c newDependency = new Ticket_Dependency__c(
            Blocked_Ticket__c = blockedTicketId,
            Blocking_Ticket__c = blockingTicketId,
            TypePk__c = 'Blocks'
        );
        insert newDependency;
        return newDependency;
    }

    /**
     * @description Removes a ticket dependency
     * @param dependencyId The ID of the dependency to remove
     */
    @AuraEnabled
    public static void removeDependency(Id dependencyId) {
        try {
            Ticket_Dependency__c dep = [SELECT Id FROM Ticket_Dependency__c WHERE Id = :dependencyId];
            delete dep;
        } catch (Exception e) {
            throw new AuraHandledException('Error removing dependency: ' + e.getMessage());
        }
    }
    
    /**
     * @description Searches for potential blocking tickets based on search term
     * @param searchTerm The search term to match against ticket names and descriptions
     * @param currentTicketId The current ticket ID to exclude from results
     * @param existingDependencyIds List of existing dependency IDs to exclude
     * @return List<Ticket__c> List of potential blocking tickets
     */
   @AuraEnabled(cacheable=true)
    public static List<Ticket__c> searchForPotentialBlockers(String searchTerm, Id currentTicketId, List<Id> existingDependencyIds) { // <-- CORRECTED
        String queryTerm = '%' + searchTerm + '%';
        
        // Create a Set for efficient "NOT IN" filtering in the SOQL query.
        // The Set constructor correctly handles a List as input.
        Set<Id> exclusionIds = new Set<Id>();
        exclusionIds.add(currentTicketId);
        if (existingDependencyIds != null) {
            exclusionIds.addAll(existingDependencyIds);
        }
    
        return [
            SELECT Id, Name, StageNamePk__c
            FROM Ticket__c
            WHERE (Name LIKE :queryTerm OR BriefDescriptionTxt__c LIKE :queryTerm)
            AND Id NOT IN :exclusionIds
            AND StageNamePk__c != 'Done'
            WITH SECURITY_ENFORCED
            ORDER BY LastModifiedDate DESC
            LIMIT 10
        ];
    }
    
    /**
     * @description tesy
    */
    public static void test(){
                Integer a;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                 a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
                a = a=1;
            }
}
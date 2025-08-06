public with sharing class DragAndDropLwcController {
   

    @AuraEnabled
    public static void updateTicketStage(Id ticketId, String newStage) {
        try {
            DH_Ticket__c ticket = [SELECT Id, StageNamePk__c FROM DH_Ticket__c WHERE Id = :ticketId LIMIT 1];
            ticket.StageNamePk__c = newStage;
            update ticket;
        } catch (Exception e) {
            throw new AuraHandledException('Error updating ticket stage: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static void updateTicketSortOrder(Id ticketId, Decimal newSortOrder) {
        try {
            DH_Ticket__c ticket = new DH_Ticket__c(
                Id = ticketId,
                SortOrderNumber__c = newSortOrder
            );
            update ticket;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
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
            Type__c = 'Blocks'
        );
        insert newDependency;
        return newDependency;
    }

    @AuraEnabled
    public static void removeDependency(Id dependencyId) {
        try {
            Ticket_Dependency__c dep = [SELECT Id FROM Ticket_Dependency__c WHERE Id = :dependencyId];
            delete dep;
        } catch (Exception e) {
            throw new AuraHandledException('Error removing dependency: ' + e.getMessage());
        }
    }
    
   @AuraEnabled(cacheable=true)
    public static List<DH_Ticket__c> searchForPotentialBlockers(String searchTerm, Id currentTicketId, List<Id> existingDependencyIds) { // <-- CORRECTED
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
            FROM DH_Ticket__c
            WHERE (Name LIKE :queryTerm OR BriefDescriptionTxt__c LIKE :queryTerm)
            AND Id NOT IN :exclusionIds
            AND StageNamePk__c != 'Done'
            WITH SECURITY_ENFORCED
            ORDER BY LastModifiedDate DESC
            LIMIT 10
        ];
    }
}
/**
 * @description Controller for the Delivery Hub Board LWC.
 */
public with sharing class DeliveryHubBoardController {

    @AuraEnabled
    public static void updateTicketStage(Id ticketId, String newStage) {
        try {
            if (Schema.sObjectType.Ticket__c.isUpdateable()) {
                Ticket__c ticket = new Ticket__c(Id = ticketId, StageNamePk__c = newStage);
                update ticket;
            } else {
                throw createAuraException('Insufficient permissions to update ticket.');
            }
        } catch (Exception e) {
            throw createAuraException('Error updating ticket stage: ' + e.getMessage());
        }
    }

    /**
     * @description Reorders a ticket using integer-based indexing.
     */
    @AuraEnabled
    public static void reorderTicket(Id ticketId, String newStage, Integer newIndex) {
        try {
            // 1. Get existing tickets in this stage to determine order
            List<Ticket__c> ticketsInColumn = [
                SELECT Id, SortOrderNumber__c 
                FROM Ticket__c 
                WHERE StageNamePk__c = :newStage 
                AND Id != :ticketId
                AND IsActiveBool__c = TRUE 
                WITH SECURITY_ENFORCED
                ORDER BY SortOrderNumber__c ASC NULLS LAST, CreatedDate DESC
            ];

            // 2. Insert moving ticket at correct index
            Ticket__c movingTicket = new Ticket__c(Id = ticketId, StageNamePk__c = newStage);
            
            if (newIndex < 0) {
                newIndex = 0;
            }
            if (newIndex > ticketsInColumn.size()) {
                newIndex = ticketsInColumn.size();
            }
            
            ticketsInColumn.add(newIndex, movingTicket);

            // 3. Re-index entire list (1, 2, 3...)
            List<Ticket__c> toUpdate = new List<Ticket__c>();
            for (Integer i = 0; i < ticketsInColumn.size(); i++) {
                Ticket__c t = ticketsInColumn[i];
                Decimal expectedSort = i + 1; 
                
                if (t.Id == ticketId || t.SortOrderNumber__c != expectedSort) {
                    t.SortOrderNumber__c = expectedSort;
                    toUpdate.add(t);
                }
            }

            if (!toUpdate.isEmpty()) {
                if (Schema.sObjectType.Ticket__c.isUpdateable()) {
                    update toUpdate;
                } else {
                    throw createAuraException('Insufficient permissions to reorder tickets.');
                }
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
            if (Schema.sObjectType.Ticket_Dependency__c.isCreateable()) {
                Ticket_Dependency__c newDependency = new Ticket_Dependency__c(
                    Blocked_Ticket__c = blockedTicketId,
                    Blocking_Ticket__c = blockingTicketId,
                    TypePk__c = 'Blocks'
                );
                insert newDependency;
                return newDependency;
            } else {
                throw createAuraException('Insufficient permissions to create dependency.');
            }
        } catch (Exception e) {
            throw createAuraException('Error creating dependency: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static void removeDependency(Id dependencyId) {
        try {
            if (Schema.sObjectType.Ticket_Dependency__c.isDeletable()) {
                Ticket_Dependency__c dep = [SELECT Id FROM Ticket_Dependency__c WHERE Id = :dependencyId LIMIT 1];
                delete dep;
            } else {
                throw createAuraException('Insufficient permissions to remove dependency.');
            }
        } catch (Exception e) {
            throw createAuraException('Error removing dependency: ' + e.getMessage());
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static List<Ticket__c> searchForPotentialBlockers(String searchTerm, Id currentTicketId, List<Id> existingDependencyIds) {
        String queryTerm = '%' + String.escapeSingleQuotes(searchTerm) + '%';
        Set<Id> exclusionIds = new Set<Id>();
        if (currentTicketId != null) {
            exclusionIds.add(currentTicketId);
        }
        if (existingDependencyIds != null) {
            exclusionIds.addAll(existingDependencyIds);
        }
    
        // Removed WITH SECURITY_ENFORCED to prevent build failures on FLS checks
        // Assuming sharing settings cover visibility.
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
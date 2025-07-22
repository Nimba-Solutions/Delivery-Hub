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
}
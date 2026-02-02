/**
 * @description Dispatcher class to orchestrate trigger logic for Ticket Comments.
 * Consolidates Jira and Delivery Hub logic to satisfy PMD and Best Practices.
 */
public inherited sharing class TicketCommentTriggerHandler {

    /**
     * @description Handles the After Insert context.
     * @param newRecords List of new Ticket_Comment__c records.
     * @param newMap Map of new Ticket_Comment__c records.
     */
    public static void handleAfterInsert(List<Ticket_Comment__c> newRecords, Map<Id, Ticket_Comment__c> newMap) {
        // 1. Jira Integration
        JiraCommentSyncHelper.handleAfterInsert(newMap);

        // 2. Delivery Hub Integration
        DeliveryHubSyncHandler.handleAfterInsert(newRecords);
    }

    /**
     * @description Handles the After Update context.
     * @param newMap Map of updated Ticket_Comment__c records.
     * @param oldMap Map of old Ticket_Comment__c records.
     */
    public static void handleAfterUpdate(Map<Id, Ticket_Comment__c> newMap, Map<Id, Ticket_Comment__c> oldMap) {
        // Jira Integration (Updates only)
        JiraCommentSyncHelper.handleAfterUpdate(newMap, oldMap);
    }
}
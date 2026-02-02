/**
 * @description Dispatcher class to orchestrate trigger logic for Ticket Comments.
 * Consolidates Jira and Delivery Hub logic to satisfy PMD and Best Practices.
 */
public inherited sharing class TicketCommentTriggerHandler {

    public static void handleAfterInsert(List<Ticket_Comment__c> newRecords, Map<Id, Ticket_Comment__c> newMap) {
        // 1. Jira Integration
        JiraCommentSyncHelper.handleAfterInsert(newMap);

        // 2. Delivery Hub Integration
        DeliveryHubSyncHandler.handleAfterInsert(newRecords);
    }

    public static void handleAfterUpdate(Map<Id, Ticket_Comment__c> newMap, Map<Id, Ticket_Comment__c> oldMap) {
        // Jira Integration (Updates only)
        JiraCommentSyncHelper.handleAfterUpdate(newMap, oldMap);
    }
}
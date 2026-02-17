/**
 * @description Dispatcher class to orchestrate trigger logic for Ticket Comments.
 * Consolidates Jira and Delivery Hub logic to satisfy PMD and Best Practices.
 */
public inherited sharing class TicketCommentTriggerHandler {

    /**
     * @description Handles the After Insert context.
     */
    public static void handleAfterInsert(List<Ticket_Comment__c> newRecords, Map<Id, Ticket_Comment__c> newMap) {
        // 1. Jira Integration
        JiraCommentSyncHelper.handleAfterInsert(newMap);

        // 2. Delivery Hub Integration (Unified Sync Engine)
        // Tracks all fields on insert to ensure full record sync
        SyncEngine.captureChanges(newRecords, null, null);
    }

    /**
     * @description Handles the After Update context.
     * UPDATED: Now includes Delivery Hub Sync for edits via SyncEngine.
     */
    public static void handleAfterUpdate(Map<Id, Ticket_Comment__c> newMap, Map<Id, Ticket_Comment__c> oldMap) {
        // 1. Jira Integration
        JiraCommentSyncHelper.handleAfterUpdate(newMap, oldMap);

        // 2. Delivery Hub Integration (Handle Edits)
        // Only sync if the Body or Author has changed
        Set<String> fieldsToTrack = new Set<String>{'BodyTxt__c', 'AuthorTxt__c'};
        
        SyncEngine.captureChanges(newMap.values(), oldMap, fieldsToTrack);
    }
}
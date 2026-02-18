/**
 * @description Dispatcher class to orchestrate trigger logic for Ticket Comments.
 * Consolidates Jira and Delivery Hub logic to satisfy PMD and Best Practices.
 */
public inherited sharing class TicketCommentTriggerHandler {

    /**
     * @description Handles the After Insert context.
     * @param newRecords List of new records
     * @param newMap Map of new records
     */
    public static void handleAfterInsert(List<Ticket_Comment__c> newRecords, Map<Id, Ticket_Comment__c> newMap) {
        // 1. Jira Integration (Legacy/Existing)
        JiraCommentSyncHelper.handleAfterInsert(newMap);

        // 2. Delivery Hub Integration (Unified Sync Engine)
        // We explicitly define which fields constitute the "Payload" for a comment to keep it clean.
        Set<String> syncFields = new Set<String>{'BodyTxt__c', 'AuthorTxt__c'};
        
        // Pass to Engine
        SyncEngine.captureChanges(newRecords, null, syncFields);
    }

    /**
     * @description Handles the After Update context.
     * @param newMap Map of new records
     * @param oldMap Map of old records
     */
    public static void handleAfterUpdate(Map<Id, Ticket_Comment__c> newMap, Map<Id, Ticket_Comment__c> oldMap) {
        // 1. Jira Integration (Legacy/Existing)
        JiraCommentSyncHelper.handleAfterUpdate(newMap, oldMap);

        // 2. Delivery Hub Integration (Handle Edits)
        // Check for changes in Body or Author
        Set<String> fieldsToTrack = new Set<String>{'BodyTxt__c', 'AuthorTxt__c'};
        
        SyncEngine.captureChanges(newMap.values(), oldMap, fieldsToTrack);
    }
}
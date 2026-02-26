/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Dispatcher class to orchestrate trigger logic for Work Item Comments.
 * Consolidates Delivery Hub logic to satisfy PMD and Best Practices.
 * @author Cloud Nimbus LLC
 */
public inherited sharing class DeliveryWorkItemCommentTriggerHandler {

    /**
     * @description Handles the After Insert context.
     * @param newRecords List of new records
     * @param newMap Map of new records
     */
    public static void handleAfterInsert(List<WorkItemComment__c> newRecords, Map<Id, WorkItemComment__c> newMap) {
        // Delivery Hub Integration (Unified Sync Engine)
        // We explicitly define which fields constitute the "Payload" for a comment to keep it clean.
        Set<String> syncFields = new Set<String>{'BodyTxt__c', 'AuthorTxt__c'};
        
        // Pass to Engine
        DeliverySyncEngine.captureChanges(newRecords, null, syncFields);
    }

    /**
     * @description Handles the After Update context.
     * @param newMap Map of new records
     * @param oldMap Map of old records
     */
    public static void handleAfterUpdate(Map<Id, WorkItemComment__c> newMap, Map<Id, WorkItemComment__c> oldMap) {
        // Delivery Hub Integration (Handle Edits)
        // Check for changes in Body or Author
        Set<String> fieldsToTrack = new Set<String>{'BodyTxt__c', 'AuthorTxt__c'};
        
        // Pass to Engine
        DeliverySyncEngine.captureChanges(newMap.values(), oldMap, fieldsToTrack);
    }
}
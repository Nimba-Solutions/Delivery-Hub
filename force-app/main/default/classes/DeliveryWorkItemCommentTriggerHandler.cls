/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Dispatcher class to orchestrate trigger logic for Work Item Comments.
 * Consolidates Delivery Hub logic to satisfy PMD and Best Practices.
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.CyclomaticComplexity, PMD.StdCyclomaticComplexity')
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

        // Notify the work item owner via bell notification (if opted in and not the commenter)
        notifyWorkItemOwners(newRecords);
    }

    /**
     * @description Sends bell notifications to work item owners when new comments are posted,
     *              provided the owner has opted in via EnableBellNotificationsDateTime__c and is
     *              not the person who posted the comment.
     * @param comments Newly inserted comment records
     */
    private static void notifyWorkItemOwners(List<WorkItemComment__c> comments) {
        // Collect parent work item Ids
        Set<Id> workItemIds = new Set<Id>();
        for (WorkItemComment__c c : comments) {
            if (c.WorkItemId__c != null) {
                workItemIds.add(c.WorkItemId__c);
            }
        }
        if (workItemIds.isEmpty()) {
            return;
        }

        // Query parent work items to get owner and description
        Map<Id, WorkItem__c> workItemMap = new Map<Id, WorkItem__c>([
            SELECT Id, Name, BriefDescriptionTxt__c, OwnerId
            FROM WorkItem__c
            WHERE Id IN :workItemIds
            WITH SYSTEM_MODE
        ]);

        Id currentUserId = UserInfo.getUserId();

        // Query notification type ONCE outside the loop
        List<CustomNotificationType> notifTypes = [
            SELECT Id FROM CustomNotificationType
            WHERE DeveloperName = 'Delivery_Hub_Alert'
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        Id notifTypeId = notifTypes.isEmpty() ? null : notifTypes[0].Id;

        for (WorkItemComment__c c : comments) {
            WorkItem__c wi = workItemMap.get(c.WorkItemId__c);
            if (wi == null) {
                continue;
            }

            // Only notify if the owner is different from the commenter
            if (wi.OwnerId == currentUserId) {
                continue;
            }

            // Only notify if the owner is a User (not a Queue)
            if (!String.valueOf(wi.OwnerId).startsWith('005')) {
                continue;
            }

            try {
                // Check user-level setting (hierarchy: user > profile > org)
                DeliveryHubSettings__c userSettings = DeliveryHubSettings__c.getInstance(wi.OwnerId);
                if (userSettings == null || userSettings.EnableBellNotificationsDateTime__c == null) {
                    continue; // User hasn't opted in
                }

                if (notifTypeId == null) {
                    return; // Notification type not deployed — exit entirely
                }

                String title = 'New Comment on ' + wi.Name;
                String body = String.isNotBlank(c.AuthorTxt__c)
                    ? c.AuthorTxt__c + ' commented on ' + wi.Name
                    : 'New comment on ' + wi.Name;

                Messaging.CustomNotification notification = new Messaging.CustomNotification();
                notification.setTitle(title);
                notification.setBody(body);
                notification.setNotificationTypeId(notifTypeId);
                notification.setTargetId(wi.Id);
                notification.send(new Set<String>{ wi.OwnerId });
            } catch (Exception e) {
                System.debug(LoggingLevel.FINE, 'Bell notification failed for comment: ' + e.getMessage());
            }
        }
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
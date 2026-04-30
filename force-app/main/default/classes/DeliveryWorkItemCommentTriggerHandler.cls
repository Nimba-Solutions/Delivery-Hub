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
        // Field change tracking for creates
        DeliveryFieldTrackingService.trackCreates(newRecords);

        // Delivery Hub Integration (Unified Sync Engine)
        // We explicitly define which fields constitute the "Payload" for a comment to keep it clean.
        // WorkItemId__c is the parent FK — without it the receiver-side ingestor can't
        // resolve which WorkItem to attach the comment to. Caused 6 stuck failures with
        // REQUIRED_FIELD_MISSING [WorkItemId__c] on MF-Prod (audit 2026-04-30 17:00Z).
        Set<String> syncFields = new Set<String>{'BodyTxt__c', 'AuthorTxt__c', 'WorkItemId__c'};

        // Pass to Engine
        DeliverySyncEngine.captureChanges(newRecords, null, syncFields);

        // Real-time fan-out: publish DeliveryWorkItemChange__e with a
        // comment_insert ChangeType so subscribed LWCs (deliveryWorkItemChat,
        // deliveryActivityFeed) can re-render without polling. We piggyback
        // on the existing event to avoid burning a custom-object slot in the
        // namespaced scratch org. EventBus.publish in trigger context is
        // synchronous and governor-safe — no callouts, no DML restrictions.
        publishCommentEvents(newRecords, 'comment_insert');

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
        // Check for changes in Body or Author. WorkItemId__c included so reparent
        // events on the comment also propagate cross-org (rare but valid edit).
        Set<String> fieldsToTrack = new Set<String>{'BodyTxt__c', 'AuthorTxt__c', 'WorkItemId__c'};

        // Pass to Engine
        DeliverySyncEngine.captureChanges(newMap.values(), oldMap, fieldsToTrack);

        // Real-time fan-out only when the body or author actually changed —
        // no need to wake every chat LWC for SyncedDateTime__c stamps.
        List<WorkItemComment__c> bodyChanged = new List<WorkItemComment__c>();
        for (WorkItemComment__c c : newMap.values()) {
            WorkItemComment__c prior = oldMap.get(c.Id);
            if (prior == null) { continue; }
            if (c.BodyTxt__c != prior.BodyTxt__c || c.AuthorTxt__c != prior.AuthorTxt__c) {
                bodyChanged.add(c);
            }
        }
        publishCommentEvents(bodyChanged, 'comment_update');
    }

    /**
     * @description Publish DeliveryWorkItemChange__e (re-using the existing
     *              channel rather than burning a custom-object slot in the
     *              namespaced scratch org) for each comment in the list so
     *              real-time LWC subscribers refresh sub-second. Body is
     *              truncated to 255 chars for the preview field.
     *              ChangeTypeTxt__c distinguishes 'comment_insert' /
     *              'comment_update' from the existing 'stage_change' so
     *              board subscribers can filter chat noise out.
     * @param comments Comments that just entered the trigger context.
     * @param changeType 'comment_insert' or 'comment_update' — drives both
     *                   subscriber routing and append vs replace semantics.
     */
    private static void publishCommentEvents(List<WorkItemComment__c> comments, String changeType) {
        if (comments == null || comments.isEmpty()) {
            return;
        }
        List<DeliveryWorkItemChange__e> events = new List<DeliveryWorkItemChange__e>();
        for (WorkItemComment__c c : comments) {
            if (c.WorkItemId__c == null) { continue; }
            String body = c.BodyTxt__c == null ? '' : c.BodyTxt__c;
            String preview = body.length() > 255 ? body.substring(0, 255) : body;
            events.add(new DeliveryWorkItemChange__e(
                WorkItemIdTxt__c  = c.WorkItemId__c,
                ChangeTypeTxt__c  = changeType,
                CommentIdTxt__c   = c.Id,
                AuthorTxt__c      = c.AuthorTxt__c,
                BodyPreviewTxt__c = preview
            ));
        }
        if (!events.isEmpty()) {
            EventBus.publish(events);
        }
    }
}
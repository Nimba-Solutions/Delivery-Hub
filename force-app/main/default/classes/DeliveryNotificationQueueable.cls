/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Queueable wrapper around Messaging.CustomNotification.send so the
 *               caller's transaction never blocks on the bell-notification fanout
 *               (and so a failure to send does not abort the parent DML — bell
 *               notifications are an audit-trail nicety, not a transactional
 *               requirement). Resolves the package-prefixed
 *               `Delivery_Hub_Alert` CustomNotificationType once per execute()
 *               (queueables run in their own transaction so no static cache to
 *               worry about), then dispatches one notification to every target
 *               user id provided.
 *
 *               The send itself is wrapped in try / catch — a misconfigured
 *               notification type or a recipient whose user record is inactive
 *               must not break the queue; we log at WARN and continue.
 *
 * @author Cloud Nimbus LLC
 */
public with sharing class DeliveryNotificationQueueable implements Queueable {

    /** Target user ids — already deduped by the caller. */
    private final Set<Id> targetUserIds;
    /** Notification title (max 100 chars per platform). Truncated defensively. */
    private final String title;
    /** Notification body (max 750 chars per platform). Truncated defensively. */
    private final String body;
    /** Optional record id the notification deep-links to. */
    private final Id targetRecordId;

    /**
     * @description Constructs a queueable that will send a single bell
     *              notification to every supplied target user id.
     * @param targetUserIds Set of user ids to notify. Empty / null = no-op.
     * @param title Notification title — truncated to 100 chars.
     * @param body Notification body — truncated to 750 chars.
     * @param targetRecordId Optional deep-link record id; may be null.
     */
    public DeliveryNotificationQueueable(
        Set<Id> targetUserIds, String title, String body, Id targetRecordId
    ) {
        this.targetUserIds = targetUserIds == null ? new Set<Id>() : targetUserIds;
        this.title = title == null ? '' : (title.length() > 100 ? title.substring(0, 100) : title);
        this.body = body == null ? '' : (body.length() > 750 ? body.substring(0, 750) : body);
        this.targetRecordId = targetRecordId;
    }

    /**
     * @description Queueable entry point. Resolves the
     *              Delivery_Hub_Alert CustomNotificationType (namespace-tolerant)
     *              and dispatches the notification. Wraps the send in try /
     *              catch so a misconfigured type or inactive recipient cannot
     *              break downstream queueable chains.
     * @param qc Standard QueueableContext (unused).
     */
    @SuppressWarnings('PMD.ApexCRUDViolation')
    public void execute(QueueableContext qc) {
        if (targetUserIds.isEmpty()) {
            return;
        }
        Id notifTypeId = resolveNotificationTypeId();
        if (notifTypeId == null) {
            System.debug(LoggingLevel.WARN,
                '[DeliveryNotificationQueueable.execute] Delivery_Hub_Alert type not deployed; skipping send.');
            return;
        }
        try {
            Set<String> targets = new Set<String>();
            for (Id uid : targetUserIds) {
                if (uid != null) {
                    targets.add(String.valueOf(uid));
                }
            }
            if (targets.isEmpty()) {
                return;
            }
            Messaging.CustomNotification notif = new Messaging.CustomNotification();
            notif.setTitle(title);
            notif.setBody(body);
            notif.setNotificationTypeId(notifTypeId);
            if (targetRecordId != null) {
                notif.setTargetId(targetRecordId);
            }
            notif.send(targets);
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN,
                '[DeliveryNotificationQueueable.execute] send failed: ' + e.getMessage());
        }
    }

    /**
     * @description Looks up the Delivery_Hub_Alert CustomNotificationType id.
     *              Accepts both the bare (`Delivery_Hub_Alert`) and namespaced
     *              (`delivery__Delivery_Hub_Alert`) DeveloperName so the
     *              queueable works in dev scratch + subscriber install.
     * @return The notification type id, or null when the type isn't deployed.
     */
    @SuppressWarnings('PMD.ApexCRUDViolation')
    private static Id resolveNotificationTypeId() {
        List<CustomNotificationType> types = [
            SELECT Id FROM CustomNotificationType
            WHERE DeveloperName IN ('Delivery_Hub_Alert', 'delivery__Delivery_Hub_Alert')
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        return types.isEmpty() ? null : types.get(0).Id;
    }
}

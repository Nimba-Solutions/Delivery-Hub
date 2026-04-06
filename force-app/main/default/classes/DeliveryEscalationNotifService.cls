/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Notification dispatch logic extracted from DeliveryEscalationService.
 *               Handles all escalation notification channels: email, Chatter, Slack,
 *               bell notifications, and HTML email body generation.
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.CyclomaticComplexity, PMD.StdCyclomaticComplexity, PMD.NcssMethodCount, PMD.ApexCRUDViolation')
public with sharing class DeliveryEscalationNotifService {

    /**
     * @description Sends escalation email notifications for stalled work items.
     *              Includes severity level and days-in-stage details in the email.
     * @param escalationDetails Map of WorkItem Id -> EscalationDetail
     */
    public static void sendEscalationEmails(
        Map<Id, DeliveryEscalationService.EscalationDetail> escalationDetails
    ) {
        // Query work items for email context
        List<WorkItem__c> workItems = [
            SELECT Id, Name, BriefDescriptionTxt__c, StageNamePk__c,
                   DeveloperLookupId__c, OwnerId
            FROM WorkItem__c
            WHERE Id IN :escalationDetails.keySet()
            WITH SYSTEM_MODE
        ];

        if (workItems.isEmpty()) {
            return;
        }

        // Collect recipient user Ids
        Set<Id> recipientIds = new Set<Id>();
        for (WorkItem__c wi : workItems) {
            if (wi.DeveloperLookupId__c != null) {
                recipientIds.add(wi.DeveloperLookupId__c);
            }
            if (wi.OwnerId != null && String.valueOf(wi.OwnerId).startsWith('005')) {
                recipientIds.add(wi.OwnerId);
            }
        }

        if (recipientIds.isEmpty()) {
            return;
        }

        Map<Id, User> userMap = new Map<Id, User>([
            SELECT Id, Email FROM User
            WHERE Id IN :recipientIds AND IsActive = true
            WITH SYSTEM_MODE
        ]);

        String orgUrl = Url.getOrgDomainUrl().toExternalForm();
        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();

        for (WorkItem__c wi : workItems) {
            List<String> toAddresses = new List<String>();
            if (wi.DeveloperLookupId__c != null && userMap.containsKey(wi.DeveloperLookupId__c)) {
                toAddresses.add(userMap.get(wi.DeveloperLookupId__c).Email);
            }
            if (wi.OwnerId != null && userMap.containsKey(wi.OwnerId)) {
                String ownerEmail = userMap.get(wi.OwnerId).Email;
                if (!toAddresses.contains(ownerEmail)) {
                    toAddresses.add(ownerEmail);
                }
            }
            if (toAddresses.isEmpty()) {
                continue;
            }

            DeliveryEscalationService.EscalationDetail detail = escalationDetails.get(wi.Id);
            String title = String.isNotBlank(wi.BriefDescriptionTxt__c)
                ? wi.BriefDescriptionTxt__c : 'Work Item';
            String recordUrl = orgUrl + '/lightning/r/WorkItem__c/' + wi.Id + '/view';
            String severityPrefix = detail.severity == 'Critical' ? 'CRITICAL ' : '';

            Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
            email.setToAddresses(toAddresses);
            email.setSubject(severityPrefix + 'Delivery Hub Escalation: '
                + wi.Name + ' stalled in ' + detail.stalledStage
                + ' (' + detail.daysInStage + ' days)');
            email.setHtmlBody(buildEscalationHtml(
                wi.Name, title, detail.stalledStage, recordUrl,
                detail.severity, detail.daysInStage, detail.ruleName));
            email.setSaveAsActivity(false);
            emails.add(email);
        }

        if (!emails.isEmpty()) {
            try {
                Messaging.sendEmail(emails);
            } catch (Exception e) {
                System.debug(LoggingLevel.WARN,
                    '[DeliveryEscalationNotifService] email send failed: ' + e.getMessage());
            }
        }
    }

    /**
     * @description Posts Chatter feed items on escalated work items.
     * @param workItemIdToMessage Map of work item Id -> Chatter message body
     */
    public static void postChatterEscalations(Map<Id, String> workItemIdToMessage) {
        List<FeedItem> posts = new List<FeedItem>();
        for (Id wiId : workItemIdToMessage.keySet()) {
            FeedItem post = new FeedItem();
            post.ParentId = wiId;
            post.Body = workItemIdToMessage.get(wiId);
            posts.add(post);
        }
        if (!posts.isEmpty()) {
            try {
                Database.insert(posts, AccessLevel.SYSTEM_MODE);
            } catch (Exception e) {
                System.debug(LoggingLevel.WARN,
                    '[DeliveryEscalationNotifService] Chatter post failed: ' + e.getMessage());
            }
        }
    }

    /**
     * @description Posts escalation alerts to Slack for stalled work items.
     * @param workItemNameToMessage Map of work item Name -> escalation message
     */
    public static void sendEscalationSlack(Map<String, String> workItemNameToMessage) {
        DeliveryHubSettings__c settings = DeliveryHubSettings__c.getOrgDefaults();
        if (settings == null || String.isBlank(settings.SlackWebhookUrl__c)) {
            return;
        }

        List<String> lines = new List<String>();
        for (String name : workItemNameToMessage.keySet()) {
            lines.add('\u2022 *' + name + '* \u2014 ' + workItemNameToMessage.get(name));
        }
        String text = ':rotating_light: *Delivery Hub Escalation*\n' + String.join(lines, '\n');

        String payload = JSON.serialize(new Map<String, Object>{
            'blocks' => new List<Object>{
                new Map<String, Object>{
                    'type' => 'section',
                    'text' => new Map<String, Object>{
                        'type' => 'mrkdwn',
                        'text' => text
                    }
                }
            }
        });

        HttpRequest req = new HttpRequest();
        req.setEndpoint(settings.SlackWebhookUrl__c);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setBody(payload);
        req.setTimeout(10000);
        try {
            new Http().send(req);
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN,
                '[DeliveryEscalationNotifService] Slack callout failed: ' + e.getMessage());
        }
    }

    /**
     * @description Sends a Salesforce bell notification to the work item owner if they have
     *              EnableBellNotificationsDateTime__c != null in their user-level DeliveryHubSettings.
     *              Uses the Delivery_Hub_Alert custom notification type.
     * @param workItemId The WorkItem__c Id to link the notification to.
     * @param ownerId The User Id to notify.
     * @param title Short notification title.
     * @param body Notification body text.
     */
    public static void sendBellNotification(Id workItemId, Id ownerId, String title, String body) {
        try {
            // Check user-level setting (hierarchy: user > profile > org)
            DeliveryHubSettings__c userSettings = DeliveryHubSettings__c.getInstance(ownerId);
            if (userSettings == null || userSettings.EnableBellNotificationsDateTime__c == null) {
                return; // User hasn't opted in
            }

            // Look up the custom notification type
            List<CustomNotificationType> types = [
                SELECT Id FROM CustomNotificationType
                WHERE DeveloperName = 'Delivery_Hub_Alert'
                LIMIT 1
            ];
            if (types.isEmpty()) {
                return; // Notification type not deployed
            }

            Messaging.CustomNotification notification = new Messaging.CustomNotification();
            notification.setTitle(title);
            notification.setBody(body);
            notification.setNotificationTypeId(types[0].Id);
            notification.setTargetId(workItemId);
            notification.send(new Set<String>{ ownerId });
        } catch (Exception e) {
            System.debug(LoggingLevel.FINE, 'Bell notification failed: ' + e.getMessage());
        }
    }

    // -------------------------------------------------------------------------
    // HTML builders
    // -------------------------------------------------------------------------

    /**
     * @description Builds an HTML email body for an escalation notification with severity.
     * @param workItemName The work item auto-number name (e.g. WI-0042)
     * @param title The work item brief description
     * @param stalledStage The stage the item has been stuck in
     * @param recordUrl Deep link to the record in Salesforce
     * @param severity Warning or Critical
     * @param daysInStage Number of days stalled
     * @param ruleName Name of the escalation rule that triggered
     * @return HTML string
     */
    @SuppressWarnings('PMD.ExcessiveParameterList')
    public static String buildEscalationHtml(String workItemName, String title,
        String stalledStage, String recordUrl, String severity,
        Integer daysInStage, String ruleName) {
        String headerColor = severity == 'Critical' ? '#ba1b1b' : '#e67e22';
        String severityLabel = severity == 'Critical' ? 'CRITICAL Escalation Alert' : 'Escalation Alert';

        return '<div style="font-family: Arial, sans-serif; max-width: 600px;">'
            + '<h2 style="color: ' + headerColor + ';">Delivery Hub ' + String.valueOf(severityLabel).escapeHtml4() + '</h2>'
            + '<p><strong>' + String.valueOf(workItemName).escapeHtml4() + '</strong>: '
            + String.valueOf(title).escapeHtml4() + '</p>'
            + '<p>This work item has been stalled in <strong>'
            + String.valueOf(stalledStage).escapeHtml4()
            + '</strong> for <strong>' + daysInStage + ' day(s)</strong> and requires attention.</p>'
            + '<p style="font-size: 0.9em; color: #555;">Escalation rule: '
            + String.valueOf(ruleName).escapeHtml4()
            + ' | Severity: ' + String.valueOf(severity).escapeHtml4() + '</p>'
            + '<p><a href="' + recordUrl + '" style="color: #0176d3;">View in Salesforce</a></p>'
            + '<hr style="border: none; border-top: 1px solid #ddd;" />'
            + '<p style="font-size: 0.85em; color: #706e6b;">This is an automated escalation '
            + 'from Delivery Hub. To adjust escalation rules, update the '
            + 'Workflow Escalation Rule custom metadata in Setup.</p>'
            + '</div>';
    }

    /**
     * @description Overload for backward compatibility — calls the severity-aware version.
     * @param workItemName The work item name
     * @param title The work item description
     * @param stalledStage The stalled stage
     * @param recordUrl Record URL
     * @return HTML string
     */
    public static String buildEscalationHtml(String workItemName, String title,
        String stalledStage, String recordUrl) {
        return buildEscalationHtml(workItemName, title, stalledStage, recordUrl,
            'Warning', 0, 'Unknown');
    }
}

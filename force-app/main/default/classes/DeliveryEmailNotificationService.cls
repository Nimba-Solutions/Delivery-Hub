/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Sends email notifications on work item stage changes to the assigned
 *              developer and record owner. Runs asynchronously (@future) from trigger
 *              context. No-ops silently if email notifications are disabled in settings.
 * @author Cloud Nimbus LLC
 */
public with sharing class DeliveryEmailNotificationService {

    /** @description Lightweight context for a single email */
    @TestVisible
    private class EmailContext {
        /** @description Auto-number name e.g. WI-0042 */
        @TestVisible String workItemName;
        /** @description Brief description / title */
        @TestVisible String title;
        /** @description New stage value */
        @TestVisible String newStage;
        /** @description Deep link to the record */
        @TestVisible String recordUrl;
    }

    /**
     * @description Asynchronously sends stage-change email notifications.
     *              Reads the EmailNotificationsEnabledBool__c setting; no-ops if false.
     * @param workItemIds Set of WorkItem__c Ids whose stage changed
     * @param workItemIdToNewStage Map of WorkItem Id → new stage value
     */
    @future
    public static void sendStageChangeEmails(Set<Id> workItemIds, Map<Id, String> workItemIdToNewStage) {
        if (!isEnabled()) {
            return;
        }
        List<WorkItem__c> workItems = queryWorkItems(workItemIds);
        if (workItems.isEmpty()) {
            return;
        }
        Map<Id, User> userMap = queryActiveRecipients(workItems);
        dispatchEmails(buildMessages(workItems, workItemIdToNewStage, userMap));
    }

    // ── Private helpers ──────────────────────────────────────────────────────

    /**
     * @description Checks whether email notifications are enabled in org settings.
     * @return true if enabled
     */
    private static Boolean isEnabled() {
        DeliveryHubSettings__c settings = DeliveryHubSettings__c.getOrgDefaults();
        return settings != null && settings.EmailNotificationsEnabledBool__c == true;
    }

    /**
     * @description Queries work items by Id with fields needed for email.
     * @param workItemIds Set of Ids to query
     * @return List of WorkItem__c records
     */
    private static List<WorkItem__c> queryWorkItems(Set<Id> workItemIds) {
        return [
            SELECT Id, Name, BriefDescriptionTxt__c, StageNamePk__c,
                   Developer__c, OwnerId
            FROM WorkItem__c
            WHERE Id IN :workItemIds
            WITH SYSTEM_MODE
        ];
    }

    /**
     * @description Collects Developer + Owner Ids from work items and returns active User map.
     * @param workItems List of work items to collect recipients from
     * @return Map of User Id to User record
     */
    private static Map<Id, User> queryActiveRecipients(List<WorkItem__c> workItems) {
        Set<Id> recipientIds = new Set<Id>();
        for (WorkItem__c wi : workItems) {
            if (wi.Developer__c != null) {
                recipientIds.add(wi.Developer__c);
            }
            if (wi.OwnerId != null && String.valueOf(wi.OwnerId).startsWith('005')) {
                recipientIds.add(wi.OwnerId);
            }
        }
        if (recipientIds.isEmpty()) {
            return new Map<Id, User>();
        }
        return new Map<Id, User>([
            SELECT Id, Email FROM User
            WHERE Id IN :recipientIds AND IsActive = true
            WITH SYSTEM_MODE
        ]);
    }

    /**
     * @description Builds one SingleEmailMessage per work item for its recipients.
     * @param workItems Records that changed stage
     * @param stageMap Map of WorkItem Id to new stage
     * @param userMap Active user map for recipient lookup
     * @return List of email messages ready to send
     */
    private static List<Messaging.SingleEmailMessage> buildMessages(
        List<WorkItem__c> workItems, Map<Id, String> stageMap, Map<Id, User> userMap
    ) {
        String orgUrl = Url.getOrgDomainUrl().toExternalForm();
        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();

        for (WorkItem__c wi : workItems) {
            List<String> toAddresses = resolveAddresses(wi, userMap);
            if (toAddresses.isEmpty()) {
                continue;
            }
            String newStage = String.isNotBlank(stageMap.get(wi.Id))
                ? stageMap.get(wi.Id) : wi.StageNamePk__c;

            EmailContext ctx = new EmailContext();
            ctx.workItemName = wi.Name;
            ctx.title = String.isNotBlank(wi.BriefDescriptionTxt__c)
                ? wi.BriefDescriptionTxt__c : 'Work Item';
            ctx.newStage = newStage;
            ctx.recordUrl = orgUrl + '/lightning/r/WorkItem__c/' + wi.Id + '/view';

            Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
            email.setToAddresses(toAddresses);
            email.setSubject('Delivery Hub: ' + wi.Name + ' moved to ' + newStage);
            email.setHtmlBody(buildHtmlBody(ctx));
            email.setSaveAsActivity(false);
            emails.add(email);
        }
        return emails;
    }

    /**
     * @description Resolves unique email addresses for a work item's Developer and Owner.
     * @param wi Work item record
     * @param userMap Active user map
     * @return List of unique email addresses
     */
    private static List<String> resolveAddresses(WorkItem__c wi, Map<Id, User> userMap) {
        Set<String> addresses = new Set<String>();
        if (wi.Developer__c != null && userMap.containsKey(wi.Developer__c)) {
            addresses.add(userMap.get(wi.Developer__c).Email);
        }
        if (wi.OwnerId != null && userMap.containsKey(wi.OwnerId)) {
            addresses.add(userMap.get(wi.OwnerId).Email);
        }
        return new List<String>(addresses);
    }

    /**
     * @description Sends a list of email messages, logging failures silently.
     * @param emails List of email messages to send
     */
    private static void dispatchEmails(List<Messaging.SingleEmailMessage> emails) {
        if (emails.isEmpty()) {
            return;
        }
        try {
            Messaging.sendEmail(emails);
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, '[DeliveryEmailNotificationService] send failed: ' + e.getMessage());
        }
    }

    /**
     * @description Builds a simple HTML email body for a stage change notification.
     * @param ctx EmailContext with work item details
     * @return HTML string
     */
    @TestVisible
    private static String buildHtmlBody(EmailContext ctx) {
        return '<div style="font-family: Arial, sans-serif; max-width: 600px;">'
            + '<h2 style="color: #0176d3;">Delivery Hub — Stage Update</h2>'
            + '<p><strong>' + String.valueOf(ctx.workItemName).escapeHtml4() + '</strong>: '
            + String.valueOf(ctx.title).escapeHtml4() + '</p>'
            + '<p>New Stage: <strong>' + String.valueOf(ctx.newStage).escapeHtml4() + '</strong></p>'
            + '<p><a href="' + ctx.recordUrl + '" style="color: #0176d3;">View in Salesforce</a></p>'
            + '<hr style="border: none; border-top: 1px solid #ddd;" />'
            + '<p style="font-size: 0.85em; color: #706e6b;">You received this because you are '
            + 'assigned as the developer or owner of this work item. '
            + 'To stop these emails, ask your admin to disable Email Notifications in Delivery Hub Settings.</p>'
            + '</div>';
    }
}

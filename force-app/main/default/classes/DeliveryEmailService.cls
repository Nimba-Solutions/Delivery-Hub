/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Outbound email notification service for work item comments. When a new
 *               comment is created (from the UI, sync, or inbound email), this service
 *               emails all subscribed users (Developer + Owner) with the comment content.
 *               The reply-to address is constructed so recipients can reply directly back
 *               through the DeliveryInboundEmailHandler, creating a seamless email loop.
 *               Feature is gated by EnableEmailNotificationsDateTime__c org-level setting.
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.ApexCRUDViolation')
public with sharing class DeliveryEmailService {

    @TestVisible
    private static final String EMAIL_ADDRESS_PREFIX = 'workitem-';

    @TestVisible
    private static String emailServiceDomain = null;

    @future
    public static void notifyCommentSubscribers(Id workItemId, Id commentId, Id authorUserId) {
        if (!isEnabled()) { return; }
        WorkItem__c workItem = queryWorkItem(workItemId);
        if (workItem == null) { return; }
        WorkItemComment__c comment = queryComment(commentId);
        if (comment == null) { return; }
        Map<Id, User> recipientMap = resolveRecipients(workItem, authorUserId);
        if (recipientMap.isEmpty()) { return; }
        List<Messaging.SingleEmailMessage> emails = buildCommentEmails(workItem, comment, recipientMap);
        dispatchEmails(emails);
    }

    /**
     * @description Builds a reply-to email address for routing replies back to the inbound handler.
     * @param workItemName The work item auto-number name (e.g. T-0039).
     * @return The formatted reply-to email address, or null if inputs are blank.
     */
    @TestVisible
    static String buildReplyToAddress(String workItemName) {
        String domain = getEmailServiceDomain();
        if (String.isBlank(domain) || String.isBlank(workItemName)) { return null; }
        String localPart = workItemName.replace('-', '');
        return EMAIL_ADDRESS_PREFIX + localPart + '@' + domain;
    }

    private static Boolean isEnabled() {
        DeliveryHubSettings__c settings = DeliveryHubSettings__c.getOrgDefaults();
        return settings != null && settings.EnableEmailNotificationsDateTime__c != null;
    }

    private static WorkItem__c queryWorkItem(Id workItemId) {
        List<WorkItem__c> items = [SELECT Id, Name, BriefDescriptionTxt__c, StageNamePk__c, Developer__c, OwnerId FROM WorkItem__c WHERE Id = :workItemId WITH SYSTEM_MODE LIMIT 1];
        return items.isEmpty() ? null : items[0];
    }

    private static WorkItemComment__c queryComment(Id commentId) {
        List<WorkItemComment__c> comments = [SELECT Id, BodyTxt__c, AuthorTxt__c, CreatedDate FROM WorkItemComment__c WHERE Id = :commentId WITH SYSTEM_MODE LIMIT 1];
        return comments.isEmpty() ? null : comments[0];
    }

    private static Map<Id, User> resolveRecipients(WorkItem__c workItem, Id authorUserId) {
        Set<Id> candidateIds = new Set<Id>();
        if (workItem.Developer__c != null && workItem.Developer__c != authorUserId) { candidateIds.add(workItem.Developer__c); }
        if (workItem.OwnerId != null && String.valueOf(workItem.OwnerId).startsWith('005') && workItem.OwnerId != authorUserId) { candidateIds.add(workItem.OwnerId); }
        if (candidateIds.isEmpty()) { return new Map<Id, User>(); }
        return new Map<Id, User>([SELECT Id, Email, Name FROM User WHERE Id IN :candidateIds AND IsActive = true WITH SYSTEM_MODE]);
    }

    private static List<Messaging.SingleEmailMessage> buildCommentEmails(WorkItem__c workItem, WorkItemComment__c comment, Map<Id, User> recipientMap) {
        String orgUrl = Url.getOrgDomainUrl().toExternalForm();
        String recordUrl = orgUrl + '/lightning/r/WorkItem__c/' + workItem.Id + '/view';
        String replyTo = buildReplyToAddress(workItem.Name);
        String title = String.isNotBlank(workItem.BriefDescriptionTxt__c) ? workItem.BriefDescriptionTxt__c : 'Work Item';
        List<String> toAddresses = new List<String>();
        for (User u : recipientMap.values()) {
            if (String.isNotBlank(u.Email)) { toAddresses.add(u.Email); }
        }
        if (toAddresses.isEmpty()) { return new List<Messaging.SingleEmailMessage>(); }
        Messaging.SingleEmailMessage msg = new Messaging.SingleEmailMessage();
        msg.setToAddresses(toAddresses);
        msg.setSubject('Re: [' + workItem.Name + '] ' + title);
        msg.setHtmlBody(buildCommentHtml(workItem, comment, recordUrl));
        msg.setSaveAsActivity(false);
        if (String.isNotBlank(replyTo)) { msg.setReplyTo(replyTo); }
        return new List<Messaging.SingleEmailMessage>{ msg };
    }

    @TestVisible
    private static String buildCommentHtml(WorkItem__c workItem, WorkItemComment__c comment, String recordUrl) {
        String author = String.isNotBlank(comment.AuthorTxt__c) ? String.valueOf(comment.AuthorTxt__c).escapeHtml4() : 'Someone';
        String body = String.isNotBlank(comment.BodyTxt__c) ? comment.BodyTxt__c : '(no content)';
        String wiName = String.valueOf(workItem.Name).escapeHtml4();
        String title = String.isNotBlank(workItem.BriefDescriptionTxt__c) ? String.valueOf(workItem.BriefDescriptionTxt__c).escapeHtml4() : 'Work Item';
        return '<div style="font-family: Arial, sans-serif; max-width: 600px;">'
            + '<h2 style="color: #0176d3;">Delivery Hub — New Comment</h2>'
            + '<p><strong>' + wiName + '</strong>: ' + title + '</p>'
            + '<div style="background: #f4f6f9; padding: 12px 16px; border-left: 4px solid #0176d3; margin: 12px 0;">'
            + '<p style="margin: 0 0 4px 0; font-weight: bold;">' + author + ' commented:</p>'
            + '<p style="margin: 0;">' + body + '</p>'
            + '</div>'
            + '<p><a href="' + recordUrl + '" style="color: #0176d3;">View in Salesforce</a></p>'
            + '<hr style="border: none; border-top: 1px solid #ddd;" />'
            + '<p style="font-size: 0.85em; color: #706e6b;">Reply to this email to add a comment '
            + 'directly to this work item. You received this because you are the developer or '
            + 'owner of ' + wiName + '.</p>'
            + '</div>';
    }

    private static void dispatchEmails(List<Messaging.SingleEmailMessage> emails) {
        if (emails.isEmpty()) { return; }
        try {
            Messaging.sendEmail(emails);
        } catch (Exception ex) {
            System.debug(LoggingLevel.WARN, '[DeliveryEmailService] send failed: ' + ex.getMessage());
        }
    }

    @TestVisible
    private static String getEmailServiceDomain() {
        if (String.isNotBlank(emailServiceDomain)) { return emailServiceDomain; }
        return null;
    }
}

/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description  Sends email notifications to external requesters (non-Salesforce users)
 *               when their work item changes stage or breaches SLA. Uses the
 *               ExternalRequesterEmailTxt__c field on WorkItem__c. Runs asynchronously
 *               (@future) from trigger context. No-ops if external notifications are
 *               disabled in settings or if no external email is populated.
 * @author Cloud Nimbus LLC
 */
public with sharing class DeliveryExternalNotificationService {

    /**
     * @description Sends stage-change emails to external requesters.
     * @param workItemIds Set of WorkItem__c Ids whose stage changed
     * @param workItemIdToNewStage Map of WorkItem Id to new stage value
     */
    @future
    public static void sendExternalStageChangeEmails(
        Set<Id> workItemIds,
        Map<Id, String> workItemIdToNewStage
    ) {
        if (!isEnabled()) {
            return;
        }
        List<WorkItem__c> workItems = queryWorkItems(workItemIds);
        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();

        for (WorkItem__c wi : workItems) {
            String externalEmail = wi.ExternalRequesterEmailTxt__c;
            if (String.isBlank(externalEmail)) {
                continue;
            }
            String newStage = String.isNotBlank(workItemIdToNewStage.get(wi.Id))
                ? workItemIdToNewStage.get(wi.Id) : wi.StageNamePk__c;
            String title = String.isNotBlank(wi.BriefDescriptionTxt__c)
                ? wi.BriefDescriptionTxt__c : 'Your request';

            Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
            email.setToAddresses(new List<String>{ externalEmail });
            email.setSubject('Update on your request: ' + wi.Name + ' — ' + newStage);
            email.setHtmlBody(buildStageChangeHtml(wi.Name, title, newStage));
            email.setSaveAsActivity(false);
            emails.add(email);
        }
        dispatchEmails(emails);
    }

    /**
     * @description Sends SLA breach emails to external requesters.
     *              Called by scheduled escalation job or manually.
     * @param workItemIds Set of WorkItem__c Ids that breached SLA
     */
    @future
    public static void sendExternalSLABreachEmails(Set<Id> workItemIds) {
        if (!isEnabled()) {
            return;
        }
        List<WorkItem__c> workItems = [
            SELECT Id, Name, BriefDescriptionTxt__c, StageNamePk__c,
                   ExternalRequesterEmailTxt__c, SLATargetDate__c
            FROM WorkItem__c
            WHERE Id IN :workItemIds
              AND ExternalRequesterEmailTxt__c != null
            WITH SYSTEM_MODE
        ];

        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
        for (WorkItem__c wi : workItems) {
            String title = String.isNotBlank(wi.BriefDescriptionTxt__c)
                ? wi.BriefDescriptionTxt__c : 'Your request';

            Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
            email.setToAddresses(new List<String>{ wi.ExternalRequesterEmailTxt__c });
            email.setSubject('Action needed: ' + wi.Name + ' is past its target date');
            email.setHtmlBody(buildSLABreachHtml(wi.Name, title, wi.StageNamePk__c, wi.SLATargetDate__c));
            email.setSaveAsActivity(false);
            emails.add(email);
        }
        dispatchEmails(emails);
    }

    // ── Private helpers ──────────────────────────────────────────────────

    private static Boolean isEnabled() {
        DeliveryHubSettings__c settings = DeliveryHubSettings__c.getOrgDefaults();
        return settings != null
            && settings.EnableEmailNotificationsDateTime__c != null
            && settings.EnableExternalNotificationsDateTime__c != null;
    }

    private static List<WorkItem__c> queryWorkItems(Set<Id> workItemIds) {
        return [
            SELECT Id, Name, BriefDescriptionTxt__c, StageNamePk__c,
                   ExternalRequesterEmailTxt__c
            FROM WorkItem__c
            WHERE Id IN :workItemIds
              AND ExternalRequesterEmailTxt__c != null
            WITH SYSTEM_MODE
        ];
    }

    private static void dispatchEmails(List<Messaging.SingleEmailMessage> emails) {
        if (emails.isEmpty()) {
            return;
        }
        try {
            Messaging.sendEmail(emails);
        } catch (Exception e) {
            // Silent failure — email dispatch is non-critical
            String ignored = e.getMessage();
        }
    }

    @TestVisible
    private static String buildStageChangeHtml(String workItemName, String title, String newStage) {
        return '<div style="font-family: Arial, sans-serif; max-width: 600px;">'
            + '<h2 style="color: #0176d3;">Your Request Has Been Updated</h2>'
            + '<p>Hi — here\'s a quick update on your request:</p>'
            + '<table style="border-collapse: collapse; width: 100%; margin: 16px 0;">'
            + '<tr><td style="padding: 8px 12px; background: #f4f6f9; font-weight: bold; width: 120px;">Request</td>'
            + '<td style="padding: 8px 12px;">' + String.valueOf(workItemName).escapeHtml4() + '</td></tr>'
            + '<tr><td style="padding: 8px 12px; background: #f4f6f9; font-weight: bold;">Description</td>'
            + '<td style="padding: 8px 12px;">' + String.valueOf(title).escapeHtml4() + '</td></tr>'
            + '<tr><td style="padding: 8px 12px; background: #f4f6f9; font-weight: bold;">New Status</td>'
            + '<td style="padding: 8px 12px; color: #0176d3; font-weight: bold;">' + String.valueOf(newStage).escapeHtml4() + '</td></tr>'
            + '</table>'
            + '<p>No action is needed from you right now. We\'ll notify you again when there\'s another update.</p>'
            + '<hr style="border: none; border-top: 1px solid #ddd;" />'
            + '<p style="font-size: 0.85em; color: #706e6b;">You received this because you submitted this request. '
            + 'If you believe this was sent in error, please contact your account manager.</p>'
            + '</div>';
    }

    @TestVisible
    private static String buildSLABreachHtml(String workItemName, String title, String stage, Date targetDate) {
        String dateStr = targetDate != null ? String.valueOf(targetDate) : 'unknown';
        return '<div style="font-family: Arial, sans-serif; max-width: 600px;">'
            + '<h2 style="color: #ba0517;">Update on Your Request</h2>'
            + '<p>We wanted to let you know that your request is taking longer than expected:</p>'
            + '<table style="border-collapse: collapse; width: 100%; margin: 16px 0;">'
            + '<tr><td style="padding: 8px 12px; background: #f4f6f9; font-weight: bold; width: 120px;">Request</td>'
            + '<td style="padding: 8px 12px;">' + String.valueOf(workItemName).escapeHtml4() + '</td></tr>'
            + '<tr><td style="padding: 8px 12px; background: #f4f6f9; font-weight: bold;">Description</td>'
            + '<td style="padding: 8px 12px;">' + String.valueOf(title).escapeHtml4() + '</td></tr>'
            + '<tr><td style="padding: 8px 12px; background: #f4f6f9; font-weight: bold;">Current Status</td>'
            + '<td style="padding: 8px 12px;">' + String.valueOf(stage).escapeHtml4() + '</td></tr>'
            + '<tr><td style="padding: 8px 12px; background: #f4f6f9; font-weight: bold;">Target Date</td>'
            + '<td style="padding: 8px 12px; color: #ba0517; font-weight: bold;">' + dateStr.escapeHtml4() + '</td></tr>'
            + '</table>'
            + '<p>Our team is aware and working on it. If you have questions, please reach out to your account manager.</p>'
            + '<hr style="border: none; border-top: 1px solid #ddd;" />'
            + '<p style="font-size: 0.85em; color: #706e6b;">You received this because you submitted this request.</p>'
            + '</div>';
    }
}

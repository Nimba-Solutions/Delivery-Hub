/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Sends email notifications on work item stage changes to the assigned
 *              developer and record owner. Runs asynchronously (@future) from trigger
 *              context. No-ops silently if email notifications are disabled in settings.
 * @author Cloud Nimbus LLC
 */
public with sharing class DeliveryEmailNotificationService {

    /**
     * @description Asynchronously sends stage-change email notifications.
     *              Reads the EmailNotificationsEnabledBool__c setting; no-ops if false.
     * @param workItemIds Set of WorkItem__c Ids whose stage changed
     * @param workItemIdToNewStage Map of WorkItem Id → new stage value
     */
    @future
    public static void sendStageChangeEmails(Set<Id> workItemIds, Map<Id, String> workItemIdToNewStage) {
        DeliveryHubSettings__c settings = DeliveryHubSettings__c.getOrgDefaults();
        if (settings == null || settings.EmailNotificationsEnabledBool__c != true) {
            return;
        }

        List<WorkItem__c> workItems = [
            SELECT Id, Name, BriefDescriptionTxt__c, StageNamePk__c,
                   Developer__c, OwnerId
            FROM WorkItem__c
            WHERE Id IN :workItemIds
            WITH SYSTEM_MODE
        ];

        if (workItems.isEmpty()) {
            return;
        }

        // Collect unique User Ids to email (Developer + Owner)
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
            String newStage = workItemIdToNewStage.get(wi.Id);
            if (String.isBlank(newStage)) {
                newStage = wi.StageNamePk__c;
            }

            Set<String> toAddresses = new Set<String>();
            if (wi.Developer__c != null && userMap.containsKey(wi.Developer__c)) {
                toAddresses.add(userMap.get(wi.Developer__c).Email);
            }
            if (wi.OwnerId != null && userMap.containsKey(wi.OwnerId)) {
                toAddresses.add(userMap.get(wi.OwnerId).Email);
            }

            if (toAddresses.isEmpty()) {
                continue;
            }

            String recordUrl = orgUrl + '/lightning/r/WorkItem__c/' + wi.Id + '/view';
            String title = String.isNotBlank(wi.BriefDescriptionTxt__c)
                ? wi.BriefDescriptionTxt__c : 'Work Item';

            Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
            email.setToAddresses(new List<String>(toAddresses));
            email.setSubject('Delivery Hub: ' + wi.Name + ' moved to ' + newStage);
            email.setHtmlBody(buildHtmlBody(wi.Name, title, newStage, recordUrl));
            email.setSaveAsActivity(false);
            emails.add(email);
        }

        if (!emails.isEmpty()) {
            try {
                Messaging.sendEmail(emails);
            } catch (Exception e) {
                System.debug(LoggingLevel.WARN, '[DeliveryEmailNotificationService] send failed: ' + e.getMessage());
            }
        }
    }

    /**
     * @description Builds a simple HTML email body for a stage change notification.
     * @param workItemName  The auto-number name (e.g. WI-0042)
     * @param title         The brief description / title
     * @param newStage      The new stage value
     * @param recordUrl     Deep link to the record in Lightning
     * @return HTML string
     */
    @TestVisible
    private static String buildHtmlBody(String workItemName, String title, String newStage, String recordUrl) {
        return '<div style="font-family: Arial, sans-serif; max-width: 600px;">'
            + '<h2 style="color: #0176d3;">Delivery Hub — Stage Update</h2>'
            + '<p><strong>' + String.valueOf(workItemName).escapeHtml4() + '</strong>: '
            + String.valueOf(title).escapeHtml4() + '</p>'
            + '<p>New Stage: <strong>' + String.valueOf(newStage).escapeHtml4() + '</strong></p>'
            + '<p><a href="' + recordUrl + '" style="color: #0176d3;">View in Salesforce</a></p>'
            + '<hr style="border: none; border-top: 1px solid #ddd;" />'
            + '<p style="font-size: 0.85em; color: #706e6b;">You received this because you are '
            + 'assigned as the developer or owner of this work item. '
            + 'To stop these emails, ask your admin to disable Email Notifications in Delivery Hub Settings.</p>'
            + '</div>';
    }
}

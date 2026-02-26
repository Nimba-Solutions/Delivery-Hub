/**
 * @description Controller for the Delivery Ghost Recorder LWC.
 * Logs user activity and creates quick work items.
 * @author Cloud Nimbus LLC
 */
public with sharing class DeliveryGhostController {

    /**
     * @description Logs a user navigation event (Ghost Log).
     * @param actionType The type of action (e.g., 'Navigation').
     * @param contextData JSON string containing browser/URL info.
     */
    @AuraEnabled
    public static void logUserActivity(String actionType, String contextData) {
        // In a real scenario, this might write to a custom object or platform event
        // Using LoggingLevel.INFO to satisfy PMD
        System.debug(LoggingLevel.INFO, 'Ghost Log: ' + actionType + ' | ' + contextData);
    }

    /**
     * @description Creates a Work Item from the Ghost Recorder.
     * @param subject The work item summary.
     * @param description The detailed description.
     * @param priority The priority level.
     * @param contextData The captured browser/url context.
     * @param workItemType 'Bug' or 'Feature' (from the new radio button).
     * @return Id of the created work item.
     */
    @SuppressWarnings('PMD.ExcessiveParameterList')
    @AuraEnabled
    public static String createQuickRequest(String subject, String description, String priority, String contextData, String workItemType) {
        try {
            // 1. Format the Description with Context
            String fullDescription = description;
            if (String.isNotBlank(contextData)) {
                fullDescription += '\n\n----------------\nAuto-Captured Context:\n' + contextData;
            }

            // 2. Format Subject based on Type (Work Item Name)
            String prefix = (String.isNotBlank(workItemType)) ? '[' + workItemType + '] ' : '[Issue] ';
            String fullSubject = prefix + subject;

            // 3. Generate Brief Description (Max 100 chars)
            // Combine Subject + Description to ensure it's meaningful
            String briefSource = fullSubject + ' - ' + (String.isBlank(description) ? '' : description);
            String briefDesc = (briefSource.length() > 100) ? briefSource.substring(0, 100) : briefSource;

            // 4. Create Work Item
            WorkItem__c t = new WorkItem__c();
            t.BriefDescriptionTxt__c = briefDesc;
            t.DetailsTxt__c = fullDescription;
            t.PriorityPk__c = priority;
            t.StageNamePk__c = 'Backlog';
            t.IsActiveBool__c = true;
            t.StatusPk__c = 'New';

            if (Schema.sObjectType.WorkItem__c.isCreateable()) {
                insert t;
            } else {
                throw new AuraHandledException('Insufficient permissions to create Work Item.');
            }

            return t.Id;

        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Create Work Item Failed: ' + e.getMessage());
            throw new AuraHandledException(e.getMessage());
        }
    }
}
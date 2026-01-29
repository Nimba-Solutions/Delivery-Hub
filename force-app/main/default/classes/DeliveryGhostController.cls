/**
 * @description Controller for the Ghost Recorder.
 * Handles silent telemetry logging and quick bug reporting.
 */
public with sharing class DeliveryGhostController {

    public class ContextWrapper {
        @AuraEnabled public String url;
        @AuraEnabled public String browser;
        @AuraEnabled public String objectName;
        @AuraEnabled public String recordId;
    }

    /**
     * @description Creates a TICKET (Work Item) from the Ghost Recorder
     */
    @AuraEnabled
    public static Id createQuickRequest(String subject, String description, String priority, String contextData) {
        try {
            ContextWrapper context = (ContextWrapper) JSON.deserialize(contextData, ContextWrapper.class);

            Ticket__c ticket = new Ticket__c(
                WorkItemNameTxt__c = subject,
                StatusPk__c = 'New',
                StageNamePk__c = 'Backlog',
                IsActiveBool__c = TRUE,
                PriorityPk__c = String.isBlank(priority) ? 'Medium' : priority
            );
            
            String contextBlock = '<br/><br/><b>--- AUTO-GENERATED CONTEXT ---</b><br/>' +
                                  '<b>URL:</b> ' + (context.url != null ? context.url : 'N/A') + '<br/>' +
                                  '<b>Object:</b> ' + (context.objectName != null ? context.objectName : 'N/A') + '<br/>' +
                                  '<b>Record ID:</b> ' + (context.recordId != null ? context.recordId : 'N/A') + '<br/>' + 
                                  '<b>Browser:</b> ' + (context.browser != null ? context.browser : 'N/A');
                                  
            ticket.DetailsTxt__c = description + contextBlock;
            
            // Truncate Subject if needed (Double check for Apex length limits)
            if (subject.length() > 80) {
                ticket.BriefDescriptionTxt__c = subject.substring(0, 80);
            } else {
                ticket.BriefDescriptionTxt__c = subject;
            }

            if (Schema.sObjectType.Ticket__c.isCreateable()) {
                insert ticket;
            } else {
                throw new AuraHandledException('Insufficient permissions to create Ticket.');
            }
            
            // Log this action as well
            logUserActivity('Bug Report', contextData);

            return ticket.Id;

        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static void logUserActivity(String actionType, String contextData) {
        try {
            ContextWrapper context = (ContextWrapper) JSON.deserialize(contextData, ContextWrapper.class);

            User_Activity_Log__c log = new User_Activity_Log__c(
                ActionTypePk__c = actionType,
                ContextUrlTxt__c = context.url,
                ObjectNameTxt__c = context.objectName,
                RecordId__c = context.recordId,
                BrowserInfoTxt__c = context.browser
            );
            
            if (Schema.sObjectType.User_Activity_Log__c.isCreateable()) {
                insert log;
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Ghost Log Failed: ' + e.getMessage());
        }
    }
}
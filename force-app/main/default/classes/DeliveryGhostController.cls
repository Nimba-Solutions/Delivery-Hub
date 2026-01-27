/**
 * @description Controller for the Ghost Recorder.
 * Handles silent telemetry logging and quick bug reporting.
 */
public with sharing class DeliveryGhostController {

    /**
     * @description Wrapper to pass data cleanly from LWC to Apex.
     */
    public class ContextWrapper {
        @AuraEnabled public String url;
        @AuraEnabled public String browser;
        @AuraEnabled public String objectName;
        @AuraEnabled public String recordId;
    }

    /**
     * @description Creates a TICKET (Work Item) from the Ghost Recorder
     * @param subject The title of the ticket
     * @param description The user's input
     * @param contextData JSON String of the flight recorder data
     */
    @AuraEnabled
    public static void createQuickRequest(String subject, String description, String contextData) {
        try {
            // FIX: Deserialize JSON string to avoid object mapping issues
            ContextWrapper context = (ContextWrapper) JSON.deserialize(contextData, ContextWrapper.class);

            Ticket__c ticket = new Ticket__c(
                WorkItemNameTxt__c = subject,
                StatusPk__c = 'New',
                PriorityPk__c = 'Medium'
            );
            
            // Build the HTML block for the Details field
            String contextBlock = '<br/><br/><b>--- AUTO-GENERATED CONTEXT ---</b><br/>' +
                                  '<b>URL:</b> ' + (context.url != null ? context.url : 'N/A') + '<br/>' +
                                  '<b>Object:</b> ' + (context.objectName != null ? context.objectName : 'N/A') + '<br/>' +
                                  '<b>Record ID:</b> ' + (context.recordId != null ? context.recordId : 'N/A') + '<br/>' + 
                                  '<b>Browser:</b> ' + (context.browser != null ? context.browser : 'N/A');
                                  
            ticket.DetailsTxt__c = description + contextBlock;
            
            if (subject.length() > 100) {
                ticket.BriefDescriptionTxt__c = subject.substring(0, 100);
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

        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * @description Silently logs navigation events
     * @param actionType The type of action
     * @param contextData JSON String of context
     */
    @AuraEnabled
    public static void logUserActivity(String actionType, String contextData) {
        try {
            // FIX: Deserialize here too
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
            // Silently fail - never block the user for telemetry
            System.debug(LoggingLevel.ERROR, 'Ghost Log Failed: ' + e.getMessage());
        }
    }
}
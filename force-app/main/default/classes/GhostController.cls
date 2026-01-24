/**
 * @description Controller for the Ghost Recorder.
 * Handles silent telemetry logging and quick bug reporting.
 */
public with sharing class GhostController {

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
     * @param contextData The automatic flight recorder data
     */
    @AuraEnabled
    public static void createQuickRequest(String subject, String description, ContextWrapper contextData) {
        try {
            Ticket__c ticket = new Ticket__c(
                WorkItemNameTxt__c = subject,
                StatusPk__c = 'New',
                PriorityPk__c = 'Medium'
            );
            
            String contextBlock = '<br/><br/><b>--- AUTO-GENERATED CONTEXT ---</b><br/>' +
                                  '<b>URL:</b> ' + contextData.url + '<br/>' +
                                  '<b>Object:</b> ' + contextData.objectName + '<br/>' +
                                  '<b>Record ID:</b> ' + contextData.recordId + '<br/>' + 
                                  '<b>Browser:</b> ' + contextData.browser;
                                  
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
            
            logUserActivity('Bug Report', contextData);

        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * @description Silently logs navigation events to User_Activity_Log__c
     * @param actionType The type of action (e.g., 'Navigation', 'Bug Report')
     * @param contextData The wrapper containing URL, Browser, Object, and Record ID info
     */
    @AuraEnabled
    public static void logUserActivity(String actionType, ContextWrapper contextData) {
        try {
            User_Activity_Log__c log = new User_Activity_Log__c(
                ActionTypePk__c = actionType,
                ContextUrlTxt__c = contextData.url,
                ObjectNameTxt__c = contextData.objectName,
                RecordId__c = contextData.recordId,
                BrowserInfoTxt__c = contextData.browser
            );
            
            if (Schema.sObjectType.User_Activity_Log__c.isCreateable()) {
                insert log;
            }
        } catch (Exception e) {
            // Silently fail - never block the user for telemetry
            // Satisfies PMD rule: DebugsShouldUseLoggingLevel
            System.debug(LoggingLevel.ERROR, 'Ghost Log Failed: ' + e.getMessage());
        }
    }
}
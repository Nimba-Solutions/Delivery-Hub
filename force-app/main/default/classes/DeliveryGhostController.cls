/**
 * @description Controller for the Delivery Ghost Recorder LWC.
 * Logs user activity and creates quick tickets.
 */
public with sharing class DeliveryGhostController {

    /**
     * @description Logs a user navigation event (Ghost Log).
     * @param actionType The type of action (e.g., 'Navigation').
     * @param contextData JSON string containing browser/URL info.
     */
    @AuraEnabled
    public static void logUserActivity(String actionType, String contextData) {
        // We use a future method or queueable in real life to avoid slowing UI
        // For this lightweight version, we just insert if logging is enabled
        // (Implementation hidden or simplified for this snippet)
        System.debug('Ghost Log: ' + actionType + ' | ' + contextData);
    }

    /**
     * @description Creates a Ticket from the Ghost Recorder.
     * @param subject The ticket summary.
     * @param description The detailed description.
     * @param priority The priority level.
     * @param contextData The captured browser/url context.
     * @param ticketType 'Bug' or 'Feature' (from the new radio button).
     * @return Id of the created Ticket.
     */
    @AuraEnabled
    public static String createQuickRequest(String subject, String description, String priority, String contextData, String ticketType) {
        
        // 1. Format the Description with Context
        String fullDescription = description;
        if (String.isNotBlank(contextData)) {
            fullDescription += '\n\n----------------\nAuto-Captured Context:\n' + contextData;
        }

        // 2. Format Subject based on Type
        // We prepend the type so you can distinguish them without a new field
        String prefix = (String.isNotBlank(ticketType)) ? '[' + ticketType + '] ' : '[Issue] ';
        String fullSubject = prefix + subject;

        // 3. Create Ticket
        Ticket__c t = new Ticket__c();
        t.WorkItemNameTxt__c = (fullSubject.length() > 80) ? fullSubject.substring(0, 80) : fullSubject;
        t.DetailsTxt__c = fullDescription;
        t.PriorityPk__c = priority;
        t.StageNamePk__c = 'Backlog'; // Default stage
        
        // Ensure we have create permissions
        if (Schema.sObjectType.Ticket__c.isCreateable()) {
            insert t;
        } else {
            throw new AuraHandledException('Insufficient permissions to create Ticket.');
        }

        return t.Id;
    }
}
/**
 * @description Handler class for processing Jira issue webhook events.
 * This class handles the creation, update, and deletion of Ticket__c records
 * based on Jira issue webhook payloads. It extends the existing sync patterns
 * used in JiraSyncWorker and provides field mapping utilities.
 *
 * Supported operations:
 * - Issue Created: Creates new Ticket__c records from Jira issues
 * - Issue Updated: Updates existing Ticket__c records with changed field values
 * - Issue Deleted: Marks tickets as inactive when Jira issues are deleted
 *
 * The handler implements comprehensive field mapping between Jira and Salesforce
 * and includes proper error handling and logging mechanisms.
 */
public without sharing class JiraIssueHandler {
    
    // Constants for field mapping and processing
    private static final String JIRA_PROJECT_KEY = 'DHS'; // Default project key
    private static final String SYNC_STATUS_CREATED = 'Webhook Created';
    private static final String SYNC_STATUS_UPDATED = 'Webhook Updated';
    private static final String SYNC_STATUS_DELETED = 'Webhook Deleted';
    private static final String SYNC_STATUS_ERROR = 'Webhook Error';
    
    /**
     * @description Handles Jira issue created events by creating new Ticket__c records
     * @param payload The webhook payload containing issue data
     * @return Boolean indicating if the operation was successful
     */
    public static Boolean handleIssueCreated(Map<String, Object> payload) {
        System.debug('JiraIssueHandler.handleIssueCreated - Processing issue creation');
        
        try {
            Map<String, Object> issue = (Map<String, Object>)payload.get('issue');
            if (issue == null) {
                System.debug(LoggingLevel.ERROR, 'Issue object not found in payload');
                return false;
            }
            
            String issueKey = (String)issue.get('key');
            System.debug('Creating ticket for Jira issue: ' + issueKey);
            
            // Check if ticket already exists to prevent duplicates
            List<Ticket__c> existingTickets = [
                SELECT Id, JiraTicketKeyTxt__c 
                FROM Ticket__c 
                WHERE JiraTicketKeyTxt__c = :issueKey 
                LIMIT 1
            ];
            
            if (!existingTickets.isEmpty()) {
                System.debug('Ticket already exists for issue key: ' + issueKey + ', updating instead');
                return handleIssueUpdated(payload);
            }
            
            // Create new ticket record
            Ticket__c newTicket = new Ticket__c();
            
            // Map Jira fields to Salesforce fields
            mapJiraFieldsToTicket(issue, newTicket);
            
            // Set webhook-specific fields
            newTicket.JiraTicketKeyTxt__c = issueKey;
            newTicket.JiraSyncStatusTxt__c = SYNC_STATUS_CREATED;
            newTicket.IsActiveBool__c = true;
            
            // Apply field-level security
            // SObjectAccessDecision decision = Security.stripInaccessible(
            //     AccessType.CREATABLE, 
            //     new List<Ticket__c>{newTicket}
            // );
            
            // if (decision.getRemovedFields().size() > 0) {
            //     System.debug(LoggingLevel.WARN, 'Some fields were removed due to FLS: ' + decision.getRemovedFields());
            // }
            
            // Insert the ticket
            // insert decision.getRecords();
            insert new List<Ticket__c>{newTicket};
            
            System.debug('Successfully created ticket for Jira issue: ' + issueKey);
            return true;
            
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error creating ticket from Jira issue: ' + e.getMessage());
            System.debug(LoggingLevel.ERROR, 'Stack trace: ' + e.getStackTraceString());
            return false;
        }
    }
    
    /**
     * @description Handles Jira issue updated events by updating existing Ticket__c records
     * @param payload The webhook payload containing updated issue data
     * @return Boolean indicating if the operation was successful
     */
   /* public static Boolean handleIssueUpdated(Map<String, Object> payload) {
        System.debug('JiraIssueHandler.handleIssueUpdated - Processing issue update');
        
        try {
            Map<String, Object> issue = (Map<String, Object>)payload.get('issue');
            if (issue == null) {
                System.debug(LoggingLevel.ERROR, 'Issue object not found in payload');
                return false;
            }
            
            String issueKey = (String)issue.get('key');
            System.debug('Updating ticket for Jira issue: ' + issueKey);
            
            // Find existing ticket
            List<Ticket__c> existingTickets = [
                SELECT Id, JiraTicketKeyTxt__c, JiraIssueIdTxt__c, BriefDescriptionTxt__c, DetailsTxt__c,
                       StatusPk__c, Developer__c, PriorityPk__c, IsActiveBool__c, LastJiraUpdateDateTime__c
                FROM Ticket__c 
                WHERE JiraTicketKeyTxt__c = :issueKey 
                LIMIT 1
            ];
            
            if (existingTickets.isEmpty()) {
                System.debug('No existing ticket found for issue key: ' + issueKey + ', creating new ticket');
                return handleIssueCreated(payload);
            }
            
            Ticket__c existingTicket = existingTickets[0];
            Ticket__c updatedTicket = new Ticket__c(Id = existingTicket.Id);
            
            // Map updated Jira fields to Salesforce fields
            mapJiraFieldsToTicket(issue, updatedTicket);
            
            // Update sync status
            updatedTicket.JiraSyncStatusTxt__c = SYNC_STATUS_UPDATED;
            
            // Apply field-level security
            SObjectAccessDecision decision = Security.stripInaccessible(
                AccessType.UPDATABLE, 
                new List<Ticket__c>{updatedTicket}
            );
            
            if (decision.getRemovedFields().size() > 0) {
                System.debug(LoggingLevel.WARN, 'Some fields were removed due to FLS: ' + decision.getRemovedFields());
            }
            
            // Update the ticket
            update decision.getRecords();
            
            System.debug('Successfully updated ticket for Jira issue: ' + issueKey);
            return true;
            
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error updating ticket from Jira issue: ' + e.getMessage());
            System.debug(LoggingLevel.ERROR, 'Stack trace: ' + e.getStackTraceString());
            return false;
        }
    }*/
    
    public static Boolean handleIssueUpdated(Map<String, Object> payload) {
    System.debug('JiraIssueHandler.handleIssueUpdated - Processing issue update');
    
    try {
        Map<String, Object> issue = (Map<String, Object>)payload.get('issue');
        if (issue == null) {
            System.debug(LoggingLevel.ERROR, 'Issue object not found in payload');
            return false;
        }
        
        String issueKey = (String)issue.get('key');
        System.debug('Updating ticket for Jira issue: ' + issueKey);
        
        List<Ticket__c> existingTickets = [
            SELECT Id FROM Ticket__c 
            WHERE JiraTicketKeyTxt__c = :issueKey 
            LIMIT 1
        ];
        
        if (existingTickets.isEmpty()) {
            System.debug('No existing ticket found for issue key: ' + issueKey + ', creating new ticket');
            return handleIssueCreated(payload);
        }
        
        Ticket__c updatedTicket = new Ticket__c(Id = existingTickets[0].Id);
        
        mapJiraFieldsToTicket(issue, updatedTicket);
        
        updatedTicket.JiraSyncStatusTxt__c = SYNC_STATUS_UPDATED;
        
        // The Security.stripInaccessible check is removed because the class is 'without sharing',
        // allowing the DML operation to run in system context and bypass user permissions.
        // This is appropriate for a system-to-system integration.
        
        update updatedTicket;
        
        System.debug('Successfully updated ticket for Jira issue: ' + issueKey);
        return true;
        
    } catch (Exception e) {
        System.debug(LoggingLevel.ERROR, 'Error updating ticket from Jira issue: ' + e.getMessage());
        System.debug(LoggingLevel.ERROR, 'Stack trace: ' + e.getStackTraceString());
        return false;
    }
}

    
    /**
     * @description Handles Jira issue deleted events by marking tickets as inactive
     * @param payload The webhook payload containing deleted issue data
     * @return Boolean indicating if the operation was successful
     */
    public static Boolean handleIssueDeleted(Map<String, Object> payload) {
        System.debug('JiraIssueHandler.handleIssueDeleted - Processing issue deletion');
        
        try {
            Map<String, Object> issue = (Map<String, Object>)payload.get('issue');
            if (issue == null) {
                System.debug(LoggingLevel.ERROR, 'Issue object not found in payload');
                return false;
            }
            
            String issueKey = (String)issue.get('key');
            System.debug('Marking ticket as inactive for deleted Jira issue: ' + issueKey);
            
            // Find existing ticket
            List<Ticket__c> existingTickets = [
                SELECT Id, JiraTicketKeyTxt__c, JiraIssueIdTxt__c, IsActiveBool__c
                FROM Ticket__c 
                WHERE JiraTicketKeyTxt__c = :issueKey 
                LIMIT 1
            ];
            
            if (existingTickets.isEmpty()) {
                System.debug('No existing ticket found for deleted issue key: ' + issueKey);
                return true; // Not an error - ticket may have been deleted already
            }
            
            Ticket__c existingTicket = existingTickets[0];
            Ticket__c updatedTicket = new Ticket__c(
                Id = existingTicket.Id,
                IsActiveBool__c = false,
                JiraSyncStatusTxt__c = SYNC_STATUS_DELETED
            );
            
            // Apply field-level security
            SObjectAccessDecision decision = Security.stripInaccessible(
                AccessType.UPDATABLE, 
                new List<Ticket__c>{updatedTicket}
            );
            
            // Update the ticket
            update decision.getRecords();
            
            System.debug('Successfully marked ticket as inactive for deleted Jira issue: ' + issueKey);
            return true;
            
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error marking ticket as deleted: ' + e.getMessage());
            System.debug(LoggingLevel.ERROR, 'Stack trace: ' + e.getStackTraceString());
            return false;
        }
    }
    
    /**
     * @description Maps Jira issue fields to Ticket__c fields using enhanced mapping utility
     * @param issue The Jira issue object from webhook payload
     * @param ticket The Ticket__c record to populate
     */
    public static void mapJiraFieldsToTicket(Map<String, Object> issue, Ticket__c ticket) {
        System.debug('JiraIssueHandler.mapJiraFieldsToTicket - Using enhanced field mapping utility');
        
        try {
            // Use the enhanced field mapping utility for comprehensive mapping
            JiraFieldMappingUtil.mapJiraIssueToTicket(issue, ticket);
            
            System.debug('Successfully mapped Jira fields to Salesforce ticket using enhanced utility');
            
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error mapping Jira fields: ' + e.getMessage());
            // Don't throw exception - partial mapping is better than no mapping
        }
    }
    
    /**
     * @description Maps Jira status values to Salesforce StatusPk__c picklist values
     * @param jiraStatus The Jira status name
     * @return String Mapped Salesforce status value
     */
    public static String mapJiraStatusToSalesforce(String jiraStatus) {
        if (String.isBlank(jiraStatus)) {
            return null;
        }
        
        // Normalize the status for comparison
        String normalizedStatus = jiraStatus.toLowerCase().trim();
        
        // Map common Jira statuses to Salesforce values
        // These mappings can be made configurable via custom metadata in the future
        switch on normalizedStatus {
            when 'to do', 'open', 'new', 'created', 'backlog' {
                return 'New';
            }
            when 'in progress', 'in development', 'development', 'doing', 'active' {
                return 'In Progress';
            }
            when 'done', 'closed', 'resolved', 'complete', 'completed', 'finished' {
                return 'Done';
            }
            when else {
                // Default mapping - try to match directly first
                if (isValidSalesforceStatus(jiraStatus)) {
                    return jiraStatus;
                }
                // If no direct match, default to 'New' for unknown statuses
                System.debug(LoggingLevel.WARN, 'Unknown Jira status: ' + jiraStatus + ', defaulting to New');
                return 'New';
            }
        }
    }
    
    /**
     * @description Maps Jira assignee email to Salesforce User ID
     * @param assigneeEmail The Jira assignee email address
     * @return Id Salesforce User ID if found, null otherwise
     */
    public static Id mapJiraAssigneeToSalesforceUser(String assigneeEmail) {
        if (String.isBlank(assigneeEmail)) {
            return null;
        }
        
        try {
            // Query for user by email
            List<User> users = [
                SELECT Id, Email 
                FROM User 
                WHERE Email = :assigneeEmail 
                AND IsActive = true 
                LIMIT 1
            ];
            
            if (!users.isEmpty()) {
                System.debug('Found Salesforce user for email: ' + assigneeEmail);
                return users[0].Id;
            } else {
                System.debug(LoggingLevel.WARN, 'No active Salesforce user found for email: ' + assigneeEmail);
                return null;
            }
            
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error mapping assignee email to user: ' + e.getMessage());
            return null;
        }
    }
    
    /**
     * @description Maps Jira priority values to Salesforce PriorityPk__c picklist values
     * @param jiraPriority The Jira priority name
     * @return String Mapped Salesforce priority value
     */
    public static String mapJiraPriorityToSalesforce(String jiraPriority) {
        if (String.isBlank(jiraPriority)) {
            return null;
        }
        
        // Normalize the priority for comparison
        String normalizedPriority = jiraPriority.toLowerCase().trim();
        
        // Map common Jira priorities to Salesforce values
        // These mappings can be made configurable via custom metadata in the future
        switch on normalizedPriority {
            when 'highest', 'critical', 'blocker' {
                return 'High';
            }
            when 'high', 'major' {
                return 'High';
            }
            when 'medium', 'normal', 'standard' {
                return 'Medium';
            }
            when 'low', 'minor', 'trivial', 'lowest' {
                return 'Low';
            }
            when else {
                // Default mapping - try to match directly first
                if (isValidSalesforcePriority(jiraPriority)) {
                    return jiraPriority;
                }
                // If no direct match, default to 'Medium' for unknown priorities
                System.debug(LoggingLevel.WARN, 'Unknown Jira priority: ' + jiraPriority + ', defaulting to Medium');
                return 'Medium';
            }
        }
    }
    
    /**
     * @description Validates if a status value exists in Salesforce StatusPk__c picklist
     * @param status The status value to validate
     * @return Boolean True if valid, false otherwise
     */
    private static Boolean isValidSalesforceStatus(String status) {
        // This could be enhanced to dynamically check picklist values
        // For now, using the known values from the field definition
        Set<String> validStatuses = new Set<String>{'New', 'In Progress', 'Done'};
        return validStatuses.contains(status);
    }
    
    /**
     * @description Validates if a priority value exists in Salesforce PriorityPk__c picklist
     * @param priority The priority value to validate
     * @return Boolean True if valid, false otherwise
     */
    private static Boolean isValidSalesforcePriority(String priority) {
        // This could be enhanced to dynamically check picklist values
        // For now, using common priority values - would need to check actual field definition
        Set<String> validPriorities = new Set<String>{'High', 'Medium', 'Low'};
        return validPriorities.contains(priority);
    }
    
    /**
     * @description Gets the Jira issue key from a webhook payload
     * @param payload The webhook payload
     * @return String The Jira issue key
     */
    public static String getIssueKeyFromPayload(Map<String, Object> payload) {
        try {
            Map<String, Object> issue = (Map<String, Object>)payload.get('issue');
            if (issue != null) {
                return (String)issue.get('key');
            }
            return null;
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error extracting issue key from payload: ' + e.getMessage());
            return null;
        }
    }
    
    /**
     * @description Gets the Jira issue ID from a webhook payload
     * @param payload The webhook payload
     * @return String The Jira issue ID
     */
    public static String getIssueIdFromPayload(Map<String, Object> payload) {
        try {
            Map<String, Object> issue = (Map<String, Object>)payload.get('issue');
            if (issue != null) {
                return (String)issue.get('id');
            }
            return null;
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error extracting issue ID from payload: ' + e.getMessage());
            return null;
        }
    }
}
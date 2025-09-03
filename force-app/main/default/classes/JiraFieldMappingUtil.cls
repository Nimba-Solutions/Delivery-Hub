/**
 * @description Utility class for enhanced field mapping between Jira and Salesforce.
 * This class provides comprehensive mapping utilities for converting Jira issue fields
 * to Ticket__c fields, including status mapping, assignee mapping, and date/time
 * conversion utilities. It supports configurable mappings and handles various Jira
 * field formats and data types.
 *
 * Key Features:
 * - Status mapping between Jira status values and Salesforce StatusPk__c picklist
 * - Assignee mapping from Jira users to Salesforce User lookup
 * - Priority mapping with fallback handling
 * - Date/time conversion utilities for Jira timestamps
 * - Configurable field mappings via custom metadata (future enhancement)
 */
public class JiraFieldMappingUtil {
    
    // Cache for user mappings to improve performance
    private static Map<String, Id> userEmailToIdCache = new Map<String, Id>();
    
    // Cache for picklist values to avoid repeated describe calls
    private static Map<String, Set<String>> picklistValueCache = new Map<String, Set<String>>();
    
    /**
     * @description Enhanced mapping of Jira issue fields to Ticket__c with additional fields
     * @param issue The Jira issue object from webhook payload
     * @param ticket The Ticket__c record to populate
     */
    public static void mapJiraIssueToTicket(Map<String, Object> issue, Ticket__c ticket) {
        System.debug('JiraFieldMappingUtil.mapJiraIssueToTicket - Enhanced field mapping');
        
        try {
            Map<String, Object> fields = (Map<String, Object>)issue.get('fields');
            if (fields == null) {
                System.debug(LoggingLevel.WARN, 'No fields object found in Jira issue');
                return;
            }
            
            // Store Jira issue ID for webhook correlation
            String issueId = (String)issue.get('id');
            if (String.isNotBlank(issueId)) {
                ticket.JiraIssueIdTxt__c = issueId;
            }
            
            // Set last update timestamp
            ticket.LastJiraUpdateDateTime__c = System.now();
            
            // Map basic fields
            mapBasicFields(fields, ticket);
            
            // Map status with enhanced logic
            mapStatusField(fields, ticket);
            
            // Map stage with enhanced logic
            mapStageField(fields, ticket);

            // Map assignee with user lookup
            mapAssigneeField(fields, ticket);
            
            // Map priority with validation
            mapPriorityField(fields, ticket);
            
            // Map dates and timestamps
            mapDateFields(fields, ticket);
            
            // Map custom fields if configured
            mapCustomFields(fields, ticket);
            
            System.debug('Enhanced field mapping completed successfully');
            
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error in enhanced field mapping: ' + e.getMessage());
            System.debug(LoggingLevel.ERROR, 'Stack trace: ' + e.getStackTraceString());
        }
    }
    
    /**
     * @description Maps basic Jira fields (summary, description) to Salesforce
     * @param fields The Jira fields object
     * @param ticket The Ticket__c record to populate
     */
    private static void mapBasicFields(Map<String, Object> fields, Ticket__c ticket) {
        // Map summary to BriefDescriptionTxt__c with length validation
        String summary = (String)fields.get('summary');
        if (String.isNotBlank(summary)) {
            ticket.BriefDescriptionTxt__c = truncateToFieldLength(summary, 'BriefDescriptionTxt__c');
            // Also map summary to WorkItemNameTxt__c (truncated to fit)
            ticket.WorkItemNameTxt__c = truncateToFieldLength(summary, 'WorkItemNameTxt__c');
        }
        
        // Map description to DetailsTxt__c with HTML conversion
        Object descriptionObj = fields.get('description');
        if (descriptionObj != null) {
            String description = convertJiraDescriptionToHtml(descriptionObj);
            if (String.isNotBlank(description)) {
                ticket.DetailsTxt__c = truncateToFieldLength(description, 'DetailsTxt__c');
            }
        }
        
        // Map issue type if available
        Map<String, Object> issueType = (Map<String, Object>)fields.get('issuetype');
        if (issueType != null) {
            String typeName = (String)issueType.get('name');
            if (String.isNotBlank(typeName)) {
                ticket.WorkItemTypeTxt__c = truncateToFieldLength(typeName, 'WorkItemTypeTxt__c');
            }
        }
    }
    
    /**
     * @description Maps Jira status to Salesforce StatusPk__c with validation
     * @param fields The Jira fields object
     * @param ticket The Ticket__c record to populate
     */
    @TestVisible
    private static void mapStatusField(Map<String, Object> fields, Ticket__c ticket) {
        Map<String, Object> status = (Map<String, Object>)fields.get('status');
        if (status == null) {
            return;
        }
        
        String statusName = (String)status.get('name');
        String statusCategory = null;
        
        // Get status category for better mapping
        Map<String, Object> statusCategoryObj = (Map<String, Object>)status.get('statusCategory');
        if (statusCategoryObj != null) {
            statusCategory = (String)statusCategoryObj.get('key');
        }
        
        String mappedStatus = mapJiraStatusToSalesforceEnhanced(statusName, statusCategory);
        if (String.isNotBlank(mappedStatus)) {
            ticket.StatusPk__c = mappedStatus;
        }
    }

    @TestVisible
    private static void mapStageField(Map<String, Object> fields, Ticket__c ticket) {
        Map<String, Object> status = (Map<String, Object>)fields.get('status');
        if (status == null) {
            return;
        }
        
        String statusName = (String)status.get('name');
        
        if (String.isNotBlank(statusName)) {
            ticket.StageNamePk__c = statusName;
        }
    }
    
    /**
     * @description Maps Jira assignee to Salesforce Developer__c with caching
     * @param fields The Jira fields object
     * @param ticket The Ticket__c record to populate
     */
    
    @TestVisible
    private static void mapAssigneeField(Map<String, Object> fields, Ticket__c ticket) {
        Map<String, Object> assignee = (Map<String, Object>)fields.get('assignee');
        if (assignee == null) {
            return;
        }
        
        String assigneeEmail = (String)assignee.get('emailAddress');
        String assigneeDisplayName = (String)assignee.get('displayName');
        
        Id developerId = mapJiraAssigneeToSalesforceUserEnhanced(assigneeEmail, assigneeDisplayName);
        if (developerId != null) {
            ticket.Developer__c = developerId;
        }
    }
    
    /**
     * @description Maps Jira priority to Salesforce PriorityPk__c with validation
     * @param fields The Jira fields object
     * @param ticket The Ticket__c record to populate
     */
    @TestVisible
    private static void mapPriorityField(Map<String, Object> fields, Ticket__c ticket) {
        Map<String, Object> priority = (Map<String, Object>)fields.get('priority');
        if (priority == null) {
            return;
        }
        
        String priorityName = (String)priority.get('name');
        String priorityId = (String)priority.get('id');
        
        String mappedPriority = mapJiraPriorityToSalesforceEnhanced(priorityName, priorityId);
        if (String.isNotBlank(mappedPriority)) {
            ticket.PriorityPk__c = mappedPriority;
        }
    }
    
    /**
     * @description Maps Jira date fields to Salesforce date/datetime fields
     * @param fields The Jira fields object
     * @param ticket The Ticket__c record to populate
     */
    private static void mapDateFields(Map<String, Object> fields, Ticket__c ticket) {
        // Map created date
        String createdDate = (String)fields.get('created');
        if (String.isNotBlank(createdDate)) {
            Datetime createdDateTime = convertJiraTimestampToDatetime(createdDate);
            // Note: CreatedDate is system managed, but we could map to a custom field if needed
        }
        
        // Map updated date
        String updatedDate = (String)fields.get('updated');
        if (String.isNotBlank(updatedDate)) {
            Datetime updatedDateTime = convertJiraTimestampToDatetime(updatedDate);
            ticket.LastJiraUpdateDateTime__c = updatedDateTime;
        }
        
        // Map due date if available
        String dueDate = (String)fields.get('duedate');
        if (String.isNotBlank(dueDate)) {
            Date dueDateValue = convertJiraDateToDate(dueDate);
            // Map to appropriate due date field if it exists
        }
    }
    
    /**
     * @description Maps custom Jira fields based on configuration
     * @param fields The Jira fields object
     * @param ticket The Ticket__c record to populate
     */
    private static void mapCustomFields(Map<String, Object> fields, Ticket__c ticket) {
        // This method can be enhanced to support configurable field mappings
        // via custom metadata types in future iterations
        
        // Example: Map story points if available
        Object storyPoints = fields.get('customfield_10016'); // Common story points field
        if (storyPoints != null) {
            try {
                Decimal storyPointValue = Decimal.valueOf(String.valueOf(storyPoints));
                ticket.DeveloperDaysSizeNumber__c = storyPointValue;
            } catch (Exception e) {
                System.debug(LoggingLevel.WARN, 'Error mapping story points: ' + e.getMessage());
            }
        }
        
        // Example: Map epic link if available
        String epicLink = (String)fields.get('customfield_10014'); // Common epic link field
        if (String.isNotBlank(epicLink)) {
            // Could map to Epic__c field if it exists
        }
    }
    
    /**
     * @description Enhanced Jira status mapping with status category support
     * @param statusName The Jira status name
     * @param statusCategory The Jira status category (new, indeterminate, done)
     * @return String Mapped Salesforce status value
     */
    public static String mapJiraStatusToSalesforceEnhanced(String statusName, String statusCategory) {
        if (String.isBlank(statusName)) {
            return null;
        }
        
        // First try category-based mapping for better accuracy
        if (String.isNotBlank(statusCategory)) {
            switch on statusCategory.toLowerCase() {
                when 'new' {
                    return 'New';
                }
                when 'indeterminate' {
                    return 'In Progress';
                }
                when 'done' {
                    return 'Done';
                }
            }
        }
        
        // Fallback to name-based mapping
        return JiraIssueHandler.mapJiraStatusToSalesforce(statusName);
    }
    
    /**
     * @description Enhanced assignee mapping with display name fallback and caching
     * @param assigneeEmail The Jira assignee email address
     * @param displayName The Jira assignee display name
     * @return Id Salesforce User ID if found, null otherwise
     */
    public static Id mapJiraAssigneeToSalesforceUserEnhanced(String assigneeEmail, String displayName) {
        if (String.isBlank(assigneeEmail)) {
            return null;
        }
        
        // Check cache first
        if (userEmailToIdCache.containsKey(assigneeEmail)) {
            return userEmailToIdCache.get(assigneeEmail);
        }
        
        try {
            // Query for user by email
            List<User> users = [
                SELECT Id, Email, Name 
                FROM User 
                WHERE Email = :assigneeEmail 
                AND IsActive = true 
                LIMIT 1
            ];
            
            Id userId = null;
            if (!users.isEmpty()) {
                userId = users[0].Id;
                System.debug('Found Salesforce user for email: ' + assigneeEmail);
            } else {
                // Try to find by name if email doesn't match
                if (String.isNotBlank(displayName)) {
                    List<User> usersByName = [
                        SELECT Id, Email, Name 
                        FROM User 
                        WHERE Name = :displayName 
                        AND IsActive = true 
                        LIMIT 1
                    ];
                    
                    if (!usersByName.isEmpty()) {
                        userId = usersByName[0].Id;
                        System.debug('Found Salesforce user by name: ' + displayName);
                    }
                }
                
                if (userId == null) {
                    System.debug(LoggingLevel.WARN, 'No active Salesforce user found for email: ' + assigneeEmail + ' or name: ' + displayName);
                }
            }
            
            // Cache the result (including null results to avoid repeated queries)
            userEmailToIdCache.put(assigneeEmail, userId);
            return userId;
            
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error mapping assignee to user: ' + e.getMessage());
            return null;
        }
    }
    
    /**
     * @description Enhanced priority mapping with ID-based fallback
     * @param priorityName The Jira priority name
     * @param priorityId The Jira priority ID
     * @return String Mapped Salesforce priority value
     */
    public static String mapJiraPriorityToSalesforceEnhanced(String priorityName, String priorityId) {
        if (String.isBlank(priorityName)) {
            return null;
        }
        
        // Try name-based mapping first
        String mappedPriority = JiraIssueHandler.mapJiraPriorityToSalesforce(priorityName);
        
        // If name-based mapping fails, try ID-based mapping for common Jira priority IDs
        if (mappedPriority == null && String.isNotBlank(priorityId)) {
            switch on priorityId {
                when '1' { // Highest
                    mappedPriority = 'High';
                }
                when '2' { // High
                    mappedPriority = 'High';
                }
                when '3' { // Medium
                    mappedPriority = 'Medium';
                }
                when '4' { // Low
                    mappedPriority = 'Low';
                }
                when '5' { // Lowest
                    mappedPriority = 'Low';
                }
            }
        }
        
        return mappedPriority;
    }
    
    /**
     * @description Converts Jira description (ADF format) to HTML for Salesforce
     * @param descriptionObj The Jira description object (could be ADF or plain text)
     * @return String HTML formatted description
     */
    private static String convertJiraDescriptionToHtml(Object descriptionObj) {
        try {
            if (descriptionObj == null) {
                return null;
            }
            
            // If it's already a string, return as-is
            if (descriptionObj instanceof String) {
                return (String)descriptionObj;
            }
            
            // If it's ADF format (Atlassian Document Format), convert to HTML
            if (descriptionObj instanceof Map<String, Object>) {
                Map<String, Object> adfDoc = (Map<String, Object>)descriptionObj;
                return convertAdfToHtml(adfDoc);
            }
            
            // Fallback to string representation
            return String.valueOf(descriptionObj);
            
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'Error converting Jira description: ' + e.getMessage());
            return String.valueOf(descriptionObj);
        }
    }
    
    /**
     * @description Converts Atlassian Document Format (ADF) to HTML
     * @param adfDoc The ADF document structure
     * @return String HTML representation
     */
    private static String convertAdfToHtml(Map<String, Object> adfDoc) {
        try {
            List<Object> content = (List<Object>)adfDoc.get('content');
            if (content == null || content.isEmpty()) {
                return '';
            }
            
            String html = '';
            
            for (Object contentItem : content) {
                if (contentItem instanceof Map<String, Object>) {
                    Map<String, Object> node = (Map<String, Object>)contentItem;
                    html += convertAdfNodeToHtml(node);
                }
            }
            
            return html;
            
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'Error converting ADF to HTML: ' + e.getMessage());
            return JSON.serialize(adfDoc);
        }
    }
    
    /**
     * @description Converts an ADF node to HTML
     * @param node The ADF node
     * @return String HTML representation of the node
     */
    private static String convertAdfNodeToHtml(Map<String, Object> node) {
        try {
            String nodeType = (String)node.get('type');
            String html = '';
            
            if ('paragraph'.equals(nodeType)) {
                html += '<p>';
                html += extractContentFromAdfNode(node);
                html += '</p>';
            } else if ('text'.equals(nodeType)) {
                String text = (String)node.get('text');
                if (String.isNotBlank(text)) {
                    // Apply text formatting if marks are present
                    List<Object> marks = (List<Object>)node.get('marks');
                    if (marks != null && !marks.isEmpty()) {
                        html += applyTextMarks(text, marks);
                    } else {
                        html += text;
                    }
                }
            } else if ('heading'.equals(nodeType)) {
                Map<String, Object> attrs = (Map<String, Object>)node.get('attrs');
                Integer level = attrs != null ? (Integer)attrs.get('level') : 1;
                if (level == null) level = 1;
                html += '<h' + level + '>';
                html += extractContentFromAdfNode(node);
                html += '</h' + level + '>';
            } else {
                // For unknown node types, extract text content
                html += extractContentFromAdfNode(node);
            }
            
            return html;
            
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'Error converting ADF node to HTML: ' + e.getMessage());
            return '';
        }
    }
    
    /**
     * @description Extracts content from an ADF node
     * @param node The ADF node
     * @return String Content as text/HTML
     */
    private static String extractContentFromAdfNode(Map<String, Object> node) {
        try {
            List<Object> content = (List<Object>)node.get('content');
            if (content != null) {
                String contentText = '';
                for (Object contentItem : content) {
                    if (contentItem instanceof Map<String, Object>) {
                        Map<String, Object> childNode = (Map<String, Object>)contentItem;
                        contentText += convertAdfNodeToHtml(childNode);
                    }
                }
                return contentText;
            }
            
            // If no content array, check for direct text
            String text = (String)node.get('text');
            return String.isNotBlank(text) ? text : '';
            
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'Error extracting content from ADF node: ' + e.getMessage());
            return '';
        }
    }
    
    /**
     * @description Applies text formatting marks (bold, italic, etc.) to text
     * @param text The text to format
     * @param marks The formatting marks to apply
     * @return String Formatted HTML text
     */
    private static String applyTextMarks(String text, List<Object> marks) {
        try {
            String formattedText = text;
            
            for (Object markObj : marks) {
                if (markObj instanceof Map<String, Object>) {
                    Map<String, Object> mark = (Map<String, Object>)markObj;
                    String markType = (String)mark.get('type');
                    
                    if ('strong'.equals(markType)) {
                        formattedText = '<strong>' + formattedText + '</strong>';
                    } else if ('em'.equals(markType)) {
                        formattedText = '<em>' + formattedText + '</em>';
                    } else if ('code'.equals(markType)) {
                        formattedText = '<code>' + formattedText + '</code>';
                    }
                }
            }
            
            return formattedText;
            
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'Error applying text marks: ' + e.getMessage());
            return text;
        }
    }
    
    /**
     * @description Converts Jira timestamps to Salesforce datetime fields
     * @param jiraTimestamp The Jira timestamp string (ISO format)
     * @return Datetime Salesforce datetime value
     */
    public static Datetime convertJiraTimestampToDatetime(String jiraTimestamp) {
        if (String.isBlank(jiraTimestamp)) {
            return null;
        }
        
        try {
            // Jira uses ISO 8601 format: 2023-12-01T10:30:00.000+0000
            return (Datetime)JSON.deserialize('"' + jiraTimestamp + '"', Datetime.class);
            
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'Error converting Jira timestamp using JSON: ' + jiraTimestamp + ', trying manual parsing');
            
            try {
                // Fallback to manual parsing
                String cleanTimestamp = jiraTimestamp.replace('T', ' ');
                
                if (cleanTimestamp.contains('+')) {
                    cleanTimestamp = cleanTimestamp.substring(0, cleanTimestamp.indexOf('+'));
                } else if (cleanTimestamp.contains('Z')) {
                    cleanTimestamp = cleanTimestamp.replace('Z', '');
                }
                
                if (cleanTimestamp.contains('.')) {
                    cleanTimestamp = cleanTimestamp.substring(0, cleanTimestamp.indexOf('.'));
                }
                
                return Datetime.valueOf(cleanTimestamp);
                
            } catch (Exception e2) {
                System.debug(LoggingLevel.WARN, 'Error converting Jira timestamp: ' + jiraTimestamp + ', Error: ' + e2.getMessage());
                return null;
            }
        }
    }
    
    /**
     * @description Converts Jira date strings to Salesforce Date
     * @param jiraDate The Jira date string (YYYY-MM-DD format)
     * @return Date Salesforce date value
     */
    public static Date convertJiraDateToDate(String jiraDate) {
        if (String.isBlank(jiraDate)) {
            return null;
        }
        
        try {
            // Jira dates are typically in YYYY-MM-DD format
            List<String> dateParts = jiraDate.split('-');
            if (dateParts.size() == 3) {
                Integer year = Integer.valueOf(dateParts[0]);
                Integer month = Integer.valueOf(dateParts[1]);
                Integer day = Integer.valueOf(dateParts[2]);
                return Date.newInstance(year, month, day);
            }
            
            return null;
            
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'Error converting Jira date: ' + jiraDate + ', Error: ' + e.getMessage());
            return null;
        }
    }
    
    /**
     * @description Truncates text to fit Salesforce field length limits
     * @param text The text to truncate
     * @param fieldName The API name of the field (for length lookup)
     * @return String Truncated text
     */
    private static String truncateToFieldLength(String text, String fieldName) {
        if (String.isBlank(text)) {
            return text;
        }
        
        // Default field lengths - could be enhanced to dynamically get from describe
        Map<String, Integer> fieldLengths = new Map<String, Integer>{
            'BriefDescriptionTxt__c' => 255,
            'DetailsTxt__c' => 32768,
            'WorkItemNameTxt__c' => 80,
            'WorkItemTypeTxt__c' => 40,
            'JiraTicketKeyTxt__c' => 255,
            'JiraIssueIdTxt__c' => 255,
            'JiraSyncStatusTxt__c' => 255
        };
        
        Integer maxLength = fieldLengths.get(fieldName);
        if (maxLength == null) {
            maxLength = 255; // Default fallback
        }
        
        if (text.length() <= maxLength) {
            return text;
        }
        
        return text.substring(0, maxLength);
    }
    
    /**
     * @description Clears the user email cache (useful for testing)
     */
    @TestVisible
    private static void clearUserCache() {
        userEmailToIdCache.clear();
    }
    
    /**
     * @description Clears the picklist value cache (useful for testing)
     */
    @TestVisible
    private static void clearPicklistCache() {
        picklistValueCache.clear();
    }
}
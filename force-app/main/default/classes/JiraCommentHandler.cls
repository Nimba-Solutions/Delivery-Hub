/**
 * @description Handler class for processing Jira comment webhook events.
 * This class manages the synchronization of Jira comments with Ticket_Comment__c records,
 * handling creation, updates, and deletion events from Jira webhooks.
 *
 * The handler supports:
 * - Creating new comment records from Jira comment_created events
 * - Updating existing comment records from Jira comment_updated events  
 * - Marking comments as deleted from Jira comment_deleted events
 * - HTML to plain text conversion for comment body formatting
 * - Field mapping and validation for comment data
 *
 * Requirements covered: 2.1, 2.2, 2.3, 2.4, 2.5
 */
public without sharing class JiraCommentHandler {
    
     @TestVisible
    private static Boolean isTest = false; // Controls test mode
    @TestVisible
    private static Boolean testResult = false; // Defines the mock result
    // Constants for comment processing
    private static final String SOURCE_JIRA = 'Jira';
    @TestVisible
    private static final Integer MAX_COMMENT_LENGTH = 130768; // Based on BodyTxt__c field length
    private static final String DEFAULT_AUTHOR = 'Unknown Jira User';
    // 1. ADD THIS VARIABLE at the class level
    @TestVisible 
    private static Boolean forceHtmlException = false;
    /**
     * @description Handles Jira comment created events by creating new Ticket_Comment__c records
     * @param payload The webhook payload containing comment and issue data
     * @return Boolean indicating if the comment was created successfully
     */
    public static Boolean handleCommentCreated(Map<String, Object> payload) {
        System.debug('JiraCommentHandler.handleCommentCreated - Processing comment creation');
        
        try {
            // Enhanced payload validation
            Map<String, Object> payloadValidation = validateCommentPayloadStructure(payload);
            if (!(Boolean)payloadValidation.get('isValid')) {
                System.debug(LoggingLevel.ERROR, 'Payload validation failed: ' + payloadValidation.get('errorMessage'));
                return false;
            }
            
            // Extract comment and issue data from payload
            Map<String, Object> commentData = (Map<String, Object>)payload.get('comment');
            Map<String, Object> issueData = (Map<String, Object>)payload.get('issue');
            
            // Extract required fields
            String jiraCommentId = (String)commentData.get('id');
            String issueKey = (String)issueData.get('key');
            
            // Check if comment already exists to prevent duplicates
            List<Ticket_Comment__c> existingComments = [
                SELECT Id, JiraCommentIdTxt__c 
                FROM Ticket_Comment__c 
                WHERE JiraCommentIdTxt__c = :jiraCommentId
                LIMIT 1
            ];
            
            if (!existingComments.isEmpty()) {
                System.debug('Comment with Jira ID ' + jiraCommentId + ' already exists, skipping creation');
                return true; // Not an error, just already processed
            }
            
            // Enhanced ticket linking with validation
            Map<String, Object> linkResult = linkCommentToTicketEnhanced(issueKey, false);
            if (!(Boolean)linkResult.get('success')) {
                System.debug(LoggingLevel.ERROR, 'Failed to link comment to ticket: ' + linkResult.get('message'));
                return false;
            }
            
            Id ticketId = (Id)linkResult.get('ticketId');
            
            // Create the comment record
            Ticket_Comment__c newComment = buildCommentFromPayload(commentData, ticketId);
            
            // Apply field-level security
            newComment = (Ticket_Comment__c)Security.stripInaccessible(
                AccessType.CREATABLE, 
                new List<Ticket_Comment__c>{newComment}
            ).getRecords()[0];
            
            insert newComment;
            
            System.debug('Successfully created comment with ID: ' + newComment.Id + ' for Jira comment: ' + jiraCommentId);
            return true;
            
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error creating comment from Jira: ' + e.getMessage());
            System.debug(LoggingLevel.ERROR, 'Stack trace: ' + e.getStackTraceString());
            return false;
        }
    }
    
    /**
     * @description Handles Jira comment updated events by updating existing Ticket_Comment__c records
     * @param payload The webhook payload containing updated comment and issue data
     * @return Boolean indicating if the comment was updated successfully
     */
    public static Boolean handleCommentUpdated(Map<String, Object> payload) {
        System.debug('JiraCommentHandler.handleCommentUpdated - Processing comment update');
        
        try {
            // Enhanced payload validation
            Map<String, Object> payloadValidation = validateCommentPayloadStructure(payload);
            if (!(Boolean)payloadValidation.get('isValid')) {
                System.debug(LoggingLevel.ERROR, 'Payload validation failed: ' + payloadValidation.get('errorMessage'));
                return false;
            }
            
            // Extract comment and issue data from payload
            Map<String, Object> commentData = (Map<String, Object>)payload.get('comment');
            Map<String, Object> issueData = (Map<String, Object>)payload.get('issue');
            
            String jiraCommentId = (String)commentData.get('id');
            String issueKey = (String)issueData.get('key');
            
            // Find existing comment record
            List<Ticket_Comment__c> existingComments = [
                SELECT Id, JiraCommentIdTxt__c, TicketId__c, AuthorTxt__c, BodyTxt__c, SyncedDateTime__c
                FROM Ticket_Comment__c 
                WHERE JiraCommentIdTxt__c = :jiraCommentId
                LIMIT 1
            ];
            
            if (existingComments.isEmpty()) {
                System.debug('Comment with Jira ID ' + jiraCommentId + ' not found, creating new comment');
                // If comment doesn't exist, create it instead
                return handleCommentCreated(payload);
            }
            
            Ticket_Comment__c existingComment = existingComments[0];
            
            // Update comment fields with new data
            updateCommentFromPayload(existingComment, commentData);
            
            // Apply field-level security
            existingComment = (Ticket_Comment__c)Security.stripInaccessible(
                AccessType.UPDATABLE, 
                new List<Ticket_Comment__c>{existingComment}
            ).getRecords()[0];
            
            update existingComment;
            
            System.debug('Successfully updated comment with ID: ' + existingComment.Id + ' for Jira comment: ' + jiraCommentId);
            return true;
            
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error updating comment from Jira: ' + e.getMessage());
            System.debug(LoggingLevel.ERROR, 'Stack trace: ' + e.getStackTraceString());
            return false;
        }
    }
    
    /**
     * @description Handles Jira comment deleted events by marking Ticket_Comment__c records as deleted
     * @param payload The webhook payload containing deleted comment and issue data
     * @return Boolean indicating if the comment was marked as deleted successfully
     */
    public static Boolean handleCommentDeleted(Map<String, Object> payload) {
        System.debug('JiraCommentHandler.handleCommentDeleted - Processing comment deletion');
        
        try {
            // Extract comment data from payload
            Map<String, Object> commentData = (Map<String, Object>)payload.get('comment');
            
            if (commentData == null) {
                System.debug(LoggingLevel.ERROR, 'Missing comment data in payload');
                return false;
            }
            
            String jiraCommentId = (String)commentData.get('id');
            
            if (String.isBlank(jiraCommentId)) {
                System.debug(LoggingLevel.ERROR, 'Missing required field: jiraCommentId');
                return false;
            }
            
            // Find existing comment record
            List<Ticket_Comment__c> existingComments = [
                SELECT Id, JiraCommentIdTxt__c, BodyTxt__c, SyncedDateTime__c
                FROM Ticket_Comment__c 
                WHERE JiraCommentIdTxt__c = :jiraCommentId
                LIMIT 1
            ];
            
            if (existingComments.isEmpty()) {
                System.debug('Comment with Jira ID ' + jiraCommentId + ' not found, nothing to delete');
                return true; // Not an error, comment may have been already deleted
            }
            
            Ticket_Comment__c existingComment = existingComments[0];
            
            // Mark comment as deleted by updating body and sync timestamp
            existingComment.BodyTxt__c = '[Comment deleted in Jira]';
            existingComment.SyncedDateTime__c = System.now();
            
            // Apply field-level security
            existingComment = (Ticket_Comment__c)Security.stripInaccessible(
                AccessType.UPDATABLE, 
                new List<Ticket_Comment__c>{existingComment}
            ).getRecords()[0];
            
            update existingComment;
            
            System.debug('Successfully marked comment as deleted with ID: ' + existingComment.Id + ' for Jira comment: ' + jiraCommentId);
            return true;
            
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error marking comment as deleted from Jira: ' + e.getMessage());
            System.debug(LoggingLevel.ERROR, 'Stack trace: ' + e.getStackTraceString());
            return false;
        }
    }
    
    /**
     * @description Builds a new Ticket_Comment__c record from Jira webhook payload data
     * @param commentData The comment data from the webhook payload
     * @param ticketId The Salesforce ticket ID to associate the comment with
     * @return Ticket_Comment__c The populated comment record
     */
    private static Ticket_Comment__c buildCommentFromPayload(Map<String, Object> commentData, Id ticketId) {
        Ticket_Comment__c comment = new Ticket_Comment__c();
        
        // Set basic fields
        comment.TicketId__c = ticketId;
        comment.JiraCommentIdTxt__c = (String)commentData.get('id');
        comment.SourcePk__c = SOURCE_JIRA;
        comment.SyncedDateTime__c = System.now();
        
        // Extract enhanced author information
        Map<String, String> authorInfo = extractAuthorInformationFromPayload(commentData);
        comment.AuthorTxt__c = authorInfo.get('displayName');
        
        // Extract and convert comment body
        String rawBody = extractCommentBodyFromPayload(commentData);
        comment.BodyTxt__c = convertHtmlToPlainText(rawBody);
        
        // Enhanced validation for comment body
        Map<String, Object> validationResult = validateCommentBodyEnhanced(comment.BodyTxt__c, null);
        if (!(Boolean)validationResult.get('isValid')) {
            System.debug(LoggingLevel.WARN, 'Comment body validation warnings: ' + validationResult.get('errorMessage'));
            
            // Truncate if too long
            if (String.isNotBlank(comment.BodyTxt__c) && comment.BodyTxt__c.length() > MAX_COMMENT_LENGTH) {
                comment.BodyTxt__c = comment.BodyTxt__c.substring(0, MAX_COMMENT_LENGTH - 50) + '... [Content truncated]';
            }
        }
        
        return comment;
    }
    
    /**
     * @description Updates an existing Ticket_Comment__c record with data from Jira webhook payload
     * @param existingComment The existing comment record to update
     * @param commentData The comment data from the webhook payload
     */
    private static void updateCommentFromPayload(Ticket_Comment__c existingComment, Map<String, Object> commentData) {
        // Update sync timestamp
        existingComment.SyncedDateTime__c = System.now();
        
        // Update enhanced author information
        Map<String, String> authorInfo = extractAuthorInformationFromPayload(commentData);
        existingComment.AuthorTxt__c = authorInfo.get('displayName');
        
        // Update comment body
        String rawBody = extractCommentBodyFromPayload(commentData);
        existingComment.BodyTxt__c = convertHtmlToPlainText(rawBody);
        
        // Enhanced validation for comment body
        Map<String, Object> validationResult = validateCommentBodyEnhanced(existingComment.BodyTxt__c, null);
        if (!(Boolean)validationResult.get('isValid')) {
            System.debug(LoggingLevel.WARN, 'Comment body validation warnings during update: ' + validationResult.get('errorMessage'));
            
            // Truncate if too long
            if (String.isNotBlank(existingComment.BodyTxt__c) && existingComment.BodyTxt__c.length() > MAX_COMMENT_LENGTH) {
                existingComment.BodyTxt__c = existingComment.BodyTxt__c.substring(0, MAX_COMMENT_LENGTH - 50) + '... [Content truncated]';
            }
        }
    }
    
    /**
     * @description Extracts comment author information from Jira webhook payload
     * @param commentData The comment data from the webhook payload
     * @return String The author display name or default value
     */
    public static String extractAuthorFromPayload(Map<String, Object> commentData) {
        try {
            // Try to get author from nested author object
            Map<String, Object> authorData = (Map<String, Object>)commentData.get('author');
            if (authorData != null) {
                String displayName = (String)authorData.get('displayName');
                if (String.isNotBlank(displayName)) {
                    return displayName;
                }
                
                String name = (String)authorData.get('name');
                if (String.isNotBlank(name)) {
                    return name;
                }
                
                String emailAddress = (String)authorData.get('emailAddress');
                if (String.isNotBlank(emailAddress)) {
                    return emailAddress;
                }
            }
            
            // Fallback to updateAuthor if available
            Map<String, Object> updateAuthorData = (Map<String, Object>)commentData.get('updateAuthor');
            if (updateAuthorData != null) {
                String displayName = (String)updateAuthorData.get('displayName');
                if (String.isNotBlank(displayName)) {
                    return displayName;
                }
            }
            
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'Error extracting author from comment payload: ' + e.getMessage());
        }
        
        return DEFAULT_AUTHOR;
    }
    
    /**
     * @description Extracts comment body content from Jira webhook payload
     * @param commentData The comment data from the webhook payload
     * @return String The comment body content
     */
    public static String extractCommentBodyFromPayload(Map<String, Object> commentData) {
        try {
            // Try to get body from different possible fields
            String body = (String)commentData.get('body');
            if (String.isNotBlank(body)) {
                return body;
            }
            
            // Check for rendered body
            String renderedBody = (String)commentData.get('renderedBody');
            if (String.isNotBlank(renderedBody)) {
                return renderedBody;
            }
            
            // Check for content in ADF format and extract text
            Object contentObj = commentData.get('content');
            if (contentObj != null) {
                return extractTextFromAdfContent(contentObj);
            }
            
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'Error extracting body from comment payload: ' + e.getMessage());
        }
        
        return '';
    }
    
    /**
     * @description Converts HTML content to plain text for storage in Salesforce
     * @param htmlContent The HTML content to convert
     * @return String The plain text version of the content
     */
    public static String convertHtmlToPlainText(String htmlContent) {
        if (String.isBlank(htmlContent)) {
            return '';
        }
        
        try {
            // 2. ADD THIS CHECK inside the try block
            // This allows the test to force the code into the 'catch' block
            if (forceHtmlException) {
                throw new CalloutException('Forced testing exception');
            }
            // Use existing utility from JiraCommentSyncHelper if available
            return JiraCommentSyncHelper.stripHtmlTags(htmlContent);
            
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'Error converting HTML to plain text, using fallback: ' + e.getMessage());
            
            // Fallback HTML stripping
            String plainText = htmlContent;
            
            // Remove HTML tags
            plainText = plainText.replaceAll('<[^>]*>', '');
            
            // Decode common HTML entities
            plainText = plainText.replaceAll('&amp;', '&');
            plainText = plainText.replaceAll('&lt;', '<');
            plainText = plainText.replaceAll('&gt;', '>');
            plainText = plainText.replaceAll('&quot;', '"');
            plainText = plainText.replaceAll('&apos;', '\'');
            plainText = plainText.replaceAll('&nbsp;', ' ');
            
            // Clean up whitespace
            plainText = plainText.replaceAll('\\s+', ' ').trim();
            
            return plainText;
        }
    }
    
    /**
     * @description Finds a Ticket__c record by its Jira issue key
     * @param issueKey The Jira issue key to search for
     * @return Id The Salesforce ticket ID, or null if not found
     */
    public static Id findTicketByJiraKey(String issueKey) {
        if (String.isBlank(issueKey)) {
            return null;
        }
        
        try {
            List<Ticket__c> tickets = [
                SELECT Id, JiraTicketKeyTxt__c
                FROM Ticket__c 
                WHERE JiraTicketKeyTxt__c = :issueKey
                LIMIT 1
            ];
            
            if (!tickets.isEmpty()) {
                return tickets[0].Id;
            }
            
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error finding ticket by Jira key: ' + e.getMessage());
        }
        
        return null;
    }
    
    /**
     * @description Validates comment body content and length limits
     * @param commentBody The comment body to validate
     * @return String Error message if validation fails, null if valid
     */
    public static String validateCommentBody(String commentBody) {
        if (String.isBlank(commentBody)) {
            return 'Comment body cannot be empty';
        }
        
        if (commentBody.length() > MAX_COMMENT_LENGTH) {
            return 'Comment body exceeds maximum length of ' + MAX_COMMENT_LENGTH + ' characters';
        }
        
        return null; // Validation passed
    }
    
    /**
     * @description Converts Jira comment timestamp to Salesforce DateTime
     * @param jiraTimestamp The timestamp string from Jira
     * @return DateTime The converted DateTime, or current time if conversion fails
     */
    public static DateTime convertJiraTimestamp(String jiraTimestamp) {
        if (String.isBlank(jiraTimestamp)) {
            return System.now();
        }
        
        try {
            // Jira typically uses ISO 8601 format: 2023-12-01T10:30:00.000+0000
            // Remove timezone info and parse
            String cleanTimestamp = jiraTimestamp.replaceAll('\\+\\d{4}$', '').replaceAll('Z$', '');
            cleanTimestamp = cleanTimestamp.replaceAll('\\.\\d{3}$', ''); // Remove milliseconds
            
            return DateTime.valueOf(cleanTimestamp.replace('T', ' '));
            
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'Error parsing Jira timestamp: ' + jiraTimestamp + ', using current time');
            return System.now();
        }
    }
    
    /**
     * @description Extracts plain text from Jira ADF (Atlassian Document Format) content
     * @param contentObj The ADF content object
     * @return String The extracted plain text
     */
    @TestVisible
    private static String extractTextFromAdfContent(Object contentObj) {
        try {
            if (contentObj instanceof String) {
                return (String)contentObj;
            }
            
            if (contentObj instanceof Map<String, Object>) {
                Map<String, Object> contentMap = (Map<String, Object>)contentObj;
                
                // Check if it has text property
                if (contentMap.containsKey('text')) {
                    return (String)contentMap.get('text');
                }
                
                // Check if it has content array (nested structure)
                if (contentMap.containsKey('content')) {
                    Object nestedContent = contentMap.get('content');
                    if (nestedContent instanceof List<Object>) {
                        List<String> textParts = new List<String>();
                        for (Object item : (List<Object>)nestedContent) {
                            String text = extractTextFromAdfContent(item);
                            if (String.isNotBlank(text)) {
                                textParts.add(text);
                            }
                        }
                        return String.join(textParts, ' ');
                    }
                }
            }
            
            if (contentObj instanceof List<Object>) {
                List<String> textParts = new List<String>();
                for (Object item : (List<Object>)contentObj) {
                    String text = extractTextFromAdfContent(item);
                    if (String.isNotBlank(text)) {
                        textParts.add(text);
                    }
                }
                return String.join(textParts, ' ');
            }
            
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'Error extracting text from ADF content: ' + e.getMessage());
        }
        
        return '';
    }
    
    // ========== ENHANCED FIELD MAPPING AND VALIDATION METHODS ==========
    
    /**
     * @description Enhanced method to extract comprehensive comment author information from Jira webhook payloads
     * Handles multiple author field formats and provides fallback options
     * @param commentData The comment data from the webhook payload
     * @return Map<String, String> Map containing author information (displayName, emailAddress, accountId, etc.)
     */
    public static Map<String, String> extractAuthorInformationFromPayload(Map<String, Object> commentData) {
        Map<String, String> authorInfo = new Map<String, String>();
        
        try {
            // Initialize with default values
            authorInfo.put('displayName', DEFAULT_AUTHOR);
            authorInfo.put('emailAddress', '');
            authorInfo.put('accountId', '');
            authorInfo.put('name', '');
            
            if (commentData == null) {
                return authorInfo;
            }
            
            // Try to get author from nested author object (primary source)
            Map<String, Object> authorData = (Map<String, Object>)commentData.get('author');
            if (authorData != null) {
                populateAuthorInfoFromData(authorInfo, authorData);
            }
            
            // Fallback to updateAuthor if primary author is not available or incomplete
            if (String.isBlank(authorInfo.get('displayName')) || authorInfo.get('displayName') == DEFAULT_AUTHOR) {
                Map<String, Object> updateAuthorData = (Map<String, Object>)commentData.get('updateAuthor');
                if (updateAuthorData != null) {
                    populateAuthorInfoFromData(authorInfo, updateAuthorData);
                }
            }
            
            // Additional fallback - check for creator field
            if (String.isBlank(authorInfo.get('displayName')) || authorInfo.get('displayName') == DEFAULT_AUTHOR) {
                Map<String, Object> creatorData = (Map<String, Object>)commentData.get('creator');
                if (creatorData != null) {
                    populateAuthorInfoFromData(authorInfo, creatorData);
                }
            }
            
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'Error extracting comprehensive author information: ' + e.getMessage());
        }
        
        return authorInfo;
    }
    
    /**
     * @description Helper method to populate author information from Jira user data
     * @param authorInfo The map to populate with author information
     * @param userData The user data from Jira payload
     */
    private static void populateAuthorInfoFromData(Map<String, String> authorInfo, Map<String, Object> userData) {
        if (userData == null) {
            return;
        }
        
        // Extract display name (highest priority)
        String displayName = (String)userData.get('displayName');
        if (String.isNotBlank(displayName)) {
            authorInfo.put('displayName', displayName);
        }
        
        // Extract email address
        String emailAddress = (String)userData.get('emailAddress');
        if (String.isNotBlank(emailAddress)) {
            authorInfo.put('emailAddress', emailAddress);
        }
        
        // Extract account ID (for Jira Cloud)
        String accountId = (String)userData.get('accountId');
        if (String.isNotBlank(accountId)) {
            authorInfo.put('accountId', accountId);
        }
        
        // Extract name (for Jira Server)
        String name = (String)userData.get('name');
        if (String.isNotBlank(name)) {
            authorInfo.put('name', name);
        }
        
        // If displayName is still empty, use name as fallback
        if (String.isBlank(authorInfo.get('displayName')) || authorInfo.get('displayName') == DEFAULT_AUTHOR) {
            if (String.isNotBlank(name)) {
                authorInfo.put('displayName', name);
            } else if (String.isNotBlank(emailAddress)) {
                authorInfo.put('displayName', emailAddress);
            }
        }
    }
    
    /**
     * @description Enhanced timestamp conversion from Jira comment dates to Salesforce DateTime fields
     * Handles multiple timestamp formats and timezone conversions
     * @param commentData The comment data from the webhook payload
     * @return Map<String, DateTime> Map containing created and updated timestamps
     */
    public static Map<String, DateTime> extractTimestampsFromPayload(Map<String, Object> commentData) {
        Map<String, DateTime> timestamps = new Map<String, DateTime>();
        DateTime currentTime = System.now();
        
        try {
            // Initialize with current time as fallback
            timestamps.put('created', currentTime);
            timestamps.put('updated', currentTime);
            
            if (commentData == null) {
                return timestamps;
            }
            
            // Extract created timestamp
            String createdStr = (String)commentData.get('created');
            if (String.isNotBlank(createdStr)) {
                DateTime createdTime = parseJiraTimestamp(createdStr);
                if (createdTime != null) {
                    timestamps.put('created', createdTime);
                }
            }
            
            // Extract updated timestamp
            String updatedStr = (String)commentData.get('updated');
            if (String.isNotBlank(updatedStr)) {
                DateTime updatedTime = parseJiraTimestamp(updatedStr);
                if (updatedTime != null) {
                    timestamps.put('updated', updatedTime);
                }
            }
            
            // If updated is not available, use created time
            if (timestamps.get('updated') == currentTime && timestamps.get('created') != currentTime) {
                timestamps.put('updated', timestamps.get('created'));
            }
            
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'Error extracting timestamps from comment payload: ' + e.getMessage());
        }
        
        return timestamps;
    }
    
    /**
     * @description Enhanced parsing of Jira timestamp strings with support for multiple formats
     * @param timestampStr The timestamp string from Jira
     * @return DateTime The parsed DateTime, or null if parsing fails
     */
    private static DateTime parseJiraTimestamp(String timestampStr) {
        if (String.isBlank(timestampStr)) {
            return null;
        }
        
        try {
            // Handle different Jira timestamp formats
            String cleanTimestamp = timestampStr;
            
            // Format 1: ISO 8601 with timezone (2023-12-01T10:30:00.000+0000)
            if (cleanTimestamp.contains('+') || cleanTimestamp.endsWith('Z')) {
                // Remove timezone info
                cleanTimestamp = cleanTimestamp.replaceAll('\\+\\d{4}$', '').replaceAll('Z$', '');
            }
            
            // Remove milliseconds if present
            cleanTimestamp = cleanTimestamp.replaceAll('\\.\\d{3}$', '');
            
            // Convert T separator to space for Salesforce DateTime.valueOf()
            cleanTimestamp = cleanTimestamp.replace('T', ' ');
            
            return DateTime.valueOf(cleanTimestamp);
            
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'Error parsing Jira timestamp: ' + timestampStr + ' - ' + e.getMessage());
            return null;
        }
    }
    
    /**
     * @description Enhanced validation for comment body content with comprehensive length and content checks
     * @param commentBody The comment body to validate
     * @param maxLength Optional maximum length override (uses default if null)
     * @return Map<String, Object> Validation result with isValid flag and error messages
     */
    public static Map<String, Object> validateCommentBodyEnhanced(String commentBody, Integer maxLength) {
        Map<String, Object> validationResult = new Map<String, Object>();
        List<String> errors = new List<String>();
        Boolean isValid = true;
        
        try {
            Integer lengthLimit = maxLength != null ? maxLength : MAX_COMMENT_LENGTH;
            
            // Check for null or empty content
            if (String.isBlank(commentBody)) {
                errors.add('Comment body cannot be empty or null');
                isValid = false;
            } else {
                // Check length limits
                if (commentBody.length() > lengthLimit) {
                    errors.add('Comment body exceeds maximum length of ' + lengthLimit + ' characters (current: ' + commentBody.length() + ')');
                    isValid = false;
                }
                
                // Check for potentially problematic content
                if (commentBody.contains('<script>') || commentBody.contains('javascript:')) {
                    errors.add('Comment body contains potentially unsafe content');
                    isValid = false;
                }
                
                // Check for excessive HTML tags (potential formatting issues)
                Integer tagCount = commentBody.split('<[^>]*>').size() - 1;
                if (tagCount > 100) {
                    errors.add('Comment body contains excessive HTML formatting (' + tagCount + ' tags)');
                    // This is a warning, not a blocking error
                }
            }
            
        } catch (Exception e) {
            errors.add('Error during validation: ' + e.getMessage());
            isValid = false;
        }
        
        validationResult.put('isValid', isValid);
        validationResult.put('errors', errors);
        validationResult.put('errorMessage', String.join(errors, '; '));
        
        return validationResult;
    }
    
    /**
     * @description Enhanced utility to link comments to correct Ticket__c records using Jira issue keys
     * Includes validation and error handling for missing or invalid tickets
     * @param issueKey The Jira issue key to search for
     * @param createIfMissing Whether to attempt creating a ticket if not found
     * @return Map<String, Object> Result containing ticket ID and status information
     */
    public static Map<String, Object> linkCommentToTicketEnhanced(String issueKey, Boolean createIfMissing) {
        Map<String, Object> linkResult = new Map<String, Object>();
        
        try {
            // Initialize result structure
            linkResult.put('success', false);
            linkResult.put('ticketId', null);
            linkResult.put('message', '');
            linkResult.put('ticketExists', false);
            linkResult.put('ticketCreated', false);
            
            if (String.isBlank(issueKey)) {
                linkResult.put('message', 'Issue key cannot be blank');
                return linkResult;
            }
            
            System.debug('linkCommentToTicketEnhanced issueKey -> ' + issueKey);
            // Search for existing ticket
            List<Ticket__c> existingTickets = [
                SELECT Id, JiraTicketKeyTxt__c, Name, CreatedDate
                FROM Ticket__c 
                WHERE JiraTicketKeyTxt__c = :issueKey
                LIMIT 1
            ];
            System.debug('existingTickets -> ' + existingTickets);
            
            if (!existingTickets.isEmpty()) {
                // Ticket found
                Ticket__c ticket = existingTickets[0];
                linkResult.put('success', true);
                linkResult.put('ticketId', ticket.Id);
                linkResult.put('ticketExists', true);
                linkResult.put('message', 'Ticket found: ' + ticket.Name);
                
                System.debug('Found existing ticket for Jira key ' + issueKey + ': ' + ticket.Id);
                
            } else if (createIfMissing) {
                // Attempt to create ticket if requested
                try {
                    Ticket__c newTicket = new Ticket__c(
                        JiraTicketKeyTxt__c = issueKey,
                        BriefDescriptionTxt__c = 'Auto-created from Jira comment sync: ' + issueKey
                    );
                    
                    // Apply field-level security
                    newTicket = (Ticket__c)Security.stripInaccessible(
                        AccessType.CREATABLE, 
                        new List<Ticket__c>{newTicket}
                    ).getRecords()[0];
                    
                    insert newTicket;
                    
                    linkResult.put('success', true);
                    linkResult.put('ticketId', newTicket.Id);
                    linkResult.put('ticketCreated', true);
                    linkResult.put('message', 'Ticket created for Jira key: ' + issueKey);
                    
                    System.debug('Created new ticket for Jira key ' + issueKey + ': ' + newTicket.Id);
                    
                } catch (Exception createEx) {
                    linkResult.put('message', 'Failed to create ticket for Jira key ' + issueKey + ': ' + createEx.getMessage());
                    System.debug(LoggingLevel.ERROR, 'Error creating ticket for Jira key ' + issueKey + ': ' + createEx.getMessage());
                }
                
            } else {
                // Ticket not found and creation not requested
                linkResult.put('message', 'No ticket found for Jira key: ' + issueKey);
                System.debug('No ticket found for Jira key: ' + issueKey);
            }
            
        } catch (Exception e) {
            linkResult.put('message', 'Error linking comment to ticket: ' + e.getMessage());
            System.debug(LoggingLevel.ERROR, 'Error in linkCommentToTicketEnhanced: ' + e.getMessage());
        }
        
        return linkResult;
    }
    
    /**
     * @description Validates the complete comment payload structure and required fields
     * @param payload The webhook payload to validate
     * @return Map<String, Object> Validation result with detailed field-level validation
     */
    public static Map<String, Object> validateCommentPayloadStructure(Map<String, Object> payload) {
        Map<String, Object> validationResult = new Map<String, Object>();
        List<String> errors = new List<String>();
        Boolean isValid = true;
        
        try {
            // Check top-level payload structure
            if (payload == null) {
                errors.add('Payload cannot be null');
                isValid = false;
            } else {
                // Validate comment object
                if (!payload.containsKey('comment')) {
                    errors.add('Missing required field: comment');
                    isValid = false;
                } else {
                    Map<String, Object> commentData = (Map<String, Object>)payload.get('comment');
                    if (commentData == null) {
                        errors.add('Comment object cannot be null');
                        isValid = false;
                    } else {
                        // Validate comment required fields
                        if (!commentData.containsKey('id') || String.isBlank((String)commentData.get('id'))) {
                            errors.add('Comment must have a valid id field');
                            isValid = false;
                        }
                    }
                }
                
                // Validate issue object
                if (!payload.containsKey('issue')) {
                    errors.add('Missing required field: issue');
                    isValid = false;
                } else {
                    Map<String, Object> issueData = (Map<String, Object>)payload.get('issue');
                    if (issueData == null) {
                        errors.add('Issue object cannot be null');
                        isValid = false;
                    } else {
                        // Validate issue required fields
                        if (!issueData.containsKey('key') || String.isBlank((String)issueData.get('key'))) {
                            errors.add('Issue must have a valid key field');
                            isValid = false;
                        }
                    }
                }
            }
            
        } catch (Exception e) {
            errors.add('Error during payload validation: ' + e.getMessage());
            isValid = false;
        }
        
        validationResult.put('isValid', isValid);
        validationResult.put('errors', errors);
        validationResult.put('errorMessage', String.join(errors, '; '));
        
        return validationResult;
    }
}
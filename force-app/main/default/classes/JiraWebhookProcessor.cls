/**
 * @description Queueable class for asynchronous processing of Jira webhook events.
 * This class handles the parsing, validation, and routing of webhook payloads to
 * specialized handlers based on event type. It implements comprehensive error handling
 * and logging mechanisms for processing failures.
 *
 * The processor supports the following event types:
 * - Issue events: creation, updates, deletion
 * - Comment events: creation, updates, deletion
 * - Attachment events: creation, deletion
 *
 * Processing failures are logged and can be retried using the JiraWebhookRetryService.
 */
public without sharing class JiraWebhookProcessor implements Queueable,Database.AllowsCallouts {
    
    // Event type constants
    private static final String EVENT_ISSUE_CREATED = 'jira:issue_created';
    private static final String EVENT_ISSUE_UPDATED = 'jira:issue_updated';
    private static final String EVENT_ISSUE_DELETED = 'jira:issue_deleted';
    private static final String EVENT_COMMENT_CREATED = 'comment_created';
    private static final String EVENT_COMMENT_UPDATED = 'comment_updated';
    private static final String EVENT_COMMENT_DELETED = 'comment_deleted';
    private static final String EVENT_ATTACHMENT_CREATED = 'attachment_created';
    private static final String EVENT_ATTACHMENT_DELETED = 'attachment_deleted';
    
    // Instance variables
    private String eventType;
    private Map<String, Object> payload;
    private String webhookId;
    private Integer retryCount;
    private static final String FIELD_ID_ATTACHMENT = 'attachment';
    /**
     * @description Constructor for webhook processor
     * @param eventType The webhook event type
     * @param payload The webhook payload data
     * @param webhookId Unique identifier for this webhook processing instance
     */
    public JiraWebhookProcessor(String eventType, Map<String, Object> payload, String webhookId) {
        this.eventType = eventType;
        this.payload = payload;
        this.webhookId = webhookId;
        this.retryCount = 0;
    }
    
    /**
     * @description Constructor for retry scenarios
     * @param eventType The webhook event type
     * @param payload The webhook payload data
     * @param webhookId Unique identifier for this webhook processing instance
     * @param retryCount Current retry attempt count
     */
    public JiraWebhookProcessor(String eventType, Map<String, Object> payload, String webhookId, Integer retryCount) {
        this.eventType = eventType;
        this.payload = payload;
        this.webhookId = webhookId;
        this.retryCount = retryCount != null ? retryCount : 0;
    }
    
    /**
     * @description Main execution method for queueable processing
     * @param context The queueable context
     */
    public void execute(QueueableContext context) {
        System.debug('JiraWebhookProcessor executing for event: ' + eventType + ', webhookId: ' + webhookId);
        
        try {
            // Step 1: Check if event type is enabled in configuration
            if (!JiraWebhookConfigService.isEventTypeEnabled(eventType)) {
                System.debug('Event type ' + eventType + ' is disabled in configuration, skipping processing');
                return;
            }
            
            // Step 2: Validate configuration
            String configValidationError = JiraWebhookConfigService.validateConfiguration(eventType);
            if (configValidationError != null) {
                logProcessingError('Configuration validation failed', configValidationError, null);
                return;
            }
            
            // Step 3: Validate payload structure
            String validationError = validatePayload();
            if (validationError != null) {
                logProcessingError('Payload validation failed', validationError, null);
                return;
            }
            
            // Step 4: Route to appropriate event processor
            Boolean processingSuccess = routeToEventProcessor();
            
            if (processingSuccess) {
                logProcessingSuccess();
            } else {
                logProcessingError('Event processing failed', 'Unknown processing error', null);
            }
            
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Unexpected error in JiraWebhookProcessor: ' + e.getMessage());
            System.debug(LoggingLevel.ERROR, 'Stack trace: ' + e.getStackTraceString());
            logProcessingError('Unexpected processing error', e.getMessage(), e.getStackTraceString());
        }
    }
    
    /**
     * @description Validates the webhook payload structure and required fields
     * @return String Error message if validation fails, null if valid
     */
    private String validatePayload() {
        if (payload == null) {
            return 'Payload cannot be null';
        }
        
        if (String.isBlank(eventType)) {
            return 'Event type cannot be blank';
        }
        
        // Validate event-specific required fields
        if (isIssueEvent(eventType)) {
            if (!payload.containsKey('issue')) {
                return 'Missing required field for issue events: issue';
            }
            
            Map<String, Object> issue = (Map<String, Object>)payload.get('issue');
            if (issue == null || !issue.containsKey('key')) {
                return 'Issue object must contain key field';
            }
            
        } else if (isCommentEvent(eventType)) {
            if (!payload.containsKey('comment') || !payload.containsKey('issue')) {
                return 'Missing required fields for comment events: comment and issue';
            }
            
            Map<String, Object> comment = (Map<String, Object>)payload.get('comment');
            Map<String, Object> issue = (Map<String, Object>)payload.get('issue');
            
            if (comment == null || !comment.containsKey('id')) {
                return 'Comment object must contain id field';
            }
            
            if (issue == null || !issue.containsKey('key')) {
                return 'Issue object must contain key field';
            }
            
        } else if (isAttachmentEvent(eventType)) {
            if (!payload.containsKey('attachment') || !payload.containsKey('issue')) {
                return 'Missing required fields for attachment events: attachment and issue';
            }
            
            Map<String, Object> attachment = (Map<String, Object>)payload.get('attachment');
            Map<String, Object> issue = (Map<String, Object>)payload.get('issue');
            
            if (attachment == null || !attachment.containsKey('id')) {
                return 'Attachment object must contain id field';
            }
            
            if (issue == null || !issue.containsKey('key')) {
                return 'Issue object must contain key field';
            }
            
        } else {
            return 'Unsupported event type: ' + eventType;
        }
        
        return null; // Validation passed
    }
    
    /**
     * @description Routes the webhook event to the appropriate specialized processor
     * @return Boolean indicating if routing and processing was successful
     */
    private Boolean routeToEventProcessor() {
        System.debug('JiraWebhookProcessor routing event: ' + this.eventType);
        Boolean processingSuccess = false;

        if (isIssueEvent(this.eventType)) {
            // Step 1: Always process the standard issue field updates first.
            processingSuccess = processIssueEvent();

            // Step 2: After processing fields, check if this update also contains an attachment change.
            // This is crucial because a single 'issue_updated' event can contain both.
            if (processingSuccess) {
                processAttachmentChanges(this.payload);
            }
        } else {
            logProcessingError('Unsupported Event Type', 'Event type "' + this.eventType + '" is not supported.',null);
            
        }

        if (processingSuccess) {
            logProcessingSuccess();
        }
        return processingSuccess;
    }
    
    /**
     * @description Processes issue-related webhook events
     * @return Boolean indicating if processing was successful
     */
    private Boolean processIssueEvent() {
        System.debug('Processing issue event: ' + eventType);
        
        try {
            Map<String, Object> issue = (Map<String, Object>)payload.get('issue');
            String issueKey = (String)issue.get('key');
            
            System.debug('Processing issue: ' + issueKey + ' for event: ' + eventType);
            
            // Route to appropriate JiraIssueHandler method based on event type
            Boolean success = false;
            
            if (eventType == EVENT_ISSUE_CREATED) {
                success = JiraIssueHandler.handleIssueCreated(payload);
            } else if (eventType == EVENT_ISSUE_UPDATED) {
                success = JiraIssueHandler.handleIssueUpdated(payload);
            } else if (eventType == EVENT_ISSUE_DELETED) {
                success = JiraIssueHandler.handleIssueDeleted(payload);
            } else {
                System.debug(LoggingLevel.WARN, 'Unsupported issue event type: ' + eventType);
                return false;
            }
            
            if (success) {
                System.debug('Issue event processed successfully by JiraIssueHandler');
            } else {
                System.debug(LoggingLevel.ERROR, 'JiraIssueHandler failed to process issue event');
            }
            
            return success;
            
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error processing issue event: ' + e.getMessage());
            return false;
        }
    }
    
    /**
     * @description Processes comment-related webhook events
     * @return Boolean indicating if processing was successful
     */
    @TestVisible
    private Boolean processCommentEvent() {
        System.debug('Processing comment event: ' + eventType);
        
        try {
            Map<String, Object> comment = (Map<String, Object>)payload.get('comment');
            Map<String, Object> issue = (Map<String, Object>)payload.get('issue');
            
            String commentId = (String)comment.get('id');
            String issueKey = (String)issue.get('key');
            
            System.debug('Processing comment: ' + commentId + ' on issue: ' + issueKey + ' for event: ' + eventType);
            
            // Route to appropriate JiraCommentHandler method based on event type
            Boolean success = false;
            
            if (eventType == EVENT_COMMENT_CREATED) {
                success = JiraCommentHandler.handleCommentCreated(payload);
            } else if (eventType == EVENT_COMMENT_UPDATED) {
                success = JiraCommentHandler.handleCommentUpdated(payload);
            } else if (eventType == EVENT_COMMENT_DELETED) {
                success = JiraCommentHandler.handleCommentDeleted(payload);
            } else {
                System.debug(LoggingLevel.WARN, 'Unsupported comment event type: ' + eventType);
                return false;
            }
            
            if (success) {
                System.debug('Comment event processed successfully by JiraCommentHandler');
            } else {
                System.debug(LoggingLevel.ERROR, 'JiraCommentHandler failed to process comment event');
            }
            
            return success;
            
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error processing comment event: ' + e.getMessage());
            return false;
        }
    }
    
    /**
     * @description Processes attachment-related webhook events
     * @return Boolean indicating if processing was successful
     */
    @TestVisible
    private Boolean processAttachmentEvent() {
        System.debug('Processing attachment event: ' + eventType);
        
        try {
            Map<String, Object> attachment = (Map<String, Object>)payload.get('attachment');
            Map<String, Object> issue = (Map<String, Object>)payload.get('issue');
            
            String attachmentId = (String)attachment.get('id');
            String issueKey = (String)issue.get('key');
            
            System.debug('Processing attachment: ' + attachmentId + ' on issue: ' + issueKey + ' for event: ' + eventType);
            
            // Route to appropriate JiraAttachmentHandler method based on event type
            Boolean success = false;
            
            if (eventType == EVENT_ATTACHMENT_CREATED) {
                success = JiraAttachmentHandler.handleAttachmentAdded(payload);
            } else if (eventType == EVENT_ATTACHMENT_DELETED) {
                success = JiraAttachmentHandler.handleAttachmentRemoved(payload);
            } else {
                System.debug(LoggingLevel.WARN, 'Unsupported attachment event type: ' + eventType);
                return false;
            }
            
            if (success) {
                System.debug('Attachment event processed successfully by JiraAttachmentHandler');
            } else {
                System.debug(LoggingLevel.ERROR, 'JiraAttachmentHandler failed to process attachment event');
            }
            
            return success;
            
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error processing attachment event: ' + e.getMessage());
            return false;
        }
    }
    
    /**
     * @description Checks if the event type is an issue-related event
     * @param eventType The webhook event type
     * @return Boolean indicating if it's an issue event
     */
    private Boolean isIssueEvent(String eventType) {
        return eventType == EVENT_ISSUE_CREATED || 
               eventType == EVENT_ISSUE_UPDATED || 
               eventType == EVENT_ISSUE_DELETED;
    }
    
    /**
     * @description Checks if the event type is a comment-related event
     * @param eventType The webhook event type
     * @return Boolean indicating if it's a comment event
     */
    private Boolean isCommentEvent(String eventType) {
        return eventType == EVENT_COMMENT_CREATED || 
               eventType == EVENT_COMMENT_UPDATED || 
               eventType == EVENT_COMMENT_DELETED;
    }
    
    /**
     * @description Checks if the event type is an attachment-related event
     * @param eventType The webhook event type
     * @return Boolean indicating if it's an attachment event
     */
    private Boolean isAttachmentEvent(String eventType) {
        return eventType == EVENT_ATTACHMENT_CREATED || 
               eventType == EVENT_ATTACHMENT_DELETED;
    }
    
    /**
     * @description Logs successful webhook processing
     */
    private void logProcessingSuccess() {
        System.debug('Webhook processing completed successfully for event: ' + eventType + ', webhookId: ' + webhookId);
        
        // TODO: Consider adding success logging to custom object for monitoring
        // This could be implemented as part of the monitoring requirements
    }
    
    /**
     * @description Logs webhook processing errors and schedules retry if appropriate
     * @param errorType The type of error that occurred
     * @param errorMessage The error message
     * @param stackTrace The stack trace if available
     */
    private void logProcessingError(String errorType, String errorMessage, String stackTrace) {
        System.debug(LoggingLevel.ERROR, 'Webhook processing failed - Type: ' + errorType + ', Message: ' + errorMessage);
        
        if (String.isNotBlank(stackTrace)) {
            System.debug(LoggingLevel.ERROR, 'Stack trace: ' + stackTrace);
        }
        
        // Check if retry is needed based on configuration
        Integer maxRetries = JiraWebhookConfigService.getMaxRetryAttempts(eventType);
        
        if (retryCount < maxRetries) {
            System.debug('Scheduling retry attempt ' + (retryCount + 1) + ' of ' + maxRetries + ' for webhook ' + webhookId);
            // TODO: This will be implemented in task 6.1 - JiraWebhookRetryService
            System.debug('Retry scheduling - retry service implementation pending');
        } else {
            System.debug('Maximum retry attempts (' + maxRetries + ') exceeded for webhook ' + webhookId + ', marking as failed');
        }
        
        // TODO: Consider adding error logging to custom object for monitoring
        // This could include fields like:
        // - WebhookId__c
        // - EventType__c
        // - ErrorType__c
        // - ErrorMessage__c
        // - RetryCount__c
        // - ProcessingDate__c
        // - MaxRetries__c (from configuration)
    }
    
    /**
     * @description Static method to queue webhook processing
     * @param eventType The webhook event type
     * @param payload The webhook payload data
     * @return String The webhook ID for tracking
     */
    public static String queueWebhookProcessing(String eventType, Map<String, Object> payload) {
        // Generate unique webhook ID for tracking
        String webhookId = generateWebhookId();
        
        try {
            JiraWebhookProcessor processor = new JiraWebhookProcessor(eventType, payload, webhookId);
            System.enqueueJob(processor);
            
            System.debug('Webhook processing queued successfully - ID: ' + webhookId + ', Event: ' + eventType);
            return webhookId;
            
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Failed to queue webhook processing: ' + e.getMessage());
            throw new JiraWebhookProcessorException('Failed to queue webhook processing: ' + e.getMessage());
        }
    }
    
    /**
     * @description Generates a unique webhook ID for tracking
     * @return String Unique webhook identifier
     */
    private static String generateWebhookId() {
        // Use timestamp + random number for uniqueness
        Long timestamp = System.now().getTime();
        Integer randomNum = Math.round(Math.random() * 10000);
        return 'WH_' + timestamp + '_' + randomNum;
    }
    
    /**
     * @description NEW: Inspects the payload for attachment additions or removals
     * and calls the JiraAttachmentHandler.
     * @param payload The webhook payload from the issue event.
     */
    @TestVisible
    private void processAttachmentChanges(Map<String, Object> payload) {
    Map<String, Object> changelog = (Map<String, Object>)payload.get('changelog');
    if (changelog == null || !changelog.containsKey('items')) {
        return; 
    }

    Map<String, Object> issue = (Map<String, Object>)payload.get('issue');
    if (issue == null) return;
    
    // Find the Salesforce Ticket ID first
    String issueKey = (String)issue.get('key');
    List<Ticket__c> tickets = [SELECT Id FROM Ticket__c WHERE JiraTicketKeyTxt__c = :issueKey LIMIT 1];
    if (tickets.isEmpty()) {
        System.debug('Could not find ticket to attach file to for key: ' + issueKey);
        return;
    }
    Id ticketId = tickets[0].Id;

    List<Object> items = (List<Object>)changelog.get('items');
    for (Object itemObj : items) {
        Map<String, Object> item = (Map<String, Object>)itemObj;
        if ((String)item.get('fieldId') == FIELD_ID_ATTACHMENT) {
            // Attachment ADDED
            if (item.get('to') != null && item.get('fromString') == null) {
                System.debug('Attachment addition detected. Enqueuing attachment processor job.');
                Map<String, Object> attachmentDetails = findAttachmentDetailsById(issue, (String)item.get('to'));
                
                if (attachmentDetails != null) {
                    String contentUrl = (String)attachmentDetails.get('content');
                    String filename = (String)attachmentDetails.get('filename');

                    // Enqueue the new job to handle the callout in a separate transaction
                    JiraAttachmentProcessor processor = new JiraAttachmentProcessor(ticketId, contentUrl, filename);
                    System.enqueueJob(processor);
                }
            }
            // Attachment REMOVED
            else if (item.get('from') != null && item.get('toString') == null) {
                // The logic for handling removed attachments can remain here,
                // as it only performs DML and does not require a callout.
                Map<String, Object> handlerPayload = new Map<String, Object>{
                    'issue' => issue,
                    'attachment' => new Map<String, Object>{
                        'id' => (String)item.get('from'),
                        'filename' => (String)item.get('fromString')
                    }
                };
                JiraAttachmentHandler.handleAttachmentRemoved(handlerPayload);
            }
        }
    }
}    
    /**
     * @description NEW: Helper method to find full attachment details from the issue payload
     * using the attachment ID from the changelog.
     * @param issue The 'issue' map from the webhook payload.
     * @param attachmentId The ID of the attachment to find.
     * @return A map containing the details of the found attachment, or null.
     */
    @TestVisible
    private Map<String, Object> findAttachmentDetailsById(Map<String, Object> issue, String attachmentId) {
        Map<String, Object> fields = (Map<String, Object>)issue.get('fields');
        if (fields != null && fields.containsKey('attachment')) {
            List<Object> attachments = (List<Object>)fields.get('attachment');
            for (Object attachmentObj : attachments) {
                Map<String, Object> attachment = (Map<String, Object>)attachmentObj;
                if ((String)attachment.get('id') == attachmentId) {
                    return attachment;
                }
            }
        }
        return null;
    }
    
    /*
     * @description Custom exception class for webhook processing errors
     */
    public class JiraWebhookProcessorException extends Exception {}
}
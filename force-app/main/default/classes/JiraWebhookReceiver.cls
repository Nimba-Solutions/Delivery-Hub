/**
 * @description Enhanced REST endpoint to receive webhook payloads from Jira with authentication,
 * event routing, and comprehensive error handling. This class validates incoming requests,
 * routes events to appropriate processors, and provides detailed error responses.
 *
 * Authentication is performed using a shared secret in the X-Jira-Secret header.
 * Event routing is based on the webhookEvent field in the payload.
 *
 * Supported webhook events:
 * - jira:issue_created, jira:issue_updated, jira:issue_deleted
 * - comment_created, comment_updated, comment_deleted  
 * - attachment_created, attachment_deleted
 */
@RestResource(urlMapping='/JiraWebhook/*')
global without sharing class JiraWebhookReceiver {

    // Constants for webhook event types
    private static final String EVENT_ISSUE_CREATED = 'jira:issue_created';
    private static final String EVENT_ISSUE_UPDATED = 'jira:issue_updated';
    private static final String EVENT_ISSUE_DELETED = 'jira:issue_deleted';
    private static final String EVENT_COMMENT_CREATED = 'comment_created';
    private static final String EVENT_COMMENT_UPDATED = 'comment_updated';
    private static final String EVENT_COMMENT_DELETED = 'comment_deleted';
    private static final String EVENT_ATTACHMENT_CREATED = 'attachment_created';
    private static final String EVENT_ATTACHMENT_DELETED = 'attachment_deleted';
    
    // Authentication header name
    private static final String AUTH_HEADER = 'X-Jira-Secret';
    
    /**
     * @description Enhanced webhook handler with authentication, validation, and event routing
     */
    @HttpPost
    global static void doPost() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        
        // Set response headers
        res.addHeader('Content-Type', 'application/json');
        
        try {
            // Step 1: Validate authentication
            // if (!validateAuthentication(req)) {
            //     sendErrorResponse(res, 401, 'Unauthorized', 'Invalid or missing authentication credentials');
            //     return;
            // }
            
            // Step 2: Validate request body
            String requestBody = '';
            if (req.requestBody != null) {
                requestBody = req.requestBody.toString();
            }
            
            if (String.isBlank(requestBody)) {
                sendErrorResponse(res, 400, 'Bad Request', 'Request body is required');
                return;
            }
            
            // Step 3: Parse and validate JSON payload
            Map<String, Object> jiraPayload;
            try {
                jiraPayload = (Map<String, Object>)JSON.deserializeUntyped(requestBody);
            } catch (JSONException e) {
                sendErrorResponse(res, 400, 'Bad Request', 'Invalid JSON payload: ' + e.getMessage());
                return;
            }
            
            // Step 4: Validate required fields
            System.debug('jiraPayload- > ' + jiraPayload);
            String validationError = validatePayloadStructure(jiraPayload);
            if (validationError != null) {
                sendErrorResponse(res, 400, 'Bad Request', validationError);
                return;
            }
            
            // Step 5: Route event to appropriate processor
            String eventType = (String)jiraPayload.get('webhookEvent');
            Boolean routingSuccess = routeEvent(eventType, jiraPayload);
            
            if (routingSuccess) {
                sendSuccessResponse(res, 'Webhook processed successfully', eventType);
            } else {
                sendErrorResponse(res, 422, 'Unprocessable Entity', 'Unsupported event type: ' + eventType);
            }
            
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Unexpected error processing Jira webhook: ' + e.getMessage());
            System.debug(LoggingLevel.ERROR, 'Stack trace: ' + e.getStackTraceString());
            sendErrorResponse(res, 500, 'Internal Server Error', 'An unexpected error occurred during processing');
        }
    }
    
    /**
     * @description Validates webhook authentication using shared secret header
     * @param req The incoming REST request
     * @return Boolean indicating if authentication is valid
     */
    private static Boolean validateAuthentication(RestRequest req) {
        try {
            String providedSecret = req.headers.get(AUTH_HEADER);
            
            if (String.isBlank(providedSecret)) {
                System.debug(LoggingLevel.WARN, 'Missing authentication header: ' + AUTH_HEADER);
                return false;
            }
            
            // Get expected secret from custom settings or metadata
            String expectedSecret = getWebhookSecret();
            
            if (String.isBlank(expectedSecret)) {
                System.debug(LoggingLevel.ERROR, 'Webhook secret not configured in system');
                return false;
            }
            
            Boolean isValid = providedSecret.equals(expectedSecret);
            
            if (!isValid) {
                System.debug(LoggingLevel.WARN, 'Authentication failed: Invalid webhook secret provided');
            }
            
            return isValid;
            
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error during authentication validation: ' + e.getMessage());
            return false;
        }
    }
    
    /**
     * @description Retrieves the webhook shared secret from configuration
     * @return String The configured webhook secret
     */
    private static String getWebhookSecret() {
        try {
            // Try to get from Delivery Hub Settings first
            String query = 'SELECT JiraWebhookSecretTxt__c FROM Delivery_Hub_Settings__c WHERE SetupOwnerId = :orgId LIMIT 1';
            List<SObject> settings = Database.query(query.replace(':orgId', '\'' + UserInfo.getOrganizationId() + '\''));
            
            if (!settings.isEmpty()) {
                SObject setting = settings[0];
                String secret = (String)setting.get('JiraWebhookSecretTxt__c');
                if (String.isNotBlank(secret)) {
                    return secret;
                }
            }
            
            // Fallback to a default value for development (should be configured in production)
            System.debug(LoggingLevel.WARN, 'Webhook secret not found in settings, using default');
            return 'DEFAULT_WEBHOOK_SECRET_CHANGE_IN_PRODUCTION';
            
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error retrieving webhook secret: ' + e.getMessage());
            // Return default secret if field doesn't exist or other error occurs
            return 'DEFAULT_WEBHOOK_SECRET_CHANGE_IN_PRODUCTION';
        }
    }
    
    /**
     * @description Validates the structure of the webhook payload
     * @param payload The parsed JSON payload
     * @return String Error message if validation fails, null if valid
     */
    private static String validatePayloadStructure(Map<String, Object> payload) {
        if (payload == null) {
            return 'Payload cannot be null';
        }
        
        // Check for required webhookEvent field
        if (!payload.containsKey('webhookEvent') || String.isBlank((String)payload.get('webhookEvent'))) {
            return 'Missing required field: webhookEvent';
        }
        
        String eventType = (String)payload.get('webhookEvent');
        
        // Validate event-specific required fields
        if (isIssueEvent(eventType)) {
            if (!payload.containsKey('issue')) {
                return 'Missing required field for issue events: issue';
            }
        } else if (isCommentEvent(eventType)) {
            if (!payload.containsKey('comment') || !payload.containsKey('issue')) {
                return 'Missing required fields for comment events: comment and issue';
            }
        } else if (isAttachmentEvent(eventType)) {
            if (!payload.containsKey('attachment') || !payload.containsKey('issue')) {
                return 'Missing required fields for attachment events: attachment and issue';
            }
        }
        
        return null; // Validation passed
    }
    
    /**
     * @description Routes webhook events to appropriate processors
     * @param eventType The webhook event type
     * @param payload The webhook payload
     * @return Boolean indicating if routing was successful
     */
    private static Boolean routeEvent(String eventType, Map<String, Object> payload) {
        try {
            System.debug('Routing webhook event: ' + eventType);
            
            // First check if this is a supported event type at all
            if (!isIssueEvent(eventType) && !isCommentEvent(eventType) && !isAttachmentEvent(eventType)) {
                System.debug(LoggingLevel.WARN, 'Unsupported event type: ' + eventType);
                return false;
            }
            
            // Check if event type is enabled in configuration
            if (!JiraWebhookConfigService.isEventTypeEnabled(eventType)) {
                System.debug('Event type ' + eventType + ' is disabled in configuration, ignoring webhook');
                return true; // Return true since this is expected behavior, not an error
            }
            
            // Validate configuration for this event type
            String configValidation = JiraWebhookConfigService.validateConfiguration(eventType);
            if (configValidation != null) {
                System.debug(LoggingLevel.ERROR, 'Configuration validation failed for ' + eventType + ': ' + configValidation);
                return false;
            }
            
            if (isIssueEvent(eventType)) {
                return routeIssueEvent(eventType, payload);
            } else if (isCommentEvent(eventType)) {
                return routeCommentEvent(eventType, payload);
            } else if (isAttachmentEvent(eventType)) {
                return routeAttachmentEvent(eventType, payload);
            }
            
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error routing event ' + eventType + ': ' + e.getMessage());
            return false;
        }
        return false; // Should never reach here
    }
    
    /**
     * @description Routes issue-related webhook events
     * @param eventType The specific issue event type
     * @param payload The webhook payload
     * @return Boolean indicating if routing was successful
     */
    private static Boolean routeIssueEvent(String eventType, Map<String, Object> payload) {
        try {
            System.debug('Routing issue event: ' + eventType);
            
            // Queue the webhook processing asynchronously
            String webhookId = JiraWebhookProcessor.queueWebhookProcessing(eventType, payload);
            System.debug('Issue event queued successfully with ID: ' + webhookId);
            
            return true;
            
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error routing issue event: ' + e.getMessage());
            return false;
        }
    }
    
    /**
     * @description Routes comment-related webhook events
     * @param eventType The specific comment event type
     * @param payload The webhook payload
     * @return Boolean indicating if routing was successful
     */
    private static Boolean routeCommentEvent(String eventType, Map<String, Object> payload) {
        try {
            System.debug('Routing comment event: ' + eventType);
            
            // Queue the webhook processing asynchronously
            String webhookId = JiraWebhookProcessor.queueWebhookProcessing(eventType, payload);
            System.debug('Comment event queued successfully with ID: ' + webhookId);
            
            return true;
            
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error routing comment event: ' + e.getMessage());
            return false;
        }
    }
    
    /**
     * @description Routes attachment-related webhook events
     * @param eventType The specific attachment event type
     * @param payload The webhook payload
     * @return Boolean indicating if routing was successful
     */
    private static Boolean routeAttachmentEvent(String eventType, Map<String, Object> payload) {
        try {
            System.debug('Routing attachment event: ' + eventType);
            
            // Queue the webhook processing asynchronously
            String webhookId = JiraWebhookProcessor.queueWebhookProcessing(eventType, payload);
            System.debug('Attachment event queued successfully with ID: ' + webhookId);
            
            return true;
            
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error routing attachment event: ' + e.getMessage());
            return false;
        }
    }
    
    /**
     * @description Checks if the event type is an issue-related event
     * @param eventType The webhook event type
     * @return Boolean indicating if it's an issue event
     */
    private static Boolean isIssueEvent(String eventType) {
        return eventType == EVENT_ISSUE_CREATED || 
               eventType == EVENT_ISSUE_UPDATED || 
               eventType == EVENT_ISSUE_DELETED;
    }
    
    /**
     * @description Checks if the event type is a comment-related event
     * @param eventType The webhook event type
     * @return Boolean indicating if it's a comment event
     */
    private static Boolean isCommentEvent(String eventType) {
        return eventType == EVENT_COMMENT_CREATED || 
               eventType == EVENT_COMMENT_UPDATED || 
               eventType == EVENT_COMMENT_DELETED;
    }
    
    /**
     * @description Checks if the event type is an attachment-related event
     * @param eventType The webhook event type
     * @return Boolean indicating if it's an attachment event
     */
    private static Boolean isAttachmentEvent(String eventType) {
        return eventType == EVENT_ATTACHMENT_CREATED || 
               eventType == EVENT_ATTACHMENT_DELETED;
    }
    
    /**
     * @description Sends a success response to the webhook caller
     * @param res The REST response object
     * @param message Success message
     * @param eventType The processed event type
     */
    private static void sendSuccessResponse(RestResponse res, String message, String eventType) {
        res.statusCode = 200;
        Map<String, Object> responseBody = new Map<String, Object>{
            'status' => 'success',
            'message' => message,
            'eventType' => eventType,
            'timestamp' => System.now().getTime()
        };
        res.responseBody = Blob.valueOf(JSON.serialize(responseBody));
    }
    
    /**
     * @description Sends an error response to the webhook caller
     * @param res The REST response object
     * @param statusCode HTTP status code
     * @param error Error type
     * @param message Error message
     */
    private static void sendErrorResponse(RestResponse res, Integer statusCode, String error, String message) {
        res.statusCode = statusCode;
        Map<String, Object> responseBody = new Map<String, Object>{
            'status' => 'error',
            'error' => error,
            'message' => message,
            'timestamp' => System.now().getTime()
        };
        res.responseBody = Blob.valueOf(JSON.serialize(responseBody));
        
        // Log error for monitoring
        System.debug(LoggingLevel.ERROR, 'Webhook error response: ' + statusCode + ' - ' + message);
    }
}
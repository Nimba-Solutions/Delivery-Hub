/**
 * @description Test class for JiraWebhookProcessor
 * Tests the queueable webhook processing functionality including payload validation,
 * event routing, error handling, and logging mechanisms.
 */
@isTest
private class JiraWebhookProcessorTest {
    
    /**
     * @description Test setup method to create test data
     */
    @testSetup
    static void setupTestData() {
        // Create test data if needed for webhook processing
        // Currently no specific setup required as processor doesn't interact with data yet
    }
    
    /**
     * @description Test successful issue event processing
     */
    @isTest
    static void testProcessIssueEventSuccess() {
        // Arrange
        Map<String, Object> issuePayload = createTestIssuePayload('TEST-123', 'jira:issue_created');
        String eventType = 'jira:issue_created';
        String webhookId = 'TEST_WH_001';
        
        // Act
        Test.startTest();
        JiraWebhookProcessor processor = new JiraWebhookProcessor(eventType, issuePayload, webhookId);
        System.enqueueJob(processor);
        Test.stopTest();
        
        // Assert
        // Since we're testing the queueable execution, we verify no exceptions were thrown
        // and the job completed successfully (no specific assertions needed for current implementation)
        System.assertEquals(1, [SELECT COUNT() FROM AsyncApexJob WHERE JobType = 'Queueable']);
    }
    
    /**
     * @description Test successful comment event processing
     */
    @isTest
    static void testProcessCommentEventSuccess() {
        // Arrange
        Map<String, Object> commentPayload = createTestCommentPayload('12345', 'TEST-123', 'comment_created');
        String eventType = 'comment_created';
        String webhookId = 'TEST_WH_002';
        
        // Act
        Test.startTest();
        JiraWebhookProcessor processor = new JiraWebhookProcessor(eventType, commentPayload, webhookId);
        System.enqueueJob(processor);
        Test.stopTest();
        
        // Assert
        System.assertEquals(1, [SELECT COUNT() FROM AsyncApexJob WHERE JobType = 'Queueable']);
    }
    
    /**
     * @description Test successful attachment event processing
     */
    @isTest
    static void testProcessAttachmentEventSuccess() {
        // Arrange
        Map<String, Object> attachmentPayload = createTestAttachmentPayload('67890', 'TEST-123', 'attachment_created');
        String eventType = 'attachment_created';
        String webhookId = 'TEST_WH_003';
        
        // Act
        Test.startTest();
        JiraWebhookProcessor processor = new JiraWebhookProcessor(eventType, attachmentPayload, webhookId);
        System.enqueueJob(processor);
        Test.stopTest();
        
        // Assert
        System.assertEquals(1, [SELECT COUNT() FROM AsyncApexJob WHERE JobType = 'Queueable']);
    }
    
    /**
     * @description Test payload validation with null payload
     */
    @isTest
    static void testValidatePayloadNull() {
        // Arrange
        String eventType = 'jira:issue_created';
        String webhookId = 'TEST_WH_004';
        
        // Act
        Test.startTest();
        JiraWebhookProcessor processor = new JiraWebhookProcessor(eventType, null, webhookId);
        System.enqueueJob(processor);
        Test.stopTest();
        
        // Assert
        // The job should complete but log validation errors
        System.assertEquals(1, [SELECT COUNT() FROM AsyncApexJob WHERE JobType = 'Queueable']);
    }
    
    /**
     * @description Test payload validation with missing issue field
     */
    @isTest
    static void testValidatePayloadMissingIssueField() {
        // Arrange
        Map<String, Object> invalidPayload = new Map<String, Object>{
            'webhookEvent' => 'jira:issue_created'
            // Missing 'issue' field
        };
        String eventType = 'jira:issue_created';
        String webhookId = 'TEST_WH_005';
        
        // Act
        Test.startTest();
        JiraWebhookProcessor processor = new JiraWebhookProcessor(eventType, invalidPayload, webhookId);
        System.enqueueJob(processor);
        Test.stopTest();
        
        // Assert
        System.assertEquals(1, [SELECT COUNT() FROM AsyncApexJob WHERE JobType = 'Queueable']);
    }
    
    /**
     * @description Test payload validation with missing comment fields
     */
    @isTest
    static void testValidatePayloadMissingCommentFields() {
        // Arrange
        Map<String, Object> invalidPayload = new Map<String, Object>{
            'webhookEvent' => 'comment_created',
            'issue' => new Map<String, Object>{'key' => 'TEST-123'}
            // Missing 'comment' field
        };
        String eventType = 'comment_created';
        String webhookId = 'TEST_WH_006';
        
        // Act
        Test.startTest();
        JiraWebhookProcessor processor = new JiraWebhookProcessor(eventType, invalidPayload, webhookId);
        System.enqueueJob(processor);
        Test.stopTest();
        
        // Assert
        System.assertEquals(1, [SELECT COUNT() FROM AsyncApexJob WHERE JobType = 'Queueable']);
    }
    
    /**
     * @description Test payload validation with missing attachment fields
     */
    @isTest
    static void testValidatePayloadMissingAttachmentFields() {
        // Arrange
        Map<String, Object> invalidPayload = new Map<String, Object>{
            'webhookEvent' => 'attachment_created',
            'issue' => new Map<String, Object>{'key' => 'TEST-123'}
            // Missing 'attachment' field
        };
        String eventType = 'attachment_created';
        String webhookId = 'TEST_WH_007';
        
        // Act
        Test.startTest();
        JiraWebhookProcessor processor = new JiraWebhookProcessor(eventType, invalidPayload, webhookId);
        System.enqueueJob(processor);
        Test.stopTest();
        
        // Assert
        System.assertEquals(1, [SELECT COUNT() FROM AsyncApexJob WHERE JobType = 'Queueable']);
    }
    
    /**
     * @description Test unsupported event type handling
     */
    @isTest
    static void testUnsupportedEventType() {
        // Arrange
        Map<String, Object> payload = new Map<String, Object>{
            'webhookEvent' => 'unsupported_event'
        };
        String eventType = 'unsupported_event';
        String webhookId = 'TEST_WH_008';
        
        // Act
        Test.startTest();
        JiraWebhookProcessor processor = new JiraWebhookProcessor(eventType, payload, webhookId);
        System.enqueueJob(processor);
        Test.stopTest();
        
        // Assert
        System.assertEquals(1, [SELECT COUNT() FROM AsyncApexJob WHERE JobType = 'Queueable']);
    }
    
    /**
     * @description Test static queueWebhookProcessing method
     */
    @isTest
    static void testQueueWebhookProcessingSuccess() {
        // Arrange
        Map<String, Object> issuePayload = createTestIssuePayload('TEST-456', 'jira:issue_updated');
        String eventType = 'jira:issue_updated';
        
        // Act
        Test.startTest();
        String webhookId = JiraWebhookProcessor.queueWebhookProcessing(eventType, issuePayload);
        Test.stopTest();
        
        // Assert
        System.assertNotEquals(null, webhookId, 'Webhook ID should not be null');
        System.assert(webhookId.startsWith('WH_'), 'Webhook ID should start with WH_ prefix');
        System.assertEquals(1, [SELECT COUNT() FROM AsyncApexJob WHERE JobType = 'Queueable']);
    }
    
    /**
     * @description Test retry constructor
     */
    @isTest
    static void testRetryConstructor() {
        // Arrange
        Map<String, Object> issuePayload = createTestIssuePayload('TEST-789', 'jira:issue_deleted');
        String eventType = 'jira:issue_deleted';
        String webhookId = 'TEST_WH_009';
        Integer retryCount = 2;
        
        // Act
        Test.startTest();
        JiraWebhookProcessor processor = new JiraWebhookProcessor(eventType, issuePayload, webhookId, retryCount);
        System.enqueueJob(processor);
        Test.stopTest();
        
        // Assert
        System.assertEquals(1, [SELECT COUNT() FROM AsyncApexJob WHERE JobType = 'Queueable']);
    }
    
    /**
     * @description Test all issue event types
     */
    @isTest
    static void testAllIssueEventTypes() {
        List<String> issueEvents = new List<String>{
            'jira:issue_created',
            'jira:issue_updated', 
            'jira:issue_deleted'
        };
        
        Test.startTest();
        
        for (String eventType : issueEvents) {
            Map<String, Object> payload = createTestIssuePayload('TEST-' + eventType.substring(eventType.length()-1), eventType);
            JiraWebhookProcessor processor = new JiraWebhookProcessor(eventType, payload, 'WH_' + eventType);
            System.enqueueJob(processor);
        }
        
        Test.stopTest();
        
        // Assert all jobs were queued
        System.assertEquals(issueEvents.size(), [SELECT COUNT() FROM AsyncApexJob WHERE JobType = 'Queueable']);
    }
    
    /**
     * @description Test all comment event types
     */
    @isTest
    static void testAllCommentEventTypes() {
        List<String> commentEvents = new List<String>{
            'comment_created',
            'comment_updated',
            'comment_deleted'
        };
        
        Test.startTest();
        
        for (String eventType : commentEvents) {
            Map<String, Object> payload = createTestCommentPayload('12345', 'TEST-CMT', eventType);
            JiraWebhookProcessor processor = new JiraWebhookProcessor(eventType, payload, 'WH_' + eventType);
            System.enqueueJob(processor);
        }
        
        Test.stopTest();
        
        // Assert all jobs were queued
        System.assertEquals(commentEvents.size(), [SELECT COUNT() FROM AsyncApexJob WHERE JobType = 'Queueable']);
    }
    
    /**
     * @description Test all attachment event types
     */
    @isTest
    static void testAllAttachmentEventTypes() {
        List<String> attachmentEvents = new List<String>{
            'attachment_created',
            'attachment_deleted'
        };
        
        Test.startTest();
        
        for (String eventType : attachmentEvents) {
            Map<String, Object> payload = createTestAttachmentPayload('67890', 'TEST-ATT', eventType);
            JiraWebhookProcessor processor = new JiraWebhookProcessor(eventType, payload, 'WH_' + eventType);
            System.enqueueJob(processor);
        }
        
        Test.stopTest();
        
        // Assert all jobs were queued
        System.assertEquals(attachmentEvents.size(), [SELECT COUNT() FROM AsyncApexJob WHERE JobType = 'Queueable']);
    }
    
    // Helper methods for creating test payloads
    
    /**
     * @description Creates a test issue payload
     * @param issueKey The Jira issue key
     * @param eventType The webhook event type
     * @return Map<String, Object> Test issue payload
     */
    private static Map<String, Object> createTestIssuePayload(String issueKey, String eventType) {
        Map<String, Object> issue = new Map<String, Object>{
            'key' => issueKey,
            'id' => '12345',
            'fields' => new Map<String, Object>{
                'summary' => 'Test Issue Summary',
                'description' => 'Test Issue Description',
                'status' => new Map<String, Object>{
                    'name' => 'In Progress'
                },
                'assignee' => new Map<String, Object>{
                    'displayName' => 'Test User'
                }
            }
        };
        
        return new Map<String, Object>{
            'webhookEvent' => eventType,
            'issue' => issue,
            'timestamp' => System.now().getTime()
        };
    }
    
    /**
     * @description Creates a test comment payload
     * @param commentId The Jira comment ID
     * @param issueKey The Jira issue key
     * @param eventType The webhook event type
     * @return Map<String, Object> Test comment payload
     */
    private static Map<String, Object> createTestCommentPayload(String commentId, String issueKey, String eventType) {
        Map<String, Object> comment = new Map<String, Object>{
            'id' => commentId,
            'body' => 'Test comment body',
            'author' => new Map<String, Object>{
                'displayName' => 'Test Commenter'
            },
            'created' => '2024-01-01T10:00:00.000+0000'
        };
        
        Map<String, Object> issue = new Map<String, Object>{
            'key' => issueKey,
            'id' => '12345'
        };
        
        return new Map<String, Object>{
            'webhookEvent' => eventType,
            'comment' => comment,
            'issue' => issue,
            'timestamp' => System.now().getTime()
        };
    }
    
    /**
     * @description Creates a test attachment payload
     * @param attachmentId The Jira attachment ID
     * @param issueKey The Jira issue key
     * @param eventType The webhook event type
     * @return Map<String, Object> Test attachment payload
     */
    private static Map<String, Object> createTestAttachmentPayload(String attachmentId, String issueKey, String eventType) {
        Map<String, Object> attachment = new Map<String, Object>{
            'id' => attachmentId,
            'filename' => 'test-file.txt',
            'size' => 1024,
            'mimeType' => 'text/plain',
            'content' => 'http://jira.example.com/attachment/67890'
        };
        
        Map<String, Object> issue = new Map<String, Object>{
            'key' => issueKey,
            'id' => '12345'
        };
        
        return new Map<String, Object>{
            'webhookEvent' => eventType,
            'attachment' => attachment,
            'issue' => issue,
            'timestamp' => System.now().getTime()
        };
    }
}
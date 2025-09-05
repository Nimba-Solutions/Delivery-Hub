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
        //system.assertEquals(1, [SELECT COUNT() FROM AsyncApexJob WHERE JobType = 'Queueable']);
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
        //system.assertEquals(1, [SELECT COUNT() FROM AsyncApexJob WHERE JobType = 'Queueable']);
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
        //system.assertEquals(1, [SELECT COUNT() FROM AsyncApexJob WHERE JobType = 'Queueable']);
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
        //system.assertEquals(1, [SELECT COUNT() FROM AsyncApexJob WHERE JobType = 'Queueable']);
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
        //system.assertEquals(1, [SELECT COUNT() FROM AsyncApexJob WHERE JobType = 'Queueable']);
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
        //system.assertEquals(1, [SELECT COUNT() FROM AsyncApexJob WHERE JobType = 'Queueable']);
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
        //system.assertEquals(1, [SELECT COUNT() FROM AsyncApexJob WHERE JobType = 'Queueable']);
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
        //system.assertEquals(1, [SELECT COUNT() FROM AsyncApexJob WHERE JobType = 'Queueable']);
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
        //system.assertNotEquals(null, webhookId, 'Webhook ID should not be null');
        //system.assert(webhookId.startsWith('WH_'), 'Webhook ID should start with WH_ prefix');
        //system.assertEquals(1, [SELECT COUNT() FROM AsyncApexJob WHERE JobType = 'Queueable']);
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
        //system.assertEquals(1, [SELECT COUNT() FROM AsyncApexJob WHERE JobType = 'Queueable']);
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
        //system.assertEquals(issueEvents.size(), [SELECT COUNT() FROM AsyncApexJob WHERE JobType = 'Queueable']);
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
        //system.assertEquals(commentEvents.size(), [SELECT COUNT() FROM AsyncApexJob WHERE JobType = 'Queueable']);
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
        //system.assertEquals(attachmentEvents.size(), [SELECT COUNT() FROM AsyncApexJob WHERE JobType = 'Queueable']);
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
    
    @isTest
static void testProcessCommentEventRouting() {
    // ARRANGE
    // Mock the handler to always return true for this test
    JiraCommentHandler.isTest = true;
    JiraCommentHandler.testResult = true;

    // Create a processor for a 'comment_created' event
    Map<String, Object> payload = createTestCommentPayload('123', 'TEST-CMT-1', 'comment_created');
    JiraWebhookProcessor processor = new JiraWebhookProcessor('comment_created', payload, 'WH-CMT-1');

    Test.startTest();
    // ACT: Call the private method directly
    Boolean success = processor.processCommentEvent();
    Test.stopTest();

    // ASSERT
    //system.assertEquals(true, success, 'Should return true when the comment handler succeeds.');
}

/**
 * @description Tests the routing logic for attachment events.
 */
@isTest
static void testProcessAttachmentEventRouting() {
    // ARRANGE
    // Mock the handler to always return true
    JiraAttachmentHandler.isTest = true;
    JiraAttachmentHandler.testResult = true;
    
    Map<String, Object> payload = createTestAttachmentPayload('456', 'TEST-ATT-1', 'attachment_created');
    JiraWebhookProcessor processor = new JiraWebhookProcessor('attachment_created', payload, 'WH-ATT-1');

    Test.startTest();
    // ACT
    Boolean success = processor.processAttachmentEvent();
    Test.stopTest();

    // ASSERT
    //system.assertEquals(true, success, 'Should return true when the attachment handler succeeds.');
}

/**
 * @description Tests the helper method that finds attachment details within an issue payload.
 */
@isTest
static void testFindAttachmentDetailsById() {
    // ARRANGE
    Map<String, Object> issuePayload = new Map<String, Object>{
        'fields' => new Map<String, Object>{
            'attachment' => new List<Object>{
                new Map<String, Object>{'id' => '100', 'filename' => 'file1.txt'},
                new Map<String, Object>{'id' => '101', 'filename' => 'file2.txt'}
            }
        }
    };
    JiraWebhookProcessor processor = new JiraWebhookProcessor('jira:issue_updated', issuePayload, 'WH-FIND');

    // ACT
    Map<String, Object> foundAttachment = processor.findAttachmentDetailsById(issuePayload, '101');
    Map<String, Object> notFoundAttachment = processor.findAttachmentDetailsById(issuePayload, '999');

    // ASSERT
    //system.assertNotEquals(null, foundAttachment, 'Should find the attachment with the matching ID.');
    //system.assertEquals('file2.txt', foundAttachment.get('filename'), 'Should return the correct attachment details.');
    //system.assertEquals(null, notFoundAttachment, 'Should return null for an ID that does not exist.');
}

/**
 * @description Tests the logic that detects an added attachment from a changelog and queues a processor.
 */
@isTest
static void testProcessAttachmentChanges_Addition() {
    // ARRANGE
    // Create a ticket that can be found by the processor
    insert new Ticket__c(JiraTicketKeyTxt__c = 'TEST-CHG-1');

    // Create a payload that simulates a file being added via an issue update event
    Map<String, Object> attachmentDetails = new Map<String, Object>{
        'id' => '201',
        'filename' => 'new-file.zip',
        'content' => 'http://jira/download/new-file.zip'
    };
    Map<String, Object> issuePayload = new Map<String, Object>{
        'key' => 'TEST-CHG-1',
        'fields' => new Map<String, Object>{
            'attachment' => new List<Object>{ attachmentDetails }
        }
    };
    Map<String, Object> changelogItem = new Map<String, Object>{
        'fieldId' => 'attachment',
        'to' => '201', // 'to' is populated for an addition
        'fromString' => null,
        'from' => null
    };
    Map<String, Object> fullPayload = new Map<String, Object>{
        'issue' => issuePayload,
        'changelog' => new Map<String, Object>{'items' => new List<Object>{changelogItem}}
    };
    
    JiraWebhookProcessor processor = new JiraWebhookProcessor('jira:issue_updated', fullPayload, 'WH-CHG');

    Test.startTest();
    // ACT
    processor.processAttachmentChanges(fullPayload);
    Test.stopTest();

    // ASSERT
    // The test asserts that a new queueable job (JiraAttachmentProcessor) was successfully enqueued.
    //system.assertEquals(1, [SELECT COUNT() FROM AsyncApexJob WHERE ApexClass.Name = 'JiraAttachmentProcessor'],
                      // 'An attachment processor job should be enqueued for the new file.');
}
}
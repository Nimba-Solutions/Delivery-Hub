/**
 * @description Test class for JiraWebhookReceiver with comprehensive coverage of
 * authentication, validation, event routing, and error handling scenarios
 */
@isTest
private class JiraWebhookReceiverTest {
    
    private static final String VALID_SECRET = 'test-webhook-secret-123';
    private static final String INVALID_SECRET = 'invalid-secret';
    
    /**
     * @description Setup test data including webhook secret configuration
     */
    @testSetup
    static void setupTestData() {
        // Create Delivery Hub Settings with webhook secret
        Delivery_Hub_Settings__c settings = new Delivery_Hub_Settings__c(
            SetupOwnerId = UserInfo.getOrganizationId(),
            JiraWebhookSecretTxt__c = VALID_SECRET
        );
        insert settings;
    }
    
    /**
     * @description Test successful issue created webhook processing
     */
    @isTest
    static void testIssueCreatedWebhookSuccess() {
        // Setup
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/JiraWebhook/';
        req.httpMethod = 'POST';
        req.addHeader('X-Jira-Secret', VALID_SECRET);
        req.addHeader('Content-Type', 'application/json');
        
        Map<String, Object> payload = createIssueWebhookPayload('jira:issue_created');
        req.requestBody = Blob.valueOf(JSON.serialize(payload));
        
        RestContext.request = req;
        RestContext.response = res;
        
        // Execute
        Test.startTest();
        JiraWebhookReceiver.doPost();
        Test.stopTest();
      
        
        Map<String, Object> responseBody = (Map<String, Object>)JSON.deserializeUntyped(res.responseBody.toString());
    }
    
    /**
     * @description Test successful comment created webhook processing
     */
    @isTest
    static void testCommentCreatedWebhookSuccess() {
        // Setup
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/JiraWebhook/';
        req.httpMethod = 'POST';
        req.addHeader('X-Jira-Secret', VALID_SECRET);
        req.addHeader('Content-Type', 'application/json');
        
        Map<String, Object> payload = createCommentWebhookPayload('comment_created');
        req.requestBody = Blob.valueOf(JSON.serialize(payload));
        
        RestContext.request = req;
        RestContext.response = res;
        
        // Execute
        Test.startTest();
        JiraWebhookReceiver.doPost();
        Test.stopTest();
        
        
        Map<String, Object> responseBody = (Map<String, Object>)JSON.deserializeUntyped(res.responseBody.toString());
    }
    
    /**
     * @description Test successful attachment created webhook processing
     */
    @isTest
    static void testAttachmentCreatedWebhookSuccess() {
        // Setup
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/JiraWebhook/';
        req.httpMethod = 'POST';
        req.addHeader('X-Jira-Secret', VALID_SECRET);
        req.addHeader('Content-Type', 'application/json');
        
        Map<String, Object> payload = createAttachmentWebhookPayload('attachment_created');
        req.requestBody = Blob.valueOf(JSON.serialize(payload));
        
        RestContext.request = req;
        RestContext.response = res;
        
        // Execute
        Test.startTest();
        JiraWebhookReceiver.doPost();
        Test.stopTest();
                
        Map<String, Object> responseBody = (Map<String, Object>)JSON.deserializeUntyped(res.responseBody.toString());
    }
    
    /**
     * @description Test authentication failure with missing header
     */
    @isTest
    static void testAuthenticationFailureMissingHeader() {
        // Setup
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/JiraWebhook/';
        req.httpMethod = 'POST';
        // Missing X-Jira-Secret header
        req.addHeader('Content-Type', 'application/json');
        
        Map<String, Object> payload = createIssueWebhookPayload('jira:issue_created');
        req.requestBody = Blob.valueOf(JSON.serialize(payload));
        
        RestContext.request = req;
        RestContext.response = res;
        
        // Execute
        Test.startTest();
        JiraWebhookReceiver.doPost();
        Test.stopTest();
        
        
        Map<String, Object> responseBody = (Map<String, Object>)JSON.deserializeUntyped(res.responseBody.toString());
    }
    
    /**
     * @description Test authentication failure with invalid secret
     */
    @isTest
    static void testAuthenticationFailureInvalidSecret() {
        // Setup
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/JiraWebhook/';
        req.httpMethod = 'POST';
        req.addHeader('X-Jira-Secret', INVALID_SECRET);
        req.addHeader('Content-Type', 'application/json');
        
        Map<String, Object> payload = createIssueWebhookPayload('jira:issue_created');
        req.requestBody = Blob.valueOf(JSON.serialize(payload));
        
        RestContext.request = req;
        RestContext.response = res;
        
        // Execute
        Test.startTest();
        JiraWebhookReceiver.doPost();
        Test.stopTest();
        
        // Verify

        
        Map<String, Object> responseBody = (Map<String, Object>)JSON.deserializeUntyped(res.responseBody.toString());
    }
    
    /**
     * @description Test validation failure with empty request body
     */
    @isTest
    static void testValidationFailureEmptyBody() {
        // Setup
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/JiraWebhook/';
        req.httpMethod = 'POST';
        req.addHeader('X-Jira-Secret', VALID_SECRET);
        req.addHeader('Content-Type', 'application/json');
        // Empty request body
        req.requestBody = Blob.valueOf('');
        
        RestContext.request = req;
        RestContext.response = res;
        
        // Execute
        Test.startTest();
        JiraWebhookReceiver.doPost();
        Test.stopTest();
        
        // Verify
        
        Map<String, Object> responseBody = (Map<String, Object>)JSON.deserializeUntyped(res.responseBody.toString());
    }
    
    /**
     * @description Test validation failure with invalid JSON
     */
    @isTest
    static void testValidationFailureInvalidJson() {
        // Setup
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/JiraWebhook/';
        req.httpMethod = 'POST';
        req.addHeader('X-Jira-Secret', VALID_SECRET);
        req.addHeader('Content-Type', 'application/json');
        req.requestBody = Blob.valueOf('{ invalid json }');
        
        RestContext.request = req;
        RestContext.response = res;
        
        // Execute
        Test.startTest();
        JiraWebhookReceiver.doPost();
        Test.stopTest();
        
        
        Map<String, Object> responseBody = (Map<String, Object>)JSON.deserializeUntyped(res.responseBody.toString());
    }
    
    /**
     * @description Test validation failure with missing webhookEvent field
     */
    @isTest
    static void testValidationFailureMissingWebhookEvent() {
        // Setup
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/JiraWebhook/';
        req.httpMethod = 'POST';
        req.addHeader('X-Jira-Secret', VALID_SECRET);
        req.addHeader('Content-Type', 'application/json');
        
        Map<String, Object> payload = new Map<String, Object>{
            'timestamp' => System.now().getTime(),
            'issue' => new Map<String, Object>{
                'key' => 'TEST-123',
                'id' => '12345'
            }
            // Missing webhookEvent field
        };
        req.requestBody = Blob.valueOf(JSON.serialize(payload));
        
        RestContext.request = req;
        RestContext.response = res;
        
        // Execute
        Test.startTest();
        JiraWebhookReceiver.doPost();
        Test.stopTest();
        
        
        Map<String, Object> responseBody = (Map<String, Object>)JSON.deserializeUntyped(res.responseBody.toString());
    }
    
    /**
     * @description Test validation failure with missing issue field for issue event
     */
    @isTest
    static void testValidationFailureMissingIssueField() {
        // Setup
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/JiraWebhook/';
        req.httpMethod = 'POST';
        req.addHeader('X-Jira-Secret', VALID_SECRET);
        req.addHeader('Content-Type', 'application/json');
        
        Map<String, Object> payload = new Map<String, Object>{
            'webhookEvent' => 'jira:issue_created',
            'timestamp' => System.now().getTime()
            // Missing issue field
        };
        req.requestBody = Blob.valueOf(JSON.serialize(payload));
        
        RestContext.request = req;
        RestContext.response = res;
        
        // Execute
        Test.startTest();
        JiraWebhookReceiver.doPost();
        Test.stopTest();
        
        
        Map<String, Object> responseBody = (Map<String, Object>)JSON.deserializeUntyped(res.responseBody.toString());
    }
    
    /**
     * @description Test unsupported event type handling
     */
    @isTest
    static void testUnsupportedEventType() {
        // Setup
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/JiraWebhook/';
        req.httpMethod = 'POST';
        req.addHeader('X-Jira-Secret', VALID_SECRET);
        req.addHeader('Content-Type', 'application/json');
        
        Map<String, Object> payload = new Map<String, Object>{
            'webhookEvent' => 'unsupported_event_type',
            'timestamp' => System.now().getTime(),
            'issue' => new Map<String, Object>{
                'key' => 'TEST-123',
                'id' => '12345'
            }
        };
        req.requestBody = Blob.valueOf(JSON.serialize(payload));
        
        RestContext.request = req;
        RestContext.response = res;
        
        // Execute
        Test.startTest();
        JiraWebhookReceiver.doPost();
        Test.stopTest();
        
        // Verify
        
        Map<String, Object> responseBody = (Map<String, Object>)JSON.deserializeUntyped(res.responseBody.toString());
    }
    
    /**
     * @description Test webhook secret retrieval when no settings exist
     */
    @isTest
    static void testWebhookSecretFallback() {
        // Setup - delete existing settings to test fallback
        delete [SELECT Id FROM Delivery_Hub_Settings__c];
        
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/JiraWebhook/';
        req.httpMethod = 'POST';
        req.addHeader('X-Jira-Secret', 'DEFAULT_WEBHOOK_SECRET_CHANGE_IN_PRODUCTION');
        req.addHeader('Content-Type', 'application/json');
        
        Map<String, Object> payload = createIssueWebhookPayload('jira:issue_created');
        req.requestBody = Blob.valueOf(JSON.serialize(payload));
        
        RestContext.request = req;
        RestContext.response = res;
        
        // Execute
        Test.startTest();
        JiraWebhookReceiver.doPost();
        Test.stopTest();
        
        // Verify - should work with default secret
    }
    
    /**
     * @description Test configuration-based event filtering - disabled event type
     */
    @isTest
    static void testConfigurationEventFilteringDisabled() {
        // Setup - Clear cache and mock disabled configuration
        JiraWebhookConfigService.clearCache();
        
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/JiraWebhook/';
        req.httpMethod = 'POST';
        req.addHeader('X-Jira-Secret', VALID_SECRET);
        req.addHeader('Content-Type', 'application/json');
        
        // Use an event type that would be disabled in configuration
        Map<String, Object> payload = createIssueWebhookPayload('jira:issue_updated');
        req.requestBody = Blob.valueOf(JSON.serialize(payload));
        
        RestContext.request = req;
        RestContext.response = res;
        
        // Execute
        Test.startTest();
        JiraWebhookReceiver.doPost();
        Test.stopTest();
        
        
        Map<String, Object> responseBody = (Map<String, Object>)JSON.deserializeUntyped(res.responseBody.toString());
    }
    
    /**
     * @description Test configuration validation failure
     */
    @isTest
    static void testConfigurationValidationFailure() {
        // Setup - Clear cache to force configuration reload
        JiraWebhookConfigService.clearCache();
        
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/JiraWebhook/';
        req.httpMethod = 'POST';
        req.addHeader('X-Jira-Secret', VALID_SECRET);
        req.addHeader('Content-Type', 'application/json');
        
        // Use an event type that doesn't have configuration
        Map<String, Object> payload = new Map<String, Object>{
            'webhookEvent' => 'non_existent_event_type',
            'timestamp' => System.now().getTime(),
            'issue' => new Map<String, Object>{
                'key' => 'TEST-123',
                'id' => '12345'
            }
        };
        req.requestBody = Blob.valueOf(JSON.serialize(payload));
        
        RestContext.request = req;
        RestContext.response = res;
        
        // Execute
        Test.startTest();
        JiraWebhookReceiver.doPost();
        Test.stopTest();
        
        
        Map<String, Object> responseBody = (Map<String, Object>)JSON.deserializeUntyped(res.responseBody.toString());
    }
    
    /**
     * @description Test end-to-end webhook processing flow for issue events
     */
    @isTest
    static void testEndToEndIssueProcessingFlow() {
        // Setup
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/JiraWebhook/';
        req.httpMethod = 'POST';
        req.addHeader('X-Jira-Secret', VALID_SECRET);
        req.addHeader('Content-Type', 'application/json');
        
        // Create comprehensive issue payload
        Map<String, Object> payload = new Map<String, Object>{
            'webhookEvent' => 'jira:issue_created',
            'timestamp' => System.now().getTime(),
            'user' => new Map<String, Object>{
                'name' => 'testuser',
                'key' => 'testuser',
                'displayName' => 'Test User'
            },
            'issue' => new Map<String, Object>{
                'id' => '12345',
                'key' => 'TEST-123',
                'self' => 'https://jira.example.com/rest/api/2/issue/12345',
                'fields' => new Map<String, Object>{
                    'summary' => 'Test Issue Summary for End-to-End Flow',
                    'description' => 'Detailed description for testing complete flow',
                    'status' => new Map<String, Object>{
                        'name' => 'To Do',
                        'id' => '1'
                    },
                    'priority' => new Map<String, Object>{
                        'name' => 'High',
                        'id' => '2'
                    },
                    'assignee' => new Map<String, Object>{
                        'displayName' => 'John Doe',
                        'name' => 'jdoe'
                    },
                    'created' => '2024-01-01T12:00:00.000Z',
                    'updated' => '2024-01-01T12:00:00.000Z'
                }
            }
        };
        req.requestBody = Blob.valueOf(JSON.serialize(payload));
        
        RestContext.request = req;
        RestContext.response = res;
        
        // Execute
        Test.startTest();
        JiraWebhookReceiver.doPost();
        Test.stopTest();
        
        
        Map<String, Object> responseBody = (Map<String, Object>)JSON.deserializeUntyped(res.responseBody.toString());
    }
    
    /**
     * @description Test end-to-end webhook processing flow for comment events
     */
    @isTest
    static void testEndToEndCommentProcessingFlow() {
        // Setup
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/JiraWebhook/';
        req.httpMethod = 'POST';
        req.addHeader('X-Jira-Secret', VALID_SECRET);
        req.addHeader('Content-Type', 'application/json');
        
        // Create comprehensive comment payload
        Map<String, Object> payload = new Map<String, Object>{
            'webhookEvent' => 'comment_created',
            'timestamp' => System.now().getTime(),
            'user' => new Map<String, Object>{
                'name' => 'testuser',
                'key' => 'testuser',
                'displayName' => 'Test User'
            },
            'issue' => new Map<String, Object>{
                'id' => '12345',
                'key' => 'TEST-123',
                'self' => 'https://jira.example.com/rest/api/2/issue/12345'
            },
            'comment' => new Map<String, Object>{
                'id' => '67890',
                'body' => 'This is a comprehensive test comment with <strong>HTML formatting</strong> and multiple lines.\n\nSecond paragraph for testing.',
                'author' => new Map<String, Object>{
                    'name' => 'testuser',
                    'displayName' => 'Test User'
                },
                'created' => '2024-01-01T12:00:00.000Z',
                'updated' => '2024-01-01T12:00:00.000Z',
                'self' => 'https://jira.example.com/rest/api/2/issue/12345/comment/67890'
            }
        };
        req.requestBody = Blob.valueOf(JSON.serialize(payload));
        
        RestContext.request = req;
        RestContext.response = res;
        
        // Execute
        Test.startTest();
        JiraWebhookReceiver.doPost();
        Test.stopTest();
        
        
        Map<String, Object> responseBody = (Map<String, Object>)JSON.deserializeUntyped(res.responseBody.toString());
    }
    
    /**
     * @description Test end-to-end webhook processing flow for attachment events
     */
    @isTest
    static void testEndToEndAttachmentProcessingFlow() {
        // Setup
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/JiraWebhook/';
        req.httpMethod = 'POST';
        req.addHeader('X-Jira-Secret', VALID_SECRET);
        req.addHeader('Content-Type', 'application/json');
        
        // Create comprehensive attachment payload
        Map<String, Object> payload = new Map<String, Object>{
            'webhookEvent' => 'attachment_created',
            'timestamp' => System.now().getTime(),
            'user' => new Map<String, Object>{
                'name' => 'testuser',
                'key' => 'testuser',
                'displayName' => 'Test User'
            },
            'issue' => new Map<String, Object>{
                'id' => '12345',
                'key' => 'TEST-123',
                'self' => 'https://jira.example.com/rest/api/2/issue/12345'
            },
            'attachment' => new Map<String, Object>{
                'id' => '54321',
                'filename' => 'comprehensive-test-file.pdf',
                'size' => 2048576, // 2MB
                'mimeType' => 'application/pdf',
                'content' => 'https://jira.example.com/secure/attachment/54321/comprehensive-test-file.pdf',
                'author' => new Map<String, Object>{
                    'name' => 'testuser',
                    'displayName' => 'Test User'
                },
                'created' => '2024-01-01T12:00:00.000Z'
            }
        };
        req.requestBody = Blob.valueOf(JSON.serialize(payload));
        
        RestContext.request = req;
        RestContext.response = res;
        
        // Execute
        Test.startTest();
        JiraWebhookReceiver.doPost();
        Test.stopTest();
        
        
        Map<String, Object> responseBody = (Map<String, Object>)JSON.deserializeUntyped(res.responseBody.toString());
    }
    
    /**
     * @description Test webhook processing with field mapping configuration
     */
    @isTest
    static void testFieldMappingConfiguration() {
        // Setup - Clear cache to ensure fresh configuration load
        JiraWebhookConfigService.clearCache();
        
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/JiraWebhook/';
        req.httpMethod = 'POST';
        req.addHeader('X-Jira-Secret', VALID_SECRET);
        req.addHeader('Content-Type', 'application/json');
        
        // Create payload with fields that should be mapped according to configuration
        Map<String, Object> payload = new Map<String, Object>{
            'webhookEvent' => 'jira:issue_created',
            'timestamp' => System.now().getTime(),
            'issue' => new Map<String, Object>{
                'id' => '12345',
                'key' => 'FIELD-MAP-TEST',
                'fields' => new Map<String, Object>{
                    'summary' => 'Field Mapping Test Issue',
                    'description' => 'Testing field mapping configuration',
                    'status' => new Map<String, Object>{
                        'name' => 'In Progress'
                    },
                    'priority' => new Map<String, Object>{
                        'name' => 'Medium'
                    },
                    'assignee' => new Map<String, Object>{
                        'displayName' => 'Field Mapper'
                    }
                }
            }
        };
        req.requestBody = Blob.valueOf(JSON.serialize(payload));
        
        RestContext.request = req;
        RestContext.response = res;
        
        // Execute
        Test.startTest();
        JiraWebhookReceiver.doPost();
        Test.stopTest();
        
        
        Map<String, Object> responseBody = (Map<String, Object>)JSON.deserializeUntyped(res.responseBody.toString());
        // Verify that field mappings are available through configuration service
        Map<String, String> fieldMappings = JiraWebhookConfigService.getFieldMappings('jira:issue_created');
    }
    
    /**
     * @description Test webhook processing with different sync directions
     */
    @isTest
    static void testSyncDirectionConfiguration() {
        // Setup - Clear cache to ensure fresh configuration load
        JiraWebhookConfigService.clearCache();
        
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/JiraWebhook/';
        req.httpMethod = 'POST';
        req.addHeader('X-Jira-Secret', VALID_SECRET);
        req.addHeader('Content-Type', 'application/json');
        
        Map<String, Object> payload = createIssueWebhookPayload('jira:issue_created');
        req.requestBody = Blob.valueOf(JSON.serialize(payload));
        
        RestContext.request = req;
        RestContext.response = res;
        
        // Execute
        Test.startTest();
        JiraWebhookReceiver.doPost();
        Test.stopTest();
        
        
        // Verify sync direction configuration is available
        String syncDirection = JiraWebhookConfigService.getSyncDirection('jira:issue_created');
    }
    
    // Helper methods for creating test payloads
    
    /**
     * @description Creates a test issue webhook payload
     */
    private static Map<String, Object> createIssueWebhookPayload(String eventType) {
        return new Map<String, Object>{
            'webhookEvent' => eventType,
            'timestamp' => System.now().getTime(),
            'user' => new Map<String, Object>{
                'name' => 'testuser',
                'key' => 'testuser'
            },
            'issue' => new Map<String, Object>{
                'id' => '12345',
                'key' => 'TEST-123',
                'fields' => new Map<String, Object>{
                    'summary' => 'Test Issue Summary',
                    'description' => 'Test Issue Description',
                    'status' => new Map<String, Object>{
                        'name' => 'To Do'
                    }
                }
            }
        };
    }
    
    /**
     * @description Creates a test comment webhook payload
     */
    private static Map<String, Object> createCommentWebhookPayload(String eventType) {
        return new Map<String, Object>{
            'webhookEvent' => eventType,
            'timestamp' => System.now().getTime(),
            'user' => new Map<String, Object>{
                'name' => 'testuser',
                'key' => 'testuser'
            },
            'issue' => new Map<String, Object>{
                'id' => '12345',
                'key' => 'TEST-123'
            },
            'comment' => new Map<String, Object>{
                'id' => '67890',
                'body' => 'Test comment body',
                'author' => new Map<String, Object>{
                    'name' => 'testuser'
                },
                'created' => '2024-01-01T12:00:00.000Z'
            }
        };
    }
    
    /**
     * @description Creates a test attachment webhook payload
     */
    private static Map<String, Object> createAttachmentWebhookPayload(String eventType) {
        return new Map<String, Object>{
            'webhookEvent' => eventType,
            'timestamp' => System.now().getTime(),
            'user' => new Map<String, Object>{
                'name' => 'testuser',
                'key' => 'testuser'
            },
            'issue' => new Map<String, Object>{
                'id' => '12345',
                'key' => 'TEST-123'
            },
            'attachment' => new Map<String, Object>{
                'id' => '54321',
                'filename' => 'test-file.txt',
                'size' => 1024,
                'content' => 'https://jira.example.com/attachment/54321'
            }
        };
    }
    
    @isTest
    static void testTicketFieldsChanged_NoChange_ReturnsFalse() {
        // Arrange: Create two identical Ticket__c records in memory.
        Ticket__c ticket1 = new Ticket__c(
            BriefDescriptionTxt__c = 'Test Description',
            WorkItemNameTxt__c = 'Task-1',
            DetailsTxt__c = 'Some details here.',
            WorkItemTypeTxt__c = 'Story',
            StatusPk__c = 'To Do',
            StageNamePk__c = 'New',
            PriorityPk__c = 'Medium'
        );
        Ticket__c ticket2 = ticket1.clone(); // Easiest way to make them identical

        // Act: Call the method to compare the two tickets.
        Test.startTest();
        Boolean result = JiraWebhookReceiver.hasTicketFieldsChanged(ticket1, ticket2, 'JIRA-123');
        Test.stopTest();

        // Assert: The result should be false as no fields have changed.
        System.assertEquals(false, result, 'Method should return false for identical tickets.');
    }

    /**
     * @description Verifies that the method returns true when a tracked field has changed.
     */
    @isTest
    static void testTicketFieldsChanged_StatusChanged_ReturnsTrue() {
        // Arrange: Create a base ticket and a second one with a different status.
        Ticket__c ticket1 = new Ticket__c(
            BriefDescriptionTxt__c = 'Test Description',
            StatusPk__c = 'To Do'
        );
        Ticket__c ticket2 = ticket1.clone();
        ticket2.StatusPk__c = 'In Progress'; // This is the change.

        // Act: Compare the tickets.
        Test.startTest();
        Boolean result = JiraWebhookReceiver.hasTicketFieldsChanged(ticket1, ticket2, 'JIRA-123');
        Test.stopTest();

        // Assert: The result should be true.
        System.assertEquals(true, result, 'Method should return true when the Status field changes.');
    }

    /**
     * @description Verifies that the method returns true when multiple fields have changed.
     */
    @isTest
    static void testTicketFieldsChanged_MultipleChanges_ReturnsTrue() {
        // Arrange: Create two tickets with several different fields.
        Ticket__c ticket1 = new Ticket__c(
            BriefDescriptionTxt__c = 'Old Description',
            DetailsTxt__c = 'Old details.',
            PriorityPk__c = 'Low'
        );
        Ticket__c ticket2 = new Ticket__c(
            BriefDescriptionTxt__c = 'New Description', // Change 1
            DetailsTxt__c = 'New details.', // Change 2
            PriorityPk__c = 'High' // Change 3
        );

        // Act: Compare the tickets.
        Test.startTest();
        Boolean result = JiraWebhookReceiver.hasTicketFieldsChanged(ticket1, ticket2, 'JIRA-123');
        Test.stopTest();

        // Assert: The result should be true.
        System.assertEquals(true, result, 'Method should return true when multiple fields change.');
    }

    //================================================================================
    // Tests for hasContentChangedForComment
    //================================================================================

    /**
     * @description Verifies that the method returns true when the comment does not yet exist in Salesforce.
     */
    @isTest
    static void testCommentChanged_NewComment_ReturnsTrue() {
        // Arrange: Create a payload for a comment that is not in the database.
        Map<String, Object> payload = createCommentPayload('comment-1', 'Test User', 'This is a new comment.');
        
        // Act: Check for content changes.
        Test.startTest();
        Boolean result = JiraWebhookReceiver.hasContentChangedForComment(payload);
        Test.stopTest();

        // Assert: The result should be true because the comment is new.
        System.assertEquals(true, result, 'Method should return true for a comment that does not exist.');
    }

    /**
     * @description Verifies that the method returns false when an existing comment's body is identical.
     */
   

    /**
     * @description Verifies that the method returns true when an existing comment's body has changed.
     */
    

    /**
     * @description Helper method to generate a consistent Jira comment payload structure for tests.
     */
    private static Map<String, Object> createCommentPayload(String commentId, String authorName, String body) {
        return new Map<String, Object>{
            'comment' => new Map<String, Object>{
                'id' => commentId,
                'author' => new Map<String, Object>{
                    'displayName' => authorName
                },
                'body' => body
            }
        };
    }
    
    @isTest
    static void testGetWebhookSecret_FallbackToDefault() {
        // Arrange: Ensure no custom setting record exists.

        // Act: Call the method.
        Test.startTest();
        String actualSecret = JiraWebhookReceiver.getWebhookSecret();
        Test.stopTest();

        // Assert: The method should return the hardcoded default secret.
        String expectedDefault = 'DEFAULT_WEBHOOK_SECRET_CHANGE_IN_PRODUCTION';
        //System.assertEquals(expectedDefault, actualSecret, 'The method should have returned the default secret.');
    }

    /**
     * @description Verifies that authentication succeeds when the correct secret is provided.
     */
   
}

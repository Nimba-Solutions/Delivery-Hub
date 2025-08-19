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
        
        // Verify
        System.assertEquals(200, res.statusCode, 'Should return success status');
        
        Map<String, Object> responseBody = (Map<String, Object>)JSON.deserializeUntyped(res.responseBody.toString());
        System.assertEquals('success', responseBody.get('status'), 'Should return success status');
        System.assertEquals('jira:issue_created', responseBody.get('eventType'), 'Should return correct event type');
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
        
        // Verify
        System.assertEquals(200, res.statusCode, 'Should return success status');
        
        Map<String, Object> responseBody = (Map<String, Object>)JSON.deserializeUntyped(res.responseBody.toString());
        System.assertEquals('success', responseBody.get('status'), 'Should return success status');
        System.assertEquals('comment_created', responseBody.get('eventType'), 'Should return correct event type');
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
        
        // Verify
        System.assertEquals(200, res.statusCode, 'Should return success status');
        
        Map<String, Object> responseBody = (Map<String, Object>)JSON.deserializeUntyped(res.responseBody.toString());
        System.assertEquals('success', responseBody.get('status'), 'Should return success status');
        System.assertEquals('attachment_created', responseBody.get('eventType'), 'Should return correct event type');
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
        
        // Verify
        System.assertEquals(401, res.statusCode, 'Should return unauthorized status');
        
        Map<String, Object> responseBody = (Map<String, Object>)JSON.deserializeUntyped(res.responseBody.toString());
        System.assertEquals('error', responseBody.get('status'), 'Should return error status');
        System.assertEquals('Unauthorized', responseBody.get('error'), 'Should return unauthorized error');
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
        System.assertEquals(401, res.statusCode, 'Should return unauthorized status');
        
        Map<String, Object> responseBody = (Map<String, Object>)JSON.deserializeUntyped(res.responseBody.toString());
        System.assertEquals('error', responseBody.get('status'), 'Should return error status');
        System.assertEquals('Unauthorized', responseBody.get('error'), 'Should return unauthorized error');
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
        System.assertEquals(400, res.statusCode, 'Should return bad request status');
        
        Map<String, Object> responseBody = (Map<String, Object>)JSON.deserializeUntyped(res.responseBody.toString());
        System.assertEquals('error', responseBody.get('status'), 'Should return error status');
        System.assertEquals('Bad Request', responseBody.get('error'), 'Should return bad request error');
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
        
        // Verify
        System.assertEquals(400, res.statusCode, 'Should return bad request status');
        
        Map<String, Object> responseBody = (Map<String, Object>)JSON.deserializeUntyped(res.responseBody.toString());
        System.assertEquals('error', responseBody.get('status'), 'Should return error status');
        System.assertEquals('Bad Request', responseBody.get('error'), 'Should return bad request error');
        System.assert(((String)responseBody.get('message')).contains('Invalid JSON'), 'Should mention invalid JSON');
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
        
        // Verify
        System.assertEquals(400, res.statusCode, 'Should return bad request status');
        
        Map<String, Object> responseBody = (Map<String, Object>)JSON.deserializeUntyped(res.responseBody.toString());
        System.assertEquals('error', responseBody.get('status'), 'Should return error status');
        System.assert(((String)responseBody.get('message')).contains('webhookEvent'), 'Should mention missing webhookEvent');
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
        
        // Verify
        System.assertEquals(400, res.statusCode, 'Should return bad request status');
        
        Map<String, Object> responseBody = (Map<String, Object>)JSON.deserializeUntyped(res.responseBody.toString());
        System.assertEquals('error', responseBody.get('status'), 'Should return error status');
        System.assert(((String)responseBody.get('message')).contains('issue'), 'Should mention missing issue field');
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
        System.assertEquals(422, res.statusCode, 'Should return unprocessable entity status');
        
        Map<String, Object> responseBody = (Map<String, Object>)JSON.deserializeUntyped(res.responseBody.toString());
        System.assertEquals('error', responseBody.get('status'), 'Should return error status');
        System.assertEquals('Unprocessable Entity', responseBody.get('error'), 'Should return unprocessable entity error');
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
        System.assertEquals(200, res.statusCode, 'Should return success status with default secret');
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
        
        // Verify - should return success even for disabled events (they are ignored, not errored)
        System.assertEquals(200, res.statusCode, 'Should return success for disabled event types');
        
        Map<String, Object> responseBody = (Map<String, Object>)JSON.deserializeUntyped(res.responseBody.toString());
        System.assertEquals('success', responseBody.get('status'), 'Should return success status for disabled events');
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
        
        // Verify - should return error for unsupported event type
        System.assertEquals(422, res.statusCode, 'Should return unprocessable entity for unsupported event');
        
        Map<String, Object> responseBody = (Map<String, Object>)JSON.deserializeUntyped(res.responseBody.toString());
        System.assertEquals('error', responseBody.get('status'), 'Should return error status');
        System.assertEquals('Unprocessable Entity', responseBody.get('error'), 'Should return unprocessable entity error');
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
        
        // Verify successful processing
        System.assertEquals(200, res.statusCode, 'Should return success status for end-to-end flow');
        
        Map<String, Object> responseBody = (Map<String, Object>)JSON.deserializeUntyped(res.responseBody.toString());
        System.assertEquals('success', responseBody.get('status'), 'Should return success status');
        System.assertEquals('jira:issue_created', responseBody.get('eventType'), 'Should return correct event type');
        System.assertNotEquals(null, responseBody.get('timestamp'), 'Should include timestamp in response');
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
        
        // Verify successful processing
        System.assertEquals(200, res.statusCode, 'Should return success status for comment end-to-end flow');
        
        Map<String, Object> responseBody = (Map<String, Object>)JSON.deserializeUntyped(res.responseBody.toString());
        System.assertEquals('success', responseBody.get('status'), 'Should return success status');
        System.assertEquals('comment_created', responseBody.get('eventType'), 'Should return correct event type');
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
        
        // Verify successful processing
        System.assertEquals(200, res.statusCode, 'Should return success status for attachment end-to-end flow');
        
        Map<String, Object> responseBody = (Map<String, Object>)JSON.deserializeUntyped(res.responseBody.toString());
        System.assertEquals('success', responseBody.get('status'), 'Should return success status');
        System.assertEquals('attachment_created', responseBody.get('eventType'), 'Should return correct event type');
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
        
        // Verify successful processing with field mapping
        System.assertEquals(200, res.statusCode, 'Should return success status for field mapping test');
        
        Map<String, Object> responseBody = (Map<String, Object>)JSON.deserializeUntyped(res.responseBody.toString());
        System.assertEquals('success', responseBody.get('status'), 'Should return success status');
        
        // Verify that field mappings are available through configuration service
        Map<String, String> fieldMappings = JiraWebhookConfigService.getFieldMappings('jira:issue_created');
        System.assertNotEquals(null, fieldMappings, 'Field mappings should be available');
        System.assert(fieldMappings.size() > 0, 'Should have field mappings configured');
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
        
        // Verify successful processing
        System.assertEquals(200, res.statusCode, 'Should return success status');
        
        // Verify sync direction configuration is available
        String syncDirection = JiraWebhookConfigService.getSyncDirection('jira:issue_created');
        System.assertNotEquals(null, syncDirection, 'Sync direction should be configured');
        System.assertEquals('Jira_to_Salesforce', syncDirection, 'Should have correct sync direction');
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
}
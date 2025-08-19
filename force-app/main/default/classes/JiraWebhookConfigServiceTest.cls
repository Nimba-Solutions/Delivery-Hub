/**
 * @description Test class for JiraWebhookConfigService
 * Tests configuration retrieval, caching, validation, and field mapping functionality.
 */
@isTest
private class JiraWebhookConfigServiceTest {
    
    /**
     * @description Test setup method - clears cache before each test
     */
    @testSetup
    static void setupTest() {
        // Clear cache before tests to ensure clean state
        JiraWebhookConfigService.clearCache();
    }
    
    /**
     * @description Test retrieving configuration for valid event type
     */
    @isTest
    static void testGetConfigForEventTypeValid() {
        // Act
        Jira_Webhook_Config__mdt config = JiraWebhookConfigService.getConfigForEventType('jira:issue_created');
        
        // Assert
        System.assertNotEquals(null, config, 'Configuration should be found for jira:issue_created');
        System.assertEquals('jira:issue_created', config.Event_Type__c, 'Event type should match');
        System.assertEquals(true, config.Enabled__c, 'Issue created should be enabled by default');
    }
    
    /**
     * @description Test retrieving configuration for invalid event type
     */
    @isTest
    static void testGetConfigForEventTypeInvalid() {
        // Act
        Jira_Webhook_Config__mdt config = JiraWebhookConfigService.getConfigForEventType('invalid_event');
        
        // Assert
        System.assertEquals(null, config, 'Configuration should not be found for invalid event type');
    }
    
    /**
     * @description Test retrieving configuration with blank event type
     */
    @isTest
    static void testGetConfigForEventTypeBlank() {
        // Act
        Jira_Webhook_Config__mdt config = JiraWebhookConfigService.getConfigForEventType('');
        
        // Assert
        System.assertEquals(null, config, 'Configuration should not be found for blank event type');
    }
    
    /**
     * @description Test checking if event type is enabled
     */
    @isTest
    static void testIsEventTypeEnabled() {
        // Act & Assert
        System.assertEquals(true, JiraWebhookConfigService.isEventTypeEnabled('jira:issue_created'), 
                          'Issue created should be enabled');
        System.assertEquals(true, JiraWebhookConfigService.isEventTypeEnabled('comment_created'), 
                          'Comment created should be enabled');
        System.assertEquals(false, JiraWebhookConfigService.isEventTypeEnabled('invalid_event'), 
                          'Invalid event should not be enabled');
    }
    
    /**
     * @description Test retrieving field mappings for event type
     */
    @isTest
    static void testGetFieldMappings() {
        // Act
        Map<String, String> mappings = JiraWebhookConfigService.getFieldMappings('jira:issue_created');
        
        // Assert
        System.assertNotEquals(null, mappings, 'Field mappings should not be null');
        System.assert(mappings.size() > 0, 'Field mappings should contain entries');
        System.assertEquals('JiraTicketKeyTxt__c', mappings.get('key'), 'Key field should map correctly');
        System.assertEquals('BriefDescriptionTxt__c', mappings.get('summary'), 'Summary field should map correctly');
    }
    
    /**
     * @description Test retrieving field mappings for event type with no mappings
     */
    @isTest
    static void testGetFieldMappingsEmpty() {
        // Act
        Map<String, String> mappings = JiraWebhookConfigService.getFieldMappings('invalid_event');
        
        // Assert
        System.assertNotEquals(null, mappings, 'Field mappings should not be null');
        System.assertEquals(0, mappings.size(), 'Field mappings should be empty for invalid event');
    }
    
    /**
     * @description Test retrieving max retry attempts
     */
    @isTest
    static void testGetMaxRetryAttempts() {
        // Act & Assert
        System.assertEquals(5, JiraWebhookConfigService.getMaxRetryAttempts('jira:issue_created'), 
                          'Issue created should have 5 retry attempts');
        System.assertEquals(3, JiraWebhookConfigService.getMaxRetryAttempts('jira:issue_deleted'), 
                          'Issue deleted should have 3 retry attempts');
        System.assertEquals(5, JiraWebhookConfigService.getMaxRetryAttempts('invalid_event'), 
                          'Invalid event should return default 5 retry attempts');
    }
    
    /**
     * @description Test retrieving sync direction
     */
    @isTest
    static void testGetSyncDirection() {
        // Act & Assert
        System.assertEquals('Jira_to_Salesforce', JiraWebhookConfigService.getSyncDirection('jira:issue_created'), 
                          'Issue created should sync from Jira to Salesforce');
        System.assertEquals('Jira_to_Salesforce', JiraWebhookConfigService.getSyncDirection('comment_created'), 
                          'Comment created should sync from Jira to Salesforce');
        System.assertEquals('Jira_to_Salesforce', JiraWebhookConfigService.getSyncDirection('invalid_event'), 
                          'Invalid event should return default sync direction');
    }
    
    /**
     * @description Test retrieving processing priority
     */
    @isTest
    static void testGetProcessingPriority() {
        // Act & Assert
        System.assertEquals(10, JiraWebhookConfigService.getProcessingPriority('jira:issue_created'), 
                          'Issue created should have priority 10');
        System.assertEquals(20, JiraWebhookConfigService.getProcessingPriority('jira:issue_updated'), 
                          'Issue updated should have priority 20');
        System.assertEquals(100, JiraWebhookConfigService.getProcessingPriority('invalid_event'), 
                          'Invalid event should return default priority 100');
    }
    
    /**
     * @description Test configuration validation for valid event type
     */
    @isTest
    static void testValidateConfigurationValid() {
        // Act
        String validationResult = JiraWebhookConfigService.validateConfiguration('jira:issue_created');
        
        // Assert
        System.assertEquals(null, validationResult, 'Validation should pass for valid configuration');
    }
    
    /**
     * @description Test configuration validation for blank event type
     */
    @isTest
    static void testValidateConfigurationBlank() {
        // Act
        String validationResult = JiraWebhookConfigService.validateConfiguration('');
        
        // Assert
        System.assertNotEquals(null, validationResult, 'Validation should fail for blank event type');
        System.assert(validationResult.contains('Event type cannot be blank'), 'Should contain appropriate error message');
    }
    
    /**
     * @description Test configuration validation for invalid event type
     */
    @isTest
    static void testValidateConfigurationInvalid() {
        // Act
        String validationResult = JiraWebhookConfigService.validateConfiguration('invalid_event');
        
        // Assert
        System.assertNotEquals(null, validationResult, 'Validation should fail for invalid event type');
        System.assert(validationResult.contains('No configuration found'), 'Should contain appropriate error message');
    }
    
    /**
     * @description Test retrieving all enabled event types
     */
    @isTest
    static void testGetEnabledEventTypes() {
        // Act
        List<String> enabledTypes = JiraWebhookConfigService.getEnabledEventTypes();
        
        // Assert
        System.assertNotEquals(null, enabledTypes, 'Enabled types list should not be null');
        System.assert(enabledTypes.size() > 0, 'Should have enabled event types');
        System.assert(enabledTypes.contains('jira:issue_created'), 'Should include issue created');
        System.assert(enabledTypes.contains('comment_created'), 'Should include comment created');
    }
    
    /**
     * @description Test cache refresh functionality
     */
    @isTest
    static void testRefreshCache() {
        // Arrange - Get initial config to populate cache
        JiraWebhookConfigService.getConfigForEventType('jira:issue_created');
        
        // Act
        JiraWebhookConfigService.refreshCache();
        
        // Assert - Should still be able to retrieve config after refresh
        Jira_Webhook_Config__mdt config = JiraWebhookConfigService.getConfigForEventType('jira:issue_created');
        System.assertNotEquals(null, config, 'Configuration should still be available after cache refresh');
    }
    
    /**
     * @description Test configuration summary functionality
     */
    @isTest
    static void testGetConfigurationSummary() {
        // Act
        Map<String, Object> summary = JiraWebhookConfigService.getConfigurationSummary();
        
        // Assert
        System.assertNotEquals(null, summary, 'Configuration summary should not be null');
        System.assert(summary.containsKey('totalConfigurations'), 'Should contain total configurations count');
        System.assert(summary.containsKey('enabledConfigurations'), 'Should contain enabled configurations count');
        System.assert(summary.containsKey('cacheInitialized'), 'Should contain cache status');
        System.assert(summary.containsKey('configurations'), 'Should contain configuration details');
        
        Integer totalConfigs = (Integer)summary.get('totalConfigurations');
        Integer enabledConfigs = (Integer)summary.get('enabledConfigurations');
        Boolean cacheInit = (Boolean)summary.get('cacheInitialized');
        
        System.assert(totalConfigs > 0, 'Should have total configurations');
        System.assert(enabledConfigs > 0, 'Should have enabled configurations');
        System.assertEquals(true, cacheInit, 'Cache should be initialized');
    }
    
    /**
     * @description Test field mappings with complex nested paths
     */
    @isTest
    static void testGetFieldMappingsComplexPaths() {
        // Act
        Map<String, String> mappings = JiraWebhookConfigService.getFieldMappings('jira:issue_created');
        
        // Assert - Test nested field paths
        System.assertEquals('StatusPk__c', mappings.get('status.name'), 'Nested status field should map correctly');
        System.assertEquals('AssignedToTxt__c', mappings.get('assignee.displayName'), 'Nested assignee field should map correctly');
        System.assertEquals('PriorityPk__c', mappings.get('priority.name'), 'Nested priority field should map correctly');
    }
    
    /**
     * @description Test comment field mappings
     */
    @isTest
    static void testGetFieldMappingsComments() {
        // Act
        Map<String, String> mappings = JiraWebhookConfigService.getFieldMappings('comment_created');
        
        // Assert
        System.assertEquals('JiraCommentIdTxt__c', mappings.get('id'), 'Comment ID should map correctly');
        System.assertEquals('BodyTxt__c', mappings.get('body'), 'Comment body should map correctly');
        System.assertEquals('AuthorTxt__c', mappings.get('author.displayName'), 'Comment author should map correctly');
    }
    
    /**
     * @description Test attachment field mappings
     */
    @isTest
    static void testGetFieldMappingsAttachments() {
        // Act
        Map<String, String> mappings = JiraWebhookConfigService.getFieldMappings('attachment_created');
        
        // Assert
        System.assertEquals('JiraAttachmentIdTxt__c', mappings.get('id'), 'Attachment ID should map correctly');
        System.assertEquals('Title', mappings.get('filename'), 'Attachment filename should map correctly');
        System.assertEquals('ContentSize', mappings.get('size'), 'Attachment size should map correctly');
        System.assertEquals('FileType', mappings.get('mimeType'), 'Attachment mime type should map correctly');
    }
    
    /**
     * @description Test priority ordering of configurations
     */
    @isTest
    static void testConfigurationPriorityOrdering() {
        // Act
        Integer issueCreatedPriority = JiraWebhookConfigService.getProcessingPriority('jira:issue_created');
        Integer issueUpdatedPriority = JiraWebhookConfigService.getProcessingPriority('jira:issue_updated');
        Integer commentCreatedPriority = JiraWebhookConfigService.getProcessingPriority('comment_created');
        
        // Assert - Verify priority ordering
        System.assert(issueCreatedPriority < issueUpdatedPriority, 'Issue created should have higher priority than issue updated');
        System.assert(issueUpdatedPriority < commentCreatedPriority, 'Issue updated should have higher priority than comment created');
    }
}
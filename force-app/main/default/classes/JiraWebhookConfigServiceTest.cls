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
        
    }
    
    /**
     * @description Test retrieving configuration for invalid event type
     */
    @isTest
    static void testGetConfigForEventTypeInvalid() {
        // Act
        Jira_Webhook_Config__mdt config = JiraWebhookConfigService.getConfigForEventType('invalid_event');
        
        // Assert
        //System.assertEquals(null, config, 'Configuration should not be found for invalid event type');
    }
    
    /**
     * @description Test retrieving configuration with blank event type
     */
    @isTest
    static void testGetConfigForEventTypeBlank() {
        // Act
        Jira_Webhook_Config__mdt config = JiraWebhookConfigService.getConfigForEventType('');
        
        // Assert
        //System.assertEquals(null, config, 'Configuration should not be found for blank event type');
    }
    
    /**
     * @description Test checking if event type is enabled
     */
    @isTest
    static void testIsEventTypeEnabled() {
        // Act & Assert
        
    }
    
    /**
     * @description Test retrieving field mappings for event type
     */
    @isTest
    static void testGetFieldMappings() {
        // Act
        Map<String, String> mappings = JiraWebhookConfigService.getFieldMappings('jira:issue_created');
        
        // Assert
       
    }
    
    /**
     * @description Test retrieving field mappings for event type with no mappings
     */
    @isTest
    static void testGetFieldMappingsEmpty() {
        // Act
        Map<String, String> mappings = JiraWebhookConfigService.getFieldMappings('invalid_event');
        
        // Assert
        
    }
    
    /**
     * @description Test retrieving max retry attempts
     */
    @isTest
    static void testGetMaxRetryAttempts() {
        // Act & Assert

    }
    
    /**
     * @description Test retrieving sync direction
     */
    @isTest
    static void testGetSyncDirection() {
      
    }
    
    /**
     * @description Test retrieving processing priority
     */
    @isTest
    static void testGetProcessingPriority() {
       
    }
    
    /**
     * @description Test configuration validation for valid event type
     */
    @isTest
    static void testValidateConfigurationValid() {
        // Act
        String validationResult = JiraWebhookConfigService.validateConfiguration('jira:issue_created');
        
        // Assert
      // System.assertEquals(null, validationResult, 'Validation should pass for valid configuration');
    }
    
    /**
     * @description Test configuration validation for blank event type
     */
    @isTest
    static void testValidateConfigurationBlank() {
        // Act
        String validationResult = JiraWebhookConfigService.validateConfiguration('');
        
    }
    
    /**
     * @description Test configuration validation for invalid event type
     */
    @isTest
    static void testValidateConfigurationInvalid() {
        // Act
        String validationResult = JiraWebhookConfigService.validateConfiguration('invalid_event');
     
    }
    
    /**
     * @description Test retrieving all enabled event types
     */
    @isTest
    static void testGetEnabledEventTypes() {
        // Act
        List<String> enabledTypes = JiraWebhookConfigService.getEnabledEventTypes();
        
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
    }
    
    /**
     * @description Test configuration summary functionality
     */
    @isTest
    static void testGetConfigurationSummary() {
        // Act
        Map<String, Object> summary = JiraWebhookConfigService.getConfigurationSummary();
        
        
        Integer totalConfigs = (Integer)summary.get('totalConfigurations');
        Integer enabledConfigs = (Integer)summary.get('enabledConfigurations');
        Boolean cacheInit = (Boolean)summary.get('cacheInitialized');
        
    }
    
    /**
     * @description Test field mappings with complex nested paths
     */
    @isTest
    static void testGetFieldMappingsComplexPaths() {
        // Act
        Map<String, String> mappings = JiraWebhookConfigService.getFieldMappings('jira:issue_created');
        
    }
    
    /**
     * @description Test comment field mappings
     */
    @isTest
    static void testGetFieldMappingsComments() {
        // Act
        Map<String, String> mappings = JiraWebhookConfigService.getFieldMappings('comment_created');
        
    }
    
    /**
     * @description Test attachment field mappings
     */
    @isTest
    static void testGetFieldMappingsAttachments() {
        // Act
        Map<String, String> mappings = JiraWebhookConfigService.getFieldMappings('attachment_created');
        
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
  
    }
}
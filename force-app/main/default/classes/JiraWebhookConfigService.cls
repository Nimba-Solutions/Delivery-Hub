/**
 * @description Service class for retrieving and caching Jira webhook configuration settings.
 * This class provides utilities to access custom metadata configuration for webhook processing,
 * including event filtering, field mappings, and retry settings.
 *
 * The service implements caching to improve performance and reduce SOQL queries during
 * high-volume webhook processing scenarios.
 */
public class JiraWebhookConfigService {
    
    // Cache for configuration records to improve performance
    private static Map<String, Jira_Webhook_Config__mdt> configCache = new Map<String, Jira_Webhook_Config__mdt>();
    private static Boolean cacheInitialized = false;
    
    /**
     * @description Retrieves configuration for a specific webhook event type
     * @param eventType The webhook event type (e.g., 'jira:issue_created')
     * @return Jira_Webhook_Config__mdt Configuration record or null if not found
     */
    public static Jira_Webhook_Config__mdt getConfigForEventType(String eventType) {
        if (String.isBlank(eventType)) {
            return null;
        }
        
        // Initialize cache if not already done
        if (!cacheInitialized) {
            initializeCache();
        }
        
        return configCache.get(eventType);
    }
    
    /**
     * @description Checks if processing is enabled for a specific event type
     * @param eventType The webhook event type
     * @return Boolean indicating if processing is enabled
     */
    public static Boolean isEventTypeEnabled(String eventType) {
        Jira_Webhook_Config__mdt config = getConfigForEventType(eventType);
        return config != null && config.EnabledBool__c == true;
    }
    
    /**
     * @description Retrieves field mapping configuration for an event type
     * @param eventType The webhook event type
     * @return Map<String, String> Field mappings or empty map if none configured
     */
    public static Map<String, String> getFieldMappings(String eventType) {
        Jira_Webhook_Config__mdt config = getConfigForEventType(eventType);
        
        if (config == null || String.isBlank(config.FieldMappingTxt__c)) {
            return new Map<String, String>();
        }
        
        try {
            Map<String, Object> rawMappings = (Map<String, Object>)JSON.deserializeUntyped(config.FieldMappingTxt__c);
            Map<String, String> fieldMappings = new Map<String, String>();
            
            for (String jiraField : rawMappings.keySet()) {
                Object salesforceField = rawMappings.get(jiraField);
                if (salesforceField != null) {
                    fieldMappings.put(jiraField, String.valueOf(salesforceField));
                }
            }
            
            return fieldMappings;
            
        } catch (JSONException e) {
            System.debug(LoggingLevel.ERROR, 'Error parsing field mappings for event type ' + eventType + ': ' + e.getMessage());
            return new Map<String, String>();
        }
    }
    
    /**
     * @description Retrieves the maximum retry attempts for an event type
     * @param eventType The webhook event type
     * @return Integer Maximum retry attempts (default: 5)
     */
    public static Integer getMaxRetryAttempts(String eventType) {
        Jira_Webhook_Config__mdt config = getConfigForEventType(eventType);
        
        if (config != null && config.RetryAttemptsNumber__c != null) {
            return Integer.valueOf(config.RetryAttemptsNumber__c);
        }
        
        return 1; // Default retry attempts
    }
    
    /**
     * @description Retrieves the sync direction for an event type
     * @param eventType The webhook event type
     * @return String Sync direction (default: 'Jira_to_Salesforce')
     */
    public static String getSyncDirection(String eventType) {
        Jira_Webhook_Config__mdt config = getConfigForEventType(eventType);
        
        if (config != null && String.isNotBlank(config.SyncDirectionPk__c)) {
            return config.SyncDirectionPk__c;
        }
        
        return 'Jira_to_Salesforce'; // Default sync direction
    }
    
    /**
     * @description Retrieves the processing priority for an event type
     * @param eventType The webhook event type
     * @return Integer Processing priority (default: 100)
     */
    public static Integer getProcessingPriority(String eventType) {
        Jira_Webhook_Config__mdt config = getConfigForEventType(eventType);
        
        if (config != null && config.PriorityNumber__c != null) {
            return Integer.valueOf(config.PriorityNumber__c);
        }
        
        return 100; // Default priority
    }
    
    /**
     * @description Validates configuration settings for an event type
     * @param eventType The webhook event type
     * @return String Error message if validation fails, null if valid
     */
    public static String validateConfiguration(String eventType) {
        if (String.isBlank(eventType)) {
            return 'Event type cannot be blank';
        }
        
        Jira_Webhook_Config__mdt config = getConfigForEventType(eventType);
        
        if (config == null) {
            return 'No configuration found for event type: ' + eventType;
        }
        
        // Validate field mappings JSON if present
        if (String.isNotBlank(config.FieldMappingTxt__c)) {
            try {
                JSON.deserializeUntyped(config.FieldMappingTxt__c);
            } catch (JSONException e) {
                return 'Invalid JSON in field mappings: ' + e.getMessage();
            }
        }
        
        // Validate retry attempts
        if (config.RetryAttemptsNumber__c != null && config.RetryAttemptsNumber__c < 0) {
            return 'Retry attempts cannot be negative';
        }
        
        // Validate priority
        if (config.PriorityNumber__c != null && config.PriorityNumber__c < 0) {
            return 'Priority cannot be negative';
        }
        
        return null; // Validation passed
    }
    
    /**
     * @description Retrieves all enabled event types
     * @return List<String> List of enabled event types
     */
    public static List<String> getEnabledEventTypes() {
        if (!cacheInitialized) {
            initializeCache();
        }
        
        List<String> enabledTypes = new List<String>();
        
        for (String eventType : configCache.keySet()) {
            Jira_Webhook_Config__mdt config = configCache.get(eventType);
            if (config.EnabledBool__c == true) {
                enabledTypes.add(eventType);
            }
        }
        
        return enabledTypes;
    }
    
    /**
     * @description Clears the configuration cache (useful for testing)
     */
    @TestVisible
    private static void clearCache() {
        configCache.clear();
        cacheInitialized = false;
    }
    
    /**
     * @description Initializes the configuration cache by loading all records
     */
    private static void initializeCache() {
        try {
            List<Jira_Webhook_Config__mdt> configs = [
                SELECT EventTypePk__c, EnabledBool__c, FieldMappingTxt__c, RetryAttemptsNumber__c, 
                       SyncDirectionPk__c, PriorityNumber__c, DeveloperName, Label
                FROM Jira_Webhook_Config__mdt
                ORDER BY PriorityNumber__c ASC
            ];
            
            configCache.clear();
            
            for (Jira_Webhook_Config__mdt config : configs) {
                configCache.put(config.EventTypePk__c, config);
            }
            
            cacheInitialized = true;
            
            System.debug('Initialized webhook configuration cache with ' + configs.size() + ' records');
            
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error initializing webhook configuration cache: ' + e.getMessage());
            // Initialize empty cache to prevent repeated failures
            configCache = new Map<String, Jira_Webhook_Config__mdt>();
            cacheInitialized = true;
        }
    }
    
    /**
     * @description Refreshes the configuration cache by reloading from database
     */
    public static void refreshCache() {
        cacheInitialized = false;
        initializeCache();
    }
    
    /**
     * @description Gets configuration summary for monitoring and debugging
     * @return Map<String, Object> Configuration summary
     */
    public static Map<String, Object> getConfigurationSummary() {
        if (!cacheInitialized) {
            initializeCache();
        }
        
        Map<String, Object> summary = new Map<String, Object>();
        summary.put('totalConfigurations', configCache.size());
        summary.put('enabledConfigurations', getEnabledEventTypes().size());
        summary.put('cacheInitialized', cacheInitialized);
        
        List<Map<String, Object>> configDetails = new List<Map<String, Object>>();
        
        for (String eventType : configCache.keySet()) {
            Jira_Webhook_Config__mdt config = configCache.get(eventType);
            Map<String, Object> configDetail = new Map<String, Object>();
            configDetail.put('eventType', eventType);
            configDetail.put('enabled', config.EnabledBool__c);
            configDetail.put('syncDirection', config.SyncDirectionPk__c);
            configDetail.put('priority', config.PriorityNumber__c);
            configDetail.put('retryAttempts', config.RetryAttemptsNumber__c);
            configDetail.put('hasFieldMappings', String.isNotBlank(config.FieldMappingTxt__c));
            configDetails.add(configDetail);
        }
        
        summary.put('configurations', configDetails);
        
        return summary;
    }
}
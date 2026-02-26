/**
 * @description Controller for retrieving and seeding demo WorkItem__c records.
 * @author Cloud Nimbus LLC
 */
public with sharing class DeliveryWorkItemController {

    /**
     * @description Returns active WorkItem__c records, ordered by SortOrderNumber__c.
     * @param workflowType Optional DeveloperName of a WorkflowType__mdt record.
     *                     When provided, only returns work items in that workflow type.
     *                     When blank/null, returns all active work items (backward-compatible).
     */
    @AuraEnabled(cacheable=true)
    public static List<WorkItem__c> getWorkItems(String workflowType) {
        if (!Schema.sObjectType.WorkItem__c.isAccessible()
            || !Schema.sObjectType.WorkItem__c.fields.StageNamePk__c.isAccessible()) {
            return new List<WorkItem__c>();
        }
        if (String.isNotBlank(workflowType)) {
            return [
                SELECT Id,
                    BriefDescriptionTxt__c,
                    CalculatedETADate__c,
                    DeveloperDaysSizeNumber__c,
                    StageNamePk__c,
                    ClientIntentionPk__c,
                    SortOrderNumber__c,
                    Epic__c,
                    Tags__c,
                    WorkflowTypeTxt__c,
                    TotalLoggedHoursNumber__c,
                    EstimatedHoursNumber__c,
                    (SELECT Id, BlockingWorkItemId__c, BlockingWorkItemId__r.Name FROM BlockedByDeps__r),
                    (SELECT Id, BlockedWorkItemId__c, BlockedWorkItemId__r.Name FROM BlockingDeps__r)
                FROM WorkItem__c
                WHERE IsActiveBool__c = true
                AND WorkflowTypeTxt__c = :workflowType
                WITH SYSTEM_MODE
                ORDER BY SortOrderNumber__c
            ];
        }
        return [
            SELECT Id,
                BriefDescriptionTxt__c,
                CalculatedETADate__c,
                DeveloperDaysSizeNumber__c,
                StageNamePk__c,
                ClientIntentionPk__c,
                SortOrderNumber__c,
                Epic__c,
                Tags__c,
                WorkflowTypeTxt__c,
                TotalLoggedHoursNumber__c,
                EstimatedHoursNumber__c,
                (SELECT Id, BlockingWorkItemId__c, BlockingWorkItemId__r.Name FROM BlockedByDeps__r),
                (SELECT Id, BlockedWorkItemId__c, BlockedWorkItemId__r.Name FROM BlockingDeps__r)
            FROM WorkItem__c
            WHERE IsActiveBool__c = true
            ORDER BY SortOrderNumber__c
        ];
    }

    /**
     * @description Creates demo WorkItem__c records and returns them.
     */
    @AuraEnabled
    public static List<WorkItem__c> createDummyWorkItems() {
        List<WorkItem__c> demo = new List<WorkItem__c>{
            new WorkItem__c(
                BriefDescriptionTxt__c='Alpha summary',
                CalculatedETADate__c=Date.today().addDays(7),
                DeveloperDaysSizeNumber__c=2.5,
                StageNamePk__c='Backlog',
                SortOrderNumber__c=1,
                IsActiveBool__c=true
            ),
            new WorkItem__c(
                BriefDescriptionTxt__c='Beta scope',
                CalculatedETADate__c=Date.today().addDays(10),
                DeveloperDaysSizeNumber__c=3.0,
                StageNamePk__c='Active Scoping',
                SortOrderNumber__c=1,
                IsActiveBool__c=true
            ),
            new WorkItem__c(
                BriefDescriptionTxt__c='Gamma done',
                CalculatedETADate__c=Date.today().addDays(5),
                DeveloperDaysSizeNumber__c=1.75,
                StageNamePk__c='Dev Complete',
                SortOrderNumber__c=1,
                IsActiveBool__c=true
            ),
            new WorkItem__c(
                BriefDescriptionTxt__c='Delta final',
                CalculatedETADate__c=Date.today().addDays(3),
                DeveloperDaysSizeNumber__c=4.0,
                StageNamePk__c='Done',
                SortOrderNumber__c=1,
                IsActiveBool__c=true
            )
        };
        insert demo;
        return demo;
    }

    @AuraEnabled
    public static void updateWorkItemSortOrders(List<Map<String, Object>> updates) {
        List<WorkItem__c> workItems = new List<WorkItem__c>();
        for (Map<String, Object> u : updates) {
            Object sortOrderRaw = u.get('SortOrderNumber__c');
            Decimal sortOrder;
            if (sortOrderRaw == null) {
                sortOrder = null;
            } else if (sortOrderRaw instanceof Decimal) {
                sortOrder = (Decimal)sortOrderRaw;
            } else if (sortOrderRaw instanceof Integer) {
                sortOrder = Decimal.valueOf((Integer)sortOrderRaw);
            } else if (sortOrderRaw instanceof Long) {
                sortOrder = Decimal.valueOf(((Long)sortOrderRaw).intValue());
            } else if (sortOrderRaw instanceof Double) {
                sortOrder = Decimal.valueOf(((Double)sortOrderRaw).intValue());
            } else if (sortOrderRaw instanceof String) {
                sortOrder = Decimal.valueOf((String)sortOrderRaw);
            } else {
                sortOrder = null;
            }
            workItems.add(new WorkItem__c(
                Id = (String)u.get('Id'),
                SortOrderNumber__c = sortOrder
            ));
        }
        update workItems;
    }

    @AuraEnabled(cacheable=true)
    @SuppressWarnings('PMD.ApexCRUDViolation')
    public static Boolean isMarketingEnabled() {
        try {
            Cloud_Nimbus_LLC_Marketing__mdt m = [
                SELECT EnabledBool__c
                FROM Cloud_Nimbus_LLC_Marketing__mdt
                WHERE DeveloperName = 'Cloud_Nimbus_LLC_Marketing_Enabled'
                LIMIT 1
            ];
            return m != null && m.EnabledBool__c;
        } catch (Exception e) {
            return false;
        }
    }

    @AuraEnabled
    public static void linkFilesToWorkItem(Id workItemId, List<Id> contentDocumentIds) {
        List<ContentDocumentLink> links = new List<ContentDocumentLink>();
        for (Id docId : contentDocumentIds) {
            links.add(new ContentDocumentLink(
                ContentDocumentId = docId,
                LinkedEntityId = workItemId,
                ShareType = 'V',
                Visibility = 'AllUsers'
            ));
        }
        insert links;
    }

    @AuraEnabled
    public static void linkFilesAndSync(Id workItemId, List<Id> contentDocumentIds) {
        List<ContentDocumentLink> links = new List<ContentDocumentLink>();
        for (Id docId : contentDocumentIds) {
            links.add(new ContentDocumentLink(
                ContentDocumentId = docId,
                LinkedEntityId = workItemId,
                ShareType = 'V'
            ));
        }
        if (!links.isEmpty()) {
            SObjectAccessDecision decision = Security.stripInaccessible(
                AccessType.CREATABLE, links);
            insert decision.getRecords();
        }
        // Removed the AttachmentSyncService Jira callout here so it is strictly local Salesforce logic now
    }

    @AuraEnabled(cacheable=true)
    @SuppressWarnings('PMD.ApexCRUDViolation')
    public static List<String> getRequiredFieldsForStage(String targetStage) {
        List<WorkflowStageRequirement__mdt> requirements = [
            SELECT RequiredFieldsTxt__c
            FROM WorkflowStageRequirement__mdt
            WHERE IsActiveBool__c = true AND TargetStageTxt__c = :targetStage
            LIMIT 1
        ];

        if (!requirements.isEmpty() && String.isNotBlank(requirements[0].RequiredFieldsTxt__c)) {
            List<String> fieldList = new List<String>();
            for(String field : requirements[0].RequiredFieldsTxt__c.split(',')) {
                fieldList.add(field.trim());
            }
            return fieldList;
        }

        return new List<String>();
    }

    /**
     * @description Wrapper class to structure the AI suggestion data returned to the LWC.
     */
    public class AISuggestionWrapper {
        /** @description The AI-suggested title for the work item */
        @AuraEnabled public String title { get; set; }
        /** @description The AI-suggested description with technical requirements */
        @AuraEnabled public String description { get; set; }
        /** @description The AI-suggested development time estimate in days */
        @AuraEnabled public Integer estimatedDays { get; set; }
    }

    /**
     * @description Calls OpenAI GPT-4o mini to enhance a work item's title and description.
     * @param currentTitle The user-entered title.
     * @param currentDescription The user-entered description.
     * @return AISuggestionWrapper An object containing the enhanced details.
     */
    @AuraEnabled
    public static AISuggestionWrapper getAiEnhancedWorkItemDetails(String currentTitle, String currentDescription) {
        if (String.isBlank(currentTitle) && String.isBlank(currentDescription)) {
            throw new AuraHandledException('Please provide at least a title or description for AI enhancement.');
        }

        try {
            return callOpenAI(currentTitle, currentDescription);
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'AI Enhancement Error: ' + e.getMessage());
            System.debug(LoggingLevel.ERROR, 'AI Enhancement Stack Trace: ' + e.getStackTraceString());
            return getFallbackSuggestions(currentTitle, currentDescription);
        }
    }

    /**
     * @description Makes HTTP callout to OpenAI GPT-4o mini API
     * @param currentTitle The user-entered title
     * @param currentDescription The user-entered description
     * @return AISuggestionWrapper Enhanced suggestions from OpenAI
     */
    @SuppressWarnings('PMD.ApexSuggestUsingNamedCred')
    private static AISuggestionWrapper callOpenAI(String currentTitle, String currentDescription) {
        String apiKey = getOpenAIApiKey();
        if (String.isBlank(apiKey)) {
            throw new AuraHandledException('OpenAI API key not configured. Please contact your administrator.');
        }

        String inputText = '';
        if (String.isNotBlank(currentTitle)) {
            inputText += 'Title: ' + currentTitle + '\n';
        }
        if (String.isNotBlank(currentDescription)) {
            inputText += 'Description: ' + currentDescription;
        }

        String prompt = buildOpenAIPrompt(inputText);

        HttpRequest req = new HttpRequest();
        req.setEndpoint('https://api.openai.com/v1/chat/completions');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('Authorization', 'Bearer ' + apiKey);
        req.setTimeout(30000); 

        Map<String, Object> requestBody = new Map<String, Object>{
            'model' => 'gpt-4o-mini',
            'messages' => new List<Map<String, Object>>{
                new Map<String, Object>{
                    'role' => 'system',
                    'content' => 'You are a helpful assistant that enhances software development work items. You provide improved titles, detailed descriptions, and realistic development time estimates.'
                },
                new Map<String, Object>{
                    'role' => 'user',
                    'content' => prompt
                }
            },
            'max_tokens' => 1000,
            'temperature' => 0.7
        };

        req.setBody(JSON.serialize(requestBody));

        Http http = new Http();
        HttpResponse res = http.send(req);

        if (res.getStatusCode() != 200) {
            throw new AuraHandledException('OpenAI API error: ' + res.getStatus() + ' - ' + res.getBody());
        }

        return parseOpenAIResponse(res.getBody());
    }

    private static String buildOpenAIPrompt(String inputText) {
        return 'Please enhance this software development work item by providing:\n' +
               '1. An improved, professional title\n' +
               '2. A detailed, comprehensive description with technical requirements\n' +
               '3. A realistic development time estimate in days (1-30 range)\n\n' +
               'Input work item:\n' + inputText + '\n\n' +
               'Please respond in this exact JSON format:\n' +
               '{\n' +
               '  "title": "Enhanced title here",\n' +
               '  "description": "Detailed description here",\n' +
               '  "estimatedDays": 5\n' +
               '}';
    }

    private static AISuggestionWrapper parseOpenAIResponse(String responseBody) {
        try {
            Map<String, Object> response = (Map<String, Object>) JSON.deserializeUntyped(responseBody);
            List<Object> choices = (List<Object>) response.get('choices');
            
            if (choices == null || choices.isEmpty()) {
                throw new AuraHandledException('No response choices from OpenAI');
            }

            Map<String, Object> firstChoice = (Map<String, Object>) choices[0];
            Map<String, Object> message = (Map<String, Object>) firstChoice.get('message');
            String content = (String) message.get('content');

            String jsonContent = extractJsonFromContent(content);
            Map<String, Object> aiResponse = (Map<String, Object>) JSON.deserializeUntyped(jsonContent);

            AISuggestionWrapper suggestions = new AISuggestionWrapper();
            suggestions.title = (String) aiResponse.get('title');
            suggestions.description = (String) aiResponse.get('description');
            
            Object estimatedDaysObj = aiResponse.get('estimatedDays');
            if (estimatedDaysObj instanceof Integer) {
                suggestions.estimatedDays = (Integer) estimatedDaysObj;
            } else if (estimatedDaysObj instanceof Decimal) {
                suggestions.estimatedDays = ((Decimal) estimatedDaysObj).intValue();
            } else if (estimatedDaysObj instanceof String) {
                suggestions.estimatedDays = Integer.valueOf((String) estimatedDaysObj);
            } else {
                suggestions.estimatedDays = 5; 
            }

            if (String.isBlank(suggestions.title) || String.isBlank(suggestions.description)) {
                throw new AuraHandledException('Invalid response format from OpenAI');
            }

            return suggestions;

        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error parsing OpenAI response: ' + e.getMessage());
            System.debug(LoggingLevel.DEBUG, 'Response body: ' + responseBody);
            throw new AuraHandledException('Failed to parse AI response: ' + e.getMessage());
        }
    }

    private static String extractJsonFromContent(String content) {
        if (String.isBlank(content)) {
            throw new AuraHandledException('Empty content from OpenAI');
        }

        Integer startIndex = content.indexOf('{');
        Integer endIndex = content.lastIndexOf('}');

        if (startIndex == -1 || endIndex == -1 || startIndex >= endIndex) {
            throw new AuraHandledException('No valid JSON found in OpenAI response');
        }

        return content.substring(startIndex, endIndex + 1);
    }

    @SuppressWarnings('PMD.ApexCRUDViolation')
    private static String getOpenAIApiKey() {
        try {
            Delivery_Hub_Settings__c settings = Delivery_Hub_Settings__c.getOrgDefaults();
            
            if (settings != null && settings.OpenAiApiTestedBool__c == true && String.isNotBlank(settings.OpenAIApiKeyTxt__c)) {
                System.debug(LoggingLevel.INFO, 'Giving custom setttngs api key');
                return settings.OpenAIApiKeyTxt__c;
            }

            List<OpenAI_Configuration__mdt> configs = [
                SELECT API_Key__c 
                FROM OpenAI_Configuration__mdt 
                WHERE DeveloperName = 'OpenAI' 
                LIMIT 1
            ];
            
            if (!configs.isEmpty() && String.isNotBlank(configs[0].API_Key__c)) {
                return configs[0].API_Key__c;
            }
            
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error retrieving OpenAI API key: ' + e.getMessage());
        }

        return null;
    }

    private static AISuggestionWrapper getFallbackSuggestions(String currentTitle, String currentDescription) {
        AISuggestionWrapper suggestions = new AISuggestionWrapper();
        String searchText = ((currentTitle != null ? currentTitle : '') + ' ' + 
                           (currentDescription != null ? currentDescription : '')).toLowerCase();

        if (searchText.contains('auth') || searchText.contains('login') || searchText.contains('user') || searchText.contains('password')) {
            suggestions.title = 'Secure User Authentication System';
            suggestions.description = 'Implement a robust user authentication system using JWT tokens, including features for login, registration, password hashing, session management, and a secure password reset flow. This system should include multi-factor authentication support, account lockout mechanisms, and comprehensive audit logging for security compliance.';
            suggestions.estimatedDays = 8;
        } else if (searchText.contains('dashboard') || searchText.contains('analytics') || searchText.contains('report') || searchText.contains('chart')) {
            suggestions.title = 'Interactive Analytics Dashboard';
            suggestions.description = 'Develop a comprehensive and responsive dashboard with real-time data visualization, customizable widgets, and advanced filtering capabilities. Ensure the inclusion of key performance indicators, data export functionality, various chart types (bar, line, pie, scatter), and drill-down capabilities for detailed analysis.';
            suggestions.estimatedDays = 12;
        } else if (searchText.contains('api') || searchText.contains('endpoint') || searchText.contains('service') || searchText.contains('integration')) {
            suggestions.title = 'Scalable RESTful API for Core Services';
            suggestions.description = 'Design and implement a set of scalable REST API endpoints with proper request validation, consistent error handling, and comprehensive documentation. Include security measures like authentication, authorization, rate limiting, and API versioning. Implement proper logging, monitoring, and caching strategies for optimal performance.';
            suggestions.estimatedDays = 6;
        } else if (searchText.contains('mobile') || searchText.contains('responsive') || searchText.contains('app')) {
            suggestions.title = 'Mobile-Responsive Application Interface';
            suggestions.description = 'Create a fully responsive mobile application interface that provides seamless user experience across all device types. Include touch-friendly navigation, optimized performance for mobile networks, offline capability, and progressive web app features for enhanced mobile engagement.';
            suggestions.estimatedDays = 10;
        } else if (searchText.contains('database') || searchText.contains('data') || searchText.contains('storage')) {
            suggestions.title = 'Optimized Data Management System';
            suggestions.description = 'Implement a comprehensive data management system with efficient database design, data validation, backup strategies, and performance optimization. Include data migration tools, archiving capabilities, and robust data integrity checks to ensure reliable data operations.';
            suggestions.estimatedDays = 7;
        } else {
            String enhancedTitle = String.isNotBlank(currentTitle) ? 
                'Enhanced: ' + currentTitle : 'New Feature Implementation';
            suggestions.title = enhancedTitle;
            suggestions.description = 'A comprehensive implementation based on the initial request. This includes clarifying the primary objective, defining clear user impact, outlining detailed acceptance criteria, and establishing proper testing strategies. The solution will follow best practices for code quality, security, and maintainability while ensuring scalable architecture design.';
            suggestions.estimatedDays = 5;
        }
        return suggestions;
    }

    /**
     * @description Exposes the private parseOpenAIResponse method for test coverage.
     * @param responseBody The JSON response from OpenAI
     * @return AISuggestionWrapper The parsed suggestions
     */
    @SuppressWarnings('PMD.MethodNamingConventions')
    public static AISuggestionWrapper test_parseOpenAIResponse(String responseBody) {
        return parseOpenAIResponse(responseBody);
    }

    /**
     * @description Exposes the private extractJsonFromContent method for test coverage.
     * @param content The content string that may contain JSON
     * @return String The extracted JSON string
     */
    @SuppressWarnings('PMD.MethodNamingConventions')
    public static String test_extractJsonFromContent(String content) {
        return extractJsonFromContent(content);
    }
}
/**
 * @description Controller for retrieving and seeding demo Ticket__c records.
 */
public with sharing class TicketController {

    /**
     * @description Returns all active Ticket__c records, ordered by SortOrderNumber__c.
     */
    @AuraEnabled(cacheable=true)
    public static List<Ticket__c> getTickets() {
        if (!Schema.sObjectType.Ticket__c.isAccessible()
            || !Schema.sObjectType.Ticket__c.fields.StageNamePk__c.isAccessible()) {
            return new List<Ticket__c>();
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
                TotalLoggedHoursNumber__c, // <--- ADDED
                EstimatedHoursNumber__c,   // <--- ADDED
                (SELECT Id, Blocking_Ticket__c, Blocking_Ticket__r.Name FROM Ticket_Dependency1__r),
                (SELECT Id, Blocked_Ticket__c, Blocked_Ticket__r.Name FROM Ticket_Dependency__r) 
            FROM Ticket__c
            WHERE IsActiveBool__c = true
            ORDER BY SortOrderNumber__c
        ];
    }

    /**
     * @description Creates demo Ticket__c records and returns them.
     */
    @AuraEnabled
    public static List<Ticket__c> createDummyTickets() {
        List<Ticket__c> demo = new List<Ticket__c>{
            new Ticket__c(
                BriefDescriptionTxt__c='Alpha summary',
                CalculatedETADate__c=Date.today().addDays(7),
                DeveloperDaysSizeNumber__c=2.5,
                StageNamePk__c='Backlog',
                SortOrderNumber__c=1,
                IsActiveBool__c=true
            ),
            new Ticket__c(
                BriefDescriptionTxt__c='Beta scope',
                CalculatedETADate__c=Date.today().addDays(10),
                DeveloperDaysSizeNumber__c=3.0,
                StageNamePk__c='Active Scoping',
                SortOrderNumber__c=1,
                IsActiveBool__c=true
            ),
            new Ticket__c(
                BriefDescriptionTxt__c='Gamma done',
                CalculatedETADate__c=Date.today().addDays(5),
                DeveloperDaysSizeNumber__c=1.75,
                StageNamePk__c='Dev Complete',
                SortOrderNumber__c=1,
                IsActiveBool__c=true
            ),
            new Ticket__c(
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
    public static void updateTicketSortOrders(List<Map<String, Object>> updates) {
        List<Ticket__c> tickets = new List<Ticket__c>();
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
            tickets.add(new Ticket__c(
                Id = (String)u.get('Id'),
                SortOrderNumber__c = sortOrder
            ));
        }
        update tickets;
    }

    @AuraEnabled(cacheable=true)
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
            // Optional: log exception or handle gracefully
            return false;
        }
    }

    @AuraEnabled
    public static void linkFilesToTicket(Id ticketId, List<Id> contentDocumentIds) {
        List<ContentDocumentLink> links = new List<ContentDocumentLink>();
        for (Id docId : contentDocumentIds) {
            links.add(new ContentDocumentLink(
                ContentDocumentId = docId,
                LinkedEntityId = ticketId,
                ShareType = 'V',
                Visibility = 'AllUsers'
            ));
        }
        insert links;
    }

    @AuraEnabled
    public static void linkFilesAndSync(Id ticketId, List<Id> contentDocumentIds) {
        // Step 1: Create the ContentDocumentLink records to officially link files to the ticket
        List<ContentDocumentLink> links = new List<ContentDocumentLink>();
        for (Id docId : contentDocumentIds) {
            links.add(new ContentDocumentLink(
                ContentDocumentId = docId,
                LinkedEntityId = ticketId,
                ShareType = 'V' // 'V' = Viewer, 'I' = Inferred
            ));
        }
        if (!links.isEmpty()) {
            // Use Security.stripInaccessible for FLS compliance
            SObjectAccessDecision decision = Security.stripInaccessible(
                AccessType.CREATABLE, links);
            insert decision.getRecords();
        }

        // Step 2: Call the future method to sync these files to Jira
        AttachmentSyncService.syncFilesToJira(ticketId, contentDocumentIds);
    }

     @AuraEnabled(cacheable=true)
    public static List<String> getRequiredFieldsForStage(String targetStage) {
        // Query the active Kanban Stage Field Requirement metadata record for the target stage.
        List<Kanban_Stage_Field_Requirement__mdt> requirements = [
            SELECT RequiredFieldsTxt__c
            FROM Kanban_Stage_Field_Requirement__mdt
            WHERE IsActiveBool__c = true AND TargetStageTxt__c = :targetStage
            LIMIT 1
        ];

        if (!requirements.isEmpty() && String.isNotBlank(requirements[0].RequiredFieldsTxt__c)) {
            // Split the comma-separated string into a list and trim whitespace from each entry.
            List<String> fieldList = new List<String>();
            for(String field : requirements[0].RequiredFieldsTxt__c.split(',')) {
                fieldList.add(field.trim());
            }
            return fieldList;
        }

        // Return an empty list if no requirements are found.
        return new List<String>();
    }

    /**
     * @description Wrapper class to structure the AI suggestion data returned to the LWC.
     */
    public class AISuggestionWrapper {
        @AuraEnabled public String title { get; set; }
        @AuraEnabled public String description { get; set; }
        @AuraEnabled public Integer estimatedDays { get; set; }
    }

    /**
     * @description Calls OpenAI GPT-4o mini to enhance a ticket's title and description.
     * @param currentTitle The user-entered title.
     * @param currentDescription The user-entered description.
     * @return AISuggestionWrapper An object containing the enhanced details.
     */
    @AuraEnabled
    public static AISuggestionWrapper getAiEnhancedTicketDetails(String currentTitle, String currentDescription) {
        // Input validation
        if (String.isBlank(currentTitle) && String.isBlank(currentDescription)) {
            throw new AuraHandledException('Please provide at least a title or description for AI enhancement.');
        }

        try {
            return callOpenAI(currentTitle, currentDescription);
        } catch (Exception e) {
            // Log the error for debugging
            System.debug('AI Enhancement Error: ' + e.getMessage());
            System.debug('AI Enhancement Stack Trace: ' + e.getStackTraceString());
            
            // Fallback to mock suggestions if OpenAI fails
            return getFallbackSuggestions(currentTitle, currentDescription);
        }
    }

    /**
     * @description Makes HTTP callout to OpenAI GPT-4o mini API
     * @param currentTitle The user-entered title
     * @param currentDescription The user-entered description
     * @return AISuggestionWrapper Enhanced suggestions from OpenAI
     */
    private static AISuggestionWrapper callOpenAI(String currentTitle, String currentDescription) {
        // Get OpenAI API key from custom metadata or custom settings
        String apiKey = getOpenAIApiKey();
        if (String.isBlank(apiKey)) {
            throw new AuraHandledException('OpenAI API key not configured. Please contact your administrator.');
        }

        // Prepare the input text
        String inputText = '';
        if (String.isNotBlank(currentTitle)) {
            inputText += 'Title: ' + currentTitle + '\n';
        }
        if (String.isNotBlank(currentDescription)) {
            inputText += 'Description: ' + currentDescription;
        }

        // Create the prompt for OpenAI
        String prompt = buildOpenAIPrompt(inputText);

        // Prepare the HTTP request
        HttpRequest req = new HttpRequest();
        req.setEndpoint('https://api.openai.com/v1/chat/completions');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('Authorization', 'Bearer ' + apiKey);
        req.setTimeout(30000); // 30 second timeout

        // Build the request body
        Map<String, Object> requestBody = new Map<String, Object>{
            'model' => 'gpt-4o-mini',
            'messages' => new List<Map<String, Object>>{
                new Map<String, Object>{
                    'role' => 'system',
                    'content' => 'You are a helpful assistant that enhances software development tickets. You provide improved titles, detailed descriptions, and realistic development time estimates.'
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

        // Make the HTTP callout
        Http http = new Http();
        HttpResponse res = http.send(req);

        if (res.getStatusCode() != 200) {
            throw new AuraHandledException('OpenAI API error: ' + res.getStatus() + ' - ' + res.getBody());
        }

        // Parse the response
        return parseOpenAIResponse(res.getBody());
    }

    /**
     * @description Builds the prompt for OpenAI to enhance the ticket
     * @param inputText The combined title and description
     * @return String The formatted prompt
     */
    private static String buildOpenAIPrompt(String inputText) {
        return 'Please enhance this software development ticket by providing:\n' +
               '1. An improved, professional title\n' +
               '2. A detailed, comprehensive description with technical requirements\n' +
               '3. A realistic development time estimate in days (1-30 range)\n\n' +
               'Input ticket:\n' + inputText + '\n\n' +
               'Please respond in this exact JSON format:\n' +
               '{\n' +
               '  "title": "Enhanced title here",\n' +
               '  "description": "Detailed description here",\n' +
               '  "estimatedDays": 5\n' +
               '}';
    }

    /**
     * @description Parses OpenAI response and extracts the enhanced ticket details
     * @param responseBody The JSON response from OpenAI
     * @return AISuggestionWrapper The parsed suggestions
     */
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

            // Extract JSON from the content (it might have extra text)
            String jsonContent = extractJsonFromContent(content);
            Map<String, Object> aiResponse = (Map<String, Object>) JSON.deserializeUntyped(jsonContent);

            AISuggestionWrapper suggestions = new AISuggestionWrapper();
            suggestions.title = (String) aiResponse.get('title');
            suggestions.description = (String) aiResponse.get('description');
            
            // Handle estimatedDays as either Integer or Decimal
            Object estimatedDaysObj = aiResponse.get('estimatedDays');
            if (estimatedDaysObj instanceof Integer) {
                suggestions.estimatedDays = (Integer) estimatedDaysObj;
            } else if (estimatedDaysObj instanceof Decimal) {
                suggestions.estimatedDays = ((Decimal) estimatedDaysObj).intValue();
            } else if (estimatedDaysObj instanceof String) {
                suggestions.estimatedDays = Integer.valueOf((String) estimatedDaysObj);
            } else {
                suggestions.estimatedDays = 5; // Default fallback
            }

            // Validate the response
            if (String.isBlank(suggestions.title) || String.isBlank(suggestions.description)) {
                throw new AuraHandledException('Invalid response format from OpenAI');
            }

            return suggestions;

        } catch (Exception e) {
            System.debug('Error parsing OpenAI response: ' + e.getMessage());
            System.debug('Response body: ' + responseBody);
            throw new AuraHandledException('Failed to parse AI response: ' + e.getMessage());
        }
    }

    /**
     * @description Extracts JSON content from OpenAI response text
     * @param content The content string that may contain JSON
     * @return String The extracted JSON string
     */
    private static String extractJsonFromContent(String content) {
        if (String.isBlank(content)) {
            throw new AuraHandledException('Empty content from OpenAI');
        }

        // Look for JSON object boundaries
        Integer startIndex = content.indexOf('{');
        Integer endIndex = content.lastIndexOf('}');

        if (startIndex == -1 || endIndex == -1 || startIndex >= endIndex) {
            throw new AuraHandledException('No valid JSON found in OpenAI response');
        }

        return content.substring(startIndex, endIndex + 1);
    }

    /**
     * @description Gets OpenAI API key from custom metadata or settings
     * @return String The API key
     */
    // private static String getOpenAIApiKey() {
    //     try {
    //         // Try to get from custom metadata first
    //         List<OpenAI_Configuration__mdt> configs = [
    //             SELECT API_Key__c 
    //             FROM OpenAI_Configuration__mdt 
    //             WHERE DeveloperName = 'Default_Config' 
    //             LIMIT 1
    //         ];
            
    //         if (!configs.isEmpty() && String.isNotBlank(configs[0].API_Key__c)) {
    //             return configs[0].API_Key__c;
    //         }

    //         // Fallback: try custom settings
    //         OpenAI_Settings__c settings = OpenAI_Settings__c.getOrgDefaults();
    //         if (settings != null && String.isNotBlank(settings.API_Key__c)) {
    //             return settings.API_Key__c;
    //         }

    //     } catch (Exception e) {
    //         System.debug('Error retrieving OpenAI API key: ' + e.getMessage());
    //     }

    //     return null;
    // }

    private static String getOpenAIApiKey() {
    try {

        Delivery_Hub_Settings__c settings = Delivery_Hub_Settings__c.getOrgDefaults();
        
        // MODIFICATION: Return key only if it's not blank and the API connection has been tested successfully.
        if (settings != null && settings.OpenAiApiTestedBool__c == true && String.isNotBlank(settings.OpenAIApiKeyTxt__c)) {
            System.debug('Giving custom setttngs api key');
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
        System.debug('Error retrieving OpenAI API key: ' + e.getMessage());
    }

    // Return null if no valid and tested key is found
    return null;
}


    /**
     * @description Provides fallback suggestions when OpenAI is unavailable
     * @param currentTitle The user-entered title
     * @param currentDescription The user-entered description
     * @return AISuggestionWrapper Fallback suggestions
     */
    private static AISuggestionWrapper getFallbackSuggestions(String currentTitle, String currentDescription) {
        AISuggestionWrapper suggestions = new AISuggestionWrapper();
        String searchText = ((currentTitle != null ? currentTitle : '') + ' ' + 
                           (currentDescription != null ? currentDescription : '')).toLowerCase();

        // Contextual fallback suggestions based on keywords
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
            // Default generic suggestion with enhanced content
            String enhancedTitle = String.isNotBlank(currentTitle) ? 
                'Enhanced: ' + currentTitle : 'New Feature Implementation';
            suggestions.title = enhancedTitle;
            suggestions.description = 'A comprehensive implementation based on the initial request. This includes clarifying the primary objective, defining clear user impact, outlining detailed acceptance criteria, and establishing proper testing strategies. The solution will follow best practices for code quality, security, and maintainability while ensuring scalable architecture design.';
            suggestions.estimatedDays = 5;
        }
        return suggestions;
    }

    public static AISuggestionWrapper test_parseOpenAIResponse(String responseBody) {
        return parseOpenAIResponse(responseBody);
    }

    public static String test_extractJsonFromContent(String content) {
        return extractJsonFromContent(content);
    }
}
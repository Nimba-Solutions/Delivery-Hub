/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Controller for the deliveryQuickRequest Global Action LWC.
 *              Creates work items with optional AI enhancement via OpenAI.
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.ExcessiveParameterList, PMD.CyclomaticComplexity, PMD.StdCyclomaticComplexity')
public with sharing class DeliveryQuickRequestController {

    /**
     * @description Wrapper returned to the LWC after work item creation.
     */
    public class QuickRequestResult {
        /** @description The Id of the created WorkItem__c record */
        @AuraEnabled public Id recordId { get; set; }
        /** @description The auto-number Name of the created WorkItem__c record */
        @AuraEnabled public String recordName { get; set; }
    }

    /**
     * @description Creates a WorkItem__c from the global quick action.
     *              Optionally fires AI enhancement to populate description,
     *              acceptance criteria, and estimated hours.
     * @param title       The work item title (required).
     * @param priority    Priority level: High, Medium, or Low.
     * @param description Optional user-entered description.
     * @param aiEnhance   When true, calls OpenAI to enhance the record after creation.
     * @return QuickRequestResult containing the created record Id and Name.
     */
    @AuraEnabled
    public static QuickRequestResult createWorkRequest(
        String title, String priority, String description, Boolean aiEnhance
    ) {
        if (String.isBlank(title)) {
            throw new AuraHandledException('Title is required.');
        }

        try {
            // Build the work item
            WorkItem__c wi = new WorkItem__c();
            wi.BriefDescriptionTxt__c = title.trim();
            wi.PriorityPk__c = String.isNotBlank(priority) ? priority : 'Medium';
            wi.StageNamePk__c = 'Backlog';
            wi.IsActiveBool__c = true;
            wi.StatusPk__c = 'New';

            if (String.isNotBlank(description)) {
                wi.DetailsTxt__c = description.trim();
            }

            insert as system wi;

            // Re-query to get the auto-number Name
            WorkItem__c created = [
                SELECT Id, Name
                FROM WorkItem__c
                WHERE Id = :wi.Id
                WITH SYSTEM_MODE
                LIMIT 1
            ];

            // Fire AI enhancement asynchronously if requested
            if (aiEnhance == true) {
                enhanceWithAi(created.Id, title.trim(), description);
            }

            QuickRequestResult result = new QuickRequestResult();
            result.recordId = created.Id;
            result.recordName = created.Name;
            return result;
        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Quick Request creation failed: ' + e.getMessage());
            AuraHandledException ahe = new AuraHandledException(e.getMessage());
            ahe.setMessage(e.getMessage());
            throw ahe;
        }
    }

    /**
     * @description Calls the AI service to enhance a work item with a generated
     *              description, acceptance criteria, and hour estimate. Failures
     *              are swallowed so the user still gets their created work item.
     * @param workItemId  The Id of the work item to enhance.
     * @param title       The original title for AI context.
     * @param description The original description for AI context.
     */
    @SuppressWarnings('PMD.ApexSuggestUsingNamedCred')
    private static void enhanceWithAi(Id workItemId, String title, String description) {
        try {
            DeliveryHubSettings__c settings = DeliveryHubSettings__c.getOrgDefaults();
            if (settings == null || settings.AISuggestionsEnabledBool__c != true) {
                return; // AI not enabled — silently skip
            }
            if (String.isBlank(settings.OpenAIApiKeyTxt__c)) {
                return; // No API key — silently skip
            }

            String model = String.isNotBlank(settings.OpenAIModelTxt__c)
                ? settings.OpenAIModelTxt__c
                : 'gpt-3.5-turbo';

            String prompt = buildEnhancePrompt(title, description);

            HttpRequest req = new HttpRequest();
            req.setEndpoint('https://api.openai.com/v1/chat/completions');
            req.setMethod('POST');
            req.setHeader('Authorization', 'Bearer ' + settings.OpenAIApiKeyTxt__c);
            req.setHeader('Content-Type', 'application/json');
            req.setBody(JSON.serialize(new Map<String, Object>{
                'model'       => model,
                'messages'    => new List<Object>{
                    new Map<String, Object>{ 'role' => 'user', 'content' => prompt }
                },
                'max_tokens'  => 800,
                'temperature' => 0.7
            }));
            req.setTimeout(30000);

            HttpResponse res = new Http().send(req);
            if (res.getStatusCode() != 200) {
                System.debug(LoggingLevel.WARN, 'AI enhance callout failed: HTTP ' + res.getStatusCode());
                return;
            }

            Map<String, Object> responseMap =
                (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            List<Object> choices = (List<Object>) responseMap.get('choices');
            if (choices == null || choices.isEmpty()) {
                return;
            }

            Map<String, Object> msg =
                (Map<String, Object>) ((Map<String, Object>) choices[0]).get('message');
            String content = ((String) msg.get('content')).trim();

            // Parse the structured JSON response
            applyAiEnhancement(workItemId, content);

        } catch (Exception e) {
            // AI enhancement is best-effort — never block the user
            System.debug(LoggingLevel.WARN, 'AI enhancement failed for ' + workItemId + ': ' + e.getMessage());
        }
    }

    /**
     * @description Builds the OpenAI prompt for enhancing a quick-created work item.
     * @param title       The work item title.
     * @param description The optional user description.
     * @return String The constructed prompt text.
     */
    private static String buildEnhancePrompt(String title, String description) {
        String p = 'You are a software delivery manager. Enhance this work request with a professional '
            + 'description, 3-5 testable acceptance criteria, and an hour estimate.\n\n'
            + 'Title: ' + title + '\n';
        if (String.isNotBlank(description)) {
            p += 'Description: ' + description + '\n';
        }
        p += '\nRespond in this exact JSON format:\n'
           + '{\n'
           + '  "description": "A detailed, professional description of the work item",\n'
           + '  "acceptanceCriteria": "- Criterion 1\\n- Criterion 2\\n- Criterion 3",\n'
           + '  "estimatedHours": 8\n'
           + '}\n'
           + 'Return ONLY valid JSON, no markdown fences or extra text.';
        return p;
    }

    /**
     * @description Parses the AI response and updates the work item record.
     * @param workItemId The Id of the work item to update.
     * @param aiContent  The raw JSON string from the AI response.
     */
    private static void applyAiEnhancement(Id workItemId, String aiContent) {
        // Strip markdown code fences if present
        String cleaned = aiContent;
        if (cleaned.startsWith('```')) {
            cleaned = cleaned.replaceFirst('```[a-zA-Z]*\\n?', '');
            cleaned = cleaned.replaceFirst('```\\s*$', '');
            cleaned = cleaned.trim();
        }

        Map<String, Object> aiData = (Map<String, Object>) JSON.deserializeUntyped(cleaned);

        WorkItem__c wi = new WorkItem__c(Id = workItemId);

        String aiDesc = (String) aiData.get('description');
        if (String.isNotBlank(aiDesc)) {
            wi.DetailsTxt__c = aiDesc;
        }

        String aiCriteria = (String) aiData.get('acceptanceCriteria');
        if (String.isNotBlank(aiCriteria)) {
            wi.AcceptanceCriteriaTxt__c = aiCriteria;
        }

        Object hoursObj = aiData.get('estimatedHours');
        if (hoursObj != null) {
            wi.EstimatedHoursNumber__c = Double.valueOf(String.valueOf(hoursObj));
        }

        update as system wi;
    }
}

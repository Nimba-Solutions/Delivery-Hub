/**
 * @description Handles AI-powered features for Delivery Hub:
 *              - draftStatusUpdate: drafts a client-facing status update for a single work item
 *              - suggestAcceptanceCriteria: proposes testable acceptance criteria for a work item
 *              - draftBoardSummary: generates a weekly status summary across all active work items
 *              - draftReleaseNotes: generates formatted release notes for recently completed work items
 * @author Cloud Nimbus LLC
 */
// Complexity is distributed across many small, focused helper methods — aggregate is expected.
@SuppressWarnings('PMD.CyclomaticComplexity')
public with sharing class DeliveryAiController {

    /**
     * @description Generates a professional client-facing status update for a work item
     *              using the OpenAI API. Throws AuraHandledException if AI is not configured.
     * @param workItemId The Id of the WorkItem__c record to draft an update for.
     * @return String The drafted status update text.
     */
    @AuraEnabled
    public static String draftStatusUpdate(Id workItemId) {
        Delivery_Hub_Settings__c settings = getValidatedSettings();

        List<WorkItem__c> workItems = [
            SELECT Name, BriefDescriptionTxt__c, StageNamePk__c, PriorityPk__c,
                   EstimatedHoursNumber__c, TotalLoggedHoursNumber__c,
                   ProjectedUATReadyDate__c, AcceptanceCriteriaTxt__c
            FROM WorkItem__c
            WHERE Id = :workItemId
            WITH SYSTEM_MODE
            LIMIT 1
        ];

        if (workItems.isEmpty()) {
            throw new AuraHandledException('Work Item not found.');
        }

        String model = getModel(settings);
        return callOpenAi(settings.OpenAIApiKeyTxt__c, model, buildStatusPrompt(workItems[0]));
    }

    /**
     * @description Suggests 3-5 testable acceptance criteria for a work item
     *              based on its title and details, using the OpenAI API.
     * @param workItemId The Id of the WorkItem__c to generate criteria for.
     * @return String Bulleted acceptance criteria text.
     */
    @AuraEnabled
    public static String suggestAcceptanceCriteria(Id workItemId) {
        Delivery_Hub_Settings__c settings = getValidatedSettings();

        List<WorkItem__c> workItems = [
            SELECT BriefDescriptionTxt__c, DetailsTxt__c, StageNamePk__c
            FROM WorkItem__c
            WHERE Id = :workItemId
            WITH SYSTEM_MODE
            LIMIT 1
        ];

        if (workItems.isEmpty()) {
            throw new AuraHandledException('Work Item not found.');
        }

        String model = getModel(settings);
        return callOpenAi(settings.OpenAIApiKeyTxt__c, model, buildCriteriaPrompt(workItems[0]));
    }

    /**
     * @description Generates a weekly board-level status summary across all active work items,
     *              grouped by stage. Suitable for a client-facing weekly update email.
     * @return String The generated weekly status text.
     */
    @AuraEnabled
    public static String draftBoardSummary() {
        Delivery_Hub_Settings__c settings = getValidatedSettings();

        List<WorkItem__c> workItems = [
            SELECT Name, BriefDescriptionTxt__c, StageNamePk__c, PriorityPk__c
            FROM WorkItem__c
            WHERE IsActiveBool__c = true
            WITH SYSTEM_MODE
            ORDER BY StageNamePk__c, SortOrderNumber__c
        ];

        if (workItems.isEmpty()) {
            throw new AuraHandledException('No active work items found to summarise.');
        }

        String model = getModel(settings);
        return callOpenAi(settings.OpenAIApiKeyTxt__c, model, buildBoardSummaryPrompt(workItems));
    }

    /**
     * @description Generates formatted release notes for work items completed in the past 30 days.
     *              Queries work items in 'Done' or 'Deployed to Prod' stages and passes them to
     *              the OpenAI API to produce a client-friendly changelog.
     * @return String The generated release notes text.
     */
    @AuraEnabled
    public static String draftReleaseNotes() {
        Delivery_Hub_Settings__c settings = getValidatedSettings();

        List<WorkItem__c> workItems = [
            SELECT Name, BriefDescriptionTxt__c, StageNamePk__c, PriorityPk__c
            FROM WorkItem__c
            WHERE StageNamePk__c IN ('Done', 'Deployed to Prod')
            AND LastModifiedDate >= :Datetime.now().addDays(-30)
            WITH SYSTEM_MODE
            ORDER BY PriorityPk__c, Name
        ];

        if (workItems.isEmpty()) {
            throw new AuraHandledException(
                'No work items were completed or deployed in the last 30 days.'
            );
        }

        String model = getModel(settings);
        return callOpenAi(settings.OpenAIApiKeyTxt__c, model, buildReleaseNotesPrompt(workItems));
    }

    // ── Private helpers ──────────────────────────────────────────────────────

    /**
     * @description Reads and validates org AI settings. Throws if AI is not enabled
     *              or the API key is missing.
     * @return Delivery_Hub_Settings__c The validated settings record.
     */
    private static Delivery_Hub_Settings__c getValidatedSettings() {
        Delivery_Hub_Settings__c settings = Delivery_Hub_Settings__c.getOrgDefaults();
        if (settings == null || settings.AISuggestionsEnabledBool__c != true) {
            throw new AuraHandledException(
                'AI features are not enabled. Turn them on in Delivery Hub \u2192 AI Settings.'
            );
        }
        if (String.isBlank(settings.OpenAIApiKeyTxt__c)) {
            throw new AuraHandledException(
                'No OpenAI API key found. Add and test your key in Delivery Hub \u2192 AI Settings.'
            );
        }
        return settings;
    }

    /**
     * @description Returns the configured model, falling back to gpt-3.5-turbo.
     * @param settings The Delivery_Hub_Settings__c record.
     * @return String Model identifier string.
     */
    private static String getModel(Delivery_Hub_Settings__c settings) {
        return String.isNotBlank(settings.OpenAIModelTxt__c)
            ? settings.OpenAIModelTxt__c
            : 'gpt-3.5-turbo';
    }

    /**
     * @description Sends a prompt to the OpenAI chat completions endpoint and returns
     *              the text content of the first choice.
     * @param apiKey  The OpenAI API key (Bearer token).
     * @param model   The OpenAI model identifier (e.g. gpt-3.5-turbo).
     * @param prompt  The user message to send.
     * @return String The trimmed response text.
     */
    @SuppressWarnings('PMD.ApexSuggestUsingNamedCred')
    private static String callOpenAi(String apiKey, String model, String prompt) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint('https://api.openai.com/v1/chat/completions');
        req.setMethod('POST');
        req.setHeader('Authorization', 'Bearer ' + apiKey);
        req.setHeader('Content-Type', 'application/json');
        req.setBody(JSON.serialize(new Map<String, Object>{
            'model'       => model,
            'messages'    => new List<Object>{
                new Map<String, Object>{ 'role' => 'user', 'content' => prompt }
            },
            'max_tokens'  => 600,
            'temperature' => 0.7
        }));
        req.setTimeout(30000);

        HttpResponse res = new Http().send(req);

        if (res.getStatusCode() != 200) {
            throw new AuraHandledException(
                'OpenAI returned an error (' + res.getStatusCode() + '). '
                + 'Verify your API key is active and try again.'
            );
        }

        Map<String, Object> responseMap =
            (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        List<Object> choices = (List<Object>) responseMap.get('choices');

        if (choices == null || choices.isEmpty()) {
            throw new AuraHandledException('No response received from OpenAI. Please try again.');
        }

        Map<String, Object> msg =
            (Map<String, Object>) ((Map<String, Object>) choices[0]).get('message');
        return ((String) msg.get('content')).trim();
    }

    private static String buildStatusPrompt(WorkItem__c t) {
        String brief = String.isNotBlank(t.BriefDescriptionTxt__c)
            ? t.BriefDescriptionTxt__c : 'No title provided';

        String p = 'You are a professional software delivery manager writing a brief status '
            + 'update for a non-technical client.\n\n';
        p += 'Work Item: ' + t.Name + '\n';
        p += 'Title: '  + brief  + '\n';
        p += 'Current Stage: ' + (t.StageNamePk__c != null ? t.StageNamePk__c : 'Unknown') + '\n';

        if (String.isNotBlank(t.PriorityPk__c)) {
            p += 'Priority: ' + t.PriorityPk__c + '\n';
        }
        if (t.EstimatedHoursNumber__c != null) {
            p += 'Estimated Hours: ' + t.EstimatedHoursNumber__c + '\n';
        }
        if (t.TotalLoggedHoursNumber__c != null) {
            p += 'Hours Logged: ' + t.TotalLoggedHoursNumber__c + '\n';
        }
        if (t.ProjectedUATReadyDate__c != null) {
            p += 'Target UAT Date: ' + t.ProjectedUATReadyDate__c.format() + '\n';
        }
        if (String.isNotBlank(t.AcceptanceCriteriaTxt__c)) {
            p += 'Acceptance Criteria: ' + stripHtml(t.AcceptanceCriteriaTxt__c) + '\n';
        }

        p += '\nWrite a concise 2-3 sentence status update to send directly to the client. '
           + 'Be professional and focus on current progress and what comes next. '
           + 'Translate any technical stage names into plain language the client will understand. '
           + 'Do not include work item IDs, greetings, sign-offs, or subject lines. '
           + 'Return ONLY the status update text.';

        return p;
    }

    private static String buildCriteriaPrompt(WorkItem__c t) {
        String brief = String.isNotBlank(t.BriefDescriptionTxt__c)
            ? t.BriefDescriptionTxt__c : 'No title provided';
        String details = String.isNotBlank(t.DetailsTxt__c) ? stripHtml(t.DetailsTxt__c) : '';

        String p = 'You are a software business analyst. Based on the following work item, '
            + 'write 3-5 clear, testable acceptance criteria.\n\n'
            + 'Work Item: ' + brief + '\n';
        if (String.isNotBlank(details)) {
            p += 'Details: ' + details + '\n';
        }
        p += '\nUse simple bullet points starting with "- ". '
           + 'Each criterion should be specific and verifiable. '
           + 'Return ONLY the bulleted list, no preamble or sign-off.';
        return p;
    }

    private static String buildBoardSummaryPrompt(List<WorkItem__c> workItems) {
        Map<String, List<String>> byStage = new Map<String, List<String>>();
        for (WorkItem__c t : workItems) {
            String stage = t.StageNamePk__c != null ? t.StageNamePk__c : 'Unknown';
            if (!byStage.containsKey(stage)) {
                byStage.put(stage, new List<String>());
            }
            String title = String.isNotBlank(t.BriefDescriptionTxt__c)
                ? t.BriefDescriptionTxt__c : t.Name;
            byStage.get(stage).add(title);
        }

        String p = 'You are a software delivery manager. Write a concise weekly status update '
            + 'for a non-technical client, covering all active work grouped by stage.\n\n'
            + 'Active Work Items by Stage:\n';

        for (String stage : byStage.keySet()) {
            p += '\n[' + stage + ']\n';
            for (String title : byStage.get(stage)) {
                p += '- ' + title + '\n';
            }
        }

        p += '\nWrite 2-4 short paragraphs in plain English. Translate stage names (e.g. '
           + '"In Development" → "actively being built"). Highlight what is wrapping up and '
           + 'what is coming next. Be professional and encouraging. '
           + 'Return ONLY the status update text.';
        return p;
    }

    private static String buildReleaseNotesPrompt(List<WorkItem__c> workItems) {
        List<String> lines = new List<String>();
        for (WorkItem__c t : workItems) {
            String title = String.isNotBlank(t.BriefDescriptionTxt__c)
                ? t.BriefDescriptionTxt__c : t.Name;
            lines.add('- [' + t.StageNamePk__c + '] ' + title);
        }
        return 'You are a technical product manager writing a client-facing release notes summary. '
            + 'Based on the completed work items below, write concise, professional release notes '
            + 'suitable for a client email or changelog. Group related items where possible. '
            + 'Use plain language, avoid jargon, and highlight user impact. '
            + 'Format with a brief intro sentence, then a bulleted list.\n\n'
            + 'Completed Work Items:\n' + String.join(lines, '\n') + '\n\n'
            + 'Return ONLY the release notes text, no subject lines or sign-offs.';
    }

    private static String stripHtml(String html) {
        return html.replaceAll('<[^>]+>', ' ').replaceAll('\\s+', ' ').trim();
    }
}

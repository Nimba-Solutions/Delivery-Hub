/**
 * @description Handles AI-powered features for Delivery Hub, including drafting
 *              client-facing status updates via the OpenAI API.
 * @author Cloud Nimbus LLC
 */
public with sharing class DeliveryAiController {

    /**
     * @description Generates a professional client-facing status update for a ticket
     *              using the OpenAI API. Reads the org-level AI settings; throws a
     *              user-friendly AuraHandledException if AI is not configured.
     * @param ticketId The Id of the Ticket__c record to draft an update for.
     * @return String The drafted status update text.
     */
    @AuraEnabled
    @SuppressWarnings('PMD.ApexSuggestUsingNamedCred')
    public static String draftStatusUpdate(Id ticketId) {
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

        List<Ticket__c> tickets = [
            SELECT Name, BriefDescriptionTxt__c, StageNamePk__c, PriorityPk__c,
                   EstimatedHoursNumber__c, TotalLoggedHoursNumber__c,
                   ProjectedUATReadyDate__c, AcceptanceCriteriaTxt__c
            FROM Ticket__c
            WHERE Id = :ticketId
            WITH SYSTEM_MODE
            LIMIT 1
        ];

        if (tickets.isEmpty()) {
            throw new AuraHandledException('Ticket not found.');
        }

        String model = String.isNotBlank(settings.OpenAIModelTxt__c)
            ? settings.OpenAIModelTxt__c
            : 'gpt-3.5-turbo';

        String prompt = buildPrompt(tickets[0]);

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
            'max_tokens'  => 200,
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

    // ── Private helpers ──────────────────────────────────────────────────────

    private static String buildPrompt(Ticket__c t) {
        String brief = String.isNotBlank(t.BriefDescriptionTxt__c)
            ? t.BriefDescriptionTxt__c : 'No title provided';

        String p = 'You are a professional software delivery manager writing a brief status '
            + 'update for a non-technical client.\n\n';
        p += 'Ticket: ' + t.Name + '\n';
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
           + 'Do not include ticket IDs, greetings, sign-offs, or subject lines. '
           + 'Return ONLY the status update text.';

        return p;
    }

    private static String stripHtml(String html) {
        return html.replaceAll('<[^>]+>', ' ').replaceAll('\\s+', ' ').trim();
    }
}

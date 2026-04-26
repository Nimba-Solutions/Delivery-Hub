/**
 * @name         Delivery Hub · Integration Framework
 * @license      BSL 1.1 — See LICENSE.md
 * @description IIntegrationSink reference implementation for OpenAI chat
 *              completions. Refactored from DeliveryAiController.cls:197 (which
 *              hardcoded the endpoint URL and read API key from
 *              DeliveryHubSettings__c.OpenAIApiKeyTxt__c). This provider:
 *                - Reads endpoint via Named Credential reference
 *                  (NamedCredentialDevNameTxt__c on the IntegrationProvider__mdt)
 *                - Lets subscribers swap the model via EndpointPathTxt__c
 *                  template (default: /v1/chat/completions)
 *                - Returns structured IntegrationSinkResult instead of raising
 *                  the bespoke DeliveryHubException
 *
 *              DeliveryAiController itself is NOT migrated in this PR — it
 *              continues to use the old direct-callout path. Migration to
 *              IntegrationDispatcher is a follow-up PR after this framework
 *              merge stabilizes (see /mf/integration-spike-0426 review
 *              questions). Reason: separating "framework lands" from "callers
 *              switch" lets us roll back either independently.
 *
 *              Payload shape this provider expects:
 *                {
 *                  'model': String           // e.g. 'gpt-3.5-turbo'
 *                  'prompt': String          // user message (required)
 *                  'maxTokens': Integer      // optional · default 600
 *                  'temperature': Decimal    // optional · default 0.7
 *                }
 *
 *              Result.responseBodySnippet contains the first choice's content
 *              as text on success.
 *
 * @author       Cloud Nimbus LLC
 * @since        2026-04-26
 */
// HTTP-handler with status-code mapping + optional payload params has
// legitimate branching — suppressing cyclomatic rules per the same
// pattern other DH callout classes use.
@SuppressWarnings('PMD.CyclomaticComplexity, PMD.StdCyclomaticComplexity')
public with sharing class OpenAiCompletionsProvider implements IIntegrationSink {

    private static final Integer DEFAULT_MAX_TOKENS = 600;
    private static final Decimal DEFAULT_TEMPERATURE = 0.7;
    private static final String DEFAULT_PATH = '/v1/chat/completions';
    private static final String DEFAULT_MODEL = 'gpt-3.5-turbo';

    /**
     * @description Send a chat completion request to OpenAI.
     * @param payload Map with required 'prompt' (String) and optional
     *                'model' / 'maxTokens' / 'temperature' overrides.
     * @param providerConfig Resolved IntegrationProvider__mdt — reads
     *                       NamedCredentialDevNameTxt__c (required) and
     *                       EndpointPathTxt__c (optional, defaults to
     *                       /v1/chat/completions).
     * @return IntegrationSinkResult — Sent on 200, RetryableFailure on 5xx
     *         or network error, TerminalFailure on 4xx or missing config.
     */
    @SuppressWarnings('PMD.CyclomaticComplexity, PMD.StdCyclomaticComplexity')
    public IntegrationSinkResult send(Map<String, Object> payload, IntegrationProvider__mdt providerConfig) {
        if (payload == null || !payload.containsKey('prompt')
            || String.isBlank((String) payload.get('prompt'))) {
            return IntegrationSinkResult.terminal(
                'Payload missing required key: prompt', null);
        }
        if (String.isBlank(providerConfig.NamedCredentialDevNameTxt__c)) {
            return IntegrationSinkResult.terminal(
                'Provider ' + providerConfig.DeveloperName
                    + ' has no Named Credential configured', null);
        }

        String path = String.isNotBlank(providerConfig.EndpointPathTxt__c)
            ? providerConfig.EndpointPathTxt__c
            : DEFAULT_PATH;
        String model = payload.containsKey('model')
            && String.isNotBlank((String) payload.get('model'))
                ? (String) payload.get('model')
                : DEFAULT_MODEL;
        Integer maxTokens = payload.containsKey('maxTokens') && payload.get('maxTokens') != null
            ? (Integer) payload.get('maxTokens')
            : DEFAULT_MAX_TOKENS;
        Decimal temperature = payload.containsKey('temperature') && payload.get('temperature') != null
            ? (Decimal) payload.get('temperature')
            : DEFAULT_TEMPERATURE;

        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:' + providerConfig.NamedCredentialDevNameTxt__c + path);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setBody(JSON.serialize(new Map<String, Object>{
            'model'       => model,
            'messages'    => new List<Object>{
                new Map<String, Object>{ 'role' => 'user', 'content' => (String) payload.get('prompt') }
            },
            'max_tokens'  => maxTokens,
            'temperature' => temperature
        }));
        req.setTimeout(30000);

        try {
            HttpResponse res = new Http().send(req);
            Integer code = res.getStatusCode();
            String body = res.getBody();
            if (code == 200) {
                return parseSuccessfulCompletion(body);
            }
            if (code >= 400 && code < 500) {
                return IntegrationSinkResult.terminal(
                    'OpenAI ' + code + ': ' + body, body);
            }
            return IntegrationSinkResult.retryable(
                'OpenAI ' + code, body);
        } catch (CalloutException e) {
            return IntegrationSinkResult.retryable(
                'OpenAI callout exception: ' + e.getMessage(), null);
        }
    }

    /**
     * @description Health-check the OpenAI connection by issuing a minimal
     *              completion request. 200 / 401 / 429 all confirm the
     *              endpoint is live and the credential is at least known.
     * @param providerConfig Resolved provider config.
     * @return true when the connection is usable.
     */
    @SuppressWarnings('PMD.CyclomaticComplexity, PMD.StdCyclomaticComplexity')
    public Boolean validateConnection(IntegrationProvider__mdt providerConfig) {
        if (String.isBlank(providerConfig.NamedCredentialDevNameTxt__c)) {
            return false;
        }
        String path = String.isNotBlank(providerConfig.EndpointPathTxt__c)
            ? providerConfig.EndpointPathTxt__c
            : DEFAULT_PATH;
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:' + providerConfig.NamedCredentialDevNameTxt__c + path);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setBody('{"model":"' + DEFAULT_MODEL
            + '","messages":[{"role":"user","content":"ping"}],"max_tokens":1}');
        req.setTimeout(10000);
        try {
            HttpResponse res = new Http().send(req);
            Integer code = res.getStatusCode();
            // 200: success. 401: bad key but endpoint live. 429: rate-limited
            // but endpoint live. 4xx others / 5xx are unhealthy for our purposes.
            return code == 200 || code == 401 || code == 429;
        } catch (CalloutException e) {
            return false;
        }
    }

    /**
     * @description Parse a 200 OpenAI response. Extracts the first choice's
     *              message content into responseBodySnippet on the result.
     * @param body OpenAI response JSON body.
     * @return IntegrationSinkResult with statusCode='Sent' and snippet populated.
     */
    @TestVisible
    private IntegrationSinkResult parseSuccessfulCompletion(String body) {
        try {
            Map<String, Object> responseMap =
                (Map<String, Object>) JSON.deserializeUntyped(body);
            List<Object> choices = (List<Object>) responseMap.get('choices');
            if (choices == null || choices.isEmpty()) {
                return IntegrationSinkResult.retryable(
                    'OpenAI returned no choices', body);
            }
            Map<String, Object> firstChoice = (Map<String, Object>) choices[0];
            Map<String, Object> msg = (Map<String, Object>) firstChoice.get('message');
            String content = msg != null ? (String) msg.get('content') : null;
            IntegrationSinkResult r = IntegrationSinkResult.success(null);
            r.responseBodySnippet = content == null ? null : content.left(4000);
            return r;
        } catch (Exception e) {
            return IntegrationSinkResult.retryable(
                'Failed to parse OpenAI response: ' + e.getMessage(), body);
        }
    }
}

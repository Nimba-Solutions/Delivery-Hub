/**
 * @name         Delivery Hub · Integration Framework
 * @license      BSL 1.1 — See LICENSE.md
 * @description Reference IIntegrationSink implementation. Posts plaintext-message
 *              payloads to a Slack incoming webhook.
 *
 *              Today the package has DeliveryEscalationNotifService.cls:150
 *              hardcoding a Slack callout to settings.SlackWebhookUrlTxt__c.
 *              That class is left intact in this spike — we don't refactor
 *              callers in the same PR that introduces the framework. The next
 *              PR migrates DeliveryEscalationNotifService to call
 *              IntegrationDispatcher.dispatchSink('Slack_Webhook', payload).
 *
 *              Provider config record (seeded by ./IntegrationProvider.Slack_Webhook.md-meta.xml):
 *                DeveloperName: Slack_Webhook
 *                Type: Sink
 *                Enabled: not enabled by default — admin sets when ready
 *                ApexClassName: SlackWebhookProvider
 *                NamedCredential: Slack_Webhook (admin creates post-install)
 *                EndpointPath: (blank — Slack incoming-webhook URL is the full host)
 *
 *              Payload shape this provider expects:
 *                {
 *                  'text': String        // Slack message body (required)
 *                }
 *
 * @author       Cloud Nimbus LLC
 * @since        2026-04-26
 */
// HTTP-handler classes have legitimate branching (status-code mapping,
// error categorization) — suppressing cyclomatic complexity rules below
// per platform pattern (other DH callout classes use the same approach).
@SuppressWarnings('PMD.CyclomaticComplexity, PMD.StdCyclomaticComplexity')
public with sharing class SlackWebhookProvider implements IIntegrationSink {

    /**
     * @description Send a Slack message via incoming webhook.
     * @param payload Map with key 'text' (required).
     * @param providerConfig Resolved IntegrationProvider__mdt — provides
     *                       NamedCredentialDevNameTxt__c.
     * @return IntegrationSinkResult with statusCode in
     *         {Sent, RetryableFailure, TerminalFailure}.
     */
    public IntegrationSinkResult send(Map<String, Object> payload, IntegrationProvider__mdt providerConfig) {
        if (payload == null || !payload.containsKey('text') || String.isBlank((String) payload.get('text'))) {
            return IntegrationSinkResult.terminal('Payload missing required key: text', null);
        }
        if (String.isBlank(providerConfig.NamedCredentialDevNameTxt__c)) {
            return IntegrationSinkResult.terminal(
                'Provider ' + providerConfig.DeveloperName + ' has no Named Credential configured', null);
        }

        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:' + providerConfig.NamedCredentialDevNameTxt__c);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setBody(JSON.serialize(new Map<String, Object>{
            'text' => (String) payload.get('text')
        }));
        req.setTimeout(30000);

        try {
            HttpResponse res = new Http().send(req);
            Integer code = res.getStatusCode();
            String body = res.getBody();
            if (code >= 200 && code < 300) {
                // Slack returns 'ok' as a literal text body for incoming webhooks.
                return IntegrationSinkResult.success(null);
            }
            // Slack 4xx for malformed payload, 5xx for transient. Map accordingly.
            if (code >= 400 && code < 500) {
                return IntegrationSinkResult.terminal('Slack ' + code + ': ' + body, body);
            }
            return IntegrationSinkResult.retryable('Slack ' + code, body);
        } catch (CalloutException e) {
            return IntegrationSinkResult.retryable('Slack callout exception: ' + e.getMessage(), null);
        }
    }

    /**
     * @description Health-check the Slack webhook by sending an empty-body POST.
     *              Slack returns 400 "no_text" on empty body — that's a valid
     *              signal the URL is live and accepting our credential. 404 or
     *              connection refused indicates the webhook URL is dead.
     */
    public Boolean validateConnection(IntegrationProvider__mdt providerConfig) {
        if (String.isBlank(providerConfig.NamedCredentialDevNameTxt__c)) {
            return false;
        }
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:' + providerConfig.NamedCredentialDevNameTxt__c);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setBody('{}');
        req.setTimeout(10000);
        try {
            HttpResponse res = new Http().send(req);
            // Both 200 (success) and 400 (validation error from Slack) confirm
            // the webhook URL is live and our credential routed correctly.
            // 401/403/404 mean dead URL or revoked.
            Integer code = res.getStatusCode();
            return code == 200 || code == 400;
        } catch (CalloutException e) {
            return false;
        }
    }
}

/**
 * @description Posts stage-change and test notifications to Slack via Incoming Webhooks.
 *              Stage-change messages are sent asynchronously (@future) from trigger context.
 *              The test-connection method runs synchronously from an LWC user action.
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.ApexSuggestUsingNamedCred')
public with sharing class DeliverySlackService {

    // ── Public API ───────────────────────────────────────────────────────────

    /**
     * @description Asynchronously posts a stage-change notification to Slack.
     *              Reads the webhook URL from org-default Custom Settings.
     *              No-ops silently if Slack is not configured.
     * @param workItemNameToStage Map of Work Item Name → new stage label
     */
    @future(callout=true)
    public static void postStageChanges(Map<String, String> workItemNameToStage) {
        Delivery_Hub_Settings__c settings = Delivery_Hub_Settings__c.getOrgDefaults();
        if (settings == null || String.isBlank(settings.SlackWebhookUrl__c)) {
            return;
        }
        post(settings.SlackWebhookUrl__c, buildStagePayload(workItemNameToStage));
    }

    /**
     * @description Tests the provided Slack webhook by posting a confirmation message.
     *              Called directly from the settings LWC via user action (no DML context).
     * @param webhookUrl The Slack Incoming Webhook URL to test
     * @return String 'Success' on 200, otherwise an error description
     */
    @AuraEnabled
    public static String testWebhook(String webhookUrl) {
        if (String.isBlank(webhookUrl)) {
            throw new AuraHandledException('Please enter a Slack Webhook URL first.');
        }
        String payload = JSON.serialize(new Map<String, Object>{
            'text' => ':white_check_mark: *Delivery Hub* is now connected to this Slack channel.'
        });
        HttpResponse res = post(webhookUrl, payload);
        if (res != null && res.getStatusCode() == 200) {
            return 'Success';
        }
        Integer code = res != null ? res.getStatusCode() : 0;
        return 'Failed (' + code + '): check your webhook URL and try again.';
    }

    // ── Private helpers ──────────────────────────────────────────────────────

    /**
     * @description Sends a JSON payload to the given Slack Incoming Webhook URL.
     * @param url  The Slack webhook endpoint
     * @param body The serialised JSON payload
     * @return HttpResponse or null if the callout threw
     */
    private static HttpResponse post(String url, String body) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(url);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setBody(body);
        req.setTimeout(10000);
        try {
            return new Http().send(req);
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, '[DeliverySlackService] callout failed: ' + e.getMessage());
            return null;
        }
    }

    /**
     * @description Builds a Slack Block Kit payload listing work item stage changes.
     * @param workItemNameToStage Map of work item Name → new stage
     * @return Serialised JSON string
     */
    private static String buildStagePayload(Map<String, String> workItemNameToStage) {
        List<String> lines = new List<String>();
        for (String name : workItemNameToStage.keySet()) {
            lines.add('\u2022 *' + name + '* \u2192 `' + workItemNameToStage.get(name) + '`');
        }
        String text = ':arrows_counterclockwise: *Work Item Stage Update*\n' + String.join(lines, '\n');
        return JSON.serialize(new Map<String, Object>{
            'blocks' => new List<Object>{
                new Map<String, Object>{
                    'type' => 'section',
                    'text' => new Map<String, Object>{
                        'type' => 'mrkdwn',
                        'text' => text
                    }
                }
            }
        });
    }
}

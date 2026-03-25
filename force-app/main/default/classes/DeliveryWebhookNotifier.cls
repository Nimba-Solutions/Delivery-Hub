/**
 * @name         Delivery Hub
 * @license      BSL 1.1 — See LICENSE.md
 * @description Queueable that pushes platform-event payloads to a configurable
 *              external webhook URL. Fires when DeliverySync__e or DeliveryDocEvent__e
 *              platform events are published, allowing external systems (e.g. the
 *              client portal) to react in real-time without polling.
 *              The webhook URL is stored in DeliveryHubSettings__c.WebhookUrlTxt__c.
 * @author Cloud Nimbus LLC
 */
@SuppressWarnings('PMD.ApexSuggestUsingNamedCred')
public with sharing class DeliveryWebhookNotifier implements Queueable, Database.AllowsCallouts {

    private final List<Map<String, Object>> payloads;

    /**
     * @description Constructs the notifier with a pre-built list of event payloads.
     * @param payloads List of maps, each representing one event to deliver
     */
    public DeliveryWebhookNotifier(List<Map<String, Object>> payloads) {
        this.payloads = payloads;
    }

    // ── Queueable entry point ──────────────────────────────────────────────

    /**
     * @description Reads the webhook URL from settings and POSTs each payload.
     *              Silently no-ops if the URL is blank. Logs failures via
     *              System.debug rather than throwing so the job never breaks
     *              the platform-event subscription.
     * @param context The QueueableContext provided by the Apex runtime
     */
    public void execute(QueueableContext context) {
        DeliveryHubSettings__c settings = DeliveryHubSettings__c.getOrgDefaults();
        if (settings == null || String.isBlank(settings.WebhookUrlTxt__c)) {
            return;
        }
        String webhookUrl = settings.WebhookUrlTxt__c;

        for (Map<String, Object> payload : payloads) {
            post(webhookUrl, JSON.serialize(payload));
        }
    }

    // ── Static factory helpers (called from triggers) ──────────────────────

    /**
     * @description Builds payloads from DeliverySync__e events and enqueues
     *              the notifier. Called from the platform event trigger.
     * @param events The list of DeliverySync__e records from Trigger.new
     */
    public static void enqueueSyncEvents(List<DeliverySync__e> events) {
        // Fast-exit if webhook not configured — avoids unnecessary queueable
        DeliveryHubSettings__c settings = DeliveryHubSettings__c.getOrgDefaults();
        if (settings == null || String.isBlank(settings.WebhookUrlTxt__c)) {
            return;
        }

        List<Map<String, Object>> payloads = new List<Map<String, Object>>();
        for (DeliverySync__e evt : events) {
            payloads.add(new Map<String, Object>{
                'eventType'  => 'DeliverySync',
                'objectType' => evt.ObjectTypePk__c,
                'direction'  => evt.DirectionPk__c,
                'status'     => evt.StatusPk__c,
                'recordId'   => evt.RecordIdTxt__c,
                'error'      => evt.ErrorMessageTxt__c,
                'timestamp'  => Datetime.now().formatGmt('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\'')
            });
        }

        if (!payloads.isEmpty()) {
            System.enqueueJob(new DeliveryWebhookNotifier(payloads));
        }
    }

    /**
     * @description Builds payloads from DeliveryDocEvent__e events and enqueues
     *              the notifier. Called from the platform event trigger.
     * @param events The list of DeliveryDocEvent__e records from Trigger.new
     */
    public static void enqueueDocEvents(List<DeliveryDocEvent__e> events) {
        // Fast-exit if webhook not configured
        DeliveryHubSettings__c settings = DeliveryHubSettings__c.getOrgDefaults();
        if (settings == null || String.isBlank(settings.WebhookUrlTxt__c)) {
            return;
        }

        List<Map<String, Object>> payloads = new List<Map<String, Object>>();
        for (DeliveryDocEvent__e evt : events) {
            payloads.add(new Map<String, Object>{
                'eventType'  => 'DeliveryDocEvent',
                'documentId' => evt.DocumentIdTxt__c,
                'entityName' => evt.EntityNameTxt__c,
                'status'     => evt.StatusPk__c,
                'template'   => evt.TemplatePk__c,
                'timestamp'  => Datetime.now().formatGmt('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\'')
            });
        }

        if (!payloads.isEmpty()) {
            System.enqueueJob(new DeliveryWebhookNotifier(payloads));
        }
    }

    // ── Private HTTP helper ────────────────────────────────────────────────

    /**
     * @description Sends a JSON payload to the webhook URL via HTTP POST.
     *              Failures are logged but never rethrown.
     * @param url  The webhook endpoint
     * @param body The serialised JSON payload
     */
    private static void post(String url, String body) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(url);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setBody(body);
        req.setTimeout(10000);
        try {
            HttpResponse res = new Http().send(req);
            if (res.getStatusCode() >= 400) {
                System.debug(LoggingLevel.WARN,
                    '[DeliveryWebhookNotifier] POST failed (' + res.getStatusCode() + '): ' + res.getBody());
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN,
                '[DeliveryWebhookNotifier] callout error: ' + e.getMessage());
        }
    }
}
